import 'package:asso/app/data/models/diaspo_offer.dart';
import 'package:asso/app/data/models/maritime.dart';
import 'package:asso/app/data/models/parcel_nature.dart';
import 'package:asso/app/data/providers/diaspo_service.dart';
import 'package:asso/app/data/providers/maritime_service.dart';
import 'package:asso/app/modules/diaspoBooking/controllers/diaspo_booking_controller.dart';
import 'package:asso/app/modules/diaspoBooking/views/diaspo_booking_view.dart';
import 'package:asso/app/modules/diaspoBooking/widgets/parcel_insurance_form.dart';
import 'package:asso/app/modules/maritime/controllers/maritime_booking_controller.dart';
import 'package:asso/app/modules/maritime/views/maritime_booking_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

final _nature = ParcelNature(
  id: 1,
  name: 'Vêtements',
  insuranceRate: 4,
  minInsuranceAmount: 0,
);

class _ParcelService extends DiaspoService {
  bool failQuote = false;
  int quoteCalls = 0;
  @override
  Future<({List<ParcelNature> natures, double airMaxKgHint})>
  getParcelNatures() async => (natures: [_nature], airMaxKgHint: 23.0);

  @override
  Future<double> insuranceQuote({
    required int natureId,
    required double declaredValue,
    required String declaredValueCurrency,
    required String currency,
  }) async {
    quoteCalls++;
    if (failQuote) throw Exception('Quote unavailable');
    return declaredValue * .04;
  }
}

void main() {
  late _ParcelService service;
  setUp(() {
    Get.testMode = true;
    service = Get.put<DiaspoService>(_ParcelService()) as _ParcelService;
    Get.put(MaritimeService());
  });
  tearDown(Get.reset);

  for (final mode in ['sea', 'air']) {
    testWidgets(
      '$mode freight uses total weight and gates insurance on a valid declaration',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(() => tester.view.resetDevicePixelRatio());
        addTearDown(() => tester.view.resetPhysicalSize());
        final departure = MaritimeDeparture.fromJson({
          'id': 1,
          'partner_name': 'Partenaire',
          'departure_date': '2026-11-20',
          'departure_datetime': '2026-11-20T10:00:00Z',
          'arrival_datetime': '2026-11-21T10:00:00Z',
          'remaining_kg': 100,
          'price_per_kg': 12,
          'currency': 'EUR',
          'status': 'open',
          'transport_mode': mode,
        });
        await tester.pumpWidget(GetMaterialApp(home: const Scaffold()));
        Get.to(
          () => const MaritimeBookingView(),
          arguments: {'departure': departure},
          binding: BindingsBuilder(() {
            Get.put<MaritimeBookingController>(MaritimeBookingController());
          }),
        );
        await tester.pumpAndSettle();
        final controller = Get.find<MaritimeBookingController>();
        expect(find.text('Nombre de colis'), findsNothing);
        expect(find.text('Poids total'), findsOneWidget);
        expect(controller.freight, 120);
        await tester.enterText(
          find.widgetWithText(TextField, 'Poids total'),
          '20,5',
        );
        await tester.pump();
        expect(controller.freight, 246);
        expect(controller.grandTotal, 246);
        expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile))
              .onChanged,
          isNull,
        );

        controller.insurance.selectNature(_nature);
        controller.insurance.valueController.text = '0';
        await tester.pump();
        expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile))
              .onChanged,
          isNull,
        );
        controller.insurance.valueController.text = '100';
        await tester.pump(const Duration(milliseconds: 450));
        expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile))
              .onChanged,
          isNotNull,
        );
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged!(true);
        await tester.pump();
        expect(controller.grandTotal, 250);
        expect(controller.bookingPayload('wallet')['parcels_count'], 1);
        expect(controller.bookingPayload('wallet')['kg_booked'], 20.5);

        controller.insurance.valueController.clear();
        await tester.pump();
        expect(controller.insuranceOptIn.value, isFalse);
        expect(controller.grandTotal, 246);
        expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile))
              .onChanged,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'traveller air booking recalculates comma weights and rejects missing insurance quotes',
    (tester) async {
      final offer = DiaspoOffer.fromJson({
        'id': 4,
        'user_id': 1,
        'price_per_kg': 12,
        'currency': 'EUR',
        'remaining_kg': 100,
        'available_kg': 100,
        'departure_date': '2026-11-20',
        'departure_datetime': '2026-11-20T10:00:00Z',
        'arrival_datetime': '2026-11-21T10:00:00Z',
        'status': 'published',
        'created_at': '2026-10-01',
        'updated_at': '2026-10-01',
      });
      await tester.pumpWidget(GetMaterialApp(home: const Scaffold()));
      Get.to(
        () => const DiaspoBookingView(),
        arguments: {'offer': offer},
        binding: BindingsBuilder(() {
          Get.put<DiaspoBookingController>(DiaspoBookingController());
        }),
      );
      await tester.pumpAndSettle();
      final controller = Get.find<DiaspoBookingController>();
      controller.kgController.text = '2,5';
      await tester.pump();
      expect(controller.kgBooked.value, 2.5);
      expect(controller.totalPrice.value, 30);
      controller.kgController.clear();
      await tester.pump();
      expect(controller.totalPrice.value, 0);

      controller.kgController.text = '2,5';
      service.failQuote = true;
      controller.insurance.selectNature(_nature);
      controller.insurance.valueController.text = '100';
      await tester.pump(const Duration(milliseconds: 450));
      await controller.submitBooking();
      await tester.pump();
      expect(
        find.text('parcel_insurance.quote_unavailable'.tr),
        findsOneWidget,
      );
      expect(controller.insurance.quoteAvailable.value, isFalse);
      expect(controller.isSubmitting.value, isFalse);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'shared declaration rejects invalid values and clears stale insurance prices',
    (tester) async {
      final form = ParcelInsuranceForm(currency: () => 'EUR');
      form.selectNature(_nature);
      for (final value in ['', '0', '-10', 'NaN', 'Infinity', '100000001']) {
        form.valueController.text = value;
        await tester.pump(const Duration(milliseconds: 450));
        expect(form.isComplete, isFalse, reason: value);
        expect(form.quoteAvailable.value, isFalse);
      }
      expect(service.quoteCalls, 0);
      form.valueController.text = '100,50';
      await tester.pump(const Duration(milliseconds: 450));
      expect(form.isComplete, isTrue);
      expect(form.insuranceAmount.value, closeTo(4.02, 0.00001));
      expect(form.quoteAvailable.value, isTrue);
      form.valueController.clear();
      expect(form.insuranceAmount.value, 0);
      expect(form.quoteAvailable.value, isFalse);
      form.dispose();
    },
  );
}
