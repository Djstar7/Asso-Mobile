import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/delivery_dashboard_controller.dart';

/// Courses de litige du livreur : produit de remplacement (boutique → client)
/// ou retour (client → boutique). Même déroulé qu'une commande : accepter,
/// récupérer le colis, puis remettre contre le code à 6 chiffres du
/// destinataire. Les deux points sont joignables d'un geste.
class DisputeCoursesSection extends GetView<DeliveryDashboardController> {
  const DisputeCoursesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final courses = controller.disputeCourses;
      if (courses.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'delivery_dashboard.dispute.section'.tr,
              style: context.subtitle1.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...courses.map((course) => _CourseCard(course: course)),
          ],
        ),
      );
    });
  }
}

class _CourseCard extends GetView<DeliveryDashboardController> {
  const _CourseCard({required this.course});

  final Map<String, dynamic> course;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse('${course['id']}') ?? 0;
    final isReturn = course['type'] != 'replacement';
    final isMine = course['is_mine'] == true;
    final pickedUp = course['picked_up'] == true;
    final isAgency = course['completion_kind'] == 'agency';
    final pickup = Map<String, dynamic>.from(
      course['pickup'] as Map? ?? const {},
    );
    final dropoff = Map<String, dynamic>.from(
      course['dropoff'] as Map? ?? const {},
    );
    final commission = double.tryParse('${course['commission'] ?? 0}') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: AppDesign.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReturn
                    ? Icons.assignment_return_outlined
                    : Icons.swap_horiz_rounded,
                size: 20,
                color: AppDesign.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReturn
                          ? 'delivery_dashboard.dispute.return_title'.tr
                          : 'delivery_dashboard.dispute.replacement_title'.tr,
                      style: context.body2.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${course['product_name'] ?? ''} · ${course['dispute_number'] ?? ''}',
                      style: context.caption.copyWith(
                        color: context.secondaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (commission > 0)
                Text(
                  controller.formatPrice(commission),
                  style: TextStyle(
                    color: AppThemeSystem.successColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _stop(
            context,
            '1. ${'delivery_dashboard.dispute.pickup'.tr}',
            pickup,
            AppDesign.accent,
          ),
          const SizedBox(height: 6),
          _stop(
            context,
            '2. ${'delivery_dashboard.dispute.dropoff'.tr}',
            dropoff,
            AppDesign.success,
          ),
          const SizedBox(height: 6),
          Text(
            isAgency ? 'delivery_dashboard.dispute.code_hint_agency'.tr : isReturn
                ? 'delivery_dashboard.dispute.code_hint_vendor'.tr
                : 'delivery_dashboard.dispute.code_hint_client'.tr,
            style: context.caption.copyWith(color: context.secondaryTextColor),
          ),
          const SizedBox(height: 10),
          Obx(() {
            final busy = controller.disputeCourseBusyId.value == id;
            final (label, icon, onPressed) = !isMine
                ? (
                    'delivery_dashboard.actions.accept'.tr,
                    Icons.check_rounded,
                    () => controller.acceptDisputeCourse(id),
                  )
                : !pickedUp
                ? (
                    'delivery_dashboard.dispute.picked_up'.tr,
                    Icons.inventory_2_outlined,
                    () => controller.pickUpDisputeCourse(id),
                  )
                : (
                    'delivery_dashboard.dispute.hand_over'.tr,
                    Icons.pin_outlined,
                    () => controller.completeDisputeCourse(
                      id,
                      isReturn: isReturn,
                      isAgency: isAgency,
                    ),
                  );

            return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onPressed,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, size: 18),
                label: Text(label),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Point de retrait ou de remise, avec le bouton d'appel.
  Widget _stop(
    BuildContext context,
    String step,
    Map<String, dynamic> stop,
    Color color,
  ) {
    final phone = stop['phone']?.toString() ?? '';
    final address = stop['address']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: context.borderRadius(BorderRadiusType.small),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step,
                  style: context.caption.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${stop['name'] ?? ''}',
                  style: context.body2.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address.isNotEmpty)
                  Text(
                    address,
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (phone.trim().isNotEmpty)
            IconButton(
              onPressed: () => controller.callCustomer(phone),
              icon: Icon(Icons.phone, size: 18, color: color),
              tooltip: 'delivery_dashboard.actions.call'.tr,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
