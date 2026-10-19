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
}
