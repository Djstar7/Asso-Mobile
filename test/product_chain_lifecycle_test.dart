import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/modules/product/views/product_view.dart';

Map<String, dynamic> _product(int id, String name) => <String, dynamic>{
  'id': id,
  'name': name,
  'price': 15000,
  'stock': 3,
  'images': <String>[],
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

  testWidgets('enchaîner les fiches produit ne casse pas la fiche affichée', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: Text('Accueil')),
        getPages: [
          GetPage(
            name: '/product',
            page: () => const ProductPage(),
          ),
        ],
      ),
    );

    Get.toNamed('/product', arguments: _product(1, 'Chaise en bois'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Chaise en bois'), findsWidgets);

    // Produit similaire : la fiche courante est remplacée.
    Get.offNamed(
      '/product',
      arguments: _product(2, 'Table basse'),
      preventDuplicates: false,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Table basse'), findsWidgets);

    // La fiche se reconstruit (clavier) : elle ne doit pas s'appuyer sur des
    // contrôleurs libérés par la fermeture de la précédente.
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // Retour : l'accueil réapparaît, la pile n'est jamais vide.
    Get.back();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Accueil'), findsOneWidget);
  });

  testWidgets('deux fiches empilées gardent chacune leur état', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: Text('Accueil')),
        getPages: [
          GetPage(
            name: '/product',
            page: () => const ProductPage(),
          ),
        ],
      ),
    );

    Get.toNamed('/product', arguments: _product(1, 'Chaise en bois'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    Get.toNamed(
      '/product',
      arguments: _product(2, 'Table basse'),
      preventDuplicates: false,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Fermer la fiche du dessus ne doit pas libérer le contrôleur de celle
    // du dessous, qui se reconstruit ensuite normalement.
    Get.back();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('Chaise en bois'), findsWidgets);
  });
}
