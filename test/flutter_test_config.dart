import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:asso/app/core/i18n/app_translations.dart';

/// Charge les textes de `assets/i18n/` pour tous les tests, en français :
/// sans cela, `'cle'.tr` renverrait la clé elle-même dans les vues testées.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final translations = AppTranslations.fromJson({
    for (final entry in AppTranslations.files.entries)
      entry.key: jsonDecode(File(entry.value).readAsStringSync())
          as Map<String, dynamic>,
  });
  void useFrench() {
    Get.addTranslations(translations.keys);
    Get.locale = const Locale('fr', 'FR');
    Get.fallbackLocale = const Locale('fr', 'FR');
  }

  useFrench();
  // Beaucoup de tests appellent Get.reset(), qui efface les traductions :
  // on les recharge avant chaque test.
  setUp(useFrench);
  // Dates, nombres et durées relatives suivent la locale courante, comme
  // dans l'application.
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR', null);
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setDefaultLocale('fr');
  await testMain();
}
