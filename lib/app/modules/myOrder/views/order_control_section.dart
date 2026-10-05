import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/my_order_controller.dart';
import '../models/customer_order_models.dart';

/// Après la livraison : 48 h pour vérifier les produits. « Tout est conforme »
/// valide la commande ; « Faire une réclamation » se fait article par article.
/// Les réclamations ouvertes restent accessibles ensuite.
class CustomerOrderControlSection extends StatelessWidget {
  final CustomerOrder order;

  const CustomerOrderControlSection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final control = order.control;
    final windowOpen = control?.windowOpen == true;
    final disputed = order.items.where((i) => i.dispute != null).toList();
    if (!windowOpen && disputed.isEmpty) return const SizedBox.shrink();

    final controller = Get.find<MyOrderController>();
    final ds = context.ds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.borderColor))),
      child: Obx(() {
        final busy = controller.controlBusyOrderId.value == order.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (windowOpen) ...[
              Text('disputes.control.title'.tr, style: context.body2.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppDesign.space2),
              Text(
                'disputes.control.message'.trParams({
                  'date': control?.until != null ? DateFormat('dd/MM/yyyy HH:mm').format(control!.until!) : '',
                }),
                style: context.caption.copyWith(color: ds.textSecondary),
              ),
              const SizedBox(height: AppDesign.space3),
              AppButton(
                label: 'disputes.control.conform'.tr,
                icon: Icons.verified_outlined,
                isLoading: busy,
                onPressed: () => controller.confirmConformity(order),
              ),
              const SizedBox(height: AppDesign.space3),
              ...order.items.where((i) => i.canReport).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppDesign.space2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(item.displayName, style: context.body2, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        TextButton.icon(
                          onPressed: busy ? null : () => controller.reportProblem(order, item),
                          icon: const Icon(Icons.report_problem_outlined, size: 18, color: AppDesign.danger),
                          label: Text(
                            'disputes.control.report'.tr,
                            style: context.caption.copyWith(color: AppDesign.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            ...disputed.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDesign.space2),
                  child: InkWell(
                    onTap: () => controller.openDispute(item.dispute!.id),
                    borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.all(AppDesign.space3),
                      decoration: BoxDecoration(
                        color: AppDesign.warningSubtle,
                        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gavel_rounded, size: 18, color: AppDesign.warning),
                          const SizedBox(width: AppDesign.space2),
                          Expanded(
                            child: Text(
                              '${item.displayName} · ${item.dispute!.number}',
                              style: context.body2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppBadge(label: item.dispute!.statusLabel, tone: AppBadgeTone.warning),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        );
      }),
    );
  }
}
