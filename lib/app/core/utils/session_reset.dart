import 'package:get/get.dart';

import '../../data/services/websocket_service.dart';
import '../../modules/profile/controllers/profile_controller.dart';
import '../../modules/wallet/controllers/wallet_controller.dart';
import '../../modules/chat/controllers/chat_controller.dart';
import '../../modules/tracking/controllers/tracking_controller.dart';
import '../../modules/myVoice/controllers/my_voice_controller.dart';
import '../../modules/home/controllers/home_controller.dart';
import '../../modules/notification/controllers/notification_controller.dart';
import '../../modules/settings/controllers/settings_controller.dart';

/// Réinitialise l'état applicatif lié à l'utilisateur authentifié.
///
/// À appeler au logout ET implicitement au changement de compte : les
/// controllers GetX déclarés `permanent: true` conservent sinon les données de
/// l'ancien compte (email, profil, wallet, chat, notifs, tracking, posts).
///
/// Placé dans un utilitaire dédié (et non dans `AuthService`) pour éviter les
/// imports circulaires entre le service d'auth et les controllers de modules.
class SessionReset {
  SessionReset._();

  /// Supprime les controllers dépendants de l'auth et coupe le WebSocket.
  /// Le prochain login les recréera proprement via les bindings.
  static void clearControllers() {
    // Couper le temps réel avant de détruire les controllers qui l'écoutent.
    if (Get.isRegistered<WebSocketService>()) {
      try {
        WebSocketService.to.disconnect();
      } catch (_) {}
    }

    _deleteIfRegistered<ProfileController>();
    _deleteIfRegistered<WalletController>();
    _deleteIfRegistered<ChatController>();
    _deleteIfRegistered<TrackingController>();
    _deleteIfRegistered<MyVoiceController>();
    _deleteIfRegistered<HomeController>();
    _deleteIfRegistered<NotificationController>();

    // SettingsController peut rester enregistré (paramètres app) : on se
    // contente de purger les données personnelles affichées.
    if (Get.isRegistered<SettingsController>()) {
      try {
        final settings = Get.find<SettingsController>();
        settings.userName.value = '';
        settings.userEmail.value = '';
        settings.userPhone.value = '';
      } catch (_) {}
    }
  }

  static void _deleteIfRegistered<T>() {
    if (Get.isRegistered<T>()) {
      try {
        Get.delete<T>(force: true);
      } catch (_) {}
    }
  }
}
