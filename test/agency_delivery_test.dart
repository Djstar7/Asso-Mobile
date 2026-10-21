import 'package:asso/app/core/widgets/delivery_details_widgets.dart';
import 'package:asso/app/data/models/delivery_info.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows the pickup agency and instructions when the parcel is ready',
    (tester) async {
      final delivery = DeliveryInfo.fromMap({
        'mode': 'carrier',
        'delivery_option': 'agency_pickup',
        'tracking_status': 'ready_for_pickup',
        'can_confirm_reception': false,
        'pickup_agency': {
          'name': 'SOLEX Mvan',
          'address': 'Gare Mvan',
          'city': 'Yaoundé',
          'phone': '237670000001',
        },
      })!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderDeliveryDetails(
                delivery: delivery,
                formatPrice: (v) => '$v',
              ),
            ),
          ),
        ),
      );
      expect(find.text('SOLEX Mvan'), findsOneWidget);
      expect(find.text('Gare Mvan, Yaoundé'), findsOneWidget);
      expect(find.text('237670000001'), findsOneWidget);
      expect(
        find.text('core.delivery.agency_pickup_instructions'.tr),
        findsOneWidget,
      );
      expect(delivery.canConfirmReception, isFalse);
      expect(DeliveryInfo.trackingStepsFor(delivery), isEmpty);
    },
  );

  test(
    'customer acknowledgement comes from the API after the recorded handover',
    () {
      final delivery = DeliveryInfo.fromMap({
        'mode': 'carrier',
        'can_confirm_reception': true,
        'agency_collected_at': '2026-10-21T10:00:00Z',
        'reception_confirmed_at': null,
      })!;
      expect(delivery.canConfirmReception, isTrue);
      expect(delivery.agencyCollectedAt, '2026-10-21T10:00:00Z');
      expect(delivery.receptionConfirmedAt, isNull);
      expect(delivery.pickupAgency, isNull);
      expect(DeliveryInfo.fromMap(null), isNull);
    },
  );
}
