import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/core/widgets/app_ui.dart';
import 'package:asso/app/data/providers/guest_access.dart';
import 'package:asso/app/data/providers/storage_service.dart';
import 'package:asso/app/modules/preferences/controllers/preferences_controller.dart';
import 'package:asso/app/modules/preferences/views/preferences_view.dart';
import 'package:asso/app/routes/app_pages.dart';

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
    // Get.reset() du teardown remet ce drapeau à false : il doit être posé
    // avant chaque test, sans quoi la navigation sans contexte lève.
    Get.testMode = true;
  });

  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: PreferencesView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Parcours invité', () {
    test('sans pays, le pays passe avant les centres d\'intérêt', () {
      expect(GuestAccess.nextRoute(), Routes.COUNTRY_SELECTION);
    });

    test('pays choisi, les centres d\'intérêt sont proposés', () {
      StorageService.saveCountry('Cameroun');
      expect(GuestAccess.nextRoute(), Routes.PREFERENCES);
    });

    test('une fois proposés, on va droit à l\'accueil', () {
      StorageService.saveCountry('Cameroun');
      StorageService.setPreferencesPrompted();
      expect(GuestAccess.nextRoute(), Routes.HOME);
    });

    test('le pays prime, même si les centres ont déjà été proposés', () {
      // Cas observé sur appareil : l'indicateur « déjà proposé » était posé
      // alors qu'aucun pays n'était enregistré. La devise passe d'abord.
      StorageService.setPreferencesPrompted();
      expect(GuestAccess.nextRoute(), Routes.COUNTRY_SELECTION);
    });
  });

  group('Contrôleur', () {
    test('« Passer » vaut réponse : l\'écran ne revient pas', () {
      final c = PreferencesController();
      Get.put(c);

      expect(StorageService.wasPreferencesPrompted, isFalse);
      c.skipPreferences();
      expect(StorageService.wasPreferencesPrompted, isTrue);
    });

    test('un invité retrouve sa sélection enregistrée', () {
      StorageService.savePreferences({
        'categories': ['fashion_women', 'food_fresh'],
      });

      final c = Get.put(PreferencesController());

      expect(
        c.selectedSubcategories,
        containsAll(['fashion_women', 'food_fresh']),
      );
    });

    test('le compte par catégorie suit la sélection', () {
      final c = Get.put(PreferencesController());

      expect(c.getCategorySelectionCount('fashion'), 0);
      expect(c.isCategorySelected('fashion'), isFalse);

      c.toggleSubcategory('fashion_women');
      c.toggleSubcategory('fashion_shoes');

      expect(c.getCategorySelectionCount('fashion'), 2);
      expect(c.isCategorySelected('fashion'), isTrue);
      expect(c.getCategorySelectionCount('food'), 0);
    });

    test('déplier une catégorie ne la sélectionne pas', () {
      final c = Get.put(PreferencesController());

      c.toggleCategory('fashion');

      expect(c.expandedCategories, contains('fashion'));
      expect(c.selectedSubcategories, isEmpty);
    });
  });

  group('Vue', () {
    testWidgets('montre les sous-catégories sans avoir à déplier', (
      tester,
    ) async {
      Get.put(PreferencesController());
      await pump(tester);

      // C'est le reproche fait à l'écran d'origine : tout était caché
      // derrière des accordéons fermés.
      expect(find.text('Homme'), findsOneWidget);
      expect(find.text('Femme'), findsOneWidget);
    });

    testWidgets('« Continuer » est inactif tant que rien n\'est choisi', (
      tester,
    ) async {
      Get.put(PreferencesController());
      await pump(tester);

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Continuer'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('« Continuer » s\'active dès la première sélection', (
      tester,
    ) async {
      final c = Get.put(PreferencesController());
      await pump(tester);

      c.toggleSubcategory('fashion_women');
      await tester.pump();

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Continuer'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('propose de passer', (tester) async {
      Get.put(PreferencesController());
      await pump(tester);

      expect(find.text('Passer'), findsOneWidget);
    });

    testWidgets('ne déborde pas à la mise en page', (tester) async {
      Get.put(PreferencesController());
      await pump(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
