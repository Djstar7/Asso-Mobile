import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/notification_controller.dart';
import '../../../data/services/firebase_messaging_service.dart';
import '../../../core/utils/app_design.dart';

class NotificationView extends GetView<NotificationController> {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    // Configuration de timeago en français
    timeago.setLocaleMessages('fr', timeago.FrMessages());

    return Scaffold(
      backgroundColor: AppThemeSystem.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppThemeSystem.whiteColor,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppThemeSystem.blackColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: const AppBackButton(color: AppThemeSystem.blackColor),
        actions: [
          Obx(() {
            final hasNotifications = controller.notifications.isNotEmpty;
            return hasNotifications
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppThemeSystem.blackColor),
                    onSelected: (value) {
                      if (value == 'mark_all_read') {
                        controller.markAllAsRead();
                      } else if (value == 'delete_all') {
                        _showDeleteAllDialog(context);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'mark_all_read',
                        child: Row(
                          children: [
                            Icon(Icons.done_all, size: 20),
                            SizedBox(width: 12),
                            Text('Tout marquer comme lu'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete_all',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep, size: 20, color: AppThemeSystem.errorColor),
                            SizedBox(width: 12),
                            Text('Tout supprimer', style: TextStyle(color: AppThemeSystem.errorColor)),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.notifications.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppThemeSystem.primaryColor),
          );
        }

        if (controller.notifications.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          color: AppThemeSystem.primaryColor,
          onRefresh: () => controller.fetchNotifications(refresh: true),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: controller.notifications.length + (controller.isLoadingMore.value ? 1 : 0),
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == controller.notifications.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: AppThemeSystem.primaryColor),
                  ),
                );
              }

              final notification = controller.notifications[index];
              return _buildNotificationItem(context, notification, index);
            },
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 120,
            color: AppThemeSystem.blackColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppThemeSystem.blackColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous serez notifié ici',
            style: TextStyle(
              fontSize: 14,
              color: AppThemeSystem.blackColor.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, notification, int index) {
    final type = notification.type ?? 'default';
    final iconData = _getIconForType(type);
    final color = _getColorForType(type);
    final isRead = notification.isRead;

    return Dismissible(
      key: Key(notification.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppThemeSystem.errorColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteDialog(context);
      },
      onDismissed: (direction) {
        controller.deleteNotification(notification.id);
      },
      child: InkWell(
        onTap: () {
          if (!isRead) {
            controller.markAsRead(notification.id);
          }
          _handleNotificationTap(notification);
        },
        child: Container(
          color: isRead ? AppThemeSystem.whiteColor : AppThemeSystem.primaryColor.withOpacity(0.05),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                              color: AppThemeSystem.blackColor,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppThemeSystem.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppThemeSystem.blackColor.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeago.format(notification.createdAt, locale: 'fr'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppThemeSystem.blackColor.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'wallet_credit':
      case 'wallet_deposit_success':
        return Icons.account_balance_wallet_rounded;
      case 'wallet_deposit_failed':
      case 'wallet_withdrawal_failed':
        return Icons.error_rounded;
      case 'wallet_withdrawal_success':
        return Icons.arrow_circle_up_rounded;
      case 'order_update':
        return Icons.shopping_bag_rounded;
      case 'new_message':
        return Icons.message_rounded;
      case 'test':
        return Icons.bug_report_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'wallet_credit':
      case 'wallet_deposit_success':
        return AppThemeSystem.successColor;
      case 'wallet_deposit_failed':
      case 'wallet_withdrawal_failed':
        return AppThemeSystem.errorColor;
      case 'wallet_withdrawal_success':
        return AppThemeSystem.infoColor;
      case 'order_update':
        return AppThemeSystem.warningColor;
      case 'new_message':
        return AppThemeSystem.primaryColor;
      case 'test':
        return AppDesign.neutral500;
      default:
        return AppThemeSystem.primaryColor;
    }
  }

  void _handleNotificationTap(notification) {
    final data = Map<String, dynamic>.from(notification.data ?? {});
    data['type'] ??= notification.type;
    // Même aiguillage qu'un tap sur la notification push. Celui d'ici visait
    // des routes inexistantes (`/orders/…`, `/chat/…`) : rien ne s'ouvrait.
    if (Get.isRegistered<FirebaseMessagingService>()) {
      FirebaseMessagingService.to.openFromNotificationData(data);
    }
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la notification'),
        content: const Text('Voulez-vous vraiment supprimer cette notification ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppThemeSystem.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAllDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer toutes les notifications'),
        content: const Text('Voulez-vous vraiment supprimer toutes vos notifications ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer tout',
              style: TextStyle(color: AppThemeSystem.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      controller.clearAll();
    }
  }
}
