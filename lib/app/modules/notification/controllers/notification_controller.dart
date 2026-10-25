import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../../core/models/notification_model.dart';
import '../../../data/services/notification_service.dart';
import '../../../routes/app_pages.dart';
import '../../../core/utils/session_scope.dart';
import '../../../data/providers/storage_service.dart';
import '../../wallet/controllers/wallet_controller.dart';

class NotificationController extends GetxController
    with WidgetsBindingObserver {
  final List<StreamSubscription<RemoteMessage>> _subscriptions = [];

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
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
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
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage),
    );

    // 2. Notification cliquée quand l'app est en arrière-plan
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(
        _handleBackgroundMessageClick,
      ),
    );
  }

  /// Gère les notifications reçues quand l'app est active
  void _handleForegroundMessage(RemoteMessage message) {
    if (!StorageService.isAuthenticated) return;
    final data = message.data;
    // Fetch account-scoped content from the API, never insert a raw push body.
    fetchNotifications(refresh: true);

    // Gérer les actions selon le type (rafraîchissement wallet, etc.).
    _handleNotificationAction(data);
  }

  /// Gère le clic sur une notification en arrière-plan
  void _handleBackgroundMessageClick(RemoteMessage message) {
    if (!StorageService.isAuthenticated) return;

    final data = message.data;

    // Rafraîchir les notifications depuis le backend
    fetchNotifications(refresh: true);

    // Gérer les actions selon le type
    _handleNotificationAction(data, fromClick: true);
  }

  /// Rafraîchit les données touchées par une notification.
  ///
  /// La navigation au tap est l'affaire de `FirebaseMessagingService`, qui
  /// écoute les mêmes flux : naviguer aussi d'ici ouvrait chaque écran deux
  /// fois, et visait des routes inexistantes (`/orders/…`, `/chat/…`).
  void _handleNotificationAction(
    Map<String, dynamic> data, {
    bool fromClick = false,
  }) {
    final type = data['type'] as String?;

    switch (type) {
      case 'wallet_credit':
      case 'wallet_deposit_success':
      case 'wallet_deposit_failed':
      case 'wallet_withdrawal_success':
      case 'wallet_withdrawal_failed':
        _refreshWallet();
        break;
    }
  }

  /// Rafraîchit le wallet
  void _refreshWallet() {
    try {
      if (Get.isRegistered<WalletController>()) {
        final walletController = Get.find<WalletController>();
        walletController.refresh();
      } else {}
    } catch (e) {}
  }

  void resetForSession() {
    notifications.clear();
    unreadCount.value = 0;
    isLoading.value = false;
    isLoadingMore.value = false;
    _currentPage = 1;
    _hasMorePages = true;
  }

  /// Récupère les notifications depuis le backend
  Future<void> fetchNotifications({bool refresh = false}) async {
    final session = SessionScope.current;
    if (!StorageService.isAuthenticated) return;
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

      if (!SessionScope.isCurrent(session)) return;
      if (response.success && response.data != null) {
        final newNotifications = NotificationService.parseNotifications(
          response.data!['notifications'],
        );

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
    } finally {
      if (SessionScope.isCurrent(session)) isLoading.value = false;
    }
  }

  /// Charge plus de notifications (pagination)
  Future<void> loadMoreNotifications() async {
    final session = SessionScope.current;
    if (!StorageService.isAuthenticated) return;
    if (isLoadingMore.value || !_hasMorePages) return;

    isLoadingMore.value = true;
    _currentPage++;

    try {
      await fetchNotifications();
    } finally {
      if (SessionScope.isCurrent(session)) isLoadingMore.value = false;
    }
  }

  /// Met à jour le compteur de notifications non lues
  Future<void> updateUnreadCount() async {
    final session = SessionScope.current;
    if (!StorageService.isAuthenticated) return;
    try {
      final response = await NotificationService.getUnreadCount();
      if (!SessionScope.isCurrent(session)) return;
      if (response.success && response.data != null) {
        unreadCount.value = response.data!['unread_count'] ?? 0;
      }
    } catch (e) {}
  }

  /// Marque une notification comme lue
  Future<void> markAsRead(int notificationId) async {
    final session = SessionScope.current;
    if (!StorageService.isAuthenticated) return;
    try {
      final response = await NotificationService.markAsRead(notificationId);

      if (!SessionScope.isCurrent(session)) return;
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
    } catch (e) {}
  }

  /// Marque toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    final session = SessionScope.current;
    if (!StorageService.isAuthenticated) return;
    try {
      final response = await NotificationService.markAllAsRead();

      if (!SessionScope.isCurrent(session)) return;
      if (response.success) {
        // Mettre à jour localement
        notifications.value = notifications
            .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
            .toList();
        unreadCount.value = 0;
        notifications.refresh();
      }
    } catch (e) {}
  }

  /// Supprime une notification
  Future<void> deleteNotification(int notificationId) async {
    final session = SessionScope.current;
    if (!StorageService.isAuthenticated) return;
    try {
      final response = await NotificationService.deleteNotification(
        notificationId,
      );

      if (!SessionScope.isCurrent(session)) return;
      if (response.success) {
        // Mettre à jour localement
        final notification = notifications.firstWhere(
          (n) => n.id == notificationId,
        );
        if (!notification.isRead) {
          unreadCount.value = (unreadCount.value - 1).clamp(0, 999);
        }
        notifications.removeWhere((n) => n.id == notificationId);
      }
    } catch (e) {}
  }

  /// Supprime toutes les notifications
  Future<void> clearAll() async {
    final session = SessionScope.current;
    if (!StorageService.isAuthenticated) return;
    try {
      final response = await NotificationService.deleteAllNotifications();

      if (!SessionScope.isCurrent(session)) return;
      if (response.success) {
        notifications.clear();
        unreadCount.value = 0;
      }
    } catch (e) {}
  }
}
