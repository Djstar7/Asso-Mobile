import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:asso/app/core/i18n/app_translations.dart';

/// Charge les textes de `assets/i18n/` pour tous les tests, en français :
/// sans cela, `'cle'.tr` renverrait la clé elle-même dans les vues testées.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final translations = AppTranslations.fromJson({
    for (final entry in AppTranslations.files.entries)
      entry.key: jsonDecode(File(entry.value).readAsStringSync())
          as Map<String, dynamic>,
  });
  Get.addTranslations(translations.keys);
  Get.locale = const Locale('fr', 'FR');
  Get.fallbackLocale = const Locale('fr', 'FR');
  await testMain();
}
