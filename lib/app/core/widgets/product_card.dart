import 'package:flutter/material.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import 'app_ui.dart';

/// Carte produit unique de l'application.
///
/// Elle était auparavant réécrite dans chaque vue (accueil, recherche,
/// favoris, boutique…), avec des rayons, ombres et tailles légèrement
/// différents à chaque fois. Une implémentation unique garantit qu'un produit
/// a partout la même apparence.
///
/// ## Hauteur
/// L'image occupe un ratio fixe et le bloc de texte une hauteur **réservée**,
/// calculée sur deux lignes de titre. Sans cela, un titre court produisait
/// une carte plus basse que sa voisine et la grille se désalignait.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    this.location,
    this.imageBuilder,
    this.onTap,
    this.onFavoriteTap,
    this.isFavorite = false,
    this.isCertified = false,
    this.badgeLabel,
    this.badgeTone = AppBadgeTone.accent,
    this.originalPrice,
    this.isSponsored = false,
  });

  final String name;

  /// Prix déjà formaté avec sa devise.
  final String price;

  /// Prix barré, pour une promotion.
  final String? originalPrice;

  final String? location;

  /// Construit le visuel du produit. Laissé à l'appelant car chaque module
  /// résout ses images différemment (URL distante, asset, placeholder).
  final WidgetBuilder? imageBuilder;

  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;
  final bool isCertified;
  final String? badgeLabel;
  final AppBadgeTone badgeTone;

  /// Asso Ads : emplacement acheté par un vendeur.
  ///
  /// L'annonce se distingue du contenu éditorial — chip « Asso Ads » sur le
  /// visuel et mention en pied de carte — parce qu'un acheteur a le droit de
  /// savoir ce qu'il regarde. Une publicité déguisée en résultat ordinaire
  /// trompe l'acheteur et dévalue le placement pour le vendeur.
  final bool isSponsored;

  /// Ratio largeur/hauteur du visuel.
  ///
  /// Légèrement portrait (4:5) : les produits sont majoritairement
  /// photographiés debout, et l'image gagne en présence sans allonger
  /// démesurément la carte.
  static const double imageAspectRatio = 4 / 5;

  /// Hauteur réservée au bloc texte, selon la densité typographique.
  static double textBlockHeight(BuildContext context) {
    final titleSize = AppThemeSystem.getFontSize(context, FontSizeType.caption);
    final priceSize = AppThemeSystem.getFontSize(context, FontSizeType.subtitle1);
    final metaSize = AppThemeSystem.getFontSize(context, FontSizeType.overline);

    // 2 lignes de titre + prix + ligne de lieu, leurs deux interlignes, et
    // les paddings réellement appliqués par `build` (space3 en haut,
    // space2 en bas). Les hauteurs de ligne sont majorées et complétées par
    // une marge : le moteur de rendu arrondit à la hausse selon la densité,
    // et une sous-estimation de deux pixels suffit à déclencher un
    // débordement.
    return (titleSize * 1.4 * 2) +
        (priceSize * 1.35) +
        (metaSize * 1.4) +
        (AppDesign.space1 * 2) +
        AppDesign.space3 +
        AppDesign.space2 +
        8;
  }

  /// Hauteur totale d'une carte pour une largeur donnée.
  ///
  /// Sert à calculer le `mainAxisExtent` d'une grille ou la hauteur d'une
  /// liste horizontale, plutôt que de deviner un `childAspectRatio`.
  static double totalHeight(BuildContext context, double width) {
    return (width / imageAspectRatio) + textBlockHeight(context);
  }

  /// Indique si la boutique d'un produit est certifiée.
  ///
  /// L'API renvoie ce drapeau tantôt en booléen, tantôt en entier, tantôt en
  /// chaîne ; chaque écran refaisait sa propre conversion.
  static bool isShopCertified(Map<String, dynamic> product) {
    final shop = product['shop'];
    if (shop is! Map) return false;

    final value = shop['is_certified'];
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  /// Largeur d'une carte dans une grille occupant toute la largeur utile.
  static double widthInGrid(BuildContext context, {int? columns}) {
    final cols = columns ?? AppDesign.productColumns(context);
    final available = MediaQuery.sizeOf(context).width - AppDesign.gutter(context) * 2;
    return (available - AppDesign.space3 * (cols - 1)) / cols;
  }

  /// Gabarit de grille partagé par tous les écrans listant des produits.
  ///
  /// Impose la hauteur réelle d'une carte plutôt qu'un `childAspectRatio`
  /// deviné : c'est ce qui garantit que les cartes restent alignées quelle
  /// que soit la largeur de l'écran ou la longueur des titres.
  static SliverGridDelegate gridDelegate(BuildContext context) {
    final columns = AppDesign.productColumns(context);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisExtent:
          totalHeight(context, widthInGrid(context, columns: columns)),
      crossAxisSpacing: AppDesign.space3,
      mainAxisSpacing: AppDesign.space3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDesign.radiusMd);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          // La carte n'a plus ni cadre ni fond : le visuel du produit tient
          // lieu de surface. Sur une grille de plusieurs dizaines d'articles,
          // les bordures empilées créaient un quadrillage qui fatiguait l'œil.
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // `max` est nécessaire pour que le `Flexible` du bloc texte ait
            // un espace à partager : avec `min`, la colonne prenait la somme
            // des hauteurs intrinsèques et débordait de la cellule.
            mainAxisSize: MainAxisSize.max,
            children: [
              // L'image garde son ratio ; le texte occupe le reste. Une
              // hauteur figée des deux côtés faisait déborder la cellule de
              // quelques pixels selon la densité de l'écran.
              AspectRatio(
                aspectRatio: imageAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesign.radiusMd),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: context.ds.surfaceMuted,
                        child: imageBuilder?.call(context) ??
                            Icon(
                              Icons.image_outlined,
                              color: context.ds.textTertiary,
                              size: 28,
                            ),
                      ),
                      if (isSponsored)
                        Positioned(
                          top: AppDesign.space2,
                          left: AppDesign.space2,
                          child: const _AssoAdsChip(),
                        )
                      else if (badgeLabel != null)
                        Positioned(
                          top: AppDesign.space2,
                          left: AppDesign.space2,
                          child: AppBadge(label: badgeLabel!, tone: badgeTone),
                        )
                      else if (isCertified)
                        Positioned(
                          top: AppDesign.space2,
                          left: AppDesign.space2,
                          child: _CertifiedMark(),
                        ),
                      if (onFavoriteTap != null)
                        Positioned(
                          top: AppDesign.space1,
                          right: AppDesign.space1,
                          child: _FavoriteButton(
                            isFavorite: isFavorite,
                            onTap: onFavoriteTap!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDesign.space1,
                    AppDesign.space3,
                    AppDesign.space1,
                    AppDesign.space2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hauteur naturelle : dans un `Expanded`, le titre
                      // absorbait l'espace restant et repoussait le prix en
                      // bas de la carte, loin du produit qu'il chiffre.
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.caption,
                          fontWeight: FontWeight.w500,
                          color: context.ds.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: AppDesign.space1),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              price,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyle(
                                FontSizeType.subtitle1,
                                fontWeight: FontWeight.w700,
                                color: context.ds.textPrimary,
                              ),
                            ),
                          ),
                          if (originalPrice != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                originalPrice!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context
                                    .textStyle(
                                      FontSizeType.overline,
                                      color: context.ds.textTertiary,
                                    )
                                    .copyWith(
                                      decoration: TextDecoration.lineThrough,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: AppDesign.space1),
                      if (isSponsored)
                        // Une annonce annonce ce qu'elle est, même hors du
                        // visuel : le chip peut être masqué par une image
                        // sombre, cette ligne reste lisible.
                        Row(
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              size: 11,
                              color: AppDesign.info,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Sponsorisé',
                              style: context.textStyle(
                                FontSizeType.overline,
                                color: AppDesign.info,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (location != null && location!.isNotEmpty) ...[
                              Text(
                                '  ·  ',
                                style: context.textStyle(
                                  FontSizeType.overline,
                                  color: context.ds.textTertiary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  location!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textStyle(
                                    FontSizeType.overline,
                                    color: context.ds.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      else if (location != null && location!.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: context.ds.textTertiary,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyle(
                                  FontSizeType.overline,
                                  color: context.ds.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asso Ads — marque d'un emplacement acheté, posée sur le visuel.
///
/// Fond plein plutôt que translucide : sur une photo claire, un chip
/// semi-transparent devient illisible, et une mention publicitaire qu'on ne
/// peut pas lire ne remplit pas son office.
class _AssoAdsChip extends StatelessWidget {
  const _AssoAdsChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppDesign.info,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.campaign, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'Asso Ads',
            style: context.textStyle(
              FontSizeType.overline,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille « boutique certifiée ».
class _CertifiedMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Pastille lisible sur n'importe quelle photo : fond plein, libellé
    // court. « Vérifié » dit ce que l'icône seule laissait deviner.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesign.space2 - 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        boxShadow: context.ds.shadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 12, color: AppDesign.info),
          const SizedBox(width: 3),
          Text(
            'Vérifié',
            style: context.textStyle(
              FontSizeType.overline,
              fontWeight: FontWeight.w600,
              color: context.ds.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton favori avec cible tactile confortable.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Pastille opaque et légèrement ombrée : posée sur une photo, une
    // surface translucide devenait illisible sur les visuels clairs.
    return Material(
      color: context.ds.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: AppDesign.neutral900.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 17,
            color: isFavorite ? AppDesign.danger : context.ds.textSecondary,
          ),
        ),
      ),
    );
  }
}
