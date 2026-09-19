import 'package:get/get.dart';

import '../../data/providers/cache_manager.dart';
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
/// À appeler au logout, au login ET au changement de compte : les controllers
/// GetX déclarés `permanent: true` conservent sinon les données de la session
/// précédente (email, profil, wallet, chat, notifs, tracking, posts).
///
/// Placé dans un utilitaire dédié (et non dans `AuthService`) pour éviter les
/// imports circulaires entre le service d'auth et les controllers de modules.
class SessionReset {
  SessionReset._();

  /// Purge l'état hérité de la session précédente après une connexion.
  ///
  /// Le mode invité laisse derrière lui des controllers permanents remplis de
  /// données anonymes et un cache HTTP sans en-tête d'autorisation : sans cette
  /// purge, l'accueil, le profil et le wallet continuent d'afficher l'invité
  /// alors que le token est déjà enregistré.
  ///
  /// Le cache est vidé avant les controllers pour que ceux recréés par les
  /// bindings rechargent depuis le réseau, et non depuis une entrée anonyme
  /// encore valide (TTL 15 min).
  static void onLogin() {
    clearCache();
    clearControllers();
    _reconnectRealtime();
    _reloadNotifications();
  }

  /// Relance le WebSocket avec le token fraîchement enregistré.
  ///
  /// Le service est permanent : démarré sans token en mode invité, il ne se
  /// reconnecte jamais tout seul.
  static void _reconnectRealtime() {
    if (Get.isRegistered<WebSocketService>()) {
      try {
        WebSocketService.to.reconnect();
      } catch (_) {}
    }
  }

  /// Recharge les notifications du compte connecté.
  ///
  /// `NotificationController` est permanent et créé dans `main.dart` : on le
  /// recharge en place plutôt que de le supprimer, pour que le badge soit
  /// correct sans attendre l'ouverture de l'écran des notifications.
  static void _reloadNotifications() {
    if (Get.isRegistered<NotificationController>()) {
      try {
        Get.find<NotificationController>().fetchNotifications(refresh: true);
      } catch (_) {}
    }
  }

  /// Vide le cache HTTP mémoire + persistant (`cache_*` dans GetStorage).
  ///
  /// Les réponses mises en cache en mode invité n'ont pas été émises avec le
  /// token : les réutiliser afficherait des données anonymes à un connecté.
  static void clearCache() {
    try {
      CacheManager().clearAll();
    } catch (_) {}
  }

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

    // NotificationController est permanent et créé dans `main.dart` : le
    // supprimer le laisserait absent jusqu'à l'ouverture de l'écran des
    // notifications. On vide donc sa liste et son badge sur place.
    if (Get.isRegistered<NotificationController>()) {
      try {
        final notifications = Get.find<NotificationController>();
        notifications.notifications.clear();
        notifications.unreadCount.value = 0;
      } catch (_) {}
    }

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
