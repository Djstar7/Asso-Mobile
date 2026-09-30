import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';

/// Asso Ads — bandeau publicitaire intercalé dans le fil, pleine largeur.
///
/// Format complémentaire de la carte sponsorisée : là où la carte se fond dans
/// la grille, ce bandeau occupe toute la largeur et arrête le défilement. Il
/// sert les campagnes dont le visuel mérite d'être vu en grand.
///
/// Il s'annonce comme publicité (chip « Asso Ads » + mention) : sa forme
/// ressemble à du contenu éditorial, la mention est donc ce qui empêche la
/// confusion.
class AssoAdsBanner extends StatelessWidget {
  const AssoAdsBanner({
    super.key,
    required this.name,
    required this.price,
    this.shopName,
    this.location,
    this.imageBuilder,
    this.onTap,
  });

  final String name;

  /// Prix déjà formaté avec sa devise.
  final String price;

  final String? shopName;
  final String? location;

  /// Construit le visuel, laissé à l'appelant comme pour [ProductCard].
  final WidgetBuilder? imageBuilder;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final radius = BorderRadius.circular(AppDesign.radiusLg);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesign.gutter(context),
        vertical: AppDesign.space3,
      ),
      child: Material(
        color: ds.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: ds.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visuel large : 16/9, le format qui donne envie de s'arrêter.
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDesign.radiusLg),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: ds.surfaceMuted,
                          child: imageBuilder?.call(context) ??
                              Icon(
                                Icons.image_outlined,
                                color: ds.textTertiary,
                                size: 32,
                              ),
                        ),
                        Positioned(
                          top: AppDesign.space3,
                          left: AppDesign.space3,
                          child: _chip(context),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(AppDesign.space4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (shopName != null && shopName!.isNotEmpty) ...[
                              Text(
                                shopName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyle(
                                  FontSizeType.overline,
                                  color: AppDesign.info,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyle(
                                FontSizeType.body1,
                                fontWeight: FontWeight.w600,
                                color: ds.textPrimary,
                                height: 1.25,
                              ),
                            ),
                            SizedBox(height: AppDesign.space2),
                            Text(
                              price,
                              style: context.textStyle(
                                FontSizeType.subtitle1,
                                fontWeight: FontWeight.w700,
                                color: ds.textPrimary,
                              ),
                            ),
                            if (location != null && location!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 11,
                                    color: ds.textTertiary,
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      location!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textStyle(
                                        FontSizeType.overline,
                                        color: ds.textTertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: AppDesign.space3),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppDesign.space4,
                          vertical: AppDesign.space2 + 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppDesign.accent,
                          borderRadius:
                              BorderRadius.circular(AppDesign.radiusPill),
                        ),
                        child: Text(
                          'core.ads.see'.tr,
                          style: context.textStyle(
                            FontSizeType.caption,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesign.info,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.campaign, size: 12, color: Colors.white),
          const SizedBox(width: 5),
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
