import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/modules/product/controllers/product_controller.dart';
import 'package:asso/app/modules/product/views/product_view.dart';

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

  testWidgets(
    'la fiche garde son produit quand un écran s’ouvre par-dessus',
    (tester) async {
      Get.put(ProductController());
      await tester.pumpWidget(
        GetMaterialApp(
          home: const Scaffold(body: Text('Accueil')),
          getPages: [
            GetPage(name: '/product', page: () => const ProductView()),
          ],
        ),
      );
      Get.toNamed(
        '/product',
        arguments: <String, dynamic>{
          'id': 42,
          'name': 'Chaise en bois',
          'price': 15000,
          'images': <String>[],
        },
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Chaise en bois'), findsWidgets);

      // Une visionneuse ou une feuille ouverte par-dessus n'a pas
      // d'arguments ; puis la fiche se reconstruit (ici, le clavier sort).
      Get.dialog(const AlertDialog(content: Text('Par-dessus')));
      await tester.pump(const Duration(milliseconds: 300));
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      addTearDown(tester.view.reset);
      await tester.pump();

      expect(find.text('Chaise en bois', skipOffstage: false), findsWidgets);
      expect(find.text('Produit', skipOffstage: false), findsNothing);
    },
  );
}
