import 'dart:convert';
import 'dart:io';
import 'package:asso/app/core/utils/address_search.dart';
import 'package:asso/app/modules/product/views/map_selection_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  setUpAll(() async {
    storage = await Directory.systemTemp.createTemp('asso-international-map-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    await GetStorage.init();
  });
  tearDownAll(() => storage.delete(recursive: true));
  tearDown(Get.reset);
  testWidgets(
    'international countries are visible, searchable and quoted with the selected country',
    (tester) async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
      );
      final requests = <Uri>[];
      final originalAddressClient = AddressSearch.newClient;
      AddressSearch.newClient = () => MockClient(
        (request) async => http.Response(
          jsonEncode({
            'features': [
              {
                'geometry': {
                  'coordinates': [2.35, 48.85],
                },
                'properties': {
                  'name': 'Paris',
                  'city': 'Paris',
                  'country': 'France',
                  'countrycode': 'FR',
                  'osm_key': 'place',
                  'osm_value': 'city',
                },
              },
            ],
          }),
          200,
        ),
      );
      final client = MockClient((request) async {
        if (!request.url.path.contains('/delivery/coverage')) {
          return http.Response.bytes(
            png,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        requests.add(request.url);
        final overseas = request.url.queryParameters['country'] == 'FR';
        return http.Response(
          jsonEncode({
            'success': true,
            'coverage': {
              'country': overseas ? 'FR' : 'CM',
              'served': false,
              'geographically_served': overseas,
              'quote_available': !overseas,
              'message': overseas ? 'Seller weight missing' : null,
              'geographic_served_by': overseas
                  ? [
                      {
                        'company_name': 'DHL Express',
                        'type': 'international',
                        'coverage_scope': 'country',
                      },
                      {
                        'company_name': 'FedEx',
                        'type': 'international',
                        'coverage_scope': 'country',
                      },
                    ]
                  : [],
              'served_by': [],
              'international_areas': [
                {
                  'id': 'FR',
                  'country': 'FR',
                  'label': 'France',
                  'reference_point': {'latitude': 48.87, 'longitude': 2.31},
                  'reference_agencies': [
                    {
                      'latitude': 48.87,
                      'longitude': 2.31,
                      'name': 'DHL Paris',
                      'address': '30 rue de la Boétie',
                      'is_provisional': false,
                      'coordinate_precision': 'street',
                      'source_url': 'https://www.dhlexpress.fr/agences-dhl',
                    },
                  ],
                  'latitude': 46.7,
                  'longitude': 2.5,
                  'companies': ['DHL Express', 'FedEx'],
                  'polygons': [
                    [
                      [
                        [42, -4],
                        [50, -4],
                        [50, 8],
                        [42, 8],
                        [42, -4],
                      ],
                    ],
                    [
                      [
                        [50.5, 2.5],
                        [50.52, 2.5],
                        [50.52, 2.52],
                        [50.5, 2.52],
                        [50.5, 2.5],
                      ],
                    ],
                  ],
                },
                {
                  'id': 'DE',
                  'country': 'DE',
                  'label': 'Allemagne',
                  'latitude': 51,
                  'longitude': 10,
                  'companies': ['DHL Express', 'FedEx'],
                  'polygons': [
                    [
                      [
                        [48, 6],
                        [54, 6],
                        [54, 15],
                        [48, 15],
                        [48, 6],
                      ],
                    ],
                  ],
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      try {
        await http.runWithClient(() async {
          await tester.pumpWidget(
            GetMaterialApp(
              home: const MapSelectionView(
                initialLatitude: 5.47,
                initialLongitude: 10.42,
                locationName: 'Bafoussam, Cameroun',
                deliveryItems: [
                  {'product_id': 79, 'quantity': 2},
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('international-destinations')),
            findsOneWidget,
          );
          final polygons = tester
              .widgetList<PolygonLayer>(find.byType(PolygonLayer))
              .first
              .polygons;
          expect(polygons, hasLength(3));
          expect(polygons.first.points.first.latitude, 42);
          await tester.tap(find.byKey(const Key('international-destinations')));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, 'France');
          await tester.pumpAndSettle();
          expect(find.widgetWithText(ListTile, 'France'), findsOneWidget);
          expect(find.widgetWithText(ListTile, 'Allemagne'), findsNothing);
          await tester.tap(find.widgetWithText(ListTile, 'France'));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(requests.last.queryParameters['country'], 'FR');
          expect(find.text('product.map.country_covered'.tr), findsOneWidget);
          expect(find.text('product.map.no_courier_here'.tr), findsNothing);
          expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton).last)
                .onPressed,
            isNull,
          );
          final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
          expect(map.mapController!.camera.center.latitude, greaterThan(40));
          expect(map.mapController!.camera.zoom, lessThan(7));
          await tester.enterText(find.byType(TextField).first, 'Paris');
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ListTile, 'Paris'));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(requests.last.queryParameters['country'], 'FR');
          expect(requests.last.queryParameters['city'], 'Paris');
          expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton).last)
                .onPressed,
            isNotNull,
          );
          expect(find.text('DHL Express'), findsWidgets);
          expect(find.text('FedEx'), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      } finally {
        AddressSearch.newClient = originalAddressClient;
      }
    },
  );
}
