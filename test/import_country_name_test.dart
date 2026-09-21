import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/modules/import/views/import_view.dart';

void main() {
  group('Nom de pays dans les pastilles du catalogue', () {
    test('retire le préfixe de marque ajouté par le back-office', () {
      // Relevé sur /v1/import-countries : le libellé turc est préfixé, pas
      // les autres. Dans une rangée à quatre pastilles, « ASSO Turquie » ne
      // tiendrait pas.
      expect(shortImportCountryName('ASSO Turquie'), 'Turquie');
    });

    test('laisse intact un nom déjà court', () {
      expect(shortImportCountryName('Chine'), 'Chine');
      expect(shortImportCountryName('Dubaï'), 'Dubaï');
    });

    test('ignore la casse du préfixe', () {
      expect(shortImportCountryName('asso Maroc'), 'Maroc');
    });

    test(
      'ne touche pas à un nom qui commence seulement par les mêmes lettres',
      () {
        expect(shortImportCountryName('Association'), 'Association');
      },
    );

    test('garde le nom quand le préfixe est tout ce qu’il y a', () {
      // Sinon la pastille se retrouverait sans libellé du tout.
      expect(shortImportCountryName('ASSO'), 'ASSO');
      expect(shortImportCountryName('ASSO '), 'ASSO');
    });

    test('tolère les espaces autour', () {
      expect(shortImportCountryName('  Chine  '), 'Chine');
      expect(shortImportCountryName(' ASSO Turquie '), 'Turquie');
    });
  });
}
