import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import '../utils/media_url.dart';
import 'autoplay_video.dart';
import 'product_video_player.dart';

/// Tuile d'un mur de produits en colonnes libres, façon Pinterest.
///
/// Contrairement à [ProductCard], dont la hauteur est figée pour aligner une
/// grille, la tuile prend la hauteur de son visuel ([aspectRatio]) puis de
/// son texte : c'est ce décalage entre colonnes qui donne son rythme au mur.
///
/// Avec [videoUrl], le visuel devient une boucle muette lue quand la tuile
/// est à l'écran ; [image] sert alors d'affiche tant que la vidéo charge.
class MasonryProductTile extends StatelessWidget {
  const MasonryProductTile({
    super.key,
    required this.aspectRatio,
    required this.image,
    required this.name,
    required this.price,
    this.videoUrl,
    this.videoDurationLabel,
    this.badge,
    this.meta,
    this.metaIcon,
    this.metaColor,
    this.onTap,
  });

  /// Largeur / hauteur du visuel.
  final double aspectRatio;

  /// Photo du produit, ou affiche de la vidéo.
  final Widget image;

  /// Aperçu vidéo muet ; null pour une tuile photo.
  final String? videoUrl;

  /// « 0:27 », affiché sur la pastille lecture.
  final String? videoDurationLabel;

  /// Marque posée en haut à gauche du visuel (annonce, boutique vérifiée…).
  final Widget? badge;

  final String name;

  /// Prix déjà formaté avec sa devise.
  final String price;

  /// Ligne discrète sous le prix : lieu, mention « Sponsorisé »…
  final String? meta;
  final IconData? metaIcon;
  final Color? metaColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final video = videoUrl;
    final metaTint = metaColor ?? context.ds.textTertiary;

    return Material(
      color: context.ds.surface,
      borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Colonne de hauteur libre : la tuile mesure son contenu, elle ne
          // s'étire pas dans une case imposée.
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: aspectRatio,
                  child: SizedBox(
                    width: double.infinity,
                    child: video == null
                        ? image
                        : AutoplayVideo(url: video, poster: image),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    left: AppDesign.space2,
                    top: AppDesign.space2,
                    child: badge!,
                  ),
                if (video != null)
                  Positioned(
                    right: AppDesign.space2,
                    top: AppDesign.space2,
                    child: VideoDurationPill(label: videoDurationLabel),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDesign.space2,
                AppDesign.space2,
                AppDesign.space2,
                AppDesign.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.caption,
                      fontWeight: FontWeight.w600,
                      color: context.ds.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: AppDesign.space1),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: FontWeight.w700,
                      color: context.ds.textPrimary,
                    ),
                  ),
                  if (meta != null && meta!.isNotEmpty) ...[
                    SizedBox(height: AppDesign.space1),
                    Row(
                      children: [
                        if (metaIcon != null) ...[
                          Icon(metaIcon, size: 11, color: metaTint),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(
                            meta!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.overline,
                              color: metaTint,
                              fontWeight: metaColor == null
                                  ? null
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo d'une tuile, décodée à la taille de la tuile.
///
/// Sans [cacheWidth], chaque photo était décodée en pleine résolution —
/// plusieurs Mo de mémoire par vignette de 180 px. Le cache disque évite en
/// plus de retélécharger le mur à chaque retour sur l'écran.
class MasonryTileImage extends StatelessWidget {
  const MasonryTileImage({super.key, required this.url, this.cacheWidth});

  final String? url;

  /// Largeur de décodage, en pixels physiques.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return const _TilePlaceholder();

    return CachedNetworkImage(
      imageUrl: resolveMediaUrl(value),
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, _) => ColoredBox(color: context.ds.surfaceMuted),
      errorWidget: (_, _, _) => const _TilePlaceholder(),
    );
  }
}

class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.ds.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: context.ds.textTertiary,
        ),
      ),
    );
  }
}

/// Squelette d'une tuile, au format de celle qui va la remplacer.
class MasonryTileSkeleton extends StatelessWidget {
  const MasonryTileSkeleton({super.key, required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.ds.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDesign.space1),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: ColoredBox(color: context.ds.surfaceMuted),
          ),
          Padding(
            padding: EdgeInsets.all(AppDesign.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(double.infinity, 10),
                SizedBox(height: AppDesign.space1),
                bar(64, 10),
                SizedBox(height: AppDesign.space2),
                bar(48, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
