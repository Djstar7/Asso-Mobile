import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
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
    if (booking.status != 'shipped') return const SizedBox.shrink();
    return Obx(() {
      final loading = controller.contactingBookingIds.contains(booking.id);
      final error = controller.contactErrors[booking.id];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Contacter la plateforme',
            button: true,
            enabled: !loading,
            child: IconButton(
              tooltip: 'Contacter la plateforme',
              onPressed: loading
                  ? null
                  : () => controller.contactPlatform(booking),
              icon: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_bubble_outline),
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
