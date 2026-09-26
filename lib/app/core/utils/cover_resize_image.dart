import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Décode une image juste assez grande pour couvrir [width] × [height] pixels
/// physiques (`BoxFit.cover`), sans jamais l'agrandir.
///
/// `cacheWidth` seul ne suffit pas pour une vignette recadrée : une photo
/// paysage dans une case portrait, décodée à la largeur de la case, était
/// ensuite étirée pour en couvrir la hauteur, et devenait floue. Ici la taille
/// de décodage dépend des proportions réelles de la photo, connues seulement
/// au décodage.
///
/// Une photo de 4000 × 3000 affichée en vignette de 180 px occupait 48 Mo en
/// mémoire ; décodée à la taille de la case, moins de 1 Mo.
@immutable
class CoverResizeImage extends ImageProvider<CoverResizeImageKey> {
  const CoverResizeImage(
    this.imageProvider, {
    required this.width,
    required this.height,
  }) : assert(width > 0 && height > 0);

  final ImageProvider imageProvider;

  /// Taille à couvrir, en pixels physiques.
  final int width;
  final int height;

  @override
  Future<CoverResizeImageKey> obtainKey(ImageConfiguration configuration) {
    // Même schéma que `ResizeImage` : si la clé de l'image source est
    // synchrone (image déjà en cache), la nôtre l'est aussi, et l'image
    // s'affiche dès la première image sans clignoter.
    Completer<CoverResizeImageKey>? completer;
    SynchronousFuture<CoverResizeImageKey>? result;
    imageProvider.obtainKey(configuration).then((Object key) {
      final coverKey = CoverResizeImageKey._(key, width, height);
      if (completer == null) {
        result = SynchronousFuture<CoverResizeImageKey>(coverKey);
      } else {
        completer!.complete(coverKey);
      }
    }, onError: (Object error, StackTrace stack) {
      completer ??= Completer<CoverResizeImageKey>();
      completer!.completeError(error, stack);
    });
    if (result != null) return result!;
    completer ??= Completer<CoverResizeImageKey>();
    return completer!.future;
  }

  @override
  ImageStreamCompleter loadImage(
    CoverResizeImageKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> decodeCover(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) {
      return decode(
        buffer,
        getTargetSize: (int intrinsicWidth, int intrinsicHeight) =>
            coverSize(intrinsicWidth, intrinsicHeight, width, height),
      );
    }

    // `loadImage` est protégé pour les appelants extérieurs, pas pour un
    // fournisseur qui en enveloppe un autre : c'est ce que fait `ResizeImage`.
    // ignore: invalid_use_of_protected_member
    final completer = imageProvider.loadImage(key._providerKey, decodeCover);
    completer.addEphemeralErrorListener((Object _, StackTrace? _) {
      // Une image en échec ne doit pas rester en cache sous notre clé.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    });
    return completer;
  }

  /// Plus petite taille, proportions conservées, qui couvre la case
  /// [boxWidth] × [boxHeight]. Jamais plus grande que l'original.
  @visibleForTesting
  static ui.TargetImageSize coverSize(
    int intrinsicWidth,
    int intrinsicHeight,
    int boxWidth,
    int boxHeight,
  ) {
    if (intrinsicWidth <= 0 || intrinsicHeight <= 0) {
      return const ui.TargetImageSize();
    }
    final scale = math.max(
      boxWidth / intrinsicWidth,
      boxHeight / intrinsicHeight,
    );
    if (scale >= 1) return const ui.TargetImageSize();
    return ui.TargetImageSize(
      width: math.max(1, (intrinsicWidth * scale).ceil()),
      height: math.max(1, (intrinsicHeight * scale).ceil()),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoverResizeImage &&
      other.imageProvider == imageProvider &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(imageProvider, width, height);
}

/// Clé de cache d'une [CoverResizeImage] : l'image source et la taille visée.
@immutable
class CoverResizeImageKey {
  const CoverResizeImageKey._(this._providerKey, this._width, this._height);

  final Object _providerKey;
  final int _width;
  final int _height;

  @override
  bool operator ==(Object other) =>
      other is CoverResizeImageKey &&
      other._providerKey == _providerKey &&
      other._width == _width &&
      other._height == _height;

  @override
  int get hashCode => Object.hash(_providerKey, _width, _height);
}
