import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../providers/device_token_provider.dart';

/// Service FCM pour gérer les notifications push
/// Utilisé principalement pour les notifications de wallet (dépôts/retraits)
class FcmService extends GetxService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Stream controller pour les notifications de wallet
  final _walletNotificationStream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get walletNotificationStream =>
      _walletNotificationStream.stream;

  // Stream controller pour les notifications de commande/livraison
  final _orderNotificationStream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get orderNotificationStream =>
      _orderNotificationStream.stream;

  /// Initialiser le service FCM
  Future<FcmService> init() async {
    print('[FCM] Initializing FCM Service...');

    // Demander la permission
    await _requestPermission();

    // Configurer les notifications locales
    await _setupLocalNotifications();

    // Écouter les messages FCM
    _setupMessageHandlers();

    // Récupérer et enregistrer le token FCM
    await _getToken();

    // Configurer le rafraîchissement automatique du token
    setupTokenRefresh();

    print('[FCM] FCM Service initialized');
    return this;
  }

  /// Demander la permission pour les notifications
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[FCM] User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('[FCM] User granted provisional notification permission');
    } else {
      print('[FCM] User declined or has not accepted notification permission');
    }
  }

  /// Configurer les notifications locales
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Gérer le tap sur une notification locale
  void _onNotificationTapped(NotificationResponse response) {
    print('[FCM] Notification tapped: ${response.payload}');

    if (response.payload == null) return;

    final payload = response.payload!;

    // Navigation basée sur le payload
    if (payload.contains('wallet')) {
      Get.toNamed('/wallet');
    } else if (payload == 'vendor_dashboard') {
      Get.toNamed('/vendor-dashboard');
    } else if (payload == 'package_subscription') {
      Get.toNamed('/package-subscription');
    } else if (payload.startsWith('order_details:')) {
      final orderId = payload.split(':').last;
      if (orderId.isNotEmpty) {
        Get.toNamed('/order-details', arguments: {'orderId': orderId});
      }
    }
  }

  /// Configurer les handlers de messages FCM
  void _setupMessageHandlers() {
    // Message reçu quand l'app est en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM] Foreground message received:');
      print('  Title: ${message.notification?.title}');
      print('  Body: ${message.notification?.body}');
      print('  Data: ${message.data}');

      _handleMessage(message, inForeground: true);
    });

    // Message reçu quand l'app est en background et qu'on clique dessus
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM] Background message opened:');
      print('  Data: ${message.data}');

      _handleMessage(message, inForeground: false);
    });

    // Vérifier si l'app a été ouverte depuis une notification
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        print('[FCM] App opened from terminated state via notification');
        _handleMessage(message, inForeground: false);
      }
    });
  }

  /// Gérer un message FCM reçu
  void _handleMessage(RemoteMessage message, {required bool inForeground}) {
    final data = message.data;
    final type = data['type'] as String?;

    print('[FCM] Handling message type: $type');

    // Notifications de wallet
    if (type == 'wallet_credit' ||
        type == 'wallet_credit_failed' ||
        type == 'wallet_withdrawal_completed' ||
        type == 'wallet_withdrawal_failed') {
      print('[FCM] Wallet notification received');

      // Émettre dans le stream pour que le WalletController puisse réagir
      _walletNotificationStream.add(data);

      // Si en foreground, afficher une notification locale
      if (inForeground) {
        _showLocalNotification(
          title: message.notification?.title ?? 'Wallet',
          body: message.notification?.body ?? 'Transaction mise à jour',
          payload: 'wallet:${data['wallet_transaction_id'] ?? data['withdrawal_id']}',
        );
      }
    }
    // Notifications de package purchase
    else if (type == 'package_purchase') {
      print('[FCM] Package purchase notification received');

      // Si en foreground, afficher une notification locale
      if (inForeground) {
        _showLocalNotification(
          title: message.notification?.title ?? '🎉 Package activé',
          body: message.notification?.body ?? 'Votre package a été activé avec succès',
          payload: 'vendor_dashboard',
        );
      }

      // Naviguer vers le dashboard vendeur si spécifié
      final screen = data['screen'] as String?;
      if (screen == 'vendor_dashboard' && !inForeground) {
        Get.toNamed('/vendor-dashboard');
      }
    }
    // Notifications d'expiration de package
    else if (type == 'package_expiring') {
      print('[FCM] Package expiring notification received');

      if (inForeground) {
        _showLocalNotification(
          title: message.notification?.title ?? '⚠️ Package expirant',
          body: message.notification?.body ?? 'Votre package va bientôt expirer',
          payload: 'package_subscription',
        );
      }

      final screen = data['screen'] as String?;
      if (screen == 'package_subscription' && !inForeground) {
        Get.toNamed('/package-subscription');
      }
    }
    // Notifications de commande / livraison
    else if (type?.startsWith('order_') == true ||
             type?.startsWith('delivery_') == true ||
             type?.startsWith('new_delivery') == true) {
      print('[FCM] Order/delivery notification received: $type');

      // Émettre dans le stream pour que TrackingController et DeliveryDashboardController réagissent
      _orderNotificationStream.add(data);

      if (inForeground) {
        _showLocalNotification(
          title: message.notification?.title ?? 'Commande',
          body: message.notification?.body ?? 'Mise à jour de commande',
          payload: 'order_details:${data['order_id'] ?? ''}',
        );
      }
    }
  }

  /// Afficher une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'wallet_channel',
      'Wallet Notifications',
      channelDescription: 'Notifications pour les transactions du wallet',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Récupérer le token FCM
  Future<String?> _getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      print('[FCM] FCM Token: $token');

      // Envoyer le token au backend
      if (token != null) {
        try {
          final response = await DeviceTokenProvider.registerToken(token);
          if (response.success) {
            print('[FCM] ✅ Token registered successfully on backend');
          } else {
            print('[FCM] ⚠️ Failed to register token: ${response.message}');
          }
        } catch (e) {
          print('[FCM] ⚠️ Error sending token to backend: $e');
          // Ne pas bloquer si l'envoi au backend échoue
        }
      }

      return token;
    } catch (e) {
      print('[FCM] Error getting token: $e');
      return null;
    }
  }

  /// Récupérer le token FCM actuel
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Rafraîchir le token FCM
  void setupTokenRefresh() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print('[FCM] Token refreshed: $newToken');

      // Mettre à jour le token sur le backend
      try {
        final response = await DeviceTokenProvider.registerToken(newToken);
        if (response.success) {
          print('[FCM] ✅ Refreshed token registered successfully');
        } else {
          print('[FCM] ⚠️ Failed to register refreshed token: ${response.message}');
        }
      } catch (e) {
        print('[FCM] ⚠️ Error sending refreshed token to backend: $e');
      }
    });
  }

  @override
  void onClose() {
    _walletNotificationStream.close();
    _orderNotificationStream.close();
    super.onClose();
  }
}
