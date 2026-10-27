import 'dart:convert';
import 'dart:io';

import 'package:asso/app/data/models/wholesale_models.dart';
import 'package:asso/app/modules/search/controllers/search_controller.dart'
    as search;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> catalog(
  String code,
  int total,
  int length, {
  int page = 1,
  bool hasMore = false,
  int start = 1000,
}) => {
  'success': true,
  'country': {'code': code, 'flag': '🏳️'},
  'products': [
    for (var i = 0; i < length; i++)
      {'id': start + i, 'name': '$code $i', 'origin_country': code},
  ],
  'pagination': {'total': total, 'current_page': page, 'has_more': hasMore},
};

void main() {
  late Directory directory;
  late search.SearchController controller;
  late Future<http.Response> Function(http.Request) handle;
  final client = MockClient((request) => handle(request));

  http.Response json(Map<String, dynamic> value) => http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('asso-search-count-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    await GetStorage.init();
  });

  setUp(() => controller = search.SearchController());
  tearDown(() {
    controller.onClose();
    Get.reset();
  });
  tearDownAll(() async => directory.delete(recursive: true));

  test('le modèle conserve le total du serveur au-delà de la page reçue', () {
    final page = WholesaleCatalog.fromJson(catalog('CN', 2800, 20));
    expect(page.products, hasLength(20));
    expect(page.total, 2800);
  });

  test('un ancien catalogue non paginé compte tous ses articles', () {
    final data = catalog('CN', 2, 2)..remove('pagination');
    expect(WholesaleCatalog.fromJson(data).total, 2);
  });

  test(
    '3000 produits annoncés dès la première page, sans compter les annonces',
    () async {
      handle = (request) async {
        switch (request.url.path) {
          case '/api/v1/products':
            return json({
              'success': true,
              'products': [
                {'id': 1},
                {'id': 1, 'is_sponsored': true},
              ],
              'pagination': {'total': 182, 'has_more': true},
            });
          case '/api/v1/import-countries':
            return json({
              'success': true,
              'countries': [
                {'code': 'CN'},
                {'code': 'TR'},
                {'code': 'AE'},
              ],
            });
          case '/api/v1/import/CN/products':
            return json(catalog('CN', 2800, 20, hasMore: true));
          case '/api/v1/import/TR/products':
            return json(catalog('TR', 10, 10, start: 2000));
          case '/api/v1/import/AE/products':
            return json(catalog('AE', 8, 8, start: 3000));
          default:
            throw StateError('Unexpected request: ${request.url}');
        }
      };
      await http.runWithClient(() async {
        await controller.loadAllProducts();
        expect(controller.wall.loadFailed.value, isFalse);
        expect(controller.wall.wholesale, hasLength(38));
        expect(controller.resultCount, 3000);

        controller.selectedCategoryId.value = 4;
        expect(controller.resultCount, 182);
      }, () => client);
    },
  );

  test(
    'les pages import restent accessibles et ne gonflent pas le total',
    () async {
      var calls = 0;
      handle = (request) async {
        if (request.url.path.endsWith('/import-countries')) {
          return json({
            'success': true,
            'countries': [
              {'code': 'CN'},
            ],
          });
        }
        if (request.url.path.endsWith('/import/CN/products')) {
          calls++;
          final page = int.parse(request.url.queryParameters['page']!);
          return json(
            catalog(
              'CN',
              3,
              2,
              page: page,
              hasMore: page == 1,
              start: page == 1 ? 1000 : 1001,
            ),
          );
        }
        return json({
          'success': true,
          'products': [
            {'id': 1},
            {'id': 2},
          ],
          'pagination': {'total': 2, 'has_more': false},
        });
      };
      await http.runWithClient(() async {
        await controller.loadAllProducts();
        expect(controller.resultCount, 5);
        expect(controller.wall.wholesale, hasLength(2));
        await controller.loadMore();
        expect(controller.wall.wholesale, hasLength(3));
        expect(controller.feed, hasLength(5));
        expect(controller.resultCount, 5);
        await controller.loadMore();
        expect(calls, 2);
      }, () => client);
    },
  );

  test(
    'la recherche utilise les totaux correspondant au texte saisi',
    () async {
      handle = (request) async {
        if (request.url.path.endsWith('/import-countries')) {
          return json({
            'success': true,
            'countries': [
              {'code': 'CN'},
            ],
          });
        }
        if (request.url.path.endsWith('/import/CN/products')) {
          expect(request.url.queryParameters['q'], 'sac');
          return json(catalog('CN', 125, 20, hasMore: true));
        }
        expect(request.url.queryParameters['search'], 'sac');
        return json({
          'success': true,
          'products': [
            {'id': 1},
          ],
          'pagination': {'total': 1, 'has_more': false},
        });
      };
      await http.runWithClient(() async {
        controller.searchQuery.value = 'sac';
        await controller.refreshWall();
        expect(controller.resultCount, 126);
        expect(controller.wall.query.value, 'sac');
      }, () => client);
    },
  );

  test('un pays indisponible ne donne pas un faux total complet', () async {
    var available = false;
    handle = (request) async {
      if (request.url.path.endsWith('/import-countries')) {
        return json({
          'success': true,
          'countries': [
            {'code': 'CN'},
          ],
        });
      }
      if (request.url.path.endsWith('/import/CN/products')) {
        return available
            ? json(catalog('CN', 2800, 20, hasMore: true))
            : http.Response('{"success":false}', 503);
      }
      return json({
        'success': true,
        'products': [
          {'id': 1},
        ],
        'pagination': {'total': 182, 'has_more': true},
      });
    };
    await http.runWithClient(() async {
      await controller.loadAllProducts();
      expect(controller.resultCount, 182);
      expect(controller.isResultCountComplete, isFalse);
      available = true;
      await controller.loadAllProducts();
      expect(controller.resultCount, 2982);
      expect(controller.isResultCountComplete, isTrue);
    }, () => client);
  });

  test(
    'une nouvelle page locale actualise le total si le catalogue change',
    () async {
      handle = (request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        return json({
          'success': true,
          'products': [
            {'id': page},
          ],
          'pagination': {'total': page == 1 ? 21 : 22, 'has_more': page == 1},
        });
      };
      await http.runWithClient(() async {
        controller.selectedCategoryId.value = 4;
        await controller.loadAllProducts();
        expect(controller.resultCount, 21);
        await controller.loadMore();
        expect(controller.resultCount, 22);
      }, () => client);
    },
  );
}
