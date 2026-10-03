import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../utils/cover_resize_image.dart';

/// Photo distante décodée à la taille où elle est affichée, et gardée en
/// cache disque.
///
/// Les photos produits sont envoyées telles que prises par le téléphone
/// (souvent 12 Mpx). Décodées en pleine résolution dans chaque vignette, un
/// mur de produits occupait plusieurs centaines de Mo : après un moment de
/// défilement, le système tuait l'application ou l'écran devenait noir.
///
/// [decodeSize] est la taille logique de la case (pas de `LayoutBuilder` :
/// certaines vignettes vivent dans un `IntrinsicHeight`, qui ne le tolère
/// pas). Elle ne sert qu'au décodage ; la mise en page reste celle du parent.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    required this.decodeSize,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorBuilder,
    this.showProgress = false,
  });

  final String url;

  /// Taille logique de la case que l'image doit couvrir.
  final Size decodeSize;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Affiché pendant le chargement (fond neutre par défaut).
  final WidgetBuilder? placeholder;

  /// Affiché si l'image est introuvable ou illisible.
  final WidgetBuilder? errorBuilder;

  /// Indicateur de progression pendant le téléchargement.
  final bool showProgress;

  /// Fournisseur décodé pour couvrir [size] (taille logique), pour les usages
  /// qui attendent un [ImageProvider] (`DecorationImage`, `CircleAvatar`…).
  static ImageProvider provider(BuildContext context, String url, Size size) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    return CoverResizeImage(
      CachedNetworkImageProvider(url),
      width: _bucket(size.width * dpr),
      height: _bucket(size.height * dpr),
    );
  }

  /// Arrondit au multiple de 64 px supérieur : deux cases de tailles
  /// voisines (grille, rail) partagent ainsi la même image décodée.
  static int _bucket(double pixels) {
    final value = pixels.isFinite && pixels > 0 ? pixels.ceil() : 64;
    return ((value + 63) ~/ 64) * 64;
  }

  @override
  Widget build(BuildContext context) {
    // Sur le web, le navigateur refuse de lire en JavaScript une image
    // servie par un autre hôte sans en-tête CORS : c'est le cas des fichiers
    // `/storage/…` (servis tels quels, hors de Laravel). L'image passe alors
    // par un élément `<img>`, qui n'en a pas besoin ; le décodage réduit
    // ci-dessous n'a de sens que sur téléphone.
    if (kIsWeb) {
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: _buildLoading,
        errorBuilder: _buildError,
      );
    }

    return Image(
      image: provider(context, url, decodeSize),
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      loadingBuilder: _buildLoading,
      errorBuilder: _buildError,
    );
  }

  Widget _buildLoading(
    BuildContext context,
    Widget child,
    ImageChunkEvent? progress,
  ) {
    if (progress == null) return child;
    final background =
        placeholder?.call(context) ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        );
    if (!showProgress) return background;
    final expected = progress.expectedTotalBytes;
    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: expected != null && expected > 0
                  ? progress.cumulativeBytesLoaded / expected
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error, StackTrace? stack) {
    return errorBuilder?.call(context) ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.image_outlined)),
        );
  }
}
