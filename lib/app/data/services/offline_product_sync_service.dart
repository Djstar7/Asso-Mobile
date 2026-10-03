import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path/path.dart' as p;

import '../../core/utils/app_design.dart';
import '../models/category_catalog.dart';
import '../models/pending_product.dart';
import '../providers/api_provider.dart';
import '../providers/offline_store.dart';
import '../providers/product_service.dart';
import '../providers/storage_service.dart';
import 'connectivity_service.dart';

/// Produits créés hors ligne : mise en file, puis envoi au serveur dès que la
/// connexion revient.
///
/// Les envois partent un par un, dans l'ordre de saisie, chacun avec sa
/// référence (`client_reference`) : un renvoi ne crée jamais de doublon.
/// Avant l'envoi, la catégorie de chaque fiche est vérifiée sur la liste
/// fraîche du serveur (voir [CategoryCatalog]) : seuls des identifiants qui
/// existent en base partent.
///
/// Selon la réponse :
/// - créé (ou déjà créé lors d'un envoi précédent) → retiré de la file,
///   photos locales supprimées ;
/// - réseau absent ou serveur en panne (5xx) → reste en attente, nouvel
///   essai au prochain retour de connexion ;
/// - refusé (422, forfait absent, espace insuffisant…) → marqué en échec
///   avec le motif ; le vendeur choisit de réessayer ou de le retirer.
class OfflineProductSyncService extends GetxService {
  static OfflineProductSyncService get to =>
      Get.find<OfflineProductSyncService>();

  /// File du vendeur connecté (les autres comptes du téléphone sont ignorés).
  final pending = <PendingProduct>[].obs;
  final isSyncing = false.obs;

  /// Incrémenté après chaque passe qui a publié au moins un produit : les
  /// écrans concernés (tableau de bord) s'y abonnent pour se rafraîchir.
  final syncedRevision = 0.obs;

  int get failedCount => pending.where((item) => item.isFailed).length;

  Worker? _onlineWorker;

  @override
  void onInit() {
    super.onInit();
    reload();
    if (Get.isRegistered<ConnectivityService>()) {
      _onlineWorker = ever<bool>(ConnectivityService.to.isOnline, (online) {
        if (online) syncNow();
      });
      if (ConnectivityService.to.isOnline.value) {
        // Laisse le premier écran s'afficher avant d'envoyer des photos.
        Future.delayed(const Duration(seconds: 3), syncNow);
      }
    }
  }

  @override
  void onClose() {
    _onlineWorker?.dispose();
    super.onClose();
  }

  /// Relit la file depuis Hive pour le vendeur connecté (après une
  /// connexion, un changement de compte…).
  void reload() {
    final userId = StorageService.getUser()?.id;
    if (userId == null) {
      pending.clear();
      return;
    }
    final items = OfflineStore.readPendingProducts()
        .map(PendingProduct.fromJson)
        .whereType<PendingProduct>()
        .where((item) => item.userId == userId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    pending.assignAll(items);
  }

  // ── Mise en file ──────────────────────────────────────────────────────

  /// Référence unique d'une création de produit (`client_reference`).
  ///
  /// Le formulaire la tire avant le premier envoi en ligne et la garde : si
  /// la connexion tombe après que le serveur a créé le produit, la fiche mise
  /// en file part avec la même référence et le serveur rend le produit déjà
  /// créé au lieu d'en publier un second.
  ///
  /// Borne en littéral : sur le web, `1 << 32` vaut 0 (entiers JavaScript
  /// sur 32 bits) et `nextInt(0)` lève une RangeError.
  static String newReference() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}';

  /// Enregistre un produit pour envoi ultérieur. [fields] sont les champs du
  /// multipart de création, [images] les photos dans l'ordre du formulaire,
  /// [reference] la référence déjà utilisée pour un envoi en ligne.
  ///
  /// Les photos sont copiées en octets dans Hive (voir [OfflineStore]) :
  /// celles de l'appareil photo vivent dans un cache que le système peut
  /// vider, et celles du web dans des URL `blob:` qui meurent avec la page.
  Future<PendingProduct> enqueue({
    required Map<String, String> fields,
    required List<XFile> images,
    Map<String, String> labels = const {},
    String? reference,
  }) async {
    final userId = StorageService.getUser()?.id;
    if (userId == null) {
      throw StateError('Enregistrement hors ligne indisponible');
    }

    final id = (reference != null && reference.isNotEmpty)
        ? reference
        : newReference();

    final refs = <String>[];
    try {
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        final ext = p.extension(image.name.isNotEmpty ? image.name : image.path);
        final ref = '$_imagePrefix$id/$i${ext.isNotEmpty ? ext : '.jpg'}';
        await OfflineStore.putPendingImage(
          ref.substring(_imagePrefix.length),
          await image.readAsBytes(),
        );
        refs.add(ref);
      }
    } catch (_) {
      await _deleteImages(refs);
      rethrow;
    }

