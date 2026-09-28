import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../core/values/constants.dart';

/// Joignabilité du serveur ASSO, pour le mode hors ligne du vendeur.
///
/// On ne se fie pas à l'état du Wi-Fi ou des données mobiles : un réseau
/// peut être « connecté » sans rien laisser passer (forfait épuisé, portail
/// captif). Le service sonde donc le serveur lui-même — toute réponse HTTP,
/// même une erreur, prouve qu'il est joignable.
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

  /// Vrai si le service est enregistré et constate l'absence de réseau.
  /// Sans service (tests, démarrage), on se considère en ligne.
  static bool get isOffline =>
      Get.isRegistered<ConnectivityService>() && !to.isOnline.value;

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
      await _client
          .head(Uri.parse(AppConstants.baseUrl))
          .timeout(_probeTimeout);
      reachable = true;
    } on SocketException {
      reachable = false;
    } on TimeoutException {
      reachable = false;
    } on http.ClientException {
      reachable = false;
    } catch (_) {
      reachable = false;
    }
    _setOnline(reachable);
    return reachable;
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
