import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/core/utils/session_reset.dart';
import 'package:asso/app/data/models/user_model.dart';
import 'package:asso/app/data/providers/cache_manager.dart';
import 'package:asso/app/data/providers/storage_service.dart';

/// Se connecter depuis le mode invité doit repartir d'une session vierge.
///
/// Le bug corrigé : l'application continuait d'afficher les données invité
/// après un login, parce que les controllers `permanent: true` survivent à la
/// navigation et que le mode invité restait inscrit en storage.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
    Get.testMode = true;
  });

  tearDown(Get.reset);

  UserModel buildUser() => UserModel(
        id: 7,
        firstName: 'Awa',
        lastName: 'Diop',
        name: 'Awa Diop',
        email: 'awa@example.com',
        phone: '+221770000000',
        role: 'client',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
      );

  test('enregistrer la session sort du mode invité', () {
    StorageService.enableGuestMode();
    expect(StorageService.isGuestMode, isTrue);

    StorageService.saveAuthSession('token-abc', buildUser());

    expect(StorageService.isGuestMode, isFalse);
    expect(StorageService.isAuthenticated, isTrue);
    expect(StorageService.getUser()?.email, 'awa@example.com');
  });

  test('onLogin purge le cache hérité de la visite anonyme', () {
    final cache = CacheManager();
    cache.set('home_feed', {'source': 'invité'}, persist: true);
    expect(cache.get<Map>('home_feed'), isNotNull);

    SessionReset.onLogin();

    expect(
      cache.get<Map>('home_feed'),
      isNull,
      reason: 'une réponse mise en cache sans token ne doit pas survivre',
    );
  });

  test('un controller permanent survit à la navigation seule', () {
    // C'est l'origine du bug : `permanent: true` (HomeBinding) fait survivre
    // le controller à `Get.back()` comme à `Get.offAllNamed()`, donc son
    // `onInit` ne rejoue jamais et les données invité restent affichées.
    // Seule une suppression explicite le recrée sous la bonne identité.
    Get.put<_FakeGuestController>(_FakeGuestController(), permanent: true);

    Get.delete<_FakeGuestController>();
    expect(
      Get.isRegistered<_FakeGuestController>(),
      isTrue,
      reason: 'un controller permanent ignore une suppression non forcée',
    );

    Get.delete<_FakeGuestController>(force: true);
    expect(
      Get.isRegistered<_FakeGuestController>(),
      isFalse,
      reason: 'SessionReset utilise force: true pour vraiment le supprimer',
    );
  });

  test('clearControllers ne lève pas quand rien n\'est enregistré', () {
    expect(SessionReset.clearControllers, returnsNormally);
  });

  test('onLogin reste sûr quand aucun controller n\'est enregistré', () {
    expect(SessionReset.onLogin, returnsNormally);
  });
}

class _FakeGuestController extends GetxController {}
