import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/vendor_web_login_controller.dart';

/// Page de connexion de l'espace vendeur web.
class VendorWebLoginView extends GetView<VendorWebLoginController> {
  const VendorWebLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesign.space4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDesign.space5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 56,
                      height: 56,
                    ),
                    const SizedBox(height: AppDesign.space3),
                    Text(
                      'vendor_web.login.title'.tr,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppDesign.space4),
                    Obx(() => _buildStep(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (controller.step.value) {
      case VendorWebLoginStep.loading:
        return const SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        );
      case VendorWebLoginStep.showQr:
        return Column(
          children: [
            // Fond blanc en mode sombre aussi : un QR inversé ne se lit pas.
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppDesign.space2),
              child: QrImageView(data: controller.qr.value, size: 240),
            ),
            const SizedBox(height: AppDesign.space4),
            Text('vendor_web.login.steps'.tr, textAlign: TextAlign.start),
          ],
        );
      case VendorWebLoginStep.scanned:
        return _message(
          Icons.phone_iphone_rounded,
          'vendor_web.login.scanned'.tr,
        );
      case VendorWebLoginStep.expired:
        return _message(
          Icons.timer_off_outlined,
          'vendor_web.login.expired'.tr,
          retry: true,
        );
      case VendorWebLoginStep.rejected:
        return _message(
          Icons.block_rounded,
          'vendor_web.login.rejected'.tr,
          retry: true,
        );
      case VendorWebLoginStep.failed:
        return _message(
          Icons.cloud_off_rounded,
          'vendor_web.login.failed'.tr,
          retry: true,
        );
    }
  }

  Widget _message(IconData icon, String text, {bool retry = false}) {
    return Column(
      children: [
        Icon(icon, size: 56, color: AppDesign.accent),
        const SizedBox(height: AppDesign.space3),
        Text(text, textAlign: TextAlign.center),
        if (retry) ...[
          const SizedBox(height: AppDesign.space4),
          FilledButton(
            onPressed: controller.start,
            child: Text('vendor_web.login.new_qr'.tr),
          ),
        ],
      ],
    );
  }
}
