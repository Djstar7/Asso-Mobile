import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/values/constants.dart';
import '../providers/api_provider.dart';

/// Handler pour les messages en arrière-plan
/// DOIT être une fonction top-level (en dehors de toute classe)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Message reçu en arrière-plan: ${message.messageId}');
  print('Titre: ${message.notification?.title}');
  print('Corps: ${message.notification?.body}');
  print('Data: ${message.data}');
}

/// Service Firebase Cloud Messaging pour gérer les notifications push
class FirebaseMessagingService extends GetxService {
  static FirebaseMessagingService get to => Get.find();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Token FCM observable
  final Rx<String?> fcmToken = Rx<String?>(null);

  // État de la permission
  final Rx<bool> isPermissionGranted = false.obs;

  /// Initialise le service FCM
  Future<FirebaseMessagingService> init() async {
    print('🚀 Initialisation du service Firebase Messaging...');

    // Demander la permission pour les notifications
    await _requestPermission();

    // Configurer les notifications locales
    await _setupLocalNotifications();

    // Configurer le handler pour les messages en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Obtenir le token FCM
    await _getFCMToken();

    // Écouter les changements de token
    _listenToTokenRefresh();

    // Écouter les messages en foreground
    _listenToForegroundMessages();

    // Gérer les notifications qui ont ouvert l'app
    _handleNotificationTaps();

    print('✅ Firebase Messaging Service initialisé');

    return this;
  }

  /// Demande la permission pour les notifications
  Future<void> _requestPermission() async {
    print('📋 Demande de permission pour les notifications...');

    final NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    isPermissionGranted.value = settings.authorizationStatus == AuthorizationStatus.authorized;

    if (isPermissionGranted.value) {
      print('✅ Permission accordée pour les notifications');
    } else {
      print('⚠️ Permission refusée pour les notifications');
    }
  }

  /// Configure les notifications locales (pour Android/iOS uniquement)
  Future<void> _setupLocalNotifications() async {
    // Les notifications locales ne sont pas supportées sur le Web
    if (kIsWeb) {
      print('🌐 Web détecté — notifications locales ignorées');
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      print('📱 Configuration des notifications locales Android...');

      // Créer le channel de notification avec haute importance
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id (doit correspondre à AndroidManifest)
        'Notifications importantes', // name
        description: 'Ce canal est utilisé pour les notifications importantes',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('✅ Channel de notification créé');
    }

    // Initialiser les paramètres des notifications locales
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('✅ Notifications locales configurées');
  }

