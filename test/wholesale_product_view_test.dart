import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/data/models/wholesale_models.dart';
import 'package:asso/app/modules/import/views/wholesale_product_view.dart';

/// Produit en gros minimal : un palier de 50 unités à 1 000 FCFA, une
/// expédition forfaitaire à 20 000 FCFA, et aucune photo (le réseau est coupé
/// en test).
WholesaleProduct _product() => const WholesaleProduct(
  id: 7,
  name: 'Chaises pliantes',
  description: 'Chaise en acier, pliable.',
  currency: 'XAF',
  priceTiers: [
    PriceTier(
      id: 1,
      label: 'Carton de 50',
      unitPrice: 1000,
      unitPriceXaf: 1000,
      currency: 'XAF',
      minQuantity: 50,
      formattedPrice: '1 000 FCFA',
    ),
  ],
);

const _shipping = [
  ShippingOption(
    id: 3,
    mode: 'sea',
    modeLabel: 'Bateau',
    rateType: 'flat',
    rateAmount: 20000,
    rateAmountXaf: 20000,
    currency: 'XAF',
    destinations: [],
    formattedRate: '20 000 FCFA',
  ),
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    await GetStorage.init();
  });

  tearDown(Get.reset);

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: WholesaleProductView(
          product: _product(),
          shippingOptions: _shipping,
          countryFlag: '🇨🇳',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder quantityField() => find.byWidgetPredicate(
    (w) => w is TextField && w.keyboardType == TextInputType.number,
  );

  testWidgets('part du minimum du palier', (tester) async {
    await openPage(tester);

    expect(find.text('Chaises pliantes'), findsOneWidget);
    expect(tester.widget<TextField>(quantityField()).controller!.text, '50');
    // 50 × 1 000 + 20 000 d'expédition.
    expect(find.textContaining('70'), findsWidgets);
  });

  testWidgets('accepte une quantité saisie au clavier', (tester) async {
    await openPage(tester);

    await tester.enterText(quantityField(), '500');
    await tester.pump();

    // 500 × 1 000 + 20 000 : le total suit la saisie.
    expect(find.textContaining('520'), findsWidgets);
    expect(find.textContaining('Minimum 50 pour'), findsNothing);
  });

  testWidgets('signale une quantité sous le minimum', (tester) async {
    await openPage(tester);

    await tester.enterText(quantityField(), '12');
    await tester.pump();

    expect(find.textContaining('Minimum 50 pour'), findsOneWidget);
  });

  testWidgets('les boutons ajustent la quantité sans passer sous le minimum', (
    tester,
  ) async {
    await openPage(tester);

    await tester.tap(find.byTooltip('Augmenter'));
    await tester.pump();
    expect(tester.widget<TextField>(quantityField()).controller!.text, '51');

    await tester.tap(find.byTooltip('Diminuer'));
    await tester.pump();
    await tester.tap(find.byTooltip('Diminuer'));
    await tester.pump();
    expect(tester.widget<TextField>(quantityField()).controller!.text, '50');
  });

  testWidgets('garde le total et « Commander » au-dessus du clavier', (
    tester,
  ) async {
    await openPage(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    final keyboardTop = 2340 / 3 - 900 / 3;
    expect(
      tester.getRect(find.text('Commander')).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('porte un bouton retour', (tester) async {
    await openPage(tester);
    expect(find.byTooltip('Retour'), findsOneWidget);
  });
}
