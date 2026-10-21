import 'dart:convert';
import 'dart:io';

import 'package:asso/app/data/models/real_estate_models.dart';
import 'package:asso/app/data/providers/real_estate_service.dart';
import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/data/providers/storage_service.dart';
import 'package:asso/app/modules/immo/views/immo_reservation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory storageDirectory;
  var status = 'paid';
  var withContact = false;
  final client = MockClient(
    (request) async => http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'id': 1,
          'reference': 'IMMO-1',
          'status': status,
          'listing': {'id': 4, 'title': 'Maison'},
          'has_documents': false,
          'can_confirm': status == 'paid',
          'can_dispute': status == 'paid',
          if (withContact)
            'contact': {
              'name': 'Bailleur Exemple',
              'phone': '+237 600 000 000',
              'email': 'bailleur@example.com',
              'address': 'Rue 11, portail noir',
              'latitude': 4.05,
              'longitude': 9.7,
            },
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    ),
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp(
      'asso-immo-documents-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => storageDirectory.path,
        );
    await GetStorage.init();
  });
  tearDownAll(() => storageDirectory.delete(recursive: true));
  tearDown(Get.reset);

  for (final state in [
    'paid',
    'released',
    'disputed',
    'refunded',
    'pending_payment',
  ]) {
    testWidgets('Documents in reservation state $state', (tester) async {
      status = state;
      Get.put(CurrencyService());
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const GetMaterialApp(
            home: ImmoReservationView(reservationId: 1, standalone: true),
          ),
        );
        await tester.pumpAndSettle();
        final paid = state != 'pending_payment';
        expect(
          find.text('immo.booking.contract'.tr),
          paid ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('immo.booking.invoice'.tr),
          paid ? findsOneWidget : findsNothing,
        );
        if (state == 'paid') {
          expect(
            tester.getTopLeft(find.text('immo.booking.contract'.tr)).dy,
            lessThan(
              tester.getTopLeft(find.text('immo.booking.confirm'.tr)).dy,
            ),
          );
          await tester.scrollUntilVisible(
            find.text('immo.booking.report'.tr),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('immo.booking.report'.tr), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }

  testWidgets('Contact details stay compact and readable on a narrow screen', (
    tester,
  ) async {
    status = 'paid';
    withContact = true;
    addTearDown(() => withContact = false);
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put(CurrencyService());
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: ImmoReservationView(reservationId: 1, standalone: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bailleur Exemple'), findsOneWidget);
      expect(find.text('+237 600 000 000'), findsOneWidget);
      expect(find.text('bailleur@example.com'), findsOneWidget);
      expect(find.text('Rue 11, portail noir'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('+237 600 000 000')).dy -
            tester.getBottomLeft(find.text('Bailleur Exemple')).dy,
        lessThan(24),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  test(
    'PDF download keeps authentication and returns portable bytes',
    () async {
      StorageService.saveToken('document-test-token');
      addTearDown(() => StorageService.saveToken(''));
      final r = RealEstateReservation.fromJson({
        'id': 1,
        'reference': 'IMMO-1',
        'status': 'paid',
      });
      await http.runWithClient(
        () async {
          final file = await RealEstateService.downloadDocument(r, 'invoice');
          expect(file, isNotNull);
          expect(file!.mimeType, 'application/pdf');
          expect(utf8.decode(await file.readAsBytes()), '%PDF-1.4 test');
        },
        () => MockClient((request) async {
          expect(
            request.url.path,
            endsWith('/reservations/1/documents/invoice'),
          );
          expect(
            request.headers['Authorization'],
            'Bearer document-test-token',
          );
          return http.Response(
            '%PDF-1.4 test',
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
      );
    },
  );
}
