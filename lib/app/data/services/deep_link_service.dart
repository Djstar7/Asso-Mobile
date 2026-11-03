import 'package:asso/app/core/utils/app_feedback.dart';
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../core/utils/app_navigation.dart';
import '../../core/values/constants.dart';
import '../../modules/import/views/wholesale_product_view.dart';
import '../../routes/app_pages.dart';
import '../models/wholesale_models.dart';
import '../providers/api_provider.dart';
import '../providers/guest_access.dart';
import '../providers/import_service.dart';
import '../providers/product_service.dart';
import '../providers/storage_service.dart';

/// Ce vers quoi pointe un lien partagé.
enum _LinkKind { product, shop }

class _LinkTarget {
  const _LinkTarget(this.kind, this.id, this.uri);

  final _LinkKind kind;
  final int id;
  final Uri uri;
}

/// Ouvre dans l'application les liens partagés : `/p/{id}` et `/b/{id}`, sur le
/// domaine ou par le schéma de la vitrine (`assomarket://domaine/p/{id}`).
///
/// Le lien n'est jamais suivi à son arrivée : il attend que l'application soit
/// sur un écran stable, quel que soit le chemin pris pour y arriver (démarrage à
/// froid, choix du pays, préférences, connexion). [DeepLinkRouteObserver] le
/// réveille à chaque changement d'écran.
///
/// Flutter ne doit pas traiter ces liens lui-même : `flutter_deeplinking_enabled`
/// (Android) et `FlutterDeepLinkingEnabled` (iOS) sont à false. Sinon, à froid, le
/// lien remplace la route de départ, le splash ne démarre jamais et l'utilisateur
/// tombe sur « Page introuvable ».
///
/// Les chemins traités ici doivent aussi figurer dans l'intent-filter Android et
/// dans les fichiers d'association servis par le back-office.
class DeepLinkService extends GetxService {
  DeepLinkService({
    AppLinks? appLinks,
    Future<ApiResponse> Function(int id)? loadProduct,
    Future<ApiResponse> Function(int id)? loadWholesaleProduct,
    Future<VoidCallback> Function(Map<String, dynamic> body)? wholesaleOpener,
    Future<void> Function()? enterAsGuest,
  }) : _appLinks = appLinks ?? AppLinks(),
       _loadProduct = loadProduct ?? ProductService.getProduct,
       _loadWholesaleProduct = loadWholesaleProduct ?? ImportService.getProduct,
       _wholesaleOpener = wholesaleOpener ?? _defaultWholesaleOpener,
       _enterAsGuest =
           enterAsGuest ?? (() => GuestAccess.enter(skipInterests: true));

  final AppLinks _appLinks;
  final Future<ApiResponse> Function(int id) _loadProduct;
  final Future<ApiResponse> Function(int id) _loadWholesaleProduct;
  final Future<VoidCallback> Function(Map<String, dynamic> body)
  _wholesaleOpener;
  final Future<void> Function() _enterAsGuest;
  StreamSubscription<Uri>? _subscription;

  /// Le démarrage à froid livre parfois le même lien deux fois (lien initial
  /// + flux). On ignore le doublon sur une courte fenêtre, sans le retenir
  /// indéfiniment : repartager le même produit dans la session est normal.
  Uri? _lastHandled;
  DateTime? _lastHandledAt;
  static const Duration _replayWindow = Duration(seconds: 3);

  /// Vrai pendant la résolution d'un lien, pour qu'un second appui n'empile
  /// pas deux fois la même fiche.
  bool _handling = false;

  /// Passe à vrai une fois [start] exécuté, le routeur étant alors monté.
  bool _started = false;

  /// Le dernier lien reçu et pas encore ouvert : le plus récent l'emporte.
  _LinkTarget? _pending;

  /// Un lien attend d'être ouvert.
  bool get hasPendingLink => _pending != null;

  Future<DeepLinkService> init() async => this;

