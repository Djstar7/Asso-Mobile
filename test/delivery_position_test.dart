import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:asso/app/modules/product/controllers/product_controller.dart';
import 'package:asso/app/modules/product/views/map_selection_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Geocoder extends GeocodingPlatform {
  final result = Completer<List<Placemark>>();
  int calls = 0;

  @override
  Future<List<Placemark>> placemarkFromCoordinates(double lat, double lng) {
    calls++;
    return result.future;
  }
}

class _Gps extends GeolocatorPlatform {
  final result = Completer<Position>();
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      result.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  late _Geocoder geocoder;
  late ProductController controller;
  final originalGps = GeolocatorPlatform.instance;
  final originalGeocoder = GeocodingPlatform.instance;

  setUpAll(() async {
    storage = await Directory.systemTemp.createTemp('asso-position-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    await GetStorage.init();
  });
  tearDownAll(() => storage.delete(recursive: true));
  setUp(() {
    GeocodingPlatform.instance = geocoder = _Geocoder();
    controller = ProductController();
  });
  tearDown(() {
    controller.onClose();
    GeolocatorPlatform.instance = originalGps;
    if (originalGeocoder != null) GeocodingPlatform.instance = originalGeocoder;
    Get.reset();
  });

  test(
    'the map selection applies immediately and clears the previous delivery quote',
    () async {
      controller.selectedPartner.value = {
        'company_id': 12,
        'delivery_price': 5000,
      };
      controller.deliveryPrice.value = 5000;
      controller.withDelivery.value = true;
      await controller.setDeliveryPosition(
        5.63,
        10.31,
        fallbackAddress: 'Mbouda, Cameroun',
      );
      expect(controller.hasValidLocation, isTrue);
      expect(controller.clientLatitude.value, 5.63);
      expect(controller.clientLongitude.value, 10.31);
      expect(controller.currentLocation.value, 'Mbouda, Cameroun');
      expect(controller.selectedPartner.value, isNull);
      expect(controller.deliveryPrice.value, 0);
      expect(controller.withDelivery.value, isFalse);
      expect(geocoder.calls, 0);
    },
  );

  test(
    'late geocoding cannot replace the address confirmed on the map',
    () async {
      final earlier = controller.setDeliveryPosition(4.05, 9.77);
      await controller.setDeliveryPosition(
        5.63,
        10.31,
        fallbackAddress: 'Mbouda, Cameroun',
      );
      geocoder.result.complete([const Placemark(locality: 'Douala')]);
      await earlier;
      expect(controller.currentLocation.value, 'Mbouda, Cameroun');
      expect(controller.clientLatitude.value, 5.63);
    },
  );

  test(
    'late GPS cannot move checkout back after manual confirmation',
    () async {
      final gps = _Gps();
      GeolocatorPlatform.instance = gps;
      final earlier = controller.fetchCurrentLocation();
      await controller.setDeliveryPosition(
        5.63,
        10.31,
        fallbackAddress: 'Mbouda, Cameroun',
      );
      gps.result.complete(
        Position(
          latitude: 4.05,
          longitude: 9.77,
          timestamp: DateTime(2026),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      await earlier;
      expect(controller.currentLocation.value, 'Mbouda, Cameroun');
      expect(controller.clientLatitude.value, 5.63);
      expect(controller.clientLongitude.value, 10.31);
      expect(geocoder.calls, 0);
    },
  );

  testWidgets(
    'confirm returns the chosen coordinates even while a snackbar is visible',
    (tester) async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
      );
      final client = MockClient(
        (request) async => request.url.path.contains('/delivery/coverage')
            ? http.Response(
                jsonEncode({
                  'success': true,
                  'coverage': {
                    'served': false,
                    'geographically_served': true,
                    'quote_available': false,
                    'served_by': [],
                    'message': 'Le point de collecte doit être renseigné.',
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              )
            : http.Response.bytes(
                png,
                200,
                headers: {'content-type': 'image/png'},
              ),
      );
      Map<String, dynamic>? selected;
      await http.runWithClient(() async {
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    selected = await Get.to<Map<String, dynamic>>(
                      () => const MapSelectionView(
                        initialLatitude: 5.63,
                        initialLongitude: 10.31,
                        locationName: 'Mbouda, Cameroun',
                        deliveryItems: [
                          {'product_id': 79, 'quantity': 8},
                        ],
                      ),
                    );
                  },
                  child: const Text('Open map'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open map'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('product.map.no_courier_here'.tr), findsNothing);
        expect(
          find.text('product.map.covered_quote_unavailable'.tr),
          findsOneWidget,
        );
        expect(
          find.text('Le point de collecte doit être renseigné.'),
          findsOneWidget,
        );
        Get.snackbar(
          'Information',
          'A message above the map',
          duration: const Duration(seconds: 10),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(Get.isSnackbarOpen, isTrue);
        await tester.tap(find.text('product.map.confirm_position'.tr));
        await tester.pump(const Duration(milliseconds: 400));
        expect(selected?['latitude'], 5.63);
        expect(selected?['longitude'], 10.31);
        expect(selected?['address'], 'Mbouda, Cameroun');
        expect(find.text('Open map'), findsOneWidget);
        Get.closeAllSnackbars();
        await tester.pumpAndSettle();
      }, () => client);
    },
  );
}
