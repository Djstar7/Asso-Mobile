import 'dart:async';
import 'dart:developer' as developer;

import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import '../services/firebase_messaging_service.dart';
import 'storage_service.dart';

/// Entrée dans l'application sans compte.
///
/// La même séquence était écrite en double dans WelcomerController ; elle est
/// désormais partagée, pour que « Passer » se comporte à l'identique depuis
/// l'accueil, la connexion et l'inscription.
class GuestAccess {
  const GuestAccess._();

  /// Active le mode invité puis ouvre l'application.
  ///
  /// Le choix du pays passe avant l'accueil quand il n'a pas encore été fait :
  /// sans pays, les prix n'ont pas de devise à afficher.
  static Future<void> enter() async {
    developer.log('Passer — activation du mode invité', name: 'GuestAccess');
    StorageService.enableGuestMode();

    // L'abonnement aux annonces part de son côté, sans être attendu.
    //
    // L'attendre bloquait « Passer » pour de bon : quand les services Google
    // Play sont hors d'atteinte, `subscribeToTopic` ne rend jamais la main —
    // il ne lève pas d'erreur non plus, donc le `catch` ne rattrapait rien et
    // la navigation n'arrivait jamais. Chaque appui relançait un abonnement
    // de plus, sans rien changer à l'écran.
    unawaited(_subscribeToAnnouncements());

    Get.offAllNamed(nextRoute());
  }

  /// Abonnement aux annonces, mené à part de la navigation.
  static Future<void> _subscribeToAnnouncements() async {
    // Le service manque à l'appel sur un appareil sans services Google Play,
    // où son initialisation a échoué au démarrage : `Get.find` lèverait alors
    // une erreur, ici sans conséquence, mais autant ne pas la provoquer.
    if (!Get.isRegistered<FirebaseMessagingService>()) {
      developer.log(
        'Service de messagerie absent — abonnement ignoré',
        name: 'GuestAccess',
      );
      return;
    }

    try {
      await FirebaseMessagingService.to
          .subscribeToAnnouncementsTopic()
          // Une borne de temps, faute de quoi l'appel reste en suspens tant
          // que dure la session.
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      developer.log(
        'Abonnement aux annonces impossible',
        name: 'GuestAccess',
        error: e,
      );
    }
  }

  /// Écran suivant une fois le mode invité actif.
  ///
  /// Le pays d'abord — sans lui les prix n'ont pas de devise —, puis les
  /// centres d'intérêt, proposés une seule fois, à l'invité comme à
  /// l'inscrit.
  static String nextRoute() {
    if (!StorageService.hasSelectedCountry) return Routes.COUNTRY_SELECTION;
    if (!StorageService.wasPreferencesPrompted) return Routes.PREFERENCES;
    return Routes.HOME;
  }
}
