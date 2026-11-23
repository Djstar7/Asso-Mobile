import 'package:asso/app/core/widgets/delivery_details_widgets.dart';
import 'package:asso/app/data/models/delivery_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

Widget _wrap(DeliveryInfo delivery) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OrderDeliveryDetails(delivery: delivery, formatPrice: (v) => '$v'),
        ),
      ),
    );

void main() {
  testWidgets('a parcel on its way shows the expected date and the tracking number', (tester) async {
    final delivery = DeliveryInfo.fromMap({
      'mode': 'local',
      'international_shipment': {
        'stage': 'in_transit',
        'stage_label': 'En route vers l’entrepôt ASSO de Douala',
        'expected_hub_date': '2026-12-16',
        'is_late': false,
        'carrier_name': 'YunExpress',
        'tracking_number': 'YT777',
      },
    })!;

    await tester.pumpWidget(_wrap(delivery));

    final shipment = delivery.internationalShipment!;
    expect(shipment.expectedHubDate, DateTime(2026, 12, 16));
    expect(find.text('En route vers l’entrepôt ASSO de Douala'), findsOneWidget);
    expect(find.text('core.delivery.international_title'.tr), findsOneWidget);
    expect(find.text('core.delivery.international_expected'.trParams({
          'date': DateFormat('d MMM', Get.locale?.toLanguageTag()).format(DateTime(2026, 12, 16)),
        })), findsOneWidget);
    expect(find.text('YT777'), findsOneWidget);
    expect(find.text('core.delivery.international_late'.tr), findsNothing);
  });

  testWidgets('a late parcel is flagged and an arrived one hides its tracking', (tester) async {
    final late = DeliveryInfo.fromMap({
      'international_shipment': {'stage': 'preparing', 'stage_label': 'En préparation', 'expected_hub_date': '2026-11-01', 'is_late': true},
    })!;
    await tester.pumpWidget(_wrap(late));
    expect(find.text('core.delivery.international_late'.tr), findsOneWidget);

    final arrived = DeliveryInfo.fromMap({
      'international_shipment': {
        'stage': 'arrived', 'stage_label': 'Arrivé', 'arrived_at': '2026-12-10T09:00:00Z',
        'tracking_number': 'YT777',
      },
    })!;
    await tester.pumpWidget(_wrap(arrived));
    expect(find.text('YT777'), findsNothing);
    expect(find.text('core.delivery.international_next'.tr), findsNothing);
  });

  test('orders without international parcel have no block', () {
    expect(DeliveryInfo.fromMap({'mode': 'local'})!.internationalShipment, isNull);
    expect(InternationalShipment.fromMap({'stage': null}), isNull);
  });
}
