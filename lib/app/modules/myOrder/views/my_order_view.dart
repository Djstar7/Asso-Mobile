import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/free_delivery_widgets.dart';
import '../controllers/my_order_controller.dart';
import '../models/customer_order_models.dart';
import '../../../core/utils/app_design.dart';
import 'order_delivery_section.dart';
import 'order_deposit_section.dart';
import 'order_control_section.dart';

class MyOrderView extends GetView<MyOrderController> {
  const MyOrderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'my_order.title'.tr,
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Filtres par statut
          _buildStatusFilters(context),

          SizedBox(height: context.elementSpacing),

          // Liste des commandes
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.filteredOrders.isEmpty) {
                return _buildEmptyState(context);
              }

              return RefreshIndicator(
                onRefresh: () => controller.loadOrders(refresh: true),
                child: ListView.separated(
                  padding: EdgeInsets.all(context.horizontalPadding),
                  itemCount: controller.filteredOrders.length,
                  separatorBuilder: (context, index) => SizedBox(height: context.elementSpacing),
                  itemBuilder: (context, index) {
                    final order = controller.filteredOrders[index];
                    return _buildOrderCard(context, order);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilters(BuildContext context) {
    final filters = [
      {'label': 'my_order.filters.all'.tr, 'value': 'all'},
      {'label': 'my_order.filters.pending'.tr, 'value': 'pending'},
      {'label': 'my_order.filters.confirmed'.tr, 'value': 'confirmed'},
      {'label': 'my_order.filters.preparing'.tr, 'value': 'preparing'},
      {'label': 'my_order.filters.shipped'.tr, 'value': 'shipped'},
      {'label': 'my_order.filters.delivered'.tr, 'value': 'delivered'},
      {'label': 'my_order.filters.cancelled'.tr, 'value': 'cancelled'},
    ];

    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];

          return Obx(() {
            final isSelected = controller.selectedStatus.value == filter['value'];

            return FilterChip(
              label: Text(filter['label'] as String),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  controller.filterByStatus(filter['value'] as String);
                }
              },
              backgroundColor: context.surfaceColor,
              selectedColor: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppThemeSystem.primaryColor : context.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppThemeSystem.primaryColor : context.borderColor,
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: context.secondaryTextColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'my_order.empty.title'.tr,
            style: context.h6.copyWith(color: context.secondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'my_order.empty.message'.tr,
            style: context.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, CustomerOrder order) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la commande
          _buildOrderHeader(context, order),

          Divider(color: context.borderColor, height: 1),

          // Articles de la commande
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'my_order.items'.tr,
                  style: context.body2.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...order.items.map((item) => _buildOrderItem(context, item)),
              ],
            ),
          ),

          Divider(color: context.borderColor, height: 1),

          // Détails de la commande
          _buildOrderDetails(context, order),

          // Commande avec acompte : suivi jusqu'au solde, puis paiement du solde
          CustomerOrderDepositSection(order: order),

          // Livraison P4 : transporteur, suivi daté, détail du prix
          CustomerOrderDeliverySection(order: order),

          // 48 h après la livraison : « Tout est conforme » ou réclamation par article
          CustomerOrderControlSection(order: order),

          // Actions
          if (_shouldShowActions(order)) ...[
            Divider(color: context.borderColor, height: 1),
            _buildOrderActions(context, order),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderHeader(BuildContext context, CustomerOrder order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icône de statut
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withValues(alpha: 0.1),
              borderRadius: context.borderRadius(BorderRadiusType.small),
            ),
            child: Text(
              order.status.icon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),

          // ID et statut
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'my_order.order_number'.trParams({'id': order.id}),
                  style: context.body1.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.status.label,
                        style: context.caption.copyWith(
                          color: _getStatusColor(order.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('dd/MM/yyyy').format(order.orderDate),
                style: context.caption,
              ),
              Text(
                DateFormat('HH:mm').format(order.orderDate),
                style: context.caption.copyWith(color: context.secondaryTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, CustomerOrderItem item) {
    final numberFormat = NumberFormat('#,###');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Image placeholder
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppThemeSystem.grey200,
              borderRadius: context.borderRadius(BorderRadiusType.small),
            ),
            child: Icon(
              Icons.shopping_bag,
              color: context.secondaryTextColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Détails du produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: context.body2.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'my_order.quantity'.trParams({'quantity': '${item.quantity}'}),
                  style: context.caption,
                ),
              ],
            ),
          ),

          // Prix
          Text(
            controller.formatPrice(item.totalPrice),
            style: context.body2.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(BuildContext context, CustomerOrder order) {
    final numberFormat = NumberFormat('#,###');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Adresse de livraison
          _buildDetailRow(
            context,
            icon: Icons.location_on,
            label: 'my_order.details.delivery_address'.tr,
            value: order.deliveryAddress,
          ),

          if (order.trackingNumber != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              icon: Icons.local_shipping,
              label: 'my_order.details.tracking_number'.tr,
              value: order.trackingNumber!,
            ),
          ],

          if (order.deliveryPersonName != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              icon: Icons.person,
              label: 'my_order.details.delivery_person'.tr,
              value: order.deliveryPersonName!,
            ),
          ],

          if (order.deliveryDate != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              icon: Icons.event_available,
              label: 'my_order.details.delivery_date'.tr,
              value: DateFormat('my_order.details.date_time_format'.tr).format(order.deliveryDate!),
            ),
          ],

          const SizedBox(height: 16),

          // Totaux
          _buildPriceRow(context, 'my_order.details.subtotal'.tr, order.subtotal),
          const SizedBox(height: 8),
          if (order.freeDeliveryAmount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('my_order.details.delivery_fee'.tr, style: context.body2),
                DeliveryPriceText(
                  price: controller.formatPrice(order.freeDeliveryAmount),
                  isFree: true,
                  style: context.body2.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            )
          else
            _buildPriceRow(context, 'my_order.details.delivery_fee'.tr, order.deliveryFee),
          const SizedBox(height: 8),
          Divider(color: context.borderColor),
          const SizedBox(height: 8),
          _buildPriceRow(
            context,
            'my_order.details.total'.tr,
            order.total,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.secondaryTextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.caption),
              const SizedBox(height: 2),
              Text(
                value,
                style: context.body2.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(BuildContext context, String label, double value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? context.body1.copyWith(fontWeight: FontWeight.bold)
              : context.body2,
        ),
        Text(
          controller.formatPrice(value),
          style: isTotal
              ? context.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppThemeSystem.primaryColor,
                )
              : context.body2.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  bool _shouldShowActions(CustomerOrder order) {
    return order.status == CustomerOrderStatus.pending ||
        order.status == CustomerOrderStatus.confirmed ||
        order.status == CustomerOrderStatus.shipped ||
        order.status == CustomerOrderStatus.delivered;
  }

  Widget _buildOrderActions(BuildContext context, CustomerOrder order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Bouton Annuler (seulement pour pending et confirmed)
          if (order.status == CustomerOrderStatus.pending ||
              order.status == CustomerOrderStatus.confirmed)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.cancelOrder(order.id),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: Text('my_order.actions.cancel'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesign.danger,
                  side: const BorderSide(color: AppDesign.danger),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          // Espacement
          if ((order.status == CustomerOrderStatus.pending ||
                  order.status == CustomerOrderStatus.confirmed) &&
              order.status == CustomerOrderStatus.shipped)
            const SizedBox(width: 12),

          // Bouton Suivre (seulement pour shipped)
          if (order.status == CustomerOrderStatus.shipped) ...[
            if (order.status == CustomerOrderStatus.pending ||
                order.status == CustomerOrderStatus.confirmed)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => controller.trackOrder(order.id),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text('my_order.actions.track'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeSystem.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => controller.trackOrder(order.id),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text('my_order.actions.track_delivery'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeSystem.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],

          // Bouton Contacter le livreur
          if (order.deliveryPersonPhone != null &&
              order.status == CustomerOrderStatus.shipped) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => controller.contactDelivery(order.deliveryPersonPhone!),
              icon: const Icon(Icons.phone),
              style: IconButton.styleFrom(
                backgroundColor: AppDesign.success.withValues(alpha: 0.1),
                foregroundColor: AppDesign.success,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],

          // Commande livrée et déjà notée : on rappelle la note laissée.
          if (order.status == CustomerOrderStatus.delivered &&
              !order.canRate &&
              order.ratingValue != null)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('my_order.actions.your_rating'.tr, style: const TextStyle(fontSize: 13)),
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= order.ratingValue!
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: AppDesign.warning,
                    ),
                ],
              ),
            ),

          // Commande livrée pas encore notée : on propose de noter.
          if (order.status == CustomerOrderStatus.delivered && order.canRate)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => controller.showRatingDialog(order),
                icon: const Icon(Icons.star_rounded, size: 18, color: Colors.white),
                label: Text('my_order.actions.rate'.tr, style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.warning,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          // Bouton Confirmer la livraison (débloque l'argent)
          if (order.status == CustomerOrderStatus.shipped && !order.isCarrier)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => controller.confirmDelivery(order.id),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('my_order.actions.confirm_reception'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(CustomerOrderStatus status) {
    switch (status) {
      case CustomerOrderStatus.pending:
        return AppDesign.accent;
      case CustomerOrderStatus.confirmed:
        return AppDesign.info;
      case CustomerOrderStatus.preparing:
        return AppDesign.neutral500;
      case CustomerOrderStatus.shipped:
        return AppDesign.neutral500;
      case CustomerOrderStatus.delivered:
        return AppDesign.success;
      case CustomerOrderStatus.cancelled:
        return AppDesign.danger;
    }
  }
}
