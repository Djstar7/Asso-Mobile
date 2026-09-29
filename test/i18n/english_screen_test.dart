import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/modules/login/controllers/login_controller.dart';
import 'package:asso/app/modules/login/views/login_view.dart';

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    await GetStorage.init();
  });

  tearDown(Get.reset);

  testWidgets("l'écran de connexion s'affiche en anglais", (tester) async {
    final en = jsonDecode(File('assets/i18n/en.json').readAsStringSync());
    Get.put(LoginController());
    await tester.pumpWidget(
      const GetMaterialApp(locale: Locale('en', 'US'), home: LoginView()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(en['login']['title'] as String), findsOneWidget);
    expect(find.text('Bon retour'), findsNothing);
  });
}
