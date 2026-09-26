import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Binding de l'application : celui de Flutter, avec un plafond de décodage
/// des images.
///
/// Filet de sécurité pour toutes les images qui ne précisent pas leur taille
/// d'affichage (fiche produit, visionneuse, photos du chat, aperçus avant
/// envoi…). Une photo de téléphone de 12 Mpx occupe 48 Mo une fois décodée ;
/// plafonnée à [maxDecodedDimension] px de côté, moins de 8 Mo — toujours plus
/// que la largeur d'un écran de téléphone, donc sans perte visible.
///
/// Les images qui demandent déjà une taille (`cacheWidth`, `ResizeImage`,
/// [CoverResizeImage]…) sont décodées telles que demandé.
class AppBinding extends WidgetsFlutterBinding {
  AppBinding._();

  /// Plus grand côté d'une image décodée sans taille demandée.
  static const int maxDecodedDimension = 1600;

  static bool _initialized = false;

  /// À appeler en tout premier dans `main`, à la place de
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  static WidgetsBinding ensureInitialized() {
    if (!_initialized) {
      _initialized = true;
      AppBinding._();
    }
    return WidgetsBinding.instance;
  }

  @override
  Future<ui.Codec> instantiateImageCodecWithSize(
    ui.ImmutableBuffer buffer, {
    ui.TargetImageSizeCallback? getTargetSize,
  }) {
    return super.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (int intrinsicWidth, int intrinsicHeight) {
        final requested =
            getTargetSize?.call(intrinsicWidth, intrinsicHeight) ??
            const ui.TargetImageSize();
        return cappedSize(requested, intrinsicWidth, intrinsicHeight);
      },
    );
  }

  /// Taille de décodage finale : celle demandée, ou l'original ramené à
  /// [maxDecodedDimension] px sur son plus grand côté.
  @visibleForTesting
  static ui.TargetImageSize cappedSize(
    ui.TargetImageSize requested,
    int intrinsicWidth,
    int intrinsicHeight,
  ) {
    if (requested.width != null || requested.height != null) return requested;
    if (math.max(intrinsicWidth, intrinsicHeight) <= maxDecodedDimension) {
      return requested;
    }
    // Un seul côté suffit : le moteur conserve les proportions.
    return intrinsicWidth >= intrinsicHeight
        ? const ui.TargetImageSize(width: maxDecodedDimension)
        : const ui.TargetImageSize(height: maxDecodedDimension);
  }
}
