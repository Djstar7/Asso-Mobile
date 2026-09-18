import 'package:asso/app/data/models/diaspo_offer.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _offerJson(Map<String, dynamic> overrides) => {
      'id': 1,
      'user_id': 2,
      'status': 'approved',
      'verification_status': 'pending',
      'departure_country': 'FR',
      'departure_city': 'Paris',
      'departure_datetime': '2026-10-01T10:00:00Z',
      'arrival_country': 'CM',
      'arrival_city': 'Douala',
      'arrival_datetime': '2026-10-02T10:00:00Z',
      'price_per_kg': 10.5,
      'available_kg': 20,
      'remaining_kg': 20,
      'currency': 'EUR',
      'created_at': '2026-09-18T10:00:00Z',
      'updated_at': '2026-09-18T10:00:00Z',
      ...overrides,
    };

void main() {
  test('offre « Profil non vérifié » : publiée, non réservable, avec échéance', () {
    final offer = DiaspoOffer.fromJson(_offerJson({
      'is_published': true,
      'is_available': false,
      'profile_verified': false,
      'verification_deadline_at': '2026-09-25T12:00:00Z',
    }));

    expect(offer.profileVerified, isFalse);
    expect(offer.isPublished, isTrue);
    expect(offer.isAvailable, isFalse);
    expect(offer.formattedVerificationDeadline, '25/09/2026');
  });

  test('sans drapeau profile_verified, on retombe sur verification_status', () {
    final offer = DiaspoOffer.fromJson(_offerJson({'verification_status': 'verified'}));

    expect(offer.profileVerified, isTrue);
    expect(offer.formattedVerificationDeadline, isNull);
  });
}
