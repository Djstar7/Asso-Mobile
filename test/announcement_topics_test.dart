import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:asso/app/core/services/locale_service.dart';
import 'package:asso/app/data/services/firebase_messaging_service.dart';

void main() {
  tearDown(Get.reset);

  test('un topic d’annonces par langue, l’ancien all_users à part', () {
    expect(FirebaseMessagingService.announcementsTopicFor('fr'), 'all_users_fr');
    expect(FirebaseMessagingService.announcementsTopicFor('en'), 'all_users_en');
    expect(FirebaseMessagingService.legacyAnnouncementsTopic, 'all_users');
  });

  test('changer de langue change le topic et la marque d’abonnement', () {
    // Sans service de langue (démarrage, tests) : le français.
    expect(FirebaseMessagingService.announcementsTopic, 'all_users_fr');
    final french = FirebaseMessagingService.topicMarker('tok');

    final locale = Get.put(LocaleService());
    locale.language.value = 'en';

    expect(FirebaseMessagingService.announcementsTopic, 'all_users_en');
    expect(FirebaseMessagingService.topicMarker('tok'), isNot(french));
    // Une installation qui n'a retenu que le token (ancien all_users) se
    // réabonne aussi.
    expect(FirebaseMessagingService.topicMarker('tok'), isNot('tok'));
  });
}
