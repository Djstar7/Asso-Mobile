import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/web_login_controller.dart';
import 'qr_scanner_view.dart';

/// Connexion à l'espace vendeur depuis un ordinateur, et sessions déjà ouvertes.
class WebLoginView extends GetView<WebLoginController> {
  const WebLoginView({super.key});

  Future<void> _scan(BuildContext context) async {
    final raw = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerView()));
    if (raw == null) return;

    final request = await controller.scan(raw);
    if (request == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('web_login.confirm.title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'web_login.confirm.device'.trParams({
                'browser': request.browser,
                'platform': request.platform,
              }),
            ),
            const SizedBox(height: AppDesign.space1),
            Text('web_login.confirm.ip'.trParams({'ip': request.ip})),
            const SizedBox(height: AppDesign.space3),
            Text(
              'web_login.confirm.warning'.tr,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('web_login.confirm.reject'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('web_login.confirm.approve'.tr),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.approve(request);
    } else {
      await controller.reject(request);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('web_login.title'.tr),
      ),
      body: RefreshIndicator(
        onRefresh: controller.loadDevices,
        child: ListView(
          padding: const EdgeInsets.all(AppDesign.space4),
          children: [
            Text('web_login.intro'.tr),
            const SizedBox(height: AppDesign.space3),
            SizedBox(
              width: double.infinity,
              child: Obx(
                () => FilledButton.icon(
                  onPressed: controller.isBusy.value
                      ? null
                      : () => _scan(context),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text('web_login.scan_action'.tr),
                ),
              ),
            ),
            const SizedBox(height: AppDesign.space5),
            Text(
              'web_login.devices_title'.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDesign.space2),
            Obx(() {
              if (controller.isLoading.value && controller.devices.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.devices.isEmpty) {
                return Text('web_login.no_devices'.tr);
              }
              return Column(
                children: controller.devices
                    .map((device) => _buildDevice(context, device))
                    .toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDevice(BuildContext context, WebDevice device) {
    final expiresAt = device.expiresAt;
    final expires = expiresAt == null
        ? ''
        : DateFormat.yMd(
            Get.locale?.languageCode ?? 'fr',
          ).add_Hm().format(expiresAt);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.computer_rounded),
        title: Text('${device.browser} · ${device.platform}'),
        subtitle: Text(
          'web_login.device_details'.trParams({
            'ip': device.ip,
            'date': expires,
          }),
        ),
        trailing: TextButton(
          onPressed: () => controller.revoke(device),
          child: Text('web_login.revoke'.tr),
        ),
      ),
    );
  }
}
