import 'dart:convert';
import 'dart:io';

import 'package:asso/app/core/i18n/app_translations.dart';
import 'package:asso/app/data/models/real_estate_models.dart';
import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/modules/immo/views/immo_home_view.dart';
import 'package:asso/app/modules/immo/widgets/immo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory storage;
  late AppTranslations translations;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storage = await Directory.systemTemp.createTemp('asso-immo-categories-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    await GetStorage.init();
    translations = await AppTranslations.load();
  });
  tearDown(Get.reset);
  tearDownAll(() => storage.delete(recursive: true));

  testWidgets('houses switch between all, rental and sale; land uses m²', (
    tester,
  ) async {
    final queries = <Map<String, String>>[];
    final client = MockClient((request) async {
      final isList = request.url.path.endsWith('/listings');
      if (isList) queries.add(request.url.queryParameters);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': isList ? [] : {'cities': []},
          if (isList) 'meta': {'total': 0},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        GetMaterialApp(
          translations: translations,
          locale: const Locale('fr', 'FR'),
          home: const ImmoHomeView(),
        ),
      );
      await tester.pumpAndSettle();
      expect(queries.last['type'], 'house');
      await tester.tap(find.text('À vendre'));
      await tester.pumpAndSettle();
      expect(queries.last['type'], 'sale');
      await tester.tap(find.text('À louer'));
      await tester.pumpAndSettle();
      expect(queries.last['type'], 'rent');
      await tester.tap(find.text('Terrains à vendre'));
      await tester.pumpAndSettle();
      expect(queries.last['type'], 'land');
      expect(queries.last['price_basis'], 'per_m2');
      expect(find.text('Prix au m²'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('a land card shows its rate and a sale has no monthly suffix', (
    tester,
  ) async {
    Get.put(CurrencyService());
    final land = RealEstateListing.fromJson({
      'id': 1,
      'type': 'land',
      'price': 4000000,
      'price_per_m2': 10000,
      'city': 'Douala',
      'title': 'Terrain',
    });
    final sale = RealEstateListing.fromJson({
      'id': 2,
      'type': 'sale',
      'price': 35000000,
      'city': 'Douala',
      'title': 'Maison',
    });
    await tester.pumpWidget(
      GetMaterialApp(
        translations: translations,
        locale: const Locale('fr', 'FR'),
        home: Scaffold(
          body: Column(
            children: [
              ImmoPriceText(listing: land),
              ImmoPriceText(listing: sale),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('${immoPrice(10000)} / m²'), findsOneWidget);
    expect(find.text(immoPrice(4000000)), findsNothing);
    expect(find.text(immoPrice(35000000)), findsOneWidget);
    expect(find.textContaining('/ mois'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
