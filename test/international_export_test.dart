import 'package:asso/app/core/widgets/delivery_details_widgets.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:asso/app/core/utils/location_label.dart';
import 'package:asso/app/data/models/delivery_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'export breakdown shows collection price, distance and international price',
    (tester) async {
      final breakdown = DeliveryBreakdown.fromMap({
        'legs': [
          {'label': 'Collecte Solex', 'price': 2750, 'distance_km': 8.25},
          {'label': 'FedEx international', 'price': 36000},
        ],
        'total': 38750,
      });
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: DeliveryBreakdownView(
              breakdown: breakdown,
              showLegPrices: true,
              formatPrice: (v) => '${v.toInt()} FCFA',
            ),
          ),
        ),
      );
      expect(find.text('Collecte Solex'), findsOneWidget);
      expect(find.text('2750 FCFA'), findsOneWidget);
      expect(find.text('FedEx international'), findsOneWidget);
      expect(find.text('36000 FCFA'), findsOneWidget);
      expect(find.textContaining('8.25 km'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('weight formatting retains grams and shows kilogram quantities', () {
    expect(formatKg(1), '1 kg');
    expect(formatKg(2), '2 kg');
    expect(formatKg(0.001), '0,001 kg');
    expect(formatKg(0.002), '0,002 kg');
    expect(formatKg(1.25), '1,25 kg');
    expect(formatKg(1000), '1000 kg');
  });

  test('OSM address preserves international country code and postal code', () {
    for (final address in [
      {
        'city': 'Paris',
        'country': 'France',
        'country_code': 'fr',
        'postcode': '75001',
      },
      {
        'city': 'Berlin',
        'country': 'Deutschland',
        'country_code': 'de',
        'postcode': '10115',
      },
      {
        'city': 'New York',
        'country': 'United States',
        'country_code': 'us',
        'postcode': '10001',
      },
    ]) {
      final location = LocationLabel.fromNominatim(
        {'address': address},
        latitude: 48.85,
        longitude: 2.3,
      );
      expect(location.city, address['city']);
      expect(location.countryCode, address['country_code']!.toUpperCase());
      expect(location.postalCode, address['postcode']);
    }
  });

  test('Solex departure agency is distinct from recipient pickup agency', () {
    final delivery = DeliveryInfo.fromMap({
      'mode': 'carrier',
      'international_export': true,
      'company_name': 'DHL Express',
      'delivery_option': 'home_delivery',
      'solex_agency': {
        'name': 'Solex Douala',
        'city': 'Douala',
        'address': 'Akwa',
        'phone': '237670000000',
      },
      'timeline': [
        {'step': 'export_at_solex', 'label': 'Reçu à Solex'},
      ],
    })!;
    expect(delivery.isInternationalExport, isTrue);
    expect(delivery.solexAgency?.city, 'Douala');
    expect(delivery.pickupAgency, isNull);
    expect(delivery.timeline.single.step, 'export_at_solex');
  });
}
