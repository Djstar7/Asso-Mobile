import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/deposit_widgets.dart';
import '../controllers/my_order_controller.dart';
import '../models/customer_order_models.dart';

/// Commande avec acompte côté acheteur : suivi jusqu'à la remise, montants et
/// paiement du solde une fois la vérification ASSO validée.
class CustomerOrderDepositSection extends StatelessWidget {
  final CustomerOrder order;

  const CustomerOrderDepositSection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final info = order.deposit;
    if (info == null) return const SizedBox.shrink();
    final controller = Get.find<MyOrderController>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'core.deposit.order_title'.tr,
            style: context.body2.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DepositOrderTimeline(info: info),
          Obx(
            () => DepositBalanceCard(
              info: info,
              total: order.total,
              formatPrice: controller.formatPrice,
              isPaying: controller.payingBalanceOrderId.value == order.id,
              onPayBalance: () => controller.payBalance(order),
            ),
          ),
        ],
      ),
    );
  }
}
