import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../../core/models/notification_model.dart';
import '../../../data/services/notification_service.dart';
import '../../../routes/app_pages.dart';
import '../../wallet/controllers/wallet_controller.dart';

class NotificationController extends GetxController with WidgetsBindingObserver {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Liste des notifications (synchronisées avec le backend)
  final notifications = <NotificationModel>[].obs;
  final unreadCount = 0.obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  int _currentPage = 1;
  bool _hasMorePages = true;

  @override
  void onInit() {
    super.onInit();
    // Observer le cycle de vie pour resynchroniser au retour au premier plan.
    WidgetsBinding.instance.addObserver(this);
    _setupFCMListeners();
    fetchNotifications(); // Charger l'historique depuis le backend
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Toujours resynchroniser le badge au retour au premier plan.
      updateUnreadCount();
      // Si l'écran des notifications est affiché, recharger aussi la liste.
      if (Get.currentRoute == Routes.NOTIFICATION) {
        fetchNotifications(refresh: true);
      }
    }
  }

  /// Configure les listeners FCM
  void _setupFCMListeners() {
    // 1. Notification reçue quand l'app est au premier plan (foreground)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 2. Notification cliquée quand l'app est en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageClick);

    // 3. Vérifier si l'app a été ouverte via une notification
    _checkInitialMessage();
  }

  /// Gère les notifications reçues quand l'app est active
  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 [FCM] Message reçu (foreground): ${message.data}');

    final data = message.data;
    final notification = message.notification;

    // Affichage : on NE montre PAS de snackbar ici. En foreground, la
    // notification locale (heads-up) est déjà affichée par
    // FirebaseMessagingService. Afficher aussi un snackbar créait un doublon
    // visuel : on garde donc uniquement la notification locale.

    // Insertion dans la liste : ne jamais utiliser d'ID temporaire
    // (DateTime.now()) sous peine de doublons et d'échecs de markAsRead sur un
    // ID inexistant côté backend.
    final rawId = data['notification_id'];
    final int? realId = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');

    if (realId != null) {
      // Le backend a fourni le vrai ID : insertion avec déduplication.
      _addLocalNotification(NotificationModel(
        id: realId,
        userId: 0,
        title: notification?.title ?? 'Notification',
        body: notification?.body ?? '',
        type: data['type'] as String?,
        data: data,
        isRead: false,
        sentAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      // Reconcilier le compteur avec le backend.
      updateUnreadCount();
    } else {
      // Pas d'ID réel : on recharge depuis le backend pour récupérer l'entrée
      // authentique (avec son ID) plutôt que d'inventer un ID local.
      fetchNotifications(refresh: true);
    }

    // Gérer les actions selon le type (rafraîchissement wallet, etc.).
    _handleNotificationAction(data);
  }

  /// Gère le clic sur une notification en arrière-plan
  void _handleBackgroundMessageClick(RemoteMessage message) {
    print('🖱️  [FCM] Notification cliquée: ${message.data}');

    final data = message.data;

    // Rafraîchir les notifications depuis le backend
    fetchNotifications(refresh: true);

    // Gérer les actions selon le type
    _handleNotificationAction(data, fromClick: true);
  }

  /// Vérifie si l'app a été ouverte via une notification
  Future<void> _checkInitialMessage() async {
    final message = await _firebaseMessaging.getInitialMessage();
    if (message != null) {
      print('🚀 [FCM] App ouverte via notification: ${message.data}');
      _handleBackgroundMessageClick(message);
    }
  }

  /// Gère les actions selon le type de notification
  void _handleNotificationAction(Map<String, dynamic> data, {bool fromClick = false}) {
    final type = data['type'] as String?;
    print('🎬 [FCM] Action pour type: $type (fromClick: $fromClick)');

    switch (type) {
      case 'wallet_credit':
      case 'wallet_deposit_success':
      case 'wallet_deposit_failed':
        // Rafraîchir le wallet
        _refreshWallet();

        // Si cliqué, naviguer vers l'historique
        if (fromClick) {
          Get.toNamed('/wallet/history');
        }
        break;

      case 'wallet_withdrawal_success':
      case 'wallet_withdrawal_failed':
        // Rafraîchir le wallet
        _refreshWallet();

        // Si cliqué, naviguer vers l'historique
        if (fromClick) {
          Get.toNamed('/wallet/history');
        }
        break;

      case 'order_update':
        // Naviguer vers les commandes
        if (fromClick) {
          final orderId = data['order_id'];
          if (orderId != null) {
            Get.toNamed('/orders/$orderId');
          } else {
            Get.toNamed('/orders');
          }
        }
        break;

      case 'new_message':
        // Naviguer vers le chat
        if (fromClick) {
          final conversationId = data['conversation_id'];
          if (conversationId != null) {
            Get.toNamed('/chat/$conversationId');
          } else {
            Get.toNamed('/chat');
          }
        }
        break;

      default:
        print('⚠️  [FCM] Type de notification non géré: $type');
    }
  }

  /// Rafraîchit le wallet
  void _refreshWallet() {
    try {
      if (Get.isRegistered<WalletController>()) {
        final walletController = Get.find<WalletController>();
        walletController.refresh();
        print('✅ [FCM] Wallet rafraîchi');
      } else {
        print('⚠️  [FCM] WalletController non enregistré');
      }
    } catch (e) {
      print('❌ [FCM] Erreur lors du rafraîchissement du wallet: $e');
    }
  }

  /// Récupère les notifications depuis le backend
  Future<void> fetchNotifications({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMorePages = true;
      notifications.clear();
    }

    if (!_hasMorePages) return;

    isLoading.value = true;

    try {
      final response = await NotificationService.getNotifications(
        page: _currentPage,
        perPage: 20,
      );

      if (response.success && response.data != null) {
        final newNotifications = NotificationService.parseNotifications(response.data!['notifications']);

        if (refresh) {
          notifications.value = newNotifications;
        } else {
          notifications.addAll(newNotifications);
        }

        // Mettre à jour le compteur non lus
        unreadCount.value = response.data!['unread_count'] ?? 0;

        // Vérifier s'il y a plus de pages
        final pagination = response.data!['pagination'];
        if (pagination != null) {
          _currentPage = pagination['current_page'];
          final lastPage = pagination['last_page'];
          _hasMorePages = _currentPage < lastPage;
        }
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Charge plus de notifications (pagination)
  Future<void> loadMoreNotifications() async {
    if (isLoadingMore.value || !_hasMorePages) return;

    isLoadingMore.value = true;
    _currentPage++;

    try {
      await fetchNotifications();
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Met à jour le compteur de notifications non lues
  Future<void> updateUnreadCount() async {
    try {
      final response = await NotificationService.getUnreadCount();
      if (response.success && response.data != null) {
        unreadCount.value = response.data!['unread_count'] ?? 0;
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du compteur: $e');
    }
  }

  /// Ajoute une notification locale (depuis FCM), avec déduplication par ID
  /// pour éviter d'afficher deux fois la même notification.
  void _addLocalNotification(NotificationModel notification) {
    if (notifications.any((n) => n.id == notification.id)) return;
    notifications.insert(0, notification);
    if (!notification.isRead) {
      unreadCount.value++;
    }
  }

  /// Marque une notification comme lue
  Future<void> markAsRead(int notificationId) async {
    try {
      final response = await NotificationService.markAsRead(notificationId);

      if (response.success) {
        // Mettre à jour localement
        final index = notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          notifications[index] = notifications[index].copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
          notifications.refresh();
          unreadCount.value = (unreadCount.value - 1).clamp(0, 999);
        }
      }
    } catch (e) {
      print('❌ Erreur lors du marquage comme lu: $e');
    }
  }

  /// Marque toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    try {
      final response = await NotificationService.markAllAsRead();

      if (response.success) {
        // Mettre à jour localement
        notifications.value = notifications.map((n) => n.copyWith(isRead: true, readAt: DateTime.now())).toList();
        unreadCount.value = 0;
        notifications.refresh();
      }
    } catch (e) {
      print('❌ Erreur lors du marquage de toutes comme lues: $e');
    }
  }

  /// Supprime une notification
  Future<void> deleteNotification(int notificationId) async {
    try {
      final response = await NotificationService.deleteNotification(notificationId);

      if (response.success) {
        // Mettre à jour localement
        final notification = notifications.firstWhere((n) => n.id == notificationId);
        if (!notification.isRead) {
          unreadCount.value = (unreadCount.value - 1).clamp(0, 999);
        }
        notifications.removeWhere((n) => n.id == notificationId);
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
    }
  }

  /// Supprime toutes les notifications
  Future<void> clearAll() async {
    try {
      final response = await NotificationService.deleteAllNotifications();

      if (response.success) {
        notifications.clear();
        unreadCount.value = 0;
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression de toutes: $e');
    }
  }

}
