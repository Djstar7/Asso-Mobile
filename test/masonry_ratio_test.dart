import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/core/widgets/masonry_grid.dart';

void main() {
  group('Format des tuiles du mur', () {
    test('un article garde son format d’un appel à l’autre', () {
      // Une hauteur qui change au retour sur la page donnerait l'impression
      // d'un bug : le format doit être une fonction de l'identifiant seul.
      for (final id in [1, 42, 160, 9999]) {
        expect(masonryAspectRatioFor(id), masonryAspectRatioFor(id));
      }
    });

    test('des articles voisins changent presque toujours de format', () {
      // Les identifiants du catalogue sont consécutifs : sans brassage, des
      // tuiles côte à côte auraient la même hauteur et la grille s'alignerait.
      // Quelques répétitions restent normales — sur quatre formats tirés au
      // sort, les exclure reviendrait à imposer un cycle prévisible.
      var differing = 0;
      for (var id = 133; id < 167; id++) {
        if (masonryAspectRatioFor(id) != masonryAspectRatioFor(id + 1)) {
          differing++;
        }
      }
      expect(differing, greaterThanOrEqualTo(30));
    });

    test('les quatre formats sont tous utilisés, sans domination', () {
      // Identifiants réels relevés sur le catalogue d'import.
      final counts = <double, int>{};
      for (var id = 133; id <= 167; id++) {
        counts.update(
          masonryAspectRatioFor(id),
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }

      expect(counts.length, 4, reason: 'les quatre formats doivent apparaître');
      for (final entry in counts.entries) {
        // Sur 35 articles, aucun format ne doit écraser les autres.
        expect(
          entry.value,
          inInclusiveRange(4, 16),
          reason: 'format ${entry.key} employé ${entry.value} fois',
        );
      }
    });

    test('le format reste dans des proportions affichables', () {
      // Trop étroit, la tuile devient une colonne ; trop large, elle écrase
      // le texte sous l'image.
      for (var id = 0; id < 500; id++) {
        expect(masonryAspectRatioFor(id), inInclusiveRange(0.5, 1.6));
      }
    });

    test('un identifiant nul ou négatif reste géré', () {
      // Un produit mal formé côté API ne doit pas faire planter la grille.
      expect(masonryAspectRatioFor(0), inInclusiveRange(0.5, 1.6));
      expect(masonryAspectRatioFor(-7), inInclusiveRange(0.5, 1.6));
    });
  });
}