    final item = PendingProduct(
      id: id,
      userId: userId,
      createdAt: DateTime.now(),
      fields: Map<String, String>.from(fields),
      imagePaths: refs,
      labels: Map<String, String>.from(labels),
    );
    await OfflineStore.putPendingProduct(id, item.toJson());
    // Même référence = même produit : la fiche remplace l'éventuelle
    // précédente au lieu de s'ajouter à côté.
    pending
      ..removeWhere((e) => e.id == id)
      ..add(item);

    // Mis en file alors que le serveur semble répondre (panne passagère) :
    // aucun retour de connexion ne relancera l'envoi, on le tente nous-mêmes.
    if (!ConnectivityService.isOffline) {
      Future.delayed(const Duration(seconds: 5), syncNow);
    }
    return item;
  }

  /// Retire un produit de la file sans l'envoyer.
  Future<void> remove(String id) async {
    final item = pending.firstWhereOrNull((e) => e.id == id);
    await OfflineStore.deletePendingProduct(id);
    await _deleteImages(item?.imagePaths ?? const []);
    pending.removeWhere((item) => item.id == id);
  }

  /// Remet un produit refusé dans la file et relance l'envoi.
  Future<void> retry(String id) async {
    final item = pending.firstWhereOrNull((e) => e.id == id);
    if (item == null) return;
    item
      ..status = PendingProductStatus.pending
      ..error = null;
    await _persist(item);
    await syncNow();
  }

  // ── Envoi ─────────────────────────────────────────────────────────────

  /// Envoie les produits en attente. Sans effet hors ligne, sans session,
  /// ou si un envoi est déjà en cours.
  Future<void> syncNow() async {
    if (isSyncing.value || ConnectivityService.isOffline) return;
    if (!StorageService.isAuthenticated) return;

    reload();
    final queue = pending
        .where((item) => item.status == PendingProductStatus.pending)
        .toList();
    if (queue.isEmpty) return;

    isSyncing.value = true;
    var published = 0;
    var rejected = 0;
    try {
      final catalog = await _loadCatalog();
      // Sans la liste du serveur, impossible de garantir les catégories :
      // on attend le prochain passage.
      if (catalog == null) return;
      for (final item in queue) {
        final outcome = await _send(item, catalog);
        if (outcome == _Outcome.published) {
          published++;
        } else if (outcome == _Outcome.rejected) {
          rejected++;
        } else {
          // Réseau coupé ou serveur indisponible : inutile d'insister sur
          // les suivants, ils partiront au prochain retour de connexion.
          break;
        }
      }
    } finally {
      isSyncing.value = false;
    }

    if (published > 0) {
      syncedRevision.value++;
      _notify(
        published == 1
            ? 'data.offline_sync.published_one'.tr
            : 'data.offline_sync.published_many'
                .trParams({'count': '$published'}),
        AppDesign.success,
      );
    }
    if (rejected > 0) {
      _notify(
        rejected == 1
            ? 'data.offline_sync.rejected_one'.tr
            : 'data.offline_sync.rejected_many'
                .trParams({'count': '$rejected'}),
        AppDesign.danger,
      );
    }
  }

  /// Catégories actuelles du serveur (gardées aussi pour le formulaire).
  Future<CategoryCatalog?> _loadCatalog() async {
    try {
      final response = await ProductService.getCategories();
      final list = response.data?['categories'];
      if (!response.success || list is! List || list.isEmpty) return null;
      await OfflineStore.saveSnapshot(CategoryCatalog.snapshotKey, list);
      final catalog = CategoryCatalog.fromApi(list);
      return catalog.isEmpty ? null : catalog;
    } catch (_) {
      return null;
    }
  }

  /// Remplace la catégorie de la fiche par les identifiants de la base.
  /// Faux si elle ne correspond à aucune catégorie existante.
  Future<bool> _alignCategory(PendingProduct item, CategoryCatalog catalog) async {
    final fields = item.fields;
    final categoryName = item.labels['category_name'];
    final selection = catalog.resolve(
          categoryId: fields['category_id'],
          subcategoryId: fields['subcategory_id'],
          categoryName: categoryName,
          subcategoryName: item.labels['subcategory_name'],
        ) ??
        // Sous-catégorie disparue : la catégorie seule suffit au serveur.
        catalog.resolve(
          categoryId: fields['category_id'],
          categoryName: categoryName,
        );
    if (selection == null) return false;

    final before = '${fields['category_id']}|${fields['subcategory_id']}';
    fields['category_id'] = selection.categoryId;
    final subcategoryId = selection.subcategoryId;
    if (subcategoryId != null) {
      fields['subcategory_id'] = subcategoryId;
    } else {
      fields.remove('subcategory_id');
    }
    if (before != '${fields['category_id']}|${fields['subcategory_id']}') {
      await _persist(item);
    }
    return true;
  }

  Future<_Outcome> _send(PendingProduct item, CategoryCatalog catalog) async {
    final files = <String, XFile>{};
    for (var i = 0; i < item.imagePaths.length; i++) {
      final ref = item.imagePaths[i];
      final bytes = await imageBytes(ref);
      if (bytes == null || bytes.isEmpty) continue;
      files['images[$i]'] = XFile.fromData(bytes, name: p.basename(ref));
    }
    if (files.isEmpty) {
      return _reject(item, 'data.offline_sync.photos_missing'.tr);
    }

    if (!await _alignCategory(item, catalog)) {
      final label = item.labels['subcategory_name'] ??
          item.labels['category_name'] ??
          item.fields['category_id'] ??
          '';
      return _reject(
        item,
        label.isNotEmpty
            ? 'data.offline_sync.category_removed_named'
                .trParams({'label': label})
            : 'data.offline_sync.category_removed'.tr,
      );
    }

    item
      ..status = PendingProductStatus.syncing
      ..attempts += 1;
    pending.refresh();

    final response = await ApiProvider.multipart(
      '/v1/products',
      fields: {
        ...item.fields,
        // Même référence à chaque renvoi : si une réponse s'est perdue alors
        // que le produit était créé, le serveur le rend au lieu d'en créer
        // un second.
        'client_reference': item.id,
      },
      mediaFiles: files,
    );

    if (response.success) {
      await OfflineStore.deletePendingProduct(item.id);
      await _deleteImages(item.imagePaths);
      pending.removeWhere((e) => e.id == item.id);
      return _Outcome.published;
    }

    final code = response.statusCode;
    if (code == 0 || code == 401 || code == 408 || code == 429 || code >= 500) {
      // Pas de verdict du serveur sur le produit lui-même : on réessaiera.
      item.status = PendingProductStatus.pending;
      await _persist(item);
      if (code == 0) ConnectivityService.to.check();
      return _Outcome.retryLater;
    }

    return _reject(item, _errorMessage(response));
  }

  Future<_Outcome> _reject(PendingProduct item, String message) async {
    item
      ..status = PendingProductStatus.failed
      ..error = message;
    await _persist(item);
    return _Outcome.rejected;
  }

  /// Motif lisible : première erreur de validation, sinon le message.
  String _errorMessage(ApiResponse response) {
    final data = response.data;
    switch (data?['error_code']) {
      case 'NO_ACTIVE_PACKAGE':
        return 'data.offline_sync.no_active_package'.tr;
      case 'INSUFFICIENT_STORAGE':
        return 'data.offline_sync.insufficient_storage'.tr;
    }
    final errors = data?['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return '${first.first}';
      if (first is String) return first;
    }
    return response.message.isNotEmpty
        ? response.message
        : 'data.offline_sync.server_rejected'.tr;
  }

  Future<void> _persist(PendingProduct item) async {
    await OfflineStore.putPendingProduct(item.id, item.toJson());
    pending.refresh();
  }

  // ── Photos ────────────────────────────────────────────────────────

  /// Préfixe des photos rangées dans Hive. Sans lui, la référence est le
  /// chemin d'un fichier, format des fiches mises en file avant le passage
  /// à Hive (téléphone uniquement).
  static const _imagePrefix = 'hive:';

  /// Octets d'une photo en attente (aussi pour la vignette du tableau de
  /// bord), ou null si elle a disparu.
  Future<Uint8List?> imageBytes(String ref) async {
    if (ref.startsWith(_imagePrefix)) {
      return OfflineStore.readPendingImage(ref.substring(_imagePrefix.length));
    }
    if (kIsWeb) return null;
    try {
      final file = File(ref);
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteImages(List<String> refs) async {
    try {
      await OfflineStore.deletePendingImages(
        refs
            .where((ref) => ref.startsWith(_imagePrefix))
            .map((ref) => ref.substring(_imagePrefix.length)),
      );
      if (kIsWeb) return;
      // Anciennes fiches : photos copiées dans Documents/offline_products.
      for (final ref in refs.where((ref) => !ref.startsWith(_imagePrefix))) {
        final dir = Directory(p.dirname(ref));
        if (p.basename(p.dirname(dir.path)) == 'offline_products' &&
            await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {
      // Quelques photos orphelines ne valent pas d'interrompre l'envoi.
    }
  }

  void _notify(String message, Color color) {
    Get.snackbar(
      'data.offline_sync.title'.tr,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: color,
      colorText: Colors.white,
      margin: const EdgeInsets.all(AppDesign.space4),
      borderRadius: AppDesign.radiusMd,
      duration: const Duration(seconds: 4),
    );
  }
}

enum _Outcome { published, rejected, retryLater }
