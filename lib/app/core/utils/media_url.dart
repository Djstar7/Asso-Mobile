import '../values/constants.dart';

/// Aligne l'URL d'un média (photo, vidéo) sur l'hôte réel de l'API.
///
/// Le serveur renvoie parfois `localhost` (injoignable depuis un téléphone),
/// un chemin `/storage/storage/` doublé, ou un chemin relatif au disque
/// public. Les ressources embarquées (`assets/…`) sont rendues telles quelles.
String resolveMediaUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('assets/')) return trimmed;

  final apiUri = Uri.parse(AppConstants.baseUrl);
  final mediaUri = Uri.tryParse(trimmed);
  String fixPath(String path) =>
      path.replaceFirst('/storage/storage/', '/storage/');

  if (mediaUri != null && mediaUri.hasScheme && mediaUri.host.isNotEmpty) {
    final isLocal =
        mediaUri.host == 'localhost' || mediaUri.host == '127.0.0.1';
    return (isLocal
            ? mediaUri.replace(
                host: apiUri.host,
                port: apiUri.port,
                path: fixPath(mediaUri.path),
              )
            : mediaUri.replace(path: fixPath(mediaUri.path)))
        .toString();
  }

  return Uri(
    scheme: apiUri.scheme,
    host: apiUri.host,
    port: apiUri.port,
    path: trimmed.startsWith('/storage/')
        ? fixPath(trimmed)
        : '/storage/${trimmed.replaceFirst(RegExp(r'^/'), '')}',
  ).toString();
}
