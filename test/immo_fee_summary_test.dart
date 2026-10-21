import 'dart:io';

import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/modules/immo/widgets/immo_fee_details.dart';
import 'package:asso/app/modules/immo/widgets/immo_summary_row.dart';
import 'package:asso/app/modules/immo/widgets/immo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  late Directory storageDirectory;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp(
      'asso-immo-summary-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storageDirectory.path,
        );
    await GetStorage.init();
  });
  tearDownAll(() => storageDirectory.delete(recursive: true));
  tearDown(Get.reset);

  for (final width in [320.0, 520.0]) {
    testWidgets('All amounts align with a long cabinet name at width $width', (
      tester,
    ) async {
      Get.put(CurrencyService());
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ImmoSummaryRow(
                          label: 'Avance (3 mois)',
                          value: immoPrice(148500),
                        ),
                        const ImmoFeeDetails(
                          netAmount: 148500,
                          platformAmount: 13500,
                          netPayeeKind: 'landlord',
                          cabinetName:
                              'Cabinet partenaire Gollew et ses associés',
                        ),
                        ImmoSummaryRow(
                          label: 'Commission du cabinet',
                          value: immoPrice(6750),
                          help: 'Non remboursable',
                        ),
                        ImmoSummaryRow(
                          label: 'Total à payer',
                          value: immoPrice(168750),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final right = tester.getTopRight(find.text(immoPrice(168750))).dx;
      for (final amount in [148500, 13500, 6750]) {
        final amounts = find.text(immoPrice(amount));
        expect(amounts, findsWidgets);
        for (final element in amounts.evaluate()) {
          expect(
            tester.getTopRight(find.byWidget(element.widget)).dx,
            closeTo(right, 0.1),
          );
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
