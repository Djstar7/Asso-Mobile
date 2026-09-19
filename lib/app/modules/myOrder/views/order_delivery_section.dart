import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/delivery_details_widgets.dart';
import '../controllers/my_order_controller.dart';
import '../models/customer_order_models.dart';

/// Livraison d'une commande côté acheteur : transporteur + n° de suivi,
/// chronologie datée, détail du prix et confirmation de réception.
class CustomerOrderDeliverySection extends StatelessWidget {
  final CustomerOrder order;

  const CustomerOrderDeliverySection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final delivery = order.delivery;
    if (delivery == null) return const SizedBox.shrink();
    final controller = Get.find<MyOrderController>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: delivery.isCarrier,
              leading: Icon(
                Icons.local_shipping_outlined,
                color: AppThemeSystem.primaryColor,
              ),
              title: Text(
                'Livraison et suivi',
                style: context.body2.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: delivery.trackingStatusLabel != null
                  ? Text(delivery.trackingStatusLabel!, style: context.caption)
                  : null,
              children: [
                OrderDeliveryDetails(
                  delivery: delivery,
                  deliveryFee: order.deliveryFee,
                  formatPrice: (v) => controller.formatPrice(v),
                ),
              ],
            ),
          ),
          if (delivery.canConfirmReception)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => controller.confirmReception(order),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('J’ai reçu mon colis'),
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
}
