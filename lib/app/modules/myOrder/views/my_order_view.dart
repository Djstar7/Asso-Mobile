import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/my_order_controller.dart';
import '../models/customer_order_models.dart';

class MyOrderView extends GetView<MyOrderController> {
  const MyOrderView({super.key});

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
      {'label': 'Tout', 'value': 'all'},
      {'label': 'En attente', 'value': 'pending'},
      {'label': 'Confirmée', 'value': 'confirmed'},
      {'label': 'En préparation', 'value': 'preparing'},
      {'label': 'Expédiée', 'value': 'shipped'},
      {'label': 'Livrée', 'value': 'delivered'},
      {'label': 'Annulée', 'value': 'cancelled'},
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
            'Aucune commande',
            style: context.h6.copyWith(color: context.secondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos commandes apparaîtront ici',
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
                  'Articles',
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
                  'Commande ${order.id}',
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
                DateFormat('dd/MM/yyyy', 'fr_FR').format(order.orderDate),
                style: context.caption,
              ),
              Text(
                DateFormat('HH:mm', 'fr_FR').format(order.orderDate),
                style: context.caption.copyWith(color: context.secondaryTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, CustomerOrderItem item) {
    final numberFormat = NumberFormat('#,###', 'fr_FR');

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
                  item.productName,
                  style: context.body2.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qté: ${item.quantity}',
                  style: context.caption,
                ),
              ],
            ),
          ),

          // Prix
          Text(
            '${numberFormat.format(item.totalPrice)} FCFA',
            style: context.body2.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(BuildContext context, CustomerOrder order) {
    final numberFormat = NumberFormat('#,###', 'fr_FR');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Adresse de livraison
          _buildDetailRow(
            context,
            icon: Icons.location_on,
            label: 'Adresse de livraison',
            value: order.deliveryAddress,
          ),

          if (order.trackingNumber != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              icon: Icons.local_shipping,
              label: 'Numéro de suivi',
              value: order.trackingNumber!,
            ),
          ],

          if (order.deliveryPersonName != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              icon: Icons.person,
              label: 'Livreur',
              value: order.deliveryPersonName!,
            ),
          ],

          if (order.deliveryDate != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              icon: Icons.event_available,
              label: 'Date de livraison',
              value: DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(order.deliveryDate!),
            ),
          ],

          const SizedBox(height: 16),

          // Totaux
          _buildPriceRow(context, 'Sous-total', numberFormat.format(order.subtotal)),
          const SizedBox(height: 8),
          _buildPriceRow(context, 'Frais de livraison', numberFormat.format(order.deliveryFee)),
          const SizedBox(height: 8),
          Divider(color: context.borderColor),
          const SizedBox(height: 8),
          _buildPriceRow(
            context,
            'Total',
            numberFormat.format(order.total),
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

  Widget _buildPriceRow(BuildContext context, String label, String value, {bool isTotal = false}) {
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
          '$value FCFA',
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
                label: const Text('Annuler'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
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
                  label: const Text('Suivre'),
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
                  label: const Text('Suivre la livraison'),
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
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                foregroundColor: Colors.green,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],

          // Bouton Confirmer la livraison (débloque l'argent)
          if (order.status == CustomerOrderStatus.delivered)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => controller.confirmDelivery(order.id),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Confirmer la réception'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
        return Colors.orange;
      case CustomerOrderStatus.confirmed:
        return Colors.blue;
      case CustomerOrderStatus.preparing:
        return Colors.purple;
      case CustomerOrderStatus.shipped:
        return Colors.indigo;
      case CustomerOrderStatus.delivered:
        return Colors.green;
      case CustomerOrderStatus.cancelled:
        return Colors.red;
    }
  }
}
