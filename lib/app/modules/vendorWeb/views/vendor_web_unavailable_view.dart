import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_ui.dart';

/// Tout écran hors du périmètre web : wallet, paiements, forfaits, boosts.
class VendorWebUnavailableView extends StatelessWidget {
  const VendorWebUnavailableView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton()),
      body: AppEmptyState(
        icon: Icons.phone_iphone_rounded,
        title: 'vendor_web.unavailable.title'.tr,
        message: 'vendor_web.unavailable.message'.tr,
      ),
    );
  }
}
