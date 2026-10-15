import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/sales_program.dart';

/// Code commercial de l'utilisateur, à copier ou partager, avec ce qu'il
/// rapporte. Commun aux félicitations et au retour d'un commercial inscrit.
class SalesAgentCodePanel extends StatelessWidget {
  const SalesAgentCodePanel({
    super.key,
    required this.code,
    required this.commissionRate,
  });

  final String code;
  final double commissionRate;

  void _copy() {
    Clipboard.setData(ClipboardData(text: code));
    Get.snackbar(
      'sales_program.code.copied_title'.tr,
      'sales_program.code.copied_message'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _share() {
    Share.share('sales_program.code.share_text'.trParams({'code': code}));
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.all(AppDesign.space5),
          child: Column(
            children: [
              Text(
                'sales_program.code.label'.tr,
                textAlign: TextAlign.center,
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: FontWeight.w600,
                  color: ds.textSecondary,
                ),
              ),
              SizedBox(height: AppDesign.space2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: SelectableText(
                  code,
                  key: const ValueKey('sales-agent-code'),
                  style: context
                      .textStyle(
                        FontSizeType.h3,
                        fontWeight: FontWeight.w800,
                        color: ds.textPrimary,
                      )
                      .copyWith(letterSpacing: 1.5),
                ),
              ),
              SizedBox(height: AppDesign.space4),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'sales_program.code.copy'.tr,
                      icon: Icons.copy_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _copy,
                    ),
                  ),
                  SizedBox(width: AppDesign.space3),
                  Expanded(
                    child: AppButton(
                      label: 'sales_program.code.share'.tr,
                      icon: Icons.ios_share_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _share,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: AppDesign.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: ds.icon),
            SizedBox(width: AppDesign.space2),
            Expanded(
              child: Text(
                'sales_program.code.explanation'.trParams({
                  'rate': SalesProgram.formatRate(commissionRate),
                }),
                style: context.textStyle(
                  FontSizeType.body2,
                  color: ds.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
