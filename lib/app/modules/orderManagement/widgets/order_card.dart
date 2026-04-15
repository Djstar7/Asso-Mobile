import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/order_management_controller.dart';
import '../models/order_model.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onValidate;
  final VoidCallback onCancel;
  final VoidCallback onChat;
  final VoidCallback onContactDelivery;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.onValidate,
    required this.onCancel,
    required this.onChat,
    required this.onContactDelivery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');
    final numberFormat = NumberFormat('#,###', 'fr_FR');

    return InkWell(
      onTap: onTap,
      borderRadius: context.borderRadius(BorderRadiusType.medium),
      child: Container(
        margin: EdgeInsets.only(bottom: context.elementSpacing),
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(
            color: context.borderColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Numéro de commande + Badge statut
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Commande #${order.id}',
                    style: context.h6.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(context),
              ],
            ),

            SizedBox(height: context.elementSpacing),

            // Info client
            _buildClientInfo(context),

            SizedBox(height: context.elementSpacing),

            // Localisation et date
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: context.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  order.city,
                  style: context.caption.copyWith(
                    color: context.secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: context.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dateFormat.format(order.orderDate),
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: context.elementSpacing),

            // Articles (aperçu)
            _buildItemsPreview(context),

            SizedBox(height: context.elementSpacing),

            // Total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                borderRadius: context.borderRadius(BorderRadiusType.small),
              ),
              child: Row(
                children: [
                  Text(
                    'Total:',
                    style: context.body2.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${numberFormat.format(order.totalAmount)} XAF',
                    style: context.h6.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: context.elementSpacing),

            // Boutons d'action
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color badgeColor;
    IconData icon;

    switch (order.status) {
      case OrderStatus.pending:
        badgeColor = AppThemeSystem.warningColor;
        icon = Icons.access_time;
        break;
      case OrderStatus.validated:
        badgeColor = AppThemeSystem.successColor;
        icon = Icons.check_circle;
        break;
      case OrderStatus.cancelled:
        badgeColor = AppThemeSystem.errorColor;
        icon = Icons.cancel;
        break;
      case OrderStatus.inDelivery:
        badgeColor = AppThemeSystem.infoColor;
        icon = Icons.local_shipping;
        break;
      case OrderStatus.delivered:
        badgeColor = AppThemeSystem.successColor;
        icon = Icons.done_all;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: context.borderRadius(BorderRadiusType.small),
        border: Border.all(
          color: badgeColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            order.status.shortLabel,
            style: context.caption.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfo(BuildContext context) {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
          child: order.clientAvatar.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    order.clientAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                      Icons.person,
                      color: AppThemeSystem.primaryColor,
                    );
                    },
                  ),
                )
              : Icon(
                  Icons.person,
                  color: AppThemeSystem.primaryColor,
                ),
        ),
        const SizedBox(width: 12),
        // Nom et téléphone
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.clientName,
                style: context.body1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order.clientPhone,
                style: context.caption.copyWith(
                  color: context.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsPreview(BuildContext context) {
    final displayItems = order.items.take(2).toList();
    final hasMore = order.items.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: context.secondaryTextColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item.productName} x${item.quantity}',
                  style: context.body2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              '+ ${order.items.length - 2} autre(s) article(s)',
              style: context.caption.copyWith(
                color: AppThemeSystem.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final isTablet = AppThemeSystem.isTabletOrLarger(context);

    // Boutons selon le statut
    if (order.status == OrderStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: _buildCompactButton(
              context,
              icon: Icons.check,
              label: 'Valider',
              color: AppThemeSystem.successColor,
              onPressed: onValidate,
              isTablet: isTablet,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildCompactButton(
              context,
              icon: Icons.close,
              label: 'Annuler',
              color: AppThemeSystem.errorColor,
              onPressed: onCancel,
              isTablet: isTablet,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildCompactButton(
              context,
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              color: AppThemeSystem.infoColor,
              onPressed: onChat,
              isTablet: isTablet,
            ),
          ),
        ],
      );
    } else if (order.status == OrderStatus.validated) {
      final controller = Get.find<OrderManagementController>();
      return Row(
        children: [
          Expanded(
            child: Obx(() => controller.isLoadingDeliverers.value
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppThemeSystem.infoColor,
                      ),
                    ),
                  )
                : _buildCompactButton(
                    context,
                    icon: Icons.delivery_dining,
                    label: isTablet ? 'Contacter livreur' : 'Livreur',
                    color: AppThemeSystem.infoColor,
                    onPressed: onContactDelivery,
                    isTablet: isTablet,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactButton(
              context,
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              color: AppThemeSystem.infoColor,
              onPressed: onChat,
              isTablet: isTablet,
            ),
          ),
        ],
      );
    } else {
      return _buildCompactButton(
        context,
        icon: Icons.chat_bubble_outline,
        label: isTablet ? 'Contacter le client' : 'Chat client',
        color: AppThemeSystem.infoColor,
        onPressed: onChat,
        isTablet: isTablet,
      );
    }
  }

  Widget _buildCompactButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isTablet,
  }) {
    // Sur mobile, réduire le padding et la taille de police
    final fontSize = isTablet ? 14.0 : 12.0;
    final iconSize = isTablet ? 18.0 : 16.0;
    final horizontalPadding = isTablet ? 12.0 : 8.0;
    final verticalPadding = isTablet ? 10.0 : 8.0;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      label: Text(
        label,
        style: TextStyle(fontSize: fontSize),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: context.borderRadius(BorderRadiusType.small),
        ),
      ),
    );
  }
}
