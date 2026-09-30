import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../core/values/constants.dart';

/// Joignabilité du serveur ASSO, pour le mode hors ligne du vendeur.
///
/// « Hors ligne » veut dire : le backend ne peut pas traiter de requête. On
/// ne se fie donc pas à l'état du Wi-Fi ou des données mobiles — un réseau
/// peut être « connecté » sans rien laisser passer (forfait épuisé, portail
/// captif), et internet peut marcher alors que le serveur ASSO est tombé.
/// Le service sonde la route de santé de Laravel (`/up`) : seule une réponse
/// 2xx de sa part vaut « en ligne ». Une passerelle en erreur (502/503/504),
/// la maintenance Laravel (503), une redirection de portail captif ou un
/// délai dépassé valent « hors ligne ».
///
/// Sondages : au démarrage, au retour au premier plan, après un échec réseau
/// signalé par [ApiProvider], puis régulièrement (plus souvent hors ligne,
/// pour détecter vite le retour de la connexion).
class ConnectivityService extends GetxService with WidgetsBindingObserver {
  static ConnectivityService get to => Get.find<ConnectivityService>();

  /// Optimiste tant que rien n'a été sondé : l'application se comporte comme
  /// avant tant qu'aucun échec n'est constaté.
  final isOnline = true.obs;

  static const Duration _probeTimeout = Duration(seconds: 5);
  static const Duration _onlineInterval = Duration(seconds: 30);
  static const Duration _offlineInterval = Duration(seconds: 10);

  final http.Client _client = http.Client();
  Timer? _timer;
  Future<bool>? _probing;
  DateTime? _lastProbeAt;

  /// Vrai si le service est enregistré et constate l'absence de réseau.
  /// Sans service (tests, démarrage), on se considère en ligne.
  static bool get isOffline =>
      Get.isRegistered<ConnectivityService>() && !to.isOnline.value;

  /// État vérifié récemment, pour décider avant une action (ouverture du
  /// formulaire, envoi d'un produit) : re-sonde si le dernier sondage date
  /// de plus de [maxAge]. Sans service, on se considère en ligne.
  static Future<bool> ensureFresh({
    Duration maxAge = const Duration(seconds: 15),
  }) async {
    if (!Get.isRegistered<ConnectivityService>()) return true;
    final last = to._lastProbeAt;
    if (last != null && DateTime.now().difference(last) < maxAge) {
      return to.isOnline.value;
    }
    return to.check();
  }

  /// Premier sondage, attendu avant le premier écran : il décide si le
  /// démarrage attend les réglages du serveur ou part sur les données locales.
  Future<ConnectivityService> init() async {
    WidgetsBinding.instance.addObserver(this);
    await check();
    return this;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _client.close();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      check();
    } else if (state == AppLifecycleState.paused) {
      // Rien à surveiller en arrière-plan.
      _timer?.cancel();
    }
  }

  /// Sonde le serveur et met [isOnline] à jour. Les appels simultanés
  /// partagent le même sondage.
  Future<bool> check() {
    return _probing ??= _probe().whenComplete(() => _probing = null);
  }

  Future<bool> _probe() async {
    bool reachable;
    try {
      final request = http.Request(kIsWeb ? 'HEAD' : 'GET', _probeUri)
        // Un portail captif répond par une redirection : ce n'est pas le
        // serveur ASSO.
        ..followRedirects = false;
      final response = await _client.send(request).timeout(_probeTimeout);
      await response.stream.drain<void>();
      reachable = _isHealthy(response.statusCode);
    } on SocketException {
      reachable = false;
    } on TimeoutException {
      reachable = false;
    } on http.ClientException {
      reachable = false;
    } catch (_) {
      reachable = false;
    }
    _lastProbeAt = DateTime.now();
    _setOnline(reachable);
    return reachable;
  }

  /// Route sondée. Sur mobile, la route de santé de Laravel, à la racine du
  /// site (`…/api` → `…/up`) : elle ne répond 200 que si l'application
  /// démarre réellement. Sur le web, elle n'est pas ouverte au CORS : on
  /// garde la racine de l'API.
  static Uri get _probeUri {
    final api = Uri.parse(AppConstants.baseUrl);
    if (kIsWeb) return api;
    final segments = api.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && segments.last == 'api') segments.removeLast();
    return api.replace(pathSegments: [...segments, 'up']);
  }

  /// `/up` doit répondre 2xx ; la racine de l'API (web) répond 404 ou 405
  /// quand tout va bien. Dans les deux cas, 3xx et 5xx = injoignable.
  static bool _isHealthy(int status) {
    if (status >= 200 && status < 300) return true;
    return kIsWeb && status >= 400 && status < 500;
  }

  void _setOnline(bool value) {
    if (isOnline.value != value) isOnline.value = value;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(
      isOnline.value ? _onlineInterval : _offlineInterval,
      check,
    );
  }

  // ── Signaux venus des appels API ──────────────────────────────────────

  /// Une réponse lisible du serveur est arrivée. Une 5xx (passerelle, panne,
  /// maintenance) ne prouve rien : on re-sonde au lieu de conclure.
  static void reportResponse(int statusCode) {
    if (statusCode >= 500) {
      if (Get.isRegistered<ConnectivityService>()) to.check();
      return;
    }
    reportReachable();
  }

  /// Une réponse du serveur est arrivée : il est joignable.
  static void reportReachable() {
    if (!Get.isRegistered<ConnectivityService>()) return;
    if (!to.isOnline.value) to._setOnline(true);
  }

  /// Un appel a échoué faute de réseau : on vérifie sans attendre, plutôt
  /// que de conclure sur un seul échec (un délai dépassé sur un gros envoi
  /// ne veut pas dire que le réseau est coupé).
  static void reportNetworkFailure(Object error) {
    if (!Get.isRegistered<ConnectivityService>()) return;
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      to.check();
    }
  }
}
