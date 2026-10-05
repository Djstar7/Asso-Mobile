import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/vendor_disputes_controller.dart';
import '../models/dispute_models.dart';

/// Espace vendeur « Réclamations » : dossiers ouverts par les clients, avec
/// l'action attendue (répondre, remplacer, organiser et payer le retour).
class VendorDisputesView extends GetView<VendorDisputesController> {
  const VendorDisputesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text('disputes.vendor.list_title'.tr, style: context.h5.copyWith(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
            child: Obx(() => Row(
                  children: ['open', 'closed']
                      .map((value) => Padding(
                            padding: const EdgeInsets.only(right: AppDesign.space2),
                            child: ChoiceChip(
                              label: Text('disputes.vendor.filter_$value'.tr),
                              selected: controller.filter.value == value,
                              selectedColor: AppDesign.accentSubtle,
                              onSelected: (_) => controller.setFilter(value),
                            ),
                          ))
                      .toList(),
                )),
          ),
          const SizedBox(height: AppDesign.space3),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.disputes.isEmpty) {
                return AppEmptyState(
                  icon: Icons.verified_outlined,
                  title: 'disputes.vendor.empty'.tr,
                  message: 'disputes.vendor.empty_message'.tr,
                );
              }
              return RefreshIndicator(
                onRefresh: controller.load,
                child: ListView.separated(
                  padding: EdgeInsets.all(context.ds.gutter),
                  itemCount: controller.disputes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppDesign.space3),
                  itemBuilder: (context, index) => _card(context, controller.disputes[index]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Dispute dispute) {
    final ds = context.ds;
    final todo = dispute.action('pay_shipment')
        ? 'disputes.vendor.todo_pay'.tr
        : dispute.action('replace') || dispute.action('organize_return')
            ? 'disputes.vendor.todo_choose'.tr
            : dispute.action('mark_shipped')
                ? 'disputes.vendor.todo_ship'.tr
                : null;

    return AppCard(
      onTap: () => controller.open(dispute),
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(dispute.productName, style: context.body1.copyWith(fontWeight: FontWeight.w600)),
              ),
              AppBadge(label: dispute.statusLabel, tone: todo != null ? AppBadgeTone.warning : AppBadgeTone.neutral),
            ],
          ),
          const SizedBox(height: AppDesign.space1),
          Text(
            '${dispute.number} · ${dispute.reasonLabel}'
            '${dispute.createdAt != null ? ' · ${DateFormat('dd/MM/yyyy').format(dispute.createdAt!)}' : ''}',
            style: context.caption.copyWith(color: ds.textSecondary),
          ),
          if (dispute.heldAmount != null && dispute.heldAmount! > 0)
            Text(
              'disputes.vendor.held_short'.trParams({'amount': controller.formatPrice(dispute.heldAmount!)}),
              style: context.caption.copyWith(color: AppDesign.warning),
            ),
          if (todo != null) ...[
            const SizedBox(height: AppDesign.space2),
            Text(todo, style: context.body2.copyWith(color: AppDesign.accent, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
