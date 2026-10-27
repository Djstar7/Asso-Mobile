import 'package:asso/app/data/models/maritime.dart';
import 'package:asso/app/data/models/parcel_nature.dart';
import 'package:asso/app/data/providers/diaspo_service.dart';
import 'package:asso/app/data/providers/maritime_service.dart';
import 'package:asso/app/modules/maritime/controllers/maritime_booking_controller.dart';
import 'package:asso/app/modules/maritime/views/maritime_booking_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _QuietDiaspo extends DiaspoService {
  @override
  getParcelNatures() async => throw Exception('No catalogue in this test');
}

void main() {
  tearDown(Get.reset);

  testWidgets('sea booking shows the public route and sends only CBM', (
    tester,
  ) async {
    Get.testMode = true;
    Get.put<MaritimeService>(MaritimeService());
    Get.put<DiaspoService>(_QuietDiaspo());
    final departure = MaritimeDeparture.fromJson({
      'id': 1,
      'transport_mode': 'sea',
      'remaining_kg': 2500,
      'price_per_kg': 0.9,
      'price_per_cbm': 900,
      'kg_per_cbm': 1000,
      'currency': 'EUR',
      'cargo_options': [
        {
          'cargo_category': 'general',
          'price_per_unit': 900,
          'unit': 'CBM',
          'currency': 'EUR',
        },
        {
          'cargo_category': 'sensitive',
          'price_per_unit': 1200,
          'unit': 'CBM',
          'currency': 'EUR',
        },
      ],
      'departure_date': '2026-12-01',
      'origin_hub': {
        'id': 1,
        'city': 'Guangzhou',
        'country': 'CN',
        'country_name': 'Chine',
        'address': 'PRIVATE',
      },
      'destination_hub': {
        'id': 2,
        'city': 'Douala',
        'country': 'CM',
        'country_name': 'Cameroun',
        'address': 'PRIVATE',
      },
    });
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: TextButton(
            onPressed: () =>
                Get.toNamed('/booking', arguments: {'departure': departure}),
            child: const Text('Open'),
          ),
        ),
        getPages: [
          GetPage(
            name: '/booking',
            page: () => const MaritimeBookingView(),
            binding: BindingsBuilder(() {
              Get.put(MaritimeBookingController());
            }),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Guangzhou, Chine'), findsOneWidget);
    expect(find.text('Douala, Cameroun'), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.text('Volume à envoyer (CBM)'), findsOneWidget);
    final controller = Get.find<MaritimeBookingController>();
    expect(controller.kgController.text, '1');
    expect(controller.quantity, 1);
    expect(controller.freight, 900);
    expect(find.text('2,5 CBM disponibles'), findsOneWidget);
    expect(find.text('1.000'), findsNothing);
    controller.insurance.selectedNature.value = ParcelNature(
      id: 1,
      name: 'Vêtements',
      insuranceRate: 1,
      minInsuranceAmount: 0,
    );
    expect(controller.bookingPayload('wallet')['volume_cbm'], 1);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colis sensible').last);
    await tester.pumpAndSettle();
    expect(controller.cargoCategory.value, 'sensitive');
    expect(controller.freight, 1200);
    expect(controller.bookingPayload('wallet')['cargo_category'], 'sensitive');
    expect(controller.bookingPayload('wallet')['expected_unit_price'], 1200);
    controller.selectCargoCategory('general');
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Volume à envoyer (CBM)'),
      '0,123',
    );
    await tester.pump();
    expect(controller.quantity, closeTo(0.123, 0.000001));
    expect(controller.freight, 110.7);
    controller.insurance.selectedNature.value = ParcelNature(
      id: 1,
      name: 'Vêtements',
      insuranceRate: 1,
      minInsuranceAmount: 0,
    );
    final payload = controller.bookingPayload('wallet');
    expect(payload['volume_cbm'], closeTo(0.123, 0.000001));
    expect(payload.containsKey('kg_booked'), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
