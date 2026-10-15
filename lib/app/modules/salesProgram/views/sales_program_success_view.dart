import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/sales_program.dart';
import '../widgets/sales_agent_code_panel.dart';

/// Félicitations après l'inscription : le code reçu, prêt à être transmis.
/// Arguments : { code, commission_rate }.
class SalesProgramSuccessView extends StatelessWidget {
  const SalesProgramSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final args = Get.arguments is Map ? Get.arguments as Map : const {};
    final code = '${args['code'] ?? ''}';
    final rate = SalesProgram.parseRate(args['commission_rate']);

    return Scaffold(
      backgroundColor: ds.canvas,
      appBar: AppBar(
        backgroundColor: ds.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(close: true),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: AppContentWidth(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ds.gutter,
                0,
                ds.gutter,
                AppDesign.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 180,
                    child: Lottie.asset(
                      'assets/lotties/Sales and Consulting.json',
                      fit: BoxFit.contain,
                      repeat: false,
                      errorBuilder: (context, error, stack) => Center(
                        child: Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: AppDesign.success,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppDesign.space4),
                  Text(
                    'sales_program.success.title'.tr,
                    textAlign: TextAlign.center,
                    style: context.textStyle(
                      FontSizeType.h3,
                      fontWeight: FontWeight.w700,
                      color: ds.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppDesign.space2),
                  Text(
                    'sales_program.success.message'.tr,
                    textAlign: TextAlign.center,
                    style: context.textStyle(
                      FontSizeType.body1,
                      color: ds.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: AppDesign.space6),
                  if (code.isNotEmpty)
                    SalesAgentCodePanel(code: code, commissionRate: rate),
                  SizedBox(height: AppDesign.space8),
                  AppButton(
                    label: 'sales_program.success.done'.tr,
                    onPressed: () => AppNavigation.back(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
