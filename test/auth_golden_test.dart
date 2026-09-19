@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/modules/login/controllers/login_controller.dart';
import 'package:asso/app/modules/login/views/login_view.dart';
import 'package:asso/app/modules/preferences/controllers/preferences_controller.dart';
import 'package:asso/app/modules/preferences/views/preferences_view.dart';
import 'package:asso/app/modules/welcomer/controllers/welcomer_controller.dart';
import 'package:asso/app/modules/welcomer/views/welcomer_view.dart';

/// Rend les deux écrans d'authentification en image, pour les relire.
///
/// Lancé avec `flutter test --update-goldens test/auth_golden_test.dart`,
/// il écrit les PNG sous test/goldens/.
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

  tearDown(Get.reset);

  Future<void> render(WidgetTester tester, Widget view, String name) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GetMaterialApp(home: view));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('connexion', (tester) async {
    Get.put(LoginController());
    await render(tester, const LoginView(), 'login');
  });

  testWidgets('inscription', (tester) async {
    Get.put(WelcomerController());
    await render(tester, const WelcomerView(), 'register');
  });

  testWidgets('préférences, rien de sélectionné', (tester) async {
    Get.put(PreferencesController());
    await render(tester, const PreferencesView(), 'preferences');
  });

  testWidgets('préférences, avec sélection', (tester) async {
    final c = Get.put(PreferencesController());
    c.selectedSubcategories.addAll(['fashion_women', 'fashion_shoes', 'food_fresh']);
    await render(tester, const PreferencesView(), 'preferences_selected');
  });
}
