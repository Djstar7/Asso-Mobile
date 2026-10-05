import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:asso/app/core/widgets/english_version_section.dart';

void main() {
  group('EnglishVersionSection.fields', () {
    test('en création, seuls les champs remplis partent', () {
      final fields = EnglishVersionSection.fields(
        TextEditingController(text: ' Leather bag '),
        TextEditingController(),
      );

      expect(fields, {'translations[en][name]': 'Leather bag'});
    });

    test('en modification, un champ vidé part vide pour effacer la traduction', () {
      final fields = EnglishVersionSection.fields(
        TextEditingController(),
        TextEditingController(text: 'Soft leather'),
        clearEmpty: true,
      );

      expect(fields, {
        'translations[en][name]': '',
        'translations[en][description]': 'Soft leather',
      });
    });
  });

  test('readTranslation lit translations.en renvoyé par l’API vendeur', () {
    final translations = {
      'en': {'name': 'Leather bag', 'description': null},
    };

    expect(EnglishVersionSection.readTranslation(translations, 'name'), 'Leather bag');
    expect(EnglishVersionSection.readTranslation(translations, 'description'), '');
    expect(EnglishVersionSection.readTranslation(null, 'name'), '');
    expect(EnglishVersionSection.readTranslation([], 'name'), '');
  });

  testWidgets('repliée sans traduction, dépliée quand une traduction arrive', (tester) async {
    final name = TextEditingController();
    final description = TextEditingController();

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: EnglishVersionSection(
            nameController: name,
            descriptionController: description,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('english_name_field')), findsNothing);

    // Pré-remplissage après coup (fiche chargée, brouillon restauré).
    name.text = 'Leather bag';
    await tester.pump();
    expect(find.byKey(const Key('english_name_field')), findsOneWidget);
  });
}
