import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/core/widgets/product_variant_selector.dart';
import 'package:asso/app/core/widgets/quantity_stepper.dart';
import 'package:asso/app/core/widgets/variant_quantity_list.dart';
import 'package:asso/app/data/models/wholesale_models.dart';
import 'package:asso/app/modules/import/views/wholesale_product_view.dart';
import 'package:asso/app/modules/product/controllers/product_controller.dart';

/// T-shirt en tailles L et XL (la taille XL coûte 500 de plus) et une taille
/// S épuisée.
Map<String, dynamic> _tshirt() => {
  'id': 12,
  'name': 'T-shirt',
  'price_xaf': 5000,
  'variants': [
    {'id': 101, 'attributes': {'Taille': 'L'}, 'stock': 4},
    {
      'id': 102,
      'attributes': {'Taille': 'XL'},
      'stock': 2,
      'price_adjustment_xaf': 500,
    },
    {'id': 103, 'attributes': {'Taille': 'S'}, 'stock': 0},
  ],
  'variant_options': [
    {
      'name': 'Taille',
      'type': 'text',
      'values': [
        {'value': 'S'},
        {'value': 'L'},
        {'value': 'XL'},
      ],
    },
  ],
};

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

  group('Commande de plusieurs tailles', () {
    test('une ligne par taille, chacune à son prix', () {
      final controller = ProductController();
      final product = _tshirt();

      // L et XL dans la même commande : c'était la demande.
      controller.setVariantQuantities({101: 2, 102: 1});

      final lines = controller.orderLines(product);
      expect(lines.map((l) => l.label), ['L', 'XL']);
      expect(lines.map((l) => l.quantity), [2, 1]);
      expect(controller.orderQuantity.value, 3);
      expect(controller.orderSubtotal(product), 2 * 5000 + 1 * 5500);
      expect(controller.missingOrderSteps(product), isNot(contains(
        'Indiquer la quantité d’au moins une option',
      )));
    });

    test('rien de choisi : la commande le signale', () {
      final controller = ProductController();
      controller.setVariantQuantities(const {});

      expect(
        controller.missingOrderSteps(_tshirt()),
        contains('Indiquer la quantité d’au moins une option'),
      );
    });

    test('la variante d’un autre produit ne fausse pas le prix', () {
      final controller = ProductController();
      controller.selectedVariant.value = {
        'id': 999,
        'attributes': {'Taille': 'M'},
        'price_xaf': 99999,
        'stock': 5,
      };

      expect(controller.unitPriceXaf(_tshirt()), 5000);
    });
  });

  group('Liste des options', () {
    Future<Map<int, int>> pumpList(
      WidgetTester tester, {
      bool limitToStock = true,
    }) async {
      var quantities = <int, int>{};
      final product = _tshirt();
      final catalog = VariantCatalog.fromApi(
        product['variants'],
        product['variant_options'],
      );
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: VariantQuantityList(
                  catalog: catalog,
                  quantities: quantities,
                  limitToStock: limitToStock,
                  onChanged: (next) => setState(() => quantities = next),
                ),
              ),
            ),
          ),
        ),
      );
      return quantities;
    }

    Finder fieldOf(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(AnimatedContainer),
      ),
      matching: find.byType(TextField),
    );

    testWidgets('chaque taille a sa quantité, saisie au clavier', (
      tester,
    ) async {
      await pumpList(tester);

      await tester.enterText(fieldOf('L'), '3');
      await tester.enterText(fieldOf('XL'), '1');
      await tester.pump();

      expect(tester.widget<TextField>(fieldOf('L')).controller!.text, '3');
      expect(tester.widget<TextField>(fieldOf('XL')).controller!.text, '1');
    });

    testWidgets('au détail, la quantité ne dépasse pas le stock de la taille', (
      tester,
    ) async {
      await pumpList(tester);

      // Deux XL en stock : taper 10 est ramené à 2.
      await tester.enterText(fieldOf('XL'), '10');
      await tester.pump();
      expect(tester.widget<TextField>(fieldOf('XL')).controller!.text, '2');

      // La taille S, épuisée, ne se commande pas.
      expect(tester.widget<TextField>(fieldOf('S')).enabled, isFalse);
      expect(find.text('Épuisé'), findsOneWidget);
    });

    testWidgets('en gros, le stock ne limite ni ne masque une option', (
      tester,
    ) async {
      await pumpList(tester, limitToStock: false);

      await tester.enterText(fieldOf('S'), '500');
      await tester.pump();

      expect(tester.widget<TextField>(fieldOf('S')).controller!.text, '500');
      expect(find.text('Épuisé'), findsNothing);
    });
  });

  testWidgets('le champ quantité reprend le minimum s’il est vidé', (
    tester,
  ) async {
    var value = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StatefulBuilder(
                builder: (context, setState) => QuantityStepper(
                  value: value,
                  min: 1,
                  onChanged: (v) => setState(() => value = v),
                ),
              ),
              const TextField(key: Key('autre')),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    await tester.tap(find.byKey(const Key('autre')));
    await tester.pump();

    expect(value, 1);
  });

  testWidgets('en gros, le minimum porte sur le total des tailles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const product = WholesaleProduct(
      id: 7,
      name: 'Polos',
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
      variants: [
        {'id': 1, 'attributes': {'Taille': 'L'}, 'stock': 0},
        {'id': 2, 'attributes': {'Taille': 'XL'}, 'stock': 0},
      ],
    );

    await tester.pumpWidget(
      const GetMaterialApp(
        home: WholesaleProductView(
          product: product,
          shippingOptions: [],
          countryFlag: '🇨🇳',
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder fieldOf(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(AnimatedContainer),
      ),
      matching: find.byType(TextField),
    );

    await tester.enterText(fieldOf('L'), '30');
    await tester.pump();
    expect(find.textContaining('minimum 50'), findsOneWidget);

    // 30 L + 20 XL = 50 : le minimum est atteint sans qu'aucune taille ne
    // l'atteigne seule.
    await tester.enterText(fieldOf('XL'), '20');
    await tester.pump();
    expect(find.text('Total : 50 unités'), findsOneWidget);
  });
}
