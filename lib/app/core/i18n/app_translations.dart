import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';

/// Textes de l'application, lus depuis `assets/i18n/<langue>.json`.
///
/// Chaque fichier est un JSON imbriqué par module :
/// `{ "auth": { "login": { "title": "Connexion" } } }`. Les clés sont
/// aplaties en notation pointée et appelées dans les pages par
/// `'auth.login.title'.tr` (ou `.trParams({'name': …})` pour `@name`).
///
/// Ajouter une langue revient à déposer un fichier et à l'inscrire dans
/// [files].
class AppTranslations extends Translations {
  AppTranslations._(this._keys);

  /// Fichier JSON de chaque locale prise en charge.
  static const Map<String, String> files = {
    'fr_FR': 'assets/i18n/fr.json',
    'en_US': 'assets/i18n/en.json',
  };

  final Map<String, Map<String, String>> _keys;

  @override
  Map<String, Map<String, String>> get keys => _keys;

  /// Charge tous les fichiers de langue ; à appeler avant `runApp`.
  static Future<AppTranslations> load() async {
    final keys = <String, Map<String, String>>{};
    for (final entry in files.entries) {
      final raw = await rootBundle.loadString(entry.value);
      keys[entry.key] = flatten(jsonDecode(raw) as Map<String, dynamic>);
    }
    return AppTranslations._(keys);
  }

  /// Construit les traductions à partir de JSON déjà décodés (tests).
  static AppTranslations fromJson(Map<String, Map<String, dynamic>> json) {
    return AppTranslations._({
      for (final entry in json.entries) entry.key: flatten(entry.value),
    });
  }

  /// `{"a": {"b": "x"}}` → `{"a.b": "x"}`.
  static Map<String, String> flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final result = <String, String>{};
    json.forEach((key, value) {
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        result.addAll(flatten(value, path));
      } else {
        result[path] = value.toString();
      }
    });
    return result;
  }
}
