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

  /// Ratio largeur/hauteur du visuel.
  static const double imageAspectRatio = 1;

  /// Hauteur réservée au bloc texte, selon la densité typographique.
  static double textBlockHeight(BuildContext context) {
    final titleSize = AppThemeSystem.getFontSize(context, FontSizeType.caption);
    final priceSize = AppThemeSystem.getFontSize(context, FontSizeType.body2);
    final metaSize = AppThemeSystem.getFontSize(context, FontSizeType.overline);

    // 2 lignes de titre + prix + ligne de lieu + interlignes + paddings.
    // Les hauteurs de ligne sont majorées (1.35) et complétées par une marge
    // de sécurité : sur certaines densités, l'arrondi du moteur de rendu
    // rognait le bas de la deuxième ligne du titre.
    return (titleSize * 1.35 * 2) +
        (priceSize * 1.35) +
        (metaSize * 1.35) +
        (AppDesign.space1 * 2) +
        (AppDesign.space3 * 2) +
        4;
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
      color: context.ds.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: context.ds.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: imageAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDesign.radiusMd),
                  ),
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
                      if (badgeLabel != null)
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
              SizedBox(
                height: textBlockHeight(context),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDesign.space3,
                    AppDesign.space3,
                    AppDesign.space3,
                    AppDesign.space3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyle(
                            FontSizeType.caption,
                            fontWeight: FontWeight.w500,
                            color: context.ds.textPrimary,
                            height: 1.3,
                          ),
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
                                FontSizeType.body2,
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
                      if (location != null && location!.isNotEmpty)
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

/// Pastille « boutique certifiée ».
class _CertifiedMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.ds.surface,
        shape: BoxShape.circle,
        boxShadow: context.ds.shadowSm,
      ),
      child: const Icon(
        Icons.verified_rounded,
        size: 13,
        color: AppDesign.info,
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
    return Material(
      color: context.ds.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
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
