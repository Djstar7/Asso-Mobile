import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/maritime.dart';
import '../controllers/maritime_controller.dart';

class MaritimeContactButton extends StatelessWidget {
  const MaritimeContactButton({
    super.key,
    required this.booking,
    required this.controller,
  });

  final MaritimeBooking booking;
  final MaritimeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.contactingBookingIds.contains(booking.id);
      final error = controller.contactErrors[booking.id];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'maritime.contact_support'.tr,
            button: true,
            enabled: !loading,
            onTap: loading ? null : () => controller.contactPlatform(booking),
            child: ExcludeSemantics(
              child: Tooltip(
                message: 'maritime.contact_support'.tr,
                child: AppButton(
                  label: loading
                      ? 'maritime.contact_support_opening'.tr
                      : 'maritime.contact_support'.tr,
                  icon: Icons.chat_bubble_outline_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  isLoading: loading,
                  onPressed: () => controller.contactPlatform(booking),
                ),
              ),
            ),
          ),
          if (error != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppDesign.danger, fontSize: 11),
              ),
            ),
        ],
      );
    });
  }
}
