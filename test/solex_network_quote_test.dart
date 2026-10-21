import 'package:asso/app/data/models/delivery_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  test('agency and home network quotes keep distinct selections and full prices', () {
    final base = <String, dynamic>{
      'company_id': 4, 'company_name': 'SOLEX', 'grid_id': 8, 'route_id': 10,
      'pricing_type': 'territorial_network',
      'pickup_agency': {'name': 'SOLEX Mvan', 'address': 'Gare Mvan', 'city': 'Yaoundé', 'phone': '677000000'},
    };
    final agency = DeliveryPartnerQuote({
      ...base, 'delivery_option': 'agency_pickup', 'service_mode': 'agency_to_agency',
      'service_mode_label': 'Collecte en boutique et retrait en agence',
      'delivery_price': 5170, 'vehicle': 'agency_pickup:moto',
      'breakdown': {
        'carrier_price_ht': 4000, 'asso_commission': 400, 'vat_amount': 770, 'total': 5170,
        'legs': [{'label': 'Collecte en boutique', 'price': 1000}, {'label': 'Acheminement', 'price': 3000}],
      },
    });
    final home = DeliveryPartnerQuote({
      ...base, 'delivery_option': 'home_delivery', 'service_mode': 'door_to_door',
      'service_mode_label': 'Collecte en boutique et livraison à domicile',
      'delivery_price': 7755, 'vehicle': 'home_delivery:moto',
    });
    expect(agency.isTerritorialNetwork, isTrue);
    expect(agency.isAgencyPickup, isTrue);
    expect(home.isAgencyPickup, isFalse);
    expect(agency.key, isNot(home.key));
    expect(agency.price, 5170);
    expect(home.price, 7755);
    expect(agency.pickupAgency?.address, 'Gare Mvan');
    expect(agency.serviceModeLabel, contains('Collecte'));
    expect(agency.breakdown?.legs.length, 2);
    expect(home.pickupNotice, isNull);
  });
}
