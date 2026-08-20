import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'app_theme_system.dart';

/// Utilitaires média multiplateformes (mobile + web/Chrome).
///
/// - Un sélecteur de source (appareil photo / galerie) aux couleurs de la marque,
///   partagé entre le passage en mode vendeur et la vérification d'identité Diaspo.
/// - Une prévisualisation d'image qui fonctionne aussi bien sur mobile (dart:io File)
///   que sur le web (où `File` n'existe pas et où `XFile.path` est une URL blob).
///
/// IMPORTANT : sur le web, il ne faut jamais convertir un [XFile] en `dart:io File`.
/// On garde donc l'[XFile] tel quel et on lit ses octets (`readAsBytes`) au moment
/// de l'upload — ce qui est supporté sur toutes les plateformes.
class MediaHelper {
  MediaHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// Affiche un bottom sheet aux couleurs de la marque pour choisir la source
  /// d'image, puis retourne l'[XFile] sélectionné (ou `null` si annulé).
  ///
  /// [title] et [subtitle] permettent de contextualiser (photo de profil, logo,
  /// pièce d'identité, etc.).
  static Future<XFile?> pickBrandedImage({
    String title = 'Ajouter une photo',
    String? subtitle,
    double? maxWidth,
    double? maxHeight,
    int imageQuality = 85,
  }) async {
    final source = await showBrandedImageSourceSheet(
      title: title,
      subtitle: subtitle,
    );
    if (source == null) return null;

    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        "Impossible de sélectionner l'image",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
      return null;
    }
  }

  /// Bottom sheet de sélection de source (appareil photo / galerie) stylé aux
  /// couleurs de la marque. Retourne l'[ImageSource] choisie, ou `null`.
  ///
  /// Sur le web, la source « appareil photo » ouvre généralement la webcam si
  /// disponible, sinon le sélecteur de fichiers ; les deux entrées restent donc
  /// pertinentes.
  static Future<ImageSource?> showBrandedImageSourceSheet({
    String title = 'Ajouter une photo',
    String? subtitle,
  }) {
    final context = Get.context!;
    final isDark = AppThemeSystem.isDarkMode(context);
    final surface =
        isDark ? AppThemeSystem.darkCardColor : AppThemeSystem.whiteColor;
    final primaryText = AppThemeSystem.getPrimaryTextColor(context);
    final secondaryText = AppThemeSystem.getSecondaryTextColor(context);

    return Get.bottomSheet<ImageSource>(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poignée
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppThemeSystem.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: secondaryText),
              ),
            ],
            const SizedBox(height: 20),
            _sourceTile(
              icon: Icons.photo_camera_rounded,
              label: 'Appareil photo',
              helper: 'Prendre une nouvelle photo',
              onTap: () => Get.back(result: ImageSource.camera),
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            const SizedBox(height: 12),
            _sourceTile(
              icon: Icons.photo_library_rounded,
              label: 'Galerie',
              helper: 'Choisir une image existante',
              onTap: () => Get.back(result: ImageSource.gallery),
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Get.back(),
              style: TextButton.styleFrom(
                foregroundColor: secondaryText,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      isDismissible: true,
    );
  }

  /// Tuile de source aux couleurs de la marque (icône orange sur pastille douce).
  static Widget _sourceTile({
    required IconData icon,
    required String label,
    required String helper,
    required VoidCallback onTap,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Material(
      color: AppThemeSystem.primaryColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon,
                    color: AppThemeSystem.primaryColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helper,
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }

  /// Prévisualise un [XFile] sélectionné, de manière multiplateforme.
  ///
  /// - Web : `Image.network` sur l'URL blob (`xfile.path`).
  /// - Mobile/desktop : `Image.file` via `dart:io`.
  static Widget buildImagePreview(
    XFile file, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (kIsWeb) {
      return Image.network(
        file.path,
        width: width,
        height: height,
        fit: fit,
      );
    }
    return Image.file(
      File(file.path),
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Retourne un [ImageProvider] multiplateforme pour un [XFile] sélectionné,
  /// utilisable par ex. dans un [DecorationImage].
  ///
  /// - Web : [NetworkImage] sur l'URL blob.
  /// - Mobile/desktop : [FileImage] via `dart:io`.
  static ImageProvider imageProviderFor(XFile file) {
    if (kIsWeb) {
      return NetworkImage(file.path);
    }
    return FileImage(File(file.path));
  }
}
