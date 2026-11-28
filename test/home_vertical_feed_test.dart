import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:asso/app/modules/home/controllers/home_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fil d'accueil vertical : tout le catalogue page après page, sans bouton
/// « Découvrir plus », et sans doublon ni page égarée.
void main() {
  late Directory storage;
  final requested = <int>[];
  Future<http.Response> Function(http.Request)? handler;

  Map<String, dynamic> product(int id, {bool ad = false}) => {
    'id': id,
    'name': 'Produit $id',
    'price': 1000,
    if (ad) 'is_sponsored': true,
  };

  http.Response page(List<Map<String, dynamic>> items, {required bool more}) =>
      http.Response(
        jsonEncode({
          'success': true,
          'products': items,
          'pagination': {'has_more': more},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  final client = MockClient((request) async {
    if (!request.url.path.endsWith('/products')) {
      return http.Response(jsonEncode({'success': true, 'data': []}), 200);
    }
    requested.add(int.parse(request.url.queryParameters['page'] ?? '1'));
    return handler!(request);
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storage = await Directory.systemTemp.createTemp('asso-home-feed-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    await GetStorage.init();
  });
  setUp(requested.clear);
  tearDown(Get.reset);
  tearDownAll(() => storage.delete(recursive: true));

  test(
    'le fil charge les pages à la suite, garde les annonces et évite les doublons',
    () async {
      handler = (request) async {
        final p = int.parse(request.url.queryParameters['page'] ?? '1');
        return switch (p) {
          1 => page([
            product(1, ad: true),
            product(2),
            product(3),
            product(9, ad: true),
          ], more: true),
          // Le produit 3 revient en tête de page 2 (publication entre-temps).
          2 => page([product(3), product(4), product(5)], more: true),
          _ => page([product(6)], more: false),
        };
      };

      await http.runWithClient(() async {
        final home = HomeController();
        home.selectCategory('Tous');
        await pumpEventQueue();
        // La 1re annonce passe en bandeau, l'autre reste dans le fil.
        expect(home.sponsoredProducts.map((p) => p['id']), [1]);
        expect(home.products.map((p) => p['id']), [2, 3, 9]);

        await home.loadMoreProducts();
        expect(home.products.map((p) => p['id']), [2, 3, 9, 4, 5]);
        expect(home.hasMoreProducts.value, isTrue);

        await home.loadMoreProducts();
        expect(home.products.map((p) => p['id']), [2, 3, 9, 4, 5, 6]);
        expect(home.hasMoreProducts.value, isFalse);

        // Fin du catalogue : plus aucun appel.
        await home.loadMoreProducts();
        expect(requested, [1, 2, 3]);
      }, () => client);
    },
  );

  test(
    'une page demandée avant un changement de catégorie est ignorée',
    () async {
      final slowPage2 = Completer<http.Response>();
      handler = (request) async {
        final p = int.parse(request.url.queryParameters['page'] ?? '1');
        if (p == 2) return slowPage2.future;
        final category = request.url.queryParameters['category_id'];
        return page(
          category == null ? [product(1), product(2)] : [product(50)],
          more: true,
        );
      };

      await http.runWithClient(() async {
        final home = HomeController();
        home.apiCategories.assignAll([
          {'id': 7, 'name': 'Mode'},
        ]);
        home.selectCategory('Tous');
        await pumpEventQueue();

        final late = home.loadMoreProducts();
        await pumpEventQueue();
        home.selectCategory('Mode');
        await pumpEventQueue();
        slowPage2.complete(page([product(3)], more: false));
        await late;

        expect(home.products.map((p) => p['id']), [50]);
        expect(home.hasMoreProducts.value, isTrue);
        expect(home.isLoadingMore.value, isFalse);
      }, () => client);
    },
  );

  test('après un échec, la suite attend « Réessayer »', () async {
    var failing = true;
    handler = (request) async {
      final p = int.parse(request.url.queryParameters['page'] ?? '1');
      if (p == 1) return page([product(1)], more: true);
      if (failing) return http.Response('{"success":false}', 500);
      return page([product(2)], more: false);
    };

    await http.runWithClient(() async {
      final home = HomeController();
      home.selectCategory('Tous');
      await pumpEventQueue();

      await home.loadMoreProducts();
      expect(home.loadMoreFailed.value, isTrue);

      // Défiler à nouveau ne relance pas l'appel en boucle.
      await home.loadMoreProducts();
      expect(requested, [1, 2]);

      failing = false;
      home.retryLoadMore();
      await pumpEventQueue();
      expect(home.loadMoreFailed.value, isFalse);
      expect(home.products.map((p) => p['id']), [1, 2]);
    }, () => client);
  });
}
