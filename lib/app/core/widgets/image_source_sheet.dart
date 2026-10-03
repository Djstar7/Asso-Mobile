import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/app_theme_system.dart';

/// Feuille de choix de la source d'une image (appareil photo ou galerie).
///
/// Celle de l'ajout de produit, partagée pour que la photo de profil se
/// choisisse exactement de la même façon. Retourne la source choisie, ou
/// `null` si la feuille est fermée sans choix.
Future<ImageSource?> showImageSourceSheet(
  BuildContext context, {
  String? title,
  String? cameraSubtitle,
  String? gallerySubtitle,
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        padding: EdgeInsets.only(
          left: context.horizontalPadding,
          right: context.horizontalPadding,
          top: context.verticalPadding,
          bottom: context.bottomSheetPadding,
        ),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(
              AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: context.elementSpacing),

            // Titre
            Text(
              title ?? 'core.image_source.add_images'.tr,
              style: context.h5.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: context.sectionSpacing),

            // Option Caméra
            _ImageSourceOption(
              icon: Icons.camera_alt,
              title: 'core.media.camera'.tr,
              subtitle: cameraSubtitle ?? 'core.image_source.take_photo'.tr,
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            SizedBox(height: context.elementSpacing),

            // Option Galerie
            _ImageSourceOption(
              icon: Icons.photo_library,
              title: 'core.media.gallery'.tr,
              subtitle: gallerySubtitle ?? 'core.image_source.from_gallery'.tr,
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
}

/// Une option de source d'image.
class _ImageSourceOption extends StatelessWidget {
  const _ImageSourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: context.borderRadius(BorderRadiusType.medium),
      child: Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(color: context.borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.elementSpacing),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                borderRadius: context.borderRadius(BorderRadiusType.small),
              ),
              child: Icon(icon, color: AppThemeSystem.primaryColor, size: 28),
            ),
            SizedBox(width: context.elementSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.subtitle1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }
}
