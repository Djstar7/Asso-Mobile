import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'
    as staggered;

/// Grille en colonnes de hauteurs libres, façon Pinterest.
///
/// Une `SliverGrid` impose à toutes les tuiles d'une même rangée la hauteur
/// de la plus grande, ce qui laisse du blanc sous les images courtes. Ici
/// chaque tuile garde la sienne, et la suivante est posée dans la colonne la
/// plus courte du moment — c'est ce placement, et non un simple tourniquet,
/// qui empêche une colonne de prendre de l'avance sur l'autre.
///
/// Le placement vient de `flutter_staggered_grid_view`, qui le fait pendant
/// la disposition (donc en connaissant les hauteurs réelles) tout en gardant
/// le rendu paresseux : un catalogue de plusieurs centaines d'articles ne
/// coûte que ce qui est à l'écran.
class SliverMasonryGrid extends StatelessWidget {
  const SliverMasonryGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) {
    return staggered.SliverMasonryGrid.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Formats de tuile du mur, du plus haut au plus large.
///
/// Quatre valeurs plutôt qu'un ratio continu : l'œil lit un rythme, pas une
/// suite de hauteurs toutes différentes de quelques pixels.
const List<double> _masonryAspectRatios = [
  0.62, // portrait haut
  0.78, // portrait
  1.0, // carré
  1.25, // paysage
];

/// Format imposé à la tuile d'un article, dérivé de son identifiant.
///
/// Le catalogue est presque entièrement composé de photos carrées : s'en
/// tenir à leurs proportions réelles alignerait toutes les tuiles et
/// annulerait l'intérêt de la grille. On impose donc un format, recadré en
/// `cover`.
///
/// Le tirage vient de l'identifiant : un même article garde son format d'une
/// ouverture à l'autre et d'un défilement à l'autre — une hauteur qui change
/// au retour sur la page donnerait l'impression d'un bug. Les identifiants
/// étant souvent consécutifs, on les brasse avant de choisir, sinon les
/// formats se suivraient dans le même ordre à chaque rangée.
double masonryAspectRatioFor(int id) {
  // Multiplication par un grand nombre premier puis repli des bits hauts :
  // deux identifiants voisins tombent ainsi sur des formats éloignés.
  final scrambled = (id * 2654435761) & 0x7FFFFFFF;
  final index = (scrambled ^ (scrambled >> 13)) % _masonryAspectRatios.length;
  return _masonryAspectRatios[index];
}
