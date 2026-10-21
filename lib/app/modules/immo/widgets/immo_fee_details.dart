import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'immo_widgets.dart';
import 'immo_summary_row.dart';

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
          ImmoSummaryRow(
            label: 'immo.quote.platform_share'.tr,
            value: immoPrice(platformAmount!),
            secondary: true,
            help: (platformAmount ?? 0) > 0
                ? 'immo.quote.commission_help'.tr
                : null,
          ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) =>
      ImmoSummaryRow(label: label, value: value, secondary: true);
}
