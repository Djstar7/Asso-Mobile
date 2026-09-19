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

    // L'abonnement aux annonces ne doit jamais retenir la navigation :
    // un échec réseau ici n'empêche pas de visiter l'application.
    try {
      await FirebaseMessagingService.to.subscribeToAnnouncementsTopic();
    } catch (e) {
      developer.log(
        'Abonnement aux annonces impossible',
        name: 'GuestAccess',
        error: e,
      );
    }

    Get.offAllNamed(nextRoute());
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
