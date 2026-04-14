import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../myOrder/controllers/my_order_controller.dart';
import '../../myOrder/models/customer_order_models.dart';

class ShipmentView extends GetView<MyOrderController> {
  const ShipmentView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.primaryTextColor),
          onPressed: () => Get.back(),
        ),
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
            final isSelected = controller.selectedStatus.value == filter['value'];

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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80,
            color: context.secondaryTextColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Aucune commande', style: context.h6.copyWith(color: context.secondaryTextColor)),
          const SizedBox(height: 8),
          Text('Vos commandes apparaitront ici', style: context.caption),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, CustomerOrder order) {
    final numberFormat = NumberFormat('#,###', 'fr_FR');

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
                      child: Text('${item.productName} x${item.quantity}',
                        style: context.body2, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text('${numberFormat.format(item.totalPrice)} FCFA',
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
                    Text('${numberFormat.format(order.deliveryFee)} FCFA', style: context.caption),
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
                    Text('${numberFormat.format(order.total)} FCFA',
                      style: context.body1.copyWith(fontWeight: FontWeight.bold, color: AppThemeSystem.primaryColor)),
                  ],
                ),
              ],
            ),
          ),

          // Code de confirmation (visible quand shipped)
          if (order.status == CustomerOrderStatus.shipped && order.confirmationCode != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                border: Border(top: BorderSide(color: Colors.amber.withValues(alpha: 0.3))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.key_rounded, color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 8),
                      Text('Code de confirmation',
                        style: context.body2.copyWith(fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
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
                        color: Colors.amber.shade800,
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
                    style: context.caption.copyWith(color: Colors.amber.shade800),
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
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
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
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                foregroundColor: Colors.green,
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
                  backgroundColor: Colors.amber.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(CustomerOrderStatus status) {
    switch (status) {
      case CustomerOrderStatus.pending: return Colors.orange;
      case CustomerOrderStatus.confirmed: return Colors.blue;
      case CustomerOrderStatus.preparing: return Colors.purple;
      case CustomerOrderStatus.shipped: return Colors.indigo;
      case CustomerOrderStatus.delivered: return Colors.green;
      case CustomerOrderStatus.cancelled: return Colors.red;
    }
  }
}
