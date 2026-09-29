import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/core/i18n/app_translations.dart';

Map<String, String> _read(String path) => AppTranslations.flatten(
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
    );

Set<String> _params(String value) =>
    RegExp(r'@(\w+)').allMatches(value).map((m) => m.group(1)!).toSet();

void main() {
  final fr = _read('assets/i18n/fr.json');
  final en = _read('assets/i18n/en.json');

  test('le français et l\'anglais ont les mêmes clés', () {
    expect(en.keys.toSet().difference(fr.keys.toSet()), isEmpty,
        reason: 'clés absentes de fr.json');
    expect(fr.keys.toSet().difference(en.keys.toSet()), isEmpty,
        reason: 'clés absentes de en.json');
  });

  test('aucun texte vide', () {
    for (final map in [fr, en]) {
      final empty = map.entries.where((e) => e.value.trim().isEmpty);
      expect(empty.map((e) => e.key), isEmpty);
    }
  });

  test('les paramètres @x sont les mêmes dans les deux langues', () {
    final mismatched = fr.keys.where(
      (key) => !_setEquals(_params(fr[key]!), _params(en[key] ?? '')),
    );
    expect(mismatched, isEmpty);
  });

  test('aplatit les clés imbriquées en notation pointée', () {
    expect(
      AppTranslations.flatten({
        'a': {'b': 'x', 'c': {'d': 'y'}},
      }),
      {'a.b': 'x', 'a.c.d': 'y'},
    );
  });
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
