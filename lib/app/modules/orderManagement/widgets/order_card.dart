import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/deposit_widgets.dart';
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
    final dateFormat = DateFormat('order_management.card.date_time_format'.tr);
    final controller = Get.find<OrderManagementController>();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space3),
      child: AppCard(
        onTap: onTap,
        elevated: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppDesign.space3,
              runSpacing: AppDesign.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'order_management.card.order_number'.trParams({
                    'number': order.displayNumber,
                  }),
                  style: context.h6.copyWith(fontWeight: FontWeight.w600),
                ),
                _buildStatusBadge(context),
              ],
            ),

            if (order.isCarrier) ...[
              const SizedBox(height: 8),
              _buildHint(
                context,
                icon: Icons.local_shipping_rounded,
                color: AppThemeSystem.infoColor,
                text: [
                  'order_management.card.carrier'.trParams({
                    'name': order.delivery?.companyName ?? '',
                  }).trim(),
                  if (order.delivery?.routeLabel != null)
                    order.delivery!.routeLabel!,
                  if (order.delivery?.carrierTrackingNumber != null)
                    'order_management.card.tracking'.trParams({
                      'number': '${order.delivery!.carrierTrackingNumber}',
                    })
                  else if (order.delivery?.trackingStatusLabel != null)
                    order.delivery!.trackingStatusLabel!,
                ].join(' · '),
              ),
            ],

            // Une commande annulée est remboursée : l'avertissement « paiement en
            // attente » n'a plus lieu d'être.
            if (order.status != OrderStatus.cancelled &&
                (!order.isPaid || order.deliveryAssigned)) ...[
              const SizedBox(height: 8),
              _buildHint(
                context,
                icon: !order.isPaid
                    ? Icons.hourglass_top_rounded
                    : Icons.delivery_dining_rounded,
                color: !order.isPaid
                    ? AppThemeSystem.warningColor
                    : AppThemeSystem.infoColor,
                text: !order.isPaid
                    ? 'order_management.card.payment_pending'.tr
                    : order.deliveryPersonName != null
                    ? 'order_management.card.deliverer_assigned_named'.trParams(
                        {'name': order.deliveryPersonName!},
                      )
                    : 'order_management.card.deliverer_assigned'.tr,
              ),
            ],

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
                  order.city.isNotEmpty
                      ? order.city
                      : 'order_management.card.unknown_city'.tr,
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
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: AppDesign.space3,
                runSpacing: AppDesign.space2,
                children: [
                  Text(
                    'order_management.card.for_you'.tr,
                    style: context.body2.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    controller.formatPrice(order.vendorAmount),
                    style: context.h6.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Commande avec acompte : versement après le solde du client.
            if (order.deposit != null) ...[
              const SizedBox(height: 6),
              DepositVendorNotice(info: order.deposit!, settled: order.settled),
            ],

            // Livraison offerte au client : déjà déduite du montant ci-dessus.
            if (order.freeDeliveryAmount > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 16,
                    color: AppDesign.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'order_management.card.free_delivery_deducted'.trParams({
                        'amount': controller.formatPrice(
                          order.freeDeliveryAmount,
                        ),
                      }),
                      style: context.caption.copyWith(
                        color: AppDesign.successText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],

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
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
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

  Widget _buildHint(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: context.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
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
              : Icon(Icons.person, color: AppThemeSystem.primaryColor),
        ),
        const SizedBox(width: 12),
        // Nom et téléphone
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.clientName,
                style: context.body1.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                order.deliveryPhone.isNotEmpty
                    ? order.deliveryPhone
                    : order.clientPhone,
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
        ...displayItems.map(
          (item) => Padding(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.productName} x${item.quantity}',
                        style: context.body2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.variantLabel != null || item.tierLabel != null)
                        Text(
                          [
                            item.variantLabel,
                            item.tierLabel,
                          ].whereType<String>().join(' · '),
                          style: context.caption.copyWith(
                            color: AppThemeSystem.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              'order_management.card.more_items'.trParams({
                'count': '${order.items.length - 2}',
              }),
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
    final stackActions =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(15) > 20;

    // Boutons selon le statut
    if (order.status == OrderStatus.pending) {
      return Flex(
        direction: stackActions ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: _buildCompactButton(
              context,
              icon: Icons.check,
              label: 'order_management.card.validate'.tr,
              color: AppThemeSystem.successColor,
              onPressed: onValidate,
              isTablet: isTablet,
            ),
          ),
          SizedBox(width: 8, height: stackActions ? 8 : 0),
          Flexible(
            fit: FlexFit.loose,
            child: _buildCompactButton(
              context,
              icon: Icons.close,
              label: 'order_management.card.cancel'.tr,
              color: AppThemeSystem.errorColor,
              onPressed: onCancel,
              isTablet: isTablet,
            ),
          ),
          SizedBox(width: 8, height: stackActions ? 8 : 0),
          Flexible(
            fit: FlexFit.loose,
            child: _buildCompactButton(
              context,
              icon: Icons.chat_bubble_outline,
              label: 'order_management.card.chat'.tr,
              color: AppThemeSystem.infoColor,
              onPressed: onChat,
              isTablet: isTablet,
            ),
          ),
        ],
      );
    } else if (order.canHandToCarrier || order.canAddTrackingStep) {
      // Commande transporteur : pas de livreur, remise en agence puis suivi.
      final controller = Get.find<OrderManagementController>();
      return Flex(
        direction: stackActions ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            flex: 2,
            child: _buildCompactButton(
              context,
              icon: order.canHandToCarrier
                  ? Icons.local_shipping_rounded
                  : Icons.add_location_alt_outlined,
              label: order.canHandToCarrier
                  ? 'order_management.card.hand_to_carrier'.tr
                  : 'order_management.card.add_step'.tr,
              color: AppThemeSystem.primaryColor,
              onPressed: () => order.canHandToCarrier
                  ? controller.handToCarrier(order)
                  : controller.addTrackingStep(order),
              isTablet: isTablet,
            ),
          ),
          SizedBox(width: 8, height: stackActions ? 8 : 0),
          Flexible(
            fit: FlexFit.loose,
            child: _buildCompactButton(
              context,
              icon: Icons.chat_bubble_outline,
              label: 'order_management.card.chat'.tr,
              color: AppThemeSystem.infoColor,
              onPressed: onChat,
              isTablet: isTablet,
            ),
          ),
        ],
      );
    } else if (order.status == OrderStatus.validated && !order.isCarrier) {
      final controller = Get.find<OrderManagementController>();
      return Flex(
        direction: stackActions ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Obx(
              () => controller.isLoadingDeliverers.value
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
                      label: isTablet
                          ? 'order_management.card.contact_deliverer'.tr
                          : 'order_management.card.deliverer'.tr,
                      color: AppThemeSystem.infoColor,
                      onPressed: onContactDelivery,
                      isTablet: isTablet,
                    ),
            ),
          ),
          SizedBox(width: 8, height: stackActions ? 8 : 0),
          Flexible(
            fit: FlexFit.loose,
            child: _buildCompactButton(
              context,
              icon: Icons.chat_bubble_outline,
              label: 'order_management.card.chat'.tr,
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
        label: isTablet
            ? 'order_management.card.contact_client'.tr
            : 'order_management.card.chat_client'.tr,
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
    return AppButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      size: AppButtonSize.small,
      variant: color == AppThemeSystem.errorColor
          ? AppButtonVariant.danger
          : color == AppThemeSystem.successColor ||
                color == AppThemeSystem.primaryColor
          ? AppButtonVariant.primary
          : AppButtonVariant.secondary,
    );
  }
}
