import 'package:asso/app/data/models/maritime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> payload({required bool paid}) => {
    'id': 42,
    'partner': {
      'name': 'Identité privée',
      'logo': 'https://private.test/logo.png',
    },
    'transport_mode': 'air',
    'cargo_category': 'general',
    'transit_days_min': 10,
    'transit_days_max': 14,
    'frequency_days': null,
    'meeting_details_available': paid,
    'price_per_kg': 20000,
    'currency': 'XAF',
    'origin_hub': {
      'id': 1,
      'name': 'Dépôt privé',
      'country': 'CN',
      'city': 'Guangzhou',
      'address': 'Rue privée',
      'phone': '+861234567890',
    },
    'destination_hub': {
      'id': 2,
      'name': 'Entrepôt privé',
      'country': 'CM',
      'city': 'Douala',
      'address': 'Rue privée arrivée',
    },
    'notes': 'Informations réservées au client payé',
  };

  test(
    'partner stays anonymous and precise meeting locations are hidden before payment',
    () {
      final departure = MaritimeDeparture.fromJson(payload(paid: false));
      expect(departure.partnerName, 'Diaspo Exchange');
      expect(departure.partnerLogo, isNull);
      expect(departure.originHub!.city, 'Guangzhou');
      expect(departure.originHub!.name, isEmpty);
      expect(departure.originHub!.address, isEmpty);
      expect(departure.originHub!.phone, isNull);
      expect(departure.notes, isNull);
      expect(departure.commercialSummary, contains('Aérien'));
      expect(departure.commercialSummary, contains('10–14 jours'));
      expect(departure.commercialSummary, contains('Par occasion'));
      expect(departure.pricePerKg, 20000);
    },
  );

  test(
    'paid response reveals the meeting locations while keeping the partner anonymous',
    () {
      final departure = MaritimeDeparture.fromJson(payload(paid: true));
      expect(departure.partnerName, 'Diaspo Exchange');
      expect(
        departure.originHub!.fullAddress,
        'Dépôt privé, Rue privée, Guangzhou',
      );
      expect(departure.originHub!.phone, '+861234567890');
      expect(departure.destinationHub!.address, 'Rue privée arrivée');
    },
  );

  test('Paris frequency remains distinct from shipping lead time', () {
    final departure = MaritimeDeparture.fromJson({
      ...payload(paid: false),
      'frequency_days': 14,
    });
    expect(departure.commercialSummary, contains('Tous les 14 jours'));
    expect(departure.commercialSummary, contains('10–14 jours'));
  });
}
