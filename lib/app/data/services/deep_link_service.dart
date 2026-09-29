import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../core/utils/app_navigation.dart';
import '../../core/values/constants.dart';
import '../../routes/app_pages.dart';
import '../providers/product_service.dart';

/// Ouvre dans l'application les liens partagés (https://<domaine>/produit/{id}).
///
/// Deux portes d'entrée, réunies dans [_handleUri] :
///   1. démarrage à froid — le lien qui a lancé l'application ;
///   2. à chaud — les liens reçus pendant qu'elle tourne déjà.
///
/// La navigation attend que le routeur soit monté : un lien de démarrage à
/// froid arrive avant la première image et viserait sinon un navigateur
/// inexistant.
///
/// Les chemins traités ici doivent aussi figurer dans les fichiers
/// d'association du serveur (apple-app-site-association, assetlinks.json) et
/// dans l'intent-filter Android, sans quoi le système ne nous remet jamais
/// le lien.
class DeepLinkService extends GetxService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
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

  /// Passe à vrai une fois [start] exécuté. Un lien arrivé avant est mis de
  /// côté et rejoué à ce moment-là.
  bool _started = false;
  Uri? _pending;

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

    final pending = _pending;
    if (pending != null) {
      _pending = null;
      await _handleUri(pending);
    }
  }

  /// Point d'entrée pour les liens venus d'ailleurs que du système, par
  /// exemple le corps d'une notification.
  Future<void> handleExternal(Uri uri) => _handleUri(uri);

  Future<void> _handleUri(Uri uri) async {
    final now = DateTime.now();
    final last = _lastHandledAt;
    if (_lastHandled == uri &&
        last != null &&
        now.difference(last) < _replayWindow) {
      return;
    }
    _lastHandled = uri;
    _lastHandledAt = now;

    if (!_started) {
      _pending = uri;
      debugPrint('[DeepLink] mis de côté (routeur absent) : $uri');
      return;
    }
    if (_handling) return;

    // Le système restreint déjà les liens au domaine vérifié ; cette
    // vérification est une précaution supplémentaire.
    if (uri.host.isNotEmpty && uri.host != AppConstants.shareDomain) return;

    final segments = uri.pathSegments;
    if (segments.length < 2) return;

    final value = segments[1].trim();
    if (value.isEmpty) return;

    _handling = true;
    try {
      if (segments[0] == 'produit') {
        await _openProduct(value);
      }
    } finally {
      _handling = false;
    }
  }

  /// Récupère le produit puis ouvre sa fiche.
  ///
  /// L'écran attend le produit complet en argument, pas son identifiant :
  /// il faut donc le charger avant de naviguer.
  Future<void> _openProduct(String id) async {
    final productId = int.tryParse(id);
    if (productId == null) return;

    try {
      final response = await ProductService.getProduct(productId);
      final product = _extractProduct(response.data);

      if (!response.success || product == null) {
        _reportNotFound();
        return;
      }
      await _pushWhenIdle(Routes.PRODUCT, arguments: product);
    } catch (e) {
      debugPrint('[DeepLink] produit $id illisible : $e');
      _reportNotFound();
    }
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

  /// Navigue une fois l'arbre de widgets au repos.
  ///
  /// Pousser une route au milieu d'une reconstruction fait échouer le
  /// navigateur ; on attend la fin de l'image en cours, puis le montage du
  /// routeur au démarrage à froid.
  Future<void> _pushWhenIdle(String route, {Object? arguments}) async {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await SchedulerBinding.instance.endOfFrame;
    }
    // Le splash se termine par `offAllNamed`, qui emporterait la fiche.
    if (!await AppNavigation.whenAppReady()) {
      debugPrint('[DeepLink] pas de navigateur, $route abandonné');
      return;
    }

    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.toNamed(route, arguments: arguments);
      completer.complete();
    });
    await completer.future;
  }

  /// Un lien qui n'ouvre rien passe pour une application cassée : on dit ce
  /// qui s'est passé.
  void _reportNotFound() {
    Get.snackbar(
      'data.deep_link.product_not_found_title'.tr,
      'data.deep_link.product_not_found_message'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
