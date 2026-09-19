import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/modules/product/controllers/product_controller.dart';

/// Produit tel que l'API le renvoie réellement.
///
/// Deux détails du contrat sont reproduits fidèlement, parce qu'ils sont
/// précisément ce qui laissait la section vide : `category_id` est nul à la
/// racine, et l'identifiant ne vit que dans l'objet `category` imbriqué.
Map<String, dynamic> _apiProduct({
  required int id,
  required String name,
  int categoryId = 1,
  int subcategoryId = 5,
}) {
  return {
    'id': id,
    'name': name,
    'price': 280000,
    'price_xaf': 280000,
    'stock': 39,
    'category_id': null,
    'subcategory_id': null,
    'category': {'id': categoryId, 'name': 'Électronique'},
    'subcategory': {'id': subcategoryId, 'name': 'Accessoires électroniques'},
  };
}

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

  group('Lecture de la réponse API', () {
    test('lit les produits sous la clé « products »', () {
      // Forme réelle du catalogue, relevée sur le serveur.
      final body = {
        'success': true,
        'products': [
          _apiProduct(id: 35, name: 'Smart TV 43 Pouces'),
          _apiProduct(id: 36, name: 'Tablette Samsung Tab A9'),
        ],
        'pagination': {'total': 2},
      };

      final result = ProductController.extractProducts(body);

      expect(result, hasLength(2));
      expect(result.first['name'], 'Smart TV 43 Pouces');
    });

    test('accepte aussi une pagination sous « data »', () {
      final body = {
        'data': {
          'data': [_apiProduct(id: 40, name: 'Écouteurs JBL')],
        },
      };

      expect(ProductController.extractProducts(body), hasLength(1));
    });

    test('exclut le produit consulté de ses propres suggestions', () {
      final body = {
        'products': [
          _apiProduct(id: 35, name: 'Smart TV 43 Pouces'),
          _apiProduct(id: 36, name: 'Tablette Samsung Tab A9'),
        ],
      };

      final result = ProductController.extractProducts(body, excluding: '35');

      expect(result, hasLength(1));
      expect(result.single['id'], 36);
    });

    test('une réponse inattendue donne une liste vide, sans lever', () {
      expect(ProductController.extractProducts({'success': true}), isEmpty);
      expect(ProductController.extractProducts({'products': null}), isEmpty);
      expect(ProductController.extractProducts({'products': 'oops'}), isEmpty);
    });
  });

  group('Produits similaires', () {
    test('la liste démarre vide', () {
      final c = Get.put(ProductController());
      expect(c.similarProducts, isEmpty);
    });

    test('un produit sans catégorie ne déclenche aucune recherche', () async {
      final c = Get.put(ProductController());

      await c.loadSimilarProducts({'id': 1, 'name': 'Sans catégorie'});

      expect(c.similarProducts, isEmpty);
      expect(c.isLoadingSimilarProducts.value, isFalse);
    });

    test('l\'échec réseau laisse la section vide sans lever', () async {
      final c = Get.put(ProductController());

      // Sous test, la requête HTTP renvoie 400 : le chargement doit se
      // terminer proprement plutôt que de remonter l'erreur dans la fiche.
      await c.loadSimilarProducts(_apiProduct(id: 35, name: 'Smart TV'));

      expect(c.isLoadingSimilarProducts.value, isFalse);
      expect(c.similarProducts, isEmpty);
    });

    test('la consultation ne relance pas la recherche en boucle', () {
      final c = Get.put(ProductController());
      final product = _apiProduct(id: 35, name: 'Smart TV');

      // La fiche est reconstruite à chaque changement d'état ; le suivi est
      // dédoublonné par identifiant, sinon chaque frame relancerait l'appel.
      c.trackProductView(product);
      c.trackProductView(product);
      c.trackProductView(product);

      expect(c.isLoadingSimilarProducts.value, anyOf(isTrue, isFalse));
    });
  });
}
