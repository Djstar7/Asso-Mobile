import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/data/models/real_estate_models.dart';

void main() {
  final baseListing = <String, dynamic>{
    'id': 17,
    'reference': 'IMMO-17',
    'type': 'rent',
    'title': 'Appartement',
    'city': 'Douala',
    'price': 100000,
  };

  test('parses the API ownership flag for the current viewer', () {
    final listing = RealEstateListing.fromJson({
      ...baseListing,
      'is_owner': true,
    });

    expect(listing.isOwnListing, isTrue);
  });

  test('treats missing ownership flag as a non-owned listing', () {
    final listing = RealEstateListing.fromJson(baseListing);

    expect(listing.isOwnListing, isFalse);
  });

  test('uses the listing video and falls back to videos in the media list', () {
    final directVideo = RealEstateListing.fromJson({
      ...baseListing,
      'video': {
        'id': 1,
        'type': 'video',
        'url': 'https://example.com/direct.mp4',
      },
      'media': [
        {'id': 2, 'type': 'video', 'url': 'https://example.com/media.mp4'},
      ],
    });
    final mediaVideo = RealEstateListing.fromJson({
      ...baseListing,
      'media': [
        {'id': 3, 'type': 'image', 'url': 'https://example.com/photo.jpg'},
        {'id': 4, 'type': 'video', 'url': 'https://example.com/tour.mp4'},
      ],
    });

    expect(
      directVideo.presentationVideo?.url,
      'https://example.com/direct.mp4',
    );
    expect(mediaVideo.presentationVideo?.url, 'https://example.com/tour.mp4');
  });

  test('exposes reservation contact only after payment', () {
    final pending = RealEstateReservation.fromJson({
      'id': 22,
      'reference': 'RES-22',
      'status': 'pending_payment',
      'contact': {'name': 'Bailleur', 'phone': '+237 600 000 000'},
    });
    final paid = RealEstateReservation.fromJson({
      'id': 23,
      'reference': 'RES-23',
      'status': 'paid',
      'contact': {'name': 'Bailleur', 'phone': '+237 600 000 000'},
    });

    expect(pending.isPaid, isFalse);
    expect(pending.hasVisibleContact, isFalse);
    expect(pending.contact?['phone'], '+237 600 000 000');
    expect(paid.isPaid, isTrue);
    expect(paid.hasVisibleContact, isTrue);
    expect(paid.contact?['phone'], '+237 600 000 000');
  });
  test('preserves the API fee amounts and recipients without recalculation', () {
    final quote = RealEstateQuote.fromJson({
      'unit_price': 110,
      'base_amount': 110,
      'net_amount': 100,
      'platform_amount': 10,
      'commission': 5,
      'total': 115,
      'net_payee_kind': 'landlord',
      'commission_cabinet': {'id': 1, 'name': 'Cabinet Gwoda et Associés'},
    });
    final reservation = RealEstateReservation.fromJson({
      'id': 1,
      'reference': 'IMMO-1',
      'net_amount': 100,
      'platform_amount': 10,
      'commission_amount': 5,
      'partner_commission_amount': 5,
      'total_amount': 115,
      'net_payee_kind': 'cabinet',
      'commission_cabinet': {'id': 1, 'name': 'Cabinet Gwoda et Associés'},
    });
    expect(quote.netAmount, 100);
    expect(quote.platformAmount, 10);
    expect(quote.commission, 5);
    expect(quote.total, 115);
    expect(quote.netPayeeKind, 'landlord');
    expect(quote.commissionCabinet?.name, 'Cabinet Gwoda et Associés');
    expect(reservation.netAmount, 100);
    expect(reservation.platformAmount, 10);
    expect(reservation.partnerCommissionAmount, 5);
    expect(reservation.netPayeeKind, 'cabinet');
    expect(reservation.commissionCabinet?.id, 1);
  });

  test('historical reservations do not invent a partner commission', () {
    final reservation = RealEstateReservation.fromJson({
      'id': 1,
      'commission_amount': 20,
      'total_amount': 130,
    });
    expect(reservation.partnerCommissionAmount, isNull);
    expect(reservation.commissionCabinet, isNull);
    expect(reservation.netPayeeKind, isNull);
    expect(reservation.commissionAmount, 20);
    expect(reservation.totalAmount, 130);
  });

}
