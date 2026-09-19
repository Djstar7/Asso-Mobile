import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/core/values/constants.dart';
import 'package:asso/app/modules/product/controllers/product_controller.dart';

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

  group('Lien de partage', () {
    test('un produit se partage sous /produit/{id}', () {
      final url = AppConstants.productUrl(35);

      expect(url, 'https://asso-dashboard.sbs/produit/35');
    });

    test('le lien est construit depuis l\'identifiant du produit', () {
      final c = Get.put(ProductController());

      final url = c.shareUrl({'id': 35, 'name': 'Smart TV'});

      expect(url, endsWith('/produit/35'));
      expect(url, startsWith('https://'));
    });

    test('sans identifiant, il n\'y a rien à partager', () {
      final c = Get.put(ProductController());

      // Produit de démonstration ou fiche incomplète : diffuser un lien mort
      // serait pire que ne rien proposer.
      expect(c.shareUrl({'name': 'Sans identifiant'}), isNull);
      expect(c.shareUrl({'id': '', 'name': 'Vide'}), isNull);
    });

    test('le chemin partagé est celui déclaré aux plateformes', () {
      // Les fichiers d'association et l'intent-filter Android déclarent
      // /produit/* : un changement ici ne doit pas passer inaperçu, sinon
      // le système cesse de remettre le lien à l'application.
      final uri = Uri.parse(AppConstants.productUrl(7));

      expect(uri.pathSegments.first, 'produit');
      expect(uri.host, AppConstants.shareDomain);
    });
  });
}
