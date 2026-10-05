import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:asso/app/routes/app_pages.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/values/constants.dart';
import '../providers/api_provider.dart';
import '../providers/storage_service.dart';
import '../../core/utils/app_navigation.dart';
import 'deep_link_service.dart';

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

  /// Topic des annonces envoyées à tous : nouveaux produits, produits
  /// sponsorisés, offres Diaspo, annonces de l'administration.
  static const String announcementsTopic = 'all_users';

  /// Vrai pendant [ensureRegisteredAndSubscribed], pour qu'un retour rapide
  /// sur l'accueil ne lance pas deux rattrapages en parallèle.
  bool _ensuring = false;

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

  /// Attend que iOS ait remis le token APNs à Firebase, au plus [timeout].
  ///
  /// Sur iOS, FCM ne peut ni fournir de token ni abonner à un topic tant
  /// qu'Apple n'a pas remis ce token : l'appel échoue aussitôt
  /// (`apns-token-not-set`). Il arrive quelques instants après le lancement —
  /// ou jamais sans l'autorisation `aps-environment` (Runner.entitlements) ni
  /// la capacité Push Notifications de l'App ID. Ailleurs, rien à attendre.
  Future<bool> _apnsTokenReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) return true;

    final deadline = DateTime.now().add(timeout);
    while (true) {
      try {
        if (await _firebaseMessaging.getAPNSToken() != null) return true;
      } catch (_) {
        // Pas encore prêt : on réessaie jusqu'à l'échéance.
      }
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Token APNs arrivé après l'initialisation : on termine alors ce que le
  /// démarrage n'a pas pu faire (token au backend, abonnement aux annonces).
  Future<void> _completeRegistrationWhenApnsReady() async {
    if (!await _apnsTokenReady(timeout: const Duration(seconds: 60))) {
      print(
        '⚠️ Aucun token APNs après 60 s : notifications push indisponibles. '
        'Vérifier l\'autorisation aps-environment (Runner.entitlements), la '
        'capacité Push Notifications de l\'App ID et la clé APNs dans la '
        'console Firebase.',
      );
      return;
    }

    print('✅ Token APNs reçu, enregistrement FCM repris');
    await _getFCMToken();
    await subscribeToAnnouncementsTopic();
  }

  /// Obtient le token FCM
  Future<void> _getFCMToken() async {
    try {
      // Brève attente seulement : l'initialisation retarde le premier écran.
      // Au-delà, l'enregistrement se poursuit en arrière-plan.
      if (!await _apnsTokenReady(timeout: const Duration(seconds: 2))) {
        print('⏳ Token APNs pas encore remis par iOS : token FCM demandé plus tard');
        unawaited(_completeRegistrationWhenApnsReady());
        return;
      }

      // Borné : sans réseau, la demande de token peut rester pendante et
      // retenait le premier écran (mode hors ligne vendeur).
      final token = await _firebaseMessaging
          .getToken()
          .timeout(const Duration(seconds: 5));
      fcmToken.value = token;

      if (token != null) {
        print('🔑 FCM Token: $token');
        // Envoyer le token au backend, sans retenir le démarrage.
        unawaited(_sendTokenToBackend(token));
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
        _markTokenRegistered(token);
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
      // L'abonnement au topic est porté par le token : on le refait.
      unawaited(subscribeToAnnouncementsTopic());
    });
  }

  /// Écoute les messages en foreground (app ouverte)
  void _listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Message reçu en foreground: ${message.messageId}');
      print('Titre: ${message.notification?.title}');
      print('Corps: ${message.notification?.body}');
      print('Data: ${message.data}');

      // Afficher une notification locale quand l'app est en foreground.
      //
      // Aucune navigation ici : elle n'a lieu qu'au tap sur la notification
      // (voir _onNotificationTapped). Naviguer à la réception envoyait tout
      // utilisateur actif sur la fiche de chaque produit publié.
      _showLocalNotification(message);
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
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Ouvre l'écran d'une notification, depuis la liste des notifications.
  Future<void> openFromNotificationData(Map<String, dynamic> data) =>
      _handleMessageData(data);

  /// Ouvre l'écran correspondant à une notification touchée.
  ///
  /// Seul point de navigation des notifications (push, notification locale,
  /// liste des notifications) : `NotificationController` écoute les mêmes
  /// flux mais se contente de rafraîchir ses données. À deux, chaque tap
  /// ouvrait deux fois le même écran.
  Future<void> _handleMessageData(Map<String, dynamic> data) async {
    print('📦 Données du message: $data');

    final type = data['type'] as String?;

    if (type == null) {
      print('⚠️ Type de notification non défini');
      return;
    }

    print('🔔 Type de notification: $type');

    // Application lancée par ce tap : on attend la fin du splash, dont le
    // `offAllNamed` emporterait l'écran ouvert trop tôt.
    if (!await AppNavigation.whenAppReady()) return;

    switch (type) {
      case 'new_message':
        // Navigation vers les détails de la conversation
        final conversationId = data['conversation_id'];
        final senderName = data['sender_name']?.toString() ?? '';

        if (conversationId != null) {
          print('💬 Navigation vers la conversation $conversationId (de $senderName)');
          Get.toNamed(Routes.CHATDETAIL, arguments: {
            'id': conversationId,
            'name': senderName.isEmpty ? 'Utilisateur' : senderName,
            // Nom vide : `senderName[0]` levait une RangeError.
            'avatar': senderName.isEmpty ? 'U' : senderName[0].toUpperCase(),
          });
        } else {
          // Si pas d'ID, naviguer vers la liste des conversations
          print('💬 Navigation vers la liste des conversations');
          Get.toNamed(Routes.CHAT);
        }
        break;

      case 'new_product':
      case 'sponsored_product':
        _openProduct(data['product_id']);
        break;

      case 'new_diaspo_offer':
        // Navigation vers les détails de l'offre diaspo
        final offerId = data['offer_id'];
        if (offerId != null) {
          print('✈️ Navigation vers l\'offre diaspo $offerId');
          Get.toNamed(Routes.DIASPO_DETAIL, arguments: {'offerId': offerId});
        } else {
          // Si pas d'ID, naviguer vers la liste des offres diaspo
          print('✈️ Navigation vers la liste des offres diaspo');
          Get.toNamed(Routes.DIASPO);
        }
        break;

      // Vérification d'identité Diaspo (validée, refusée, échéance, offre retirée) :
      // tout se consulte depuis l'espace DIASPO (bannière + onglet « Mes offres »).
      case 'diaspo_verified':
      case 'diaspo_rejected':
      case 'diaspo_verification_deadline':
      case 'diaspo_offer_removed':
        Get.toNamed(Routes.DIASPO);
        break;

      // Notifications vendeur : ouvrir la gestion des commandes / des forfaits.
      case 'new_order_vendor':
      case 'order_cancelled_vendor':
      case 'order_shipped_vendor':
      case 'order_delivered_vendor':
      case 'order_rated':
      case 'order_balance_paid_vendor':
        Get.toNamed(Routes.ORDER_MANAGEMENT);
        break;

      case 'package_expiring':
      case 'package_purchase':
        Get.toNamed(Routes.PACKAGE_SUBSCRIPTION);
        break;

      case 'wallet_credit':
      case 'wallet_deposit_success':
      case 'wallet_deposit_failed':
      case 'wallet_withdrawal_success':
      case 'wallet_withdrawal_failed':
        Get.toNamed(Routes.WALLET_HISTORY);
        break;

      // Commande avec acompte : solde débloqué, payé, échoué ou commande clôturée.
      case 'order_update':
      case 'order_balance_due':
      case 'order_balance_paid':
      case 'order_balance_failed':
      case 'order_deposit_closed':
      // Commande livrée : 48 h pour la valider ou faire une réclamation.
      case 'order_control_window':
        Get.toNamed(Routes.MY_ORDER);
        break;

      // Part vendeur débloquée (client conforme, 48 h écoulées, litige clos).
      case 'vendor_funds_released':
        Get.toNamed(Routes.WALLET_HISTORY);
        break;

      default:
        // Réclamations / litiges : le dossier, côté client ou vendeur. « Paiement
        // de livraison requis » ouvre directement le paiement de la course.
        if (type.startsWith('dispute_') && data['dispute_id'] != null) {
          Get.toNamed(Routes.DISPUTE_DETAIL, arguments: {
            'id': data['dispute_id'],
            'role': data['role'] == 'vendor' ? 'vendor' : 'client',
            'pay': type == 'dispute_shipment_payment_required' || type == 'dispute_shipment_payment_failed',
          });
          break;
        }
        print('⚠️ Type de notification non géré: $type');
        break;
    }
  }

  /// Ouvre la fiche d'un produit annoncé.
  ///
  /// La fiche attend le produit complet, pas son identifiant : on passe par
  /// le même chemin que les liens partagés, qui le charge avant de naviguer
  /// et attend que le routeur soit prêt au démarrage à froid.
  void _openProduct(Object? productId) {
    final id = productId?.toString() ?? '';
    if (id.isEmpty || !Get.isRegistered<DeepLinkService>()) {
      // L'application s'ouvre simplement là où elle était. Pas de
      // `toNamed(HOME)` : l'accueil est déjà en bas de la pile, et un second
      // accueil partagerait ses contrôleurs permanents (onglets, défilement)
      // avec le premier.
      print('🛍️ Produit non identifiable, aucune navigation');
      return;
    }

    print('🛍️ Ouverture du produit $id');
    Get.find<DeepLinkService>().handleExternal(
      Uri.parse(AppConstants.productUrl(id)),
    );
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

    if (response.payload == null || response.payload!.isEmpty) {
      print('⚠️ Payload vide');
      return;
    }

    try {
      // Parser le JSON du payload
      final Map<String, dynamic> data = jsonDecode(response.payload!);
      print('📦 Payload parsé: $data');

      // Utiliser la même logique que _handleMessageData
      _handleMessageData(data);
    } catch (e) {
      print('❌ Erreur lors du parsing du payload: $e');
    }
  }

  /// S'abonne à un topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      if (!await _apnsTokenReady()) {
        print('⏳ Abonnement au topic $topic reporté : token APNs indisponible');
        return;
      }
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
        if (!await _apnsTokenReady()) {
          print('⏳ Token FCM indisponible : iOS n\'a pas encore remis le token APNs');
          return false;
        }
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
        _markTokenRegistered(token);
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
      // Sans token APNs, l'appel échouerait aussitôt : on le signale comme un
      // report, pas comme une erreur — le token arrivé, l'abonnement est
      // repris (initialisation, rafraîchissement du token, accueil).
      if (!await _apnsTokenReady()) {
        print('⏳ Abonnement à "$announcementsTopic" reporté : token APNs indisponible');
        return false;
      }

      print('📢 Abonnement au topic "$announcementsTopic" pour les annonces...');
      // Appel direct plutôt que [subscribeToTopic], qui avale l'erreur : cette
      // méthode répondait toujours « abonné », même sans APNS sur iOS ou sans
      // services Google Play, et l'échec n'était jamais retenté.
      //
      // Borné dans le temps : sans services Google Play, l'appel ne rend
      // jamais la main.
      await _firebaseMessaging
          .subscribeToTopic(announcementsTopic)
          .timeout(const Duration(seconds: 10));

      final token = fcmToken.value;
      if (token != null) StorageService.setAnnouncementsTopicToken(token);

      print('✅ Abonné au topic "$announcementsTopic" avec succès');
      return true;
    } catch (e) {
      print('❌ Erreur lors de l\'abonnement au topic "$announcementsTopic": $e');
      return false;
    }
  }

  /// Retient que le backend connaît ce token pour le compte courant.
  void _markTokenRegistered(String token) {
    final userId = StorageService.getUser()?.id;
    if (userId != null) StorageService.setFcmRegistration('$userId:$token');
  }

  /// Rattrapage depuis l'accueil : enregistre le token et abonne l'appareil
  /// aux annonces s'il ne l'a pas encore été.
  ///
  /// La connexion, l'inscription et le splash le font déjà, mais peuvent
  /// échouer sans bruit : token pas encore disponible (APNS en retard sur
  /// iOS), réseau coupé, services Google Play absents. Sans ce rattrapage,
  /// l'appareil ne recevait plus aucune annonce jusqu'à la connexion suivante.
  ///
  /// Ne fait rien quand tout est déjà en place, pour que l'appeler à chaque
  /// ouverture de l'accueil ne coûte rien.
  Future<void> ensureRegisteredAndSubscribed() async {
    if (_ensuring) return;
    _ensuring = true;

    try {
      var token = fcmToken.value;
      if (token == null) {
        if (!await _apnsTokenReady(timeout: const Duration(seconds: 10))) {
          print('⏳ Rattrapage FCM reporté : token APNs pas encore disponible');
          return;
        }
        token = await _firebaseMessaging.getToken().timeout(
          const Duration(seconds: 10),
        );
        fcmToken.value = token;
      }
      if (token == null) {
        print('⚠️ Rattrapage FCM : token toujours indisponible');
        return;
      }

      final userId = StorageService.getUser()?.id;
      if (ApiProvider.isAuthenticated &&
          userId != null &&
          StorageService.fcmRegistration != '$userId:$token') {
        print('📤 Rattrapage FCM : token inconnu du backend, envoi...');
        await sendTokenToBackend();
      }

      if (StorageService.announcementsTopicToken != token) {
        print('📢 Rattrapage FCM : appareil non abonné aux annonces...');
        await subscribeToAnnouncementsTopic();
      }
    } catch (e) {
      print('❌ Rattrapage FCM impossible: $e');
    } finally {
      _ensuring = false;
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