  /// Branche les deux portes d'entrée.
  ///
  /// À appeler une fois le routeur en place — depuis le splash — pour que la
  /// navigation vise un navigateur monté.
  Future<void> start() async {
    _started = true;

    _subscription ??= _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object e) => debugPrint('[DeepLink] erreur de flux : $e'),
    );

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleUri(initial);
    } catch (e) {
      debugPrint('[DeepLink] lien initial illisible : $e');
    }

    await drain();
  }

  /// Point d'entrée pour les liens venus d'ailleurs que du système, par
  /// exemple le corps d'une notification.
  Future<void> handleExternal(Uri uri) => _handleUri(uri, fromSystem: false);

  Future<void> _handleUri(Uri uri, {bool fromSystem = true}) async {
    // Seul le système livre un lien en double. Un toucher est toujours voulu :
    // ouvrir une annonce, revenir et la rouvrir aussitôt ne faisait plus rien.
    if (fromSystem) {
      final now = DateTime.now();
      final last = _lastHandledAt;
      if (_lastHandled == uri &&
          last != null &&
          now.difference(last) < _replayWindow) {
        return;
      }
      _lastHandled = uri;
      _lastHandledAt = now;
    }

    final target = _parse(uri);
    if (target == null) return;

    _pending = target;
    await drain();
  }

  /// Vrai pour un lien que ce service sait ouvrir.
  static bool isShareLink(Uri uri) => _parse(uri) != null;

  /// Lit un lien ; null s'il ne nous concerne pas.
  ///
  /// `/produit` reste lu pour les notifications et les appels internes, mais
  /// n'est plus déclaré aux plateformes.
  static _LinkTarget? _parse(Uri uri) {
    final schemeAllowed =
        uri.scheme == 'https' || uri.scheme == AppConstants.mobileScheme;
    if (!schemeAllowed || uri.host != AppConstants.shareDomain) return null;

    final segments = uri.pathSegments;
    if (segments.length != 2) return null;

    final id = int.tryParse(segments[1]);
    if (id == null || id <= 0) return null;

    return switch (segments[0]) {
      'p' || 'produit' => _LinkTarget(_LinkKind.product, id, uri),
      'b' => _LinkTarget(_LinkKind.shop, id, uri),
      _ => null,
    };
  }

  /// Ouvre le lien en attente si l'écran courant le permet.
  ///
  /// Sur l'accueil de bienvenue, un visiteur entre en invité ; sur les autres
  /// écrans de mise en route, le lien attend leur fin.
  @visibleForTesting
  Future<void> drain() async {
    final target = _pending;
    if (!_started || _handling || target == null) return;

    final route = Get.currentRoute;
    if (AppNavigation.isVisitorEntryRoute(route) &&
        !StorageService.isAuthenticated) {
      _handling = true;
      try {
        await _enterAsGuest();
      } finally {
        _handling = false;
      }
      return;
    }
    if (AppNavigation.isSetupRoute(route)) return;

    _pending = null;
    _handling = true;
    try {
      switch (target.kind) {
        case _LinkKind.product:
          await _openProduct(target);
        case _LinkKind.shop:
          await _openShop(target);
      }
    } finally {
      _handling = false;
    }
    // Un lien plus récent est arrivé pendant le chargement.
    if (_pending != null) await drain();
  }

  /// La page de boutique charge elle-même ses données et gère leur échec.
  Future<void> _openShop(_LinkTarget target) => _openWhenReady(
    () => Get.toNamed(
      Routes.VENDOR_DETAILS,
      arguments: {'shop_id': target.id.toString()},
      preventDuplicates: false,
    ),
  );

  /// Récupère le produit puis ouvre sa fiche.
  ///
  /// L'écran attend le produit complet en argument, pas son identifiant :
  /// il faut donc le charger avant de naviguer.
  Future<void> _openProduct(_LinkTarget target) async {
    final hideLoader = _showLoader();
    VoidCallback? open;
    try {
      open = await _resolveProduct(target.id);
      if (open == null) _reportNotFound();
    } catch (e) {
      debugPrint('[DeepLink] produit ${target.id} illisible : $e');
      _reportLoadFailed(target);
    } finally {
      hideLoader();
    }
    if (open != null) await _openWhenReady(open);
  }

  /// Renvoie de quoi ouvrir la fiche, ou null si le produit n'existe plus.
  /// Lève une erreur quand on ne peut pas conclure (réseau, serveur).
  ///
  /// Les produits importés ne sont pas servis par la route du catalogue local :
  /// sur un 404, on les cherche dans le catalogue gros, qui a son propre écran.
  Future<VoidCallback?> _resolveProduct(int id) async {
    final response = await _loadProduct(id);
    final product = _extractProduct(response.data);
    if (response.success && product != null) {
      // Sans `preventDuplicates: false`, un lien reçu depuis une fiche produit
      // ne s'ouvrait pas : GetX y voit la même route.
      return () => Get.toNamed(
        Routes.PRODUCT,
        arguments: product,
        preventDuplicates: false,
      );
    }
    if (response.statusCode != 404) {
      throw StateError('catalogue local : ${response.statusCode}');
    }

    final wholesale = await _loadWholesaleProduct(id);
    final body = wholesale.data;
    if (wholesale.success && body != null && body['product'] is Map) {
      return _wholesaleOpener(body);
    }
    if (wholesale.statusCode != 404) {
      throw StateError('catalogue gros : ${wholesale.statusCode}');
    }
    return null;
  }

  static Future<VoidCallback> _defaultWholesaleOpener(
    Map<String, dynamic> body,
  ) async {
    final product = WholesaleProduct.fromJson(
      Map<String, dynamic>.from(body['product'] as Map),
    );
    final shippingOptions = (body['shipping_options'] as List? ?? [])
        .whereType<Map>()
        .map((o) => ShippingOption.fromJson(Map<String, dynamic>.from(o)))
        .toList();
    final countries = await ProductService.getImportCountries();
    final country = countries.firstWhereOrNull(
      (c) => c['code'] == product.originCountry?.toUpperCase(),
    );
    return () => WholesaleProductView.open(
      product: product,
      shippingOptions: shippingOptions,
      countryFlag: country?['flag'] ?? '',
    );
  }

  /// Indicateur pendant le chargement, sans lequel le toucher semble sans effet.
  /// Rien au démarrage à froid : le splash est encore affiché.
  VoidCallback _showLoader() {
    final navigator = Get.key.currentState;
    final context = Get.key.currentContext;
    if (!AppNavigation.isAppReady || navigator == null || context == null) {
      return () {};
    }
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    navigator.push(route);
    return () {
      if (route.isActive) navigator.removeRoute(route);
    };
  }

  /// Extrait la fiche de la réponse.
  ///
  /// L'API répond `{success, product}` ; d'autres routes enveloppent sous
  /// `data`. On accepte les deux plutôt que d'échouer en silence.
  @visibleForTesting
  static Map<String, dynamic>? _extractProduct(Map<String, dynamic>? body) {
    if (body == null) return null;
    final raw = body['product'] ?? body['data'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// Navigue une fois l'application prête.
  ///
  /// Pousser une route au milieu d'une reconstruction fait échouer le
  /// navigateur. Au repos, on navigue tout de suite : `addPostFrameCallback` ne
  /// demande aucune image, et la fiche restait en attente du prochain toucher
  /// d'écran quand le réseau répondait après la fin de l'animation du tap.
  Future<void> _openWhenReady(VoidCallback open) async {
    // Le splash se termine par `offAllNamed`, qui emporterait la fiche.
    if (!await AppNavigation.whenAppReady()) {
      debugPrint('[DeepLink] pas de navigateur, ouverture abandonnée');
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await SchedulerBinding.instance.endOfFrame;
    }
    open();
  }

  /// Un lien qui n'ouvre rien passe pour une application cassée : on dit ce
  /// qui s'est passé.
  void _reportNotFound() {
    AppFeedback.show(
      'data.deep_link.product_not_found_title'.tr,
      'data.deep_link.product_not_found_message'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  void _reportLoadFailed(_LinkTarget target) {
    AppFeedback.show(
      'data.deep_link.load_failed_title'.tr,
      'data.deep_link.load_failed_message'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
      mainButton: TextButton(
        onPressed: () => _handleUri(target.uri, fromSystem: false),
        child: Text('common.retry'.tr),
      ),
    );
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}

/// Réveille [DeepLinkService] à chaque changement d'écran : c'est à ce moment
/// qu'un lien en attente peut devenir ouvrable.
class DeepLinkRouteObserver extends NavigatorObserver {
  void _wake() {
    if (!Get.isRegistered<DeepLinkService>()) return;
    // Après la mise à jour de `Get.currentRoute`, et hors de la navigation en
    // cours : pousser une route depuis un observateur fait échouer le navigateur.
    unawaited(
      Future<void>.delayed(Duration.zero, Get.find<DeepLinkService>().drain),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _wake();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _wake();
}
