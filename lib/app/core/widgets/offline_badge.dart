import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/connectivity_service.dart';
import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';

/// Petit badge « Hors ligne », affiché tant que le serveur est injoignable.
///
/// Ne prend aucune place en ligne : il se pose dans une barre d'en-tête sans
/// décaler le reste.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ConnectivityService>()) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      if (ConnectivityService.to.isOnline.value) {
        return const SizedBox.shrink();
      }
      return Semantics(
        label: 'Hors ligne',
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppDesign.space1),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesign.space2,
            vertical: AppDesign.space1,
          ),
          decoration: BoxDecoration(
            color: AppDesign.warningSubtle,
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 14,
                color: AppDesign.warningText,
              ),
              const SizedBox(width: AppDesign.space1),
              Text(
                'Hors ligne',
                style: context.caption.copyWith(
                  color: AppDesign.warningText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
