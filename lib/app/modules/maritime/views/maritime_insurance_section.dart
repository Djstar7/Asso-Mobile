import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../diaspoBooking/widgets/parcel_insurance_form.dart';

/// Keeps parcel declaration fields visible independently of insurance consent.
class MaritimeInsuranceSection extends StatelessWidget {
  const MaritimeInsuranceSection({
    super.key,
    required this.form,
    required this.optIn,
    required this.formatAmount,
    required this.decoration,
    required this.mutedColor,
    this.natureError,
    this.valueError,
    this.natureKey,
    this.valueKey,
  });

  final ParcelInsuranceForm form;
  final RxBool optIn;
  final String Function(double) formatAmount;
  final BoxDecoration decoration;
  final Color mutedColor;
  final String? natureError;
  final String? valueError;
  final Key? natureKey;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ParcelInsuranceCard(
        form: form,
        formatAmount: formatAmount,
        decoration: decoration,
        introKey: 'maritime.form.insurance_fields_intro',
        showQuote: false,
        natureError: natureError,
        valueError: valueError,
        natureKey: natureKey,
        valueKey: valueKey,
      ),
      const SizedBox(height: 10),
      Obx(
        () => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: decoration,
          child: Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: form.isComplete && optIn.value,
              onChanged: form.isComplete
                  ? (value) => optIn.value = value ?? false
                  : null,
              title: Text(
                'maritime.form.insurance_opt_in'.tr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!form.isComplete)
                    Text(
                      'parcel_insurance.required'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  Text(
                    'maritime.form.insurance_legal_disclosure'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
