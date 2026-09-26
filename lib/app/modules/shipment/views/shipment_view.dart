import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../myOrder/controllers/my_order_controller.dart';
import '../../myOrder/models/customer_order_models.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';
import '../../myOrder/views/order_delivery_section.dart';

class ShipmentView extends GetView<MyOrderController> {
  const ShipmentView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Mes commandes',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.secondaryTextColor),
            onPressed: () => controller.loadOrders(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilters(context),
          SizedBox(height: context.elementSpacing),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.filteredOrders.isEmpty) {
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
                  separatorBuilder: (_, __) => SizedBox(height: context.elementSpacing),
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
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: Obx(() {
        // Access observable immediately to register dependency
        final selectedStatus = controller.selectedStatus.value;

        final filters = [
          {'label': 'Tout', 'value': 'all'},
          {'label': 'En attente', 'value': 'pending'},
          {'label': 'Confirmée', 'value': 'confirmed'},
          {'label': 'En livraison', 'value': 'shipped'},
          {'label': 'Livrée', 'value': 'delivered'},
          {'label': 'Annulée', 'value': 'cancelled'},
        ];

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = selectedStatus == filter['value'];

            return FilterChip(
              label: Text(filter['label'] as String),
              selected: isSelected,
              onSelected: (_) => controller.filterByStatus(filter['value'] as String),
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
          },
        );
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Aucune commande',
      message: 'Les commandes à expédier apparaîtront ici.',
    );
  }

  Widget _buildOrderCard(BuildContext context, CustomerOrder order) {

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.1),
                    borderRadius: context.borderRadius(BorderRadiusType.small),
                  ),
                  child: Text(order.status.icon, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber != null ? '#${order.orderNumber}' : 'Commande ${order.id}',
                        style: context.body1.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(order.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order.status.label,
                          style: context.caption.copyWith(
                            color: _statusColor(order.status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(DateFormat('dd/MM/yyyy').format(order.orderDate), style: context.caption),
                    Text(DateFormat('HH:mm').format(order.orderDate),
                      style: context.caption.copyWith(color: context.secondaryTextColor)),
                  ],
                ),
              ],
            ),
          ),

          Divider(color: context.borderColor, height: 1),

          // Articles
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${item.displayName} x${item.quantity}',
                        style: context.body2, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(controller.formatPrice(item.totalPrice),
                      style: context.body2.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              )).toList(),
            ),
          ),

          // Livraison + total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.03),
              border: Border(top: BorderSide(color: context.borderColor)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Livraison', style: context.caption),
                    Text(controller.formatPrice(order.deliveryFee), style: context.caption),
                  ],
                ),
                if (order.deliveryCompanyName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.local_shipping_rounded, size: 14, color: context.secondaryTextColor),
                      const SizedBox(width: 4),
                      Text(order.deliveryCompanyName!, style: context.caption),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: context.body1.copyWith(fontWeight: FontWeight.bold)),
                    Text(controller.formatPrice(order.total),
                      style: context.body1.copyWith(fontWeight: FontWeight.bold, color: AppThemeSystem.primaryColor)),
                  ],
                ),
              ],
            ),
          ),

          // Livraison P4 : transporteur, suivi daté, détail du prix
          CustomerOrderDeliverySection(order: order),

          // Code de confirmation (visible quand shipped)
          if (order.status == CustomerOrderStatus.shipped && order.confirmationCode != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesign.warning.withValues(alpha: 0.1),
                border: Border(top: BorderSide(color: AppDesign.warning.withValues(alpha: 0.3))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.key_rounded, color: AppDesign.warning, size: 20),
                      const SizedBox(width: 8),
                      Text('Code de confirmation',
                        style: context.body2.copyWith(fontWeight: FontWeight.w600, color: AppDesign.warning)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: order.confirmationCode!));
                      Get.snackbar('Copie', 'Code copie dans le presse-papiers',
                        snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppDesign.warning,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.confirmationCode!,
                        style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold,
                          letterSpacing: 8, color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Communiquez ce code au livreur pour confirmer la reception',
                    style: context.caption.copyWith(color: AppDesign.warning),
                    textAlign: TextAlign.center),
                ],
              ),
            ),

          // Actions
          _buildActions(context, order),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, CustomerOrder order) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (order.status == CustomerOrderStatus.pending)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.cancelOrder(order.id),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Annuler'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesign.danger,
                  side: const BorderSide(color: AppDesign.danger),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          if (order.status == CustomerOrderStatus.shipped && order.deliveryPersonPhone != null) ...[
            if (order.status == CustomerOrderStatus.pending) const SizedBox(width: 8),
            IconButton(
              onPressed: () => controller.contactDelivery(order.deliveryPersonPhone!),
              icon: const Icon(Icons.phone),
              style: IconButton.styleFrom(
                backgroundColor: AppDesign.success.withValues(alpha: 0.1),
                foregroundColor: AppDesign.success,
              ),
            ),
          ],

          if (order.canRate)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => controller.showRatingDialog(order),
                icon: const Icon(Icons.star_rounded, size: 18, color: Colors.white),
                label: const Text('Noter', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.warning,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          // Commande déjà notée : l'acheteur revoit la note qu'il a laissée.
          if (!order.canRate && order.ratingValue != null)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Votre note ', style: TextStyle(fontSize: 13)),
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= order.ratingValue! ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 18,
                      color: AppDesign.warning,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(CustomerOrderStatus status) {
    switch (status) {
      case CustomerOrderStatus.pending: return AppDesign.accent;
      case CustomerOrderStatus.confirmed: return AppDesign.info;
      case CustomerOrderStatus.preparing: return AppDesign.neutral500;
      case CustomerOrderStatus.shipped: return AppDesign.neutral500;
      case CustomerOrderStatus.delivered: return AppDesign.success;
      case CustomerOrderStatus.cancelled: return AppDesign.danger;
    }
  }
}
