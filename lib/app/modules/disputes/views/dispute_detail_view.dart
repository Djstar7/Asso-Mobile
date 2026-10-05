import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/dispute_detail_controller.dart';
import '../models/dispute_models.dart';

/// Suivi d'une réclamation : décision ASSO, remplacement ou retour, puis
/// remboursement. Le vendeur y répond et paie les courses ; seul ASSO clôture.
class DisputeDetailView extends GetView<DisputeDetailController> {
  const DisputeDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Obx(() => Text(
              controller.dispute.value?.number ?? 'disputes.title'.tr,
              style: context.h5.copyWith(fontWeight: FontWeight.w600),
            )),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final dispute = controller.dispute.value;
        if (dispute == null) {
          return AppEmptyState(
            icon: Icons.error_outline,
            title: controller.error.value ?? 'disputes.not_found'.tr,
            actionLabel: 'common.retry'.tr,
            onAction: controller.load,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: EdgeInsets.all(context.ds.gutter),
            children: [
              _header(context, dispute),
              const SizedBox(height: AppDesign.space4),
              ..._actions(context, dispute),
              if (dispute.decision != null) ...[
                _decision(context, dispute),
                const SizedBox(height: AppDesign.space4),
              ],
              if (dispute.replacement != null) ...[
                _shipment(context, dispute.replacement!),
                const SizedBox(height: AppDesign.space4),
              ],
              if (dispute.returnShipment != null) ...[
                _shipment(context, dispute.returnShipment!),
                const SizedBox(height: AppDesign.space4),
              ],
              _claim(context, dispute),
              const SizedBox(height: AppDesign.space4),
              _history(context, dispute),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(BuildContext context, Dispute dispute) {
    final ds = context.ds;
    return AppCard(
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            child: SizedBox(
              width: 56,
              height: 56,
              child: dispute.productImage != null
                  ? AppNetworkImage(url: dispute.productImage!, decodeSize: const Size(56, 56), errorBuilder: (_) => const SizedBox.shrink())
                  : Container(color: ds.surfaceMuted, child: Icon(Icons.shopping_bag, color: ds.textTertiary)),
            ),
          ),
          const SizedBox(width: AppDesign.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dispute.productName, style: context.body1.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'disputes.order_ref'.trParams({'order': dispute.orderNumber ?? '${dispute.orderId}'}),
                  style: context.caption.copyWith(color: ds.textSecondary),
                ),
                const SizedBox(height: AppDesign.space2),
                AppBadge(label: dispute.statusLabel, tone: _tone(dispute.status)),
              ],
            ),
          ),
          Text(controller.formatPrice(dispute.totalPrice), style: context.body2.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// Boutons selon l'étape du dossier et la personne qui consulte.
  List<Widget> _actions(BuildContext context, Dispute dispute) {
    final buttons = <Widget>[];
    final busy = controller.isBusy.value;
    final df = DateFormat('dd/MM/yyyy HH:mm');

    if (!controller.isVendor) {
      if (dispute.action('confirm_replacement')) {
        buttons.add(_notice(
          context,
          'disputes.client.replacement_check'.trParams({
            'date': dispute.replacementControlUntil != null ? df.format(dispute.replacementControlUntil!) : '',
          }),
          AppDesign.infoSubtle,
        ));
        buttons.add(AppButton(
          label: 'disputes.client.replacement_ok'.tr,
          icon: Icons.check_circle_outline,
          isLoading: busy,
          onPressed: controller.confirmReplacement,
        ));
        buttons.add(const SizedBox(height: AppDesign.space2));
        buttons.add(AppButton(
          label: 'disputes.client.replacement_ko'.tr,
          icon: Icons.report_problem_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: busy ? null : controller.reportReplacement,
        ));
      }
      if (dispute.status == 'return') {
        buttons.add(_notice(context, 'disputes.client.return_notice'.tr, AppDesign.successSubtle));
      }
      if (dispute.action('similar_products')) {
        buttons.add(_notice(
          context,
          'disputes.client.refunded_notice'.trParams({'amount': controller.formatPrice(dispute.refundAmount ?? 0)}),
          AppDesign.successSubtle,
        ));
        buttons.add(AppButton(
          label: 'disputes.client.see_similar'.tr,
          icon: Icons.local_shipping_outlined,
          onPressed: controller.openSimilarProducts,
        ));
      }
    } else {
      if (dispute.heldAmount != null && dispute.heldAmount! > 0) {
        buttons.add(_notice(
          context,
          'disputes.vendor.held_notice'.trParams({'amount': controller.formatPrice(dispute.heldAmount!)}),
          AppDesign.warningSubtle,
        ));
      }
      if (dispute.action('pay_shipment')) {
        buttons.add(_notice(context, 'disputes.vendor.pay_notice'.tr, AppDesign.accentSubtle));
        buttons.add(AppButton(
          label: 'disputes.vendor.pay_shipment'.tr,
          icon: Icons.payments_outlined,
          isLoading: busy,
          onPressed: controller.payShipment,
        ));
        buttons.add(const SizedBox(height: AppDesign.space2));
      }
      if (dispute.action('replace')) {
        buttons.add(AppButton(
          label: 'disputes.vendor.replace'.tr,
          icon: Icons.swap_horiz_rounded,
          onPressed: busy ? null : controller.replace,
        ));
        buttons.add(const SizedBox(height: AppDesign.space2));
      }
      if (dispute.action('organize_return')) {
        buttons.add(AppButton(
          label: 'disputes.vendor.organize_return'.tr,
          icon: Icons.undo_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: busy ? null : controller.organizeReturn,
        ));
        buttons.add(const SizedBox(height: AppDesign.space2));
      }
      if (dispute.action('mark_shipped')) {
        buttons.add(AppButton(
          label: 'disputes.vendor.mark_shipped'.tr,
          icon: Icons.local_shipping_outlined,
          onPressed: busy ? null : controller.markShipped,
        ));
        buttons.add(const SizedBox(height: AppDesign.space2));
      }
      if (dispute.action('confirm_return_received')) {
        buttons.add(AppButton(
          label: 'disputes.vendor.return_received'.tr,
          icon: Icons.inventory_2_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: busy ? null : controller.confirmReturnReceived,
        ));
        buttons.add(const SizedBox(height: AppDesign.space2));
      }
      if (dispute.action('add_evidence')) {
        buttons.add(AppButton(
          label: 'disputes.vendor.send_evidence'.tr,
          icon: Icons.attach_file_rounded,
          variant: AppButtonVariant.ghost,
          onPressed: busy ? null : controller.sendEvidence,
        ));
      }
      if (dispute.isOpen) {
        buttons.add(Padding(
          padding: const EdgeInsets.only(top: AppDesign.space2),
          child: Text('disputes.vendor.asso_decides'.tr, style: context.caption.copyWith(color: context.ds.textSecondary)),
        ));
      }
    }

    if (buttons.isEmpty) return const [];
    return [...buttons, const SizedBox(height: AppDesign.space4)];
  }

  Widget _notice(BuildContext context, String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDesign.space3),
      padding: const EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppDesign.radiusSm)),
      child: Text(text, style: context.body2),
    );
  }

  Widget _decision(BuildContext context, Dispute dispute) {
    final founded = dispute.decision == 'founded';
    return _section(
      context,
      'disputes.decision.title'.tr,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(
            label: founded ? 'disputes.decision.founded'.tr : 'disputes.decision.unfounded'.tr,
            tone: founded ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
          if ((dispute.decisionNote ?? '').isNotEmpty) ...[
            const SizedBox(height: AppDesign.space2),
            Text(dispute.decisionNote!, style: context.body2),
          ],
        ],
      ),
    );
  }

  Widget _shipment(BuildContext context, DisputeShipmentInfo shipment) {
    final ds = context.ds;
    final current = shipment.currentIndex;
    return _section(
      context,
      shipment.isReturn ? 'disputes.shipment.return_title'.tr : 'disputes.shipment.replacement_title'.tr,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shipment.companyName != null)
            Text(
              '${shipment.companyName}'
              '${controller.isVendor && shipment.price > 0 ? ' · ${controller.formatPrice(shipment.price)}' : ''}',
              style: context.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          Text(
            controller.isVendor
                ? (shipment.payer == 'asso' ? 'disputes.shipment.paid_by_asso'.tr : 'disputes.shipment.paid_by_vendor'.tr)
                : 'disputes.shipment.free_for_you'.tr,
            style: context.caption.copyWith(color: ds.textSecondary),
          ),
          if (shipment.trackingNumber != null)
            Text('disputes.shipment.tracking'.trParams({'number': shipment.trackingNumber!}), style: context.caption),
          const SizedBox(height: AppDesign.space3),
          ...shipment.steps.asMap().entries.map((entry) {
            final done = entry.key <= current;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDesign.space2),
              child: Row(
                children: [
                  Icon(
                    done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 18,
                    color: done ? AppDesign.success : ds.textTertiary,
                  ),
                  const SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Text(
                      entry.value.value,
                      style: context.body2.copyWith(
                        color: done ? ds.textPrimary : ds.textTertiary,
                        fontWeight: entry.key == current ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _claim(BuildContext context, Dispute dispute) {
    return _section(
      context,
      'disputes.claim.title'.tr,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dispute.reasonLabel, style: context.body2.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDesign.space2),
          Text(dispute.description, style: context.body2),
          if (dispute.attachments.isNotEmpty) ...[
            const SizedBox(height: AppDesign.space3),
            Wrap(
              spacing: AppDesign.space2,
              runSpacing: AppDesign.space2,
              children: dispute.attachments
                  .map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: AppNetworkImage(url: url, decodeSize: const Size(72, 72), errorBuilder: (_) => const SizedBox.shrink()),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _history(BuildContext context, Dispute dispute) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final ds = context.ds;
    return _section(
      context,
      'disputes.history'.tr,
      Column(
        children: dispute.events
            .map((event) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDesign.space3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          event.occurredAt != null ? df.format(event.occurredAt!) : '',
                          style: context.caption.copyWith(color: ds.textTertiary),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.label, style: context.body2),
                            if ((event.note ?? '').isNotEmpty)
                              Text(event.note!, style: context.caption.copyWith(color: ds.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return AppCard(
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.body1.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDesign.space3),
          child,
        ],
      ),
    );
  }

  static AppBadgeTone _tone(String status) {
    switch (status) {
      case 'new':
      case 'in_review':
      case 'vendor_contacted':
        return AppBadgeTone.warning;
      case 'replacement':
      case 'return':
        return AppBadgeTone.info;
      case 'refunded':
      case 'resolved':
        return AppBadgeTone.success;
      default:
        return AppBadgeTone.neutral;
    }
  }
}
