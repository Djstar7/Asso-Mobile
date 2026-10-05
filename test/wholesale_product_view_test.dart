import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/core/widgets/app_sheet.dart';
import 'package:asso/app/data/models/user_model.dart';
import 'package:asso/app/data/models/wholesale_models.dart';
import 'package:asso/app/data/providers/storage_service.dart';
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

  tearDown(() {
    StorageService.clearAuthSession();
    Get.reset();
  });

  /// « Commander » demande un compte : la feuille ne s'ouvre qu'une fois
  /// connecté.
  void signIn() => StorageService.saveAuthSession(
    'token-abc',
    UserModel(
      id: 7,
      firstName: 'Awa',
      lastName: 'Diop',
      name: 'Awa Diop',
      email: 'awa@example.com',
      phone: '+237690000000',
      role: 'client',
      createdAt: DateTime(2026, 1, 1).toIso8601String(),
    ),
  );

  /// Ouvre la feuille de commande, où se règlent quantité et paliers.
  Future<void> openOrderSheet(WidgetTester tester) async {
    signIn();
    await tester.tap(find.text('Commander'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsOneWidget);
  }

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

  testWidgets('la fiche ne montre ni quantité, ni paliers, ni livraison', (
    tester,
  ) async {
    await openPage(tester);

    expect(quantityField(), findsNothing);
    expect(find.text('Prix selon la quantité'), findsNothing);
    expect(find.text('Numéro à contacter'), findsNothing);
    expect(find.text('Récapitulatif'), findsNothing);
  });

  testWidgets('part du minimum du palier', (tester) async {
    await openPage(tester);
    await openOrderSheet(tester);

    expect(find.text('Chaises pliantes'), findsWidgets);
    expect(tester.widget<TextField>(quantityField()).controller!.text, '50');
    // 50 × 1 000 + 20 000 d'expédition.
    expect(find.textContaining('70'), findsWidgets);
  });

  testWidgets('accepte une quantité saisie au clavier', (tester) async {
    await openPage(tester);
    await openOrderSheet(tester);

    await tester.enterText(quantityField(), '500');
    await tester.pump();

    // 500 × 1 000 + 20 000 : le total suit la saisie.
    expect(find.textContaining('520'), findsWidgets);
    expect(find.textContaining('Minimum 50 pour'), findsNothing);
  });

  testWidgets('sous le premier palier, rappelle le minimum et bloque', (
    tester,
  ) async {
    await openPage(tester);
    await openOrderSheet(tester);

    await tester.enterText(quantityField(), '12');
    await tester.pump();

    // Le seuil du premier palier (50) est le minimum de commande.
    expect(find.textContaining('Minimum 50 unités'), findsWidgets);
    expect(find.textContaining('Total : 12'), findsNothing);
  });

  testWidgets('les boutons ajustent la quantité', (tester) async {
    await openPage(tester);
    await openOrderSheet(tester);

    await tester.tap(find.byTooltip('Augmenter'));
    await tester.pump();
    expect(tester.widget<TextField>(quantityField()).controller!.text, '51');

    await tester.tap(find.byTooltip('Diminuer'));
    await tester.pump();
    await tester.tap(find.byTooltip('Diminuer'));
    await tester.pump();
    expect(tester.widget<TextField>(quantityField()).controller!.text, '49');
  });

  testWidgets('garde « Commander » au-dessus du clavier', (tester) async {
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

  group('paliers', () {
    // 50 à 1 000 FCFA, 100 à 750 FCFA.
    WholesaleProduct tiered() => const WholesaleProduct(
      id: 8,
      name: 'Gobelets',
      currency: 'XAF',
      priceTiers: [
        PriceTier(
          id: 2,
          label: 'Pack de 100',
          unitPrice: 750,
          unitPriceXaf: 750,
          currency: 'XAF',
          minQuantity: 100,
          formattedPrice: '750 FCFA',
        ),
        PriceTier(
          id: 1,
          label: 'Pack de 50',
          unitPrice: 1000,
          unitPriceXaf: 1000,
          currency: 'XAF',
          minQuantity: 50,
          formattedPrice: '1 000 FCFA',
        ),
      ],
    );

    Future<void> openTiered(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GetMaterialApp(
          home: WholesaleProductView(
            product: tiered(),
            shippingOptions: _shipping,
            countryFlag: '🇨🇳',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('part du premier palier', (tester) async {
      await openTiered(tester);
      await openOrderSheet(tester);
      expect(tester.widget<TextField>(quantityField()).controller!.text, '50');
      // 50 × 1 000 + 20 000.
      expect(find.textContaining('70'), findsWidgets);
    });

    testWidgets('toucher un palier y amène la quantité et le prix', (
      tester,
    ) async {
      await openTiered(tester);
      await openOrderSheet(tester);

      await tester.tap(find.text('Pack de 100'));
      await tester.pump();

      expect(tester.widget<TextField>(quantityField()).controller!.text, '100');
      // 100 × 750 + 20 000.
      expect(find.textContaining('95'), findsWidgets);
    });

    testWidgets('le prix suit la quantité saisie', (tester) async {
      await openTiered(tester);
      await openOrderSheet(tester);

      // Entre deux paliers : prix du palier atteint.
      await tester.enterText(quantityField(), '80');
      await tester.pump();
      expect(find.textContaining('encore 20'), findsOneWidget);
      // 80 × 1 000 + 20 000.
      expect(find.textContaining('100'), findsWidgets);

      await tester.enterText(quantityField(), '120');
      await tester.pump();
      // 120 × 750 + 20 000.
      expect(find.textContaining('110'), findsWidgets);
    });
  });

  testWidgets('le paiement attend l’adresse et sa précision', (tester) async {
    await openPage(tester);
    await openOrderSheet(tester);

    expect(find.text('Indiquez votre adresse de livraison.'), findsOneWidget);
    expect(find.text('Précisions (obligatoire)'), findsOneWidget);
  });

  testWidgets('la feuille mène au récapitulatif avant le paiement', (
    tester,
  ) async {
    await openPage(tester);
    await openOrderSheet(tester);

    // Le récapitulatif est une étape à part, comme sur la fiche détail : la
    // feuille ne propose pas de payer directement.
    expect(find.textContaining('Voir le récapitulatif'), findsOneWidget);
    expect(find.textContaining('Payer'), findsNothing);
    expect(find.text('Montant'), findsNothing);
  });

  testWidgets('porte un bouton retour', (tester) async {
    await openPage(tester);
    expect(find.byTooltip('Retour'), findsOneWidget);
  });
}
