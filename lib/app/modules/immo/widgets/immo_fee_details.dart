import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import 'immo_widgets.dart';

/// Ventilation fournie par l'API ; aucun calcul financier côté mobile.
class ImmoFeeDetails extends StatelessWidget {
  const ImmoFeeDetails({
    super.key,
    this.netAmount,
    this.platformAmount,
    this.cabinetName,
    this.netPayeeKind,
  });

  final int? netAmount;
  final int? platformAmount;
  final String? cabinetName;
  final String? netPayeeKind;

  @override
  Widget build(BuildContext context) {
    final beneficiary = netPayeeKind == 'cabinet'
        ? cabinetName ?? 'immo.quote.cabinet'.tr
        : netPayeeKind == 'landlord'
        ? 'immo.quote.landlord'.tr
        : null;
    return Column(
      children: [
        if (cabinetName != null)
          _row(context, 'immo.quote.cabinet'.tr, cabinetName!),
        if (netAmount != null)
          _row(context, 'immo.quote.net_amount'.tr, immoPrice(netAmount!)),
        if (beneficiary != null)
          _row(context, 'immo.quote.net_beneficiary'.tr, beneficiary),
        if (platformAmount != null)
          _row(context, 'immo.quote.platform_share'.tr, immoPrice(platformAmount!)),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppDesign.space2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary))),
        const SizedBox(width: AppDesign.space3),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: context.textStyle(FontSizeType.body2, color: context.ds.textPrimary))),
      ],
    ),
  );
}
