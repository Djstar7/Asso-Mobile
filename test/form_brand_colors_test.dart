import 'package:asso/app/data/providers/diaspo_service.dart';
import 'package:asso/app/modules/diaspoBooking/widgets/parcel_insurance_form.dart';
import 'package:asso/app/modules/maritime/views/maritime_insurance_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/themed_app.dart';

void main() {
  tearDown(Get.reset);

  testWidgets(
    'le champ de valeur du colis utilise l’orange de marque au focus',
    (tester) async {
      Get.put(DiaspoService());
      final form = ParcelInsuranceForm(currency: () => 'XAF');
      addTearDown(form.dispose);
      await tester.pumpWidget(
        themedApp(
          Scaffold(
            body: SingleChildScrollView(
              child: MaritimeInsuranceSection(
                form: form,
                optIn: false.obs,
                formatAmount: (value) => '$value FCFA',
                decoration: const BoxDecoration(color: Colors.white),
                mutedColor: Colors.grey,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.cursorColor, const Color(0xFFFC9141));
      expect(
        field.decoration!.floatingLabelStyle!.color,
        const Color(0xFFFC9141),
      );
      expect(
        field.decoration!.focusedBorder!.borderSide.color,
        const Color(0xFFFC9141),
      );
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}
