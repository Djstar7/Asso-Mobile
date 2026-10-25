import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_storage/get_storage.dart';

import 'storage_service.dart';
import 'secure_vault.dart';

/// Base locale Hive du mode hors ligne vendeur.
///
/// Deux boîtes, toutes deux en JSON texte (pas d'adaptateur généré à
/// maintenir, et une donnée illisible se jette sans casser la boîte) :
/// - `offline_cache` : dernières réponses du serveur utiles au chemin
///   tableau de bord → ajout de produit (tableau de bord, catégories…),
///   rangées par vendeur pour qu'un changement de compte n'affiche jamais
///   les données d'un autre ;
/// - `offline_products` : produits créés sans réseau, en attente d'envoi.
///
/// Les photos de ces produits vont dans une troisième boîte, en octets et
/// chargée à la demande (`offline_product_images`) : elle marche sur le web
/// comme sur téléphone, sans système de fichiers.
class OfflineStore {
  OfflineStore._();

  static const _cacheBoxName = 'offline_cache_secure_v1';
  static const _productsBoxName = 'offline_products_secure_v1';
  static const _imagesBoxName = 'offline_product_images_secure_v1';

  static Box<String>? _cache;
  static Box<String>? _products;
  static LazyBox<Uint8List>? _images;

  static bool _initialized = false;
  static bool get isReady => _initialized;

  /// À appeler une fois au démarrage, avant tout écran.
  static Future<void> init() async {
    if (isReady) return;
    await Hive.initFlutter();
    const keyName = 'asso_offline_key_v1';
    var encodedKey = await SecureVault.storage.read(key: keyName);
    if (encodedKey == null) {
      // Never generate a different key over existing encrypted drafts.
      if (await Hive.boxExists(_productsBoxName) ||
          await Hive.boxExists(_imagesBoxName) ||
          await Hive.boxExists(_cacheBoxName)) {
        throw StateError('Offline encryption key unavailable');
      }
      encodedKey = base64Encode(Hive.generateSecureKey());
      await SecureVault.write(keyName, encodedKey);
    }
    final cipher = HiveAesCipher(base64Decode(encodedKey));
    _cache = await Hive.openBox<String>(
      _cacheBoxName,
      encryptionCipher: cipher,
    );
    _products = await Hive.openBox<String>(
      _productsBoxName,
      encryptionCipher: cipher,
    );
    _images = await Hive.openLazyBox<Uint8List>(
      _imagesBoxName,
      encryptionCipher: cipher,
    );

    // Commit and flush each copy before removing its plaintext predecessor.
    // Missing destination entries only: restarting a migration is idempotent.
    for (final pair in [
      ('offline_cache', _cache!),
      ('offline_products', _products!),
    ]) {
      if (!await Hive.boxExists(pair.$1)) continue;
      final legacy = await Hive.openBox<String>(pair.$1);
      for (final key in legacy.keys) {
        if (!pair.$2.containsKey(key)) {
          final value = legacy.get(key);
          if (value != null) await pair.$2.put(key, value);
        }
      }
      await pair.$2.flush();
      await legacy.deleteFromDisk();
    }
    if (await Hive.boxExists('offline_product_images')) {
      final legacy = await Hive.openLazyBox<Uint8List>(
        'offline_product_images',
      );
      for (final key in legacy.keys) {
        if (!_images!.containsKey(key)) {
          final value = await legacy.get(key);
          if (value != null) await _images!.put(key, value);
        }
      }
      await _images!.flush();
      await legacy.deleteFromDisk();
    }
    // The old form draft was global. Attribute it only to the known session.
    final legacyDraft = GetStorage().read<String>('add_product_draft_v1');
    if (legacyDraft != null) {
      final scope = _userScope;
      if (scope != null) {
        final decoded = jsonDecode(legacyDraft);
        await _cache!.put('$scope:product_form_draft', jsonEncode({
          'v': _snapshotVersion,
          'saved_at': DateTime.now().toIso8601String(),
          'data': decoded,
        }));
        await _cache!.flush();
      }
      await GetStorage().remove('add_product_draft_v1');
    }
    _initialized = true;
  }

  static Future<void> clearSnapshotsFor(int? userId) async {
    final box = _cache;
    if (box == null || userId == null) return;
    final keys = box.keys
        .where((key) => '$key'.startsWith('u$userId:') && !'$key'.endsWith(':product_form_draft'))
        .toList();
    await box.deleteAll(keys);
  }

  // ── Instantanés du serveur ────────────────────────────────────────────

  /// Format des instantanés. À incrémenter quand une mise à jour de l'app
  /// change la forme des réponses mémorisées : les anciens instantanés sont
  /// alors ignorés (et supprimés) au lieu d'afficher des données périmées.
  static const _snapshotVersion = 2;
  static const snapshotLifetime = Duration(days: 7);

  static String? get _userScope {
    final id = StorageService.getUser()?.id;
    return id == null ? null : 'u$id';
  }

  /// Mémorise la dernière réponse [data] connue pour [key], pour le vendeur
  /// connecté.
  static Future<void> saveSnapshot(String key, Object? data) async {
    final scope = _userScope;
    final box = _cache;
    if (scope == null || box == null || data == null) return;
    try {
      await box.put(
        '$scope:$key',
        jsonEncode({
          'v': _snapshotVersion,
          'saved_at': DateTime.now().toIso8601String(),
          'data': data,
        }),
      );
    } catch (_) {
      // Un instantané est un confort : son échec n'interrompt rien.
    }
  }

  /// Dernière réponse connue pour [key], ou null.
  static dynamic readSnapshot(String key, {Duration maxAge = snapshotLifetime}) {
    final scope = _userScope;
    final raw = scope == null ? null : _cache?.get('$scope:$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map;
      final savedAt = DateTime.tryParse('${decoded['saved_at']}');
      if (decoded['v'] != _snapshotVersion ||
          savedAt == null ||
          DateTime.now().difference(savedAt) > maxAge ||
          savedAt.isAfter(DateTime.now())) {
        _cache?.delete('$scope:$key');
        return null;
      }
      return decoded['data'];
    } catch (_) {
      _cache?.delete('$scope:$key');
      return null;
    }
  }

  static Future<void> removeSnapshot(String key) async {
    final scope = _userScope;
    if (scope != null) await _cache?.delete('$scope:$key');
  }

  // ── File des produits en attente ──────────────────────────────────────

  static Iterable<Map<String, dynamic>> readPendingProducts() sync* {
    final box = _products;
    if (box == null) return;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        yield Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        box.delete(key);
      }
    }
  }

  static Future<void> putPendingProduct(
    String id,
    Map<String, dynamic> json,
  ) async {
    await _products?.put(id, jsonEncode(json));
  }

  static Future<void> deletePendingProduct(String id) async {
    await _products?.delete(id);
  }

  // ── Photos des produits en attente ────────────────────────────────────

  static Future<void> putPendingImage(String key, Uint8List bytes) async {
    final box = _images;
    if (box == null) throw StateError('Offline store not ready');
    await box.put(key, bytes);
  }

  static Future<Uint8List?> readPendingImage(String key) async {
    try {
      return await _images?.get(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deletePendingImages(Iterable<String> keys) async {
    await _images?.deleteAll(keys);
  }
}