  /// Obtient le token FCM
  Future<void> _getFCMToken() async {
    try {
      // Sur iOS, il faut d'abord s'assurer que le token APNS est disponible
      if (Platform.isIOS) {
        print('📱 iOS détecté - Attente du token APNS...');
        try {
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            print('✅ Token APNS obtenu: ${apnsToken.substring(0, 20)}...');
          } else {
            print('⚠️ Token APNS non disponible, attente de 2 secondes...');
            await Future.delayed(const Duration(seconds: 2));
            final retryApnsToken = await _firebaseMessaging.getAPNSToken();
            if (retryApnsToken != null) {
              print('✅ Token APNS obtenu après retry');
            } else {
              print('⚠️ Token APNS toujours non disponible');
            }
          }
        } catch (apnsError) {
          print('⚠️ Erreur lors de l\'obtention du token APNS: $apnsError');
        }
      }

      final token = await _firebaseMessaging.getToken();
      fcmToken.value = token;

      if (token != null) {
        print('🔑 FCM Token: $token');
        // Envoyer le token au backend
        await _sendTokenToBackend(token);
      } else {
        print('⚠️ Impossible d\'obtenir le token FCM');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'obtention du token FCM: $e');
    }
  }

  /// Envoie le token au backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      // Vérifier si l'utilisateur est authentifié
      if (!ApiProvider.isAuthenticated) {
        print('⚠️ Utilisateur non authentifié, token non envoyé');
        return;
      }

      // Obtenir les informations du device
      final deviceInfo = await _getDeviceInfo();

      // Envoyer le token au backend
      final response = await ApiProvider.post(
        AppConstants.deviceTokensUrl,
        body: {
          'token': token,
          'platform': deviceInfo['platform'],
          'device_name': deviceInfo['device_name'],
          'device_model': deviceInfo['device_model'],
        },
      );

      if (response.success) {
        print('✅ Token FCM envoyé au backend avec succès');
      } else {
        print('⚠️ Échec de l\'envoi du token: ${response.message}');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi du token au backend: $e');
    }
  }

  /// Obtenir les informations du device
  Future<Map<String, String>> _getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    // Sur le Web, dart:io Platform n'est pas disponible
    if (kIsWeb) {
      final WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
      return {
        'platform': 'web',
        'device_name': webInfo.browserName.name,
        'device_model': webInfo.userAgent ?? 'Web',
      };
    }

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return {
        'platform': 'android',
        'device_name': androidInfo.model,
        'device_model': '${androidInfo.manufacturer} ${androidInfo.model}',
      };
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return {
        'platform': 'ios',
        'device_name': iosInfo.name,
        'device_model': iosInfo.model,
      };
    } else if (Platform.isMacOS) {
      final MacOsDeviceInfo macInfo = await deviceInfo.macOsInfo;
      return {
        'platform': 'macos',
        'device_name': macInfo.computerName,
        'device_model': macInfo.model,
      };
    } else if (Platform.isWindows) {
      final WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
      return {
        'platform': 'windows',
        'device_name': windowsInfo.computerName,
        'device_model': windowsInfo.productName,
      };
    } else {
      return {
        'platform': 'unknown',
        'device_name': 'Unknown',
        'device_model': 'Unknown',
      };
    }
  }

  /// Écoute les rafraîchissements du token
  void _listenToTokenRefresh() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      fcmToken.value = newToken;
      print('🔄 Token FCM rafraîchi: $newToken');
      // Envoyer le nouveau token au backend
      _sendTokenToBackend(newToken);
    });
  }

  /// Écoute les messages en foreground (app ouverte)
  void _listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Message reçu en foreground: ${message.messageId}');
      print('Titre: ${message.notification?.title}');
      print('Corps: ${message.notification?.body}');
      print('Data: ${message.data}');

      // Afficher une notification locale quand l'app est en foreground
      _showLocalNotification(message);

      // TODO: Gérer les données du message selon votre logique métier
      _handleMessageData(message.data);
    });
  }

  /// Affiche une notification locale
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Notifications importantes',
            channelDescription: 'Ce canal est utilisé pour les notifications importantes',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  /// Gère les données du message
  void _handleMessageData(Map<String, dynamic> data) {
    // TODO: Implémenter votre logique selon le type de notification
    // Exemple:
    // if (data['type'] == 'new_message') {
    //   Get.toNamed('/chat', arguments: data['chatId']);
    // } else if (data['type'] == 'new_order') {
    //   Get.toNamed('/orders', arguments: data['orderId']);
    // }

    print('📦 Données du message: $data');
  }

  /// Gère les taps sur les notifications
  void _handleNotificationTaps() {
    // Message qui a ouvert l'app (depuis terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('🚀 App ouverte via notification (terminated): ${message.messageId}');
        _handleMessageData(message.data);
      }
    });

    // Message qui ouvre l'app (depuis background)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('🚀 App ouverte via notification (background): ${message.messageId}');
      _handleMessageData(message.data);
    });
  }

  /// Callback quand une notification locale est tapée
  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Notification tapée: ${response.payload}');
    // TODO: Gérer le tap selon le payload
  }

  /// S'abonne à un topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Abonné au topic: $topic');
    } catch (e) {
      print('❌ Erreur lors de l\'abonnement au topic $topic: $e');
    }
  }

  /// Se désabonne d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Désabonné du topic: $topic');
    } catch (e) {
      print('❌ Erreur lors du désabonnement du topic $topic: $e');
    }
  }

  /// Supprime le token FCM (utile lors de la déconnexion)
  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      fcmToken.value = null;
      print('✅ Token FCM supprimé');
    } catch (e) {
      print('❌ Erreur lors de la suppression du token: $e');
    }
  }

  /// Envoie le token FCM au backend (appelé après login/register)
  /// Retourne true si succès, false sinon
  Future<bool> sendTokenToBackend() async {
    try {
      // Vérifier si l'utilisateur est authentifié
      if (!ApiProvider.isAuthenticated) {
        print('⚠️ Utilisateur non authentifié, token non envoyé');
        return false;
      }

      // Obtenir le token FCM actuel
      String? token = fcmToken.value;

      // Si pas de token en mémoire, le récupérer
      if (token == null) {
        token = await _firebaseMessaging.getToken();
        fcmToken.value = token;
      }

      if (token == null) {
        print('⚠️ Impossible d\'obtenir le token FCM');
        return false;
      }

      print('📤 Envoi du token FCM au backend...');

      // Obtenir les informations du device
      final deviceInfo = await _getDeviceInfo();

      // Envoyer le token au backend
      final response = await ApiProvider.post(
        AppConstants.deviceTokensUrl,
        body: {
          'token': token,
          'platform': deviceInfo['platform'],
          'device_name': deviceInfo['device_name'],
          'device_model': deviceInfo['device_model'],
        },
      );

      if (response.success) {
        print('✅ Token FCM envoyé au backend avec succès');
        return true;
      } else {
        print('⚠️ Échec de l\'envoi du token: ${response.message}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi du token au backend: $e');
      return false;
    }
  }

  /// S'abonne au topic des annonces (all_users)
  /// Retourne true si succès, false sinon
  Future<bool> subscribeToAnnouncementsTopic() async {
    try {
      print('📢 Abonnement au topic "all_users" pour les annonces...');
      await subscribeToTopic('all_users');
      print('✅ Abonné au topic "all_users" avec succès');
      return true;
    } catch (e) {
      print('❌ Erreur lors de l\'abonnement au topic "all_users": $e');
      return false;
    }
  }

  /// Méthode complète: Envoie le token ET s'abonne au topic des annonces
  /// À appeler après login/register ou au démarrage de l'app
  Future<Map<String, bool>> registerDeviceAndSubscribe() async {
    final results = {
      'token_sent': false,
      'topic_subscribed': false,
    };

    // Envoyer le token au backend
    results['token_sent'] = await sendTokenToBackend();

    // S'abonner au topic des annonces
    results['topic_subscribed'] = await subscribeToAnnouncementsTopic();

    return results;
  }

  @override
  void onClose() {
    // Nettoyage si nécessaire
    super.onClose();
  }
}
