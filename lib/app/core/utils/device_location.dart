import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

/// Raison pour laquelle la position du téléphone n'a pas pu être lue.
enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  deniedForever,
  unavailable,
}

/// Résultat d'une lecture de position : [position], ou bien [failure].
class DeviceLocationResult {
  const DeviceLocationResult.found(Position this.position) : failure = null;
  const DeviceLocationResult.failed(LocationFailure this.failure)
    : position = null;

  final Position? position;
  final LocationFailure? failure;

  /// Le problème se règle dans les réglages du téléphone, pas en réessayant.
  bool get needsSettings =>
      failure == LocationFailure.serviceDisabled ||
      failure == LocationFailure.deniedForever;

  /// Explication à montrer à l'utilisateur ; null si la position est connue.
  String? get message => switch (failure) {
    LocationFailure.serviceDisabled =>
      'La localisation de votre téléphone est désactivée.',
    LocationFailure.permissionDenied =>
      'Autorisez ASSO à accéder à votre position.',
    LocationFailure.deniedForever =>
      'L’accès à la position est bloqué pour ASSO. Activez-le dans les réglages.',
    LocationFailure.unavailable =>
      'Votre position n’a pas pu être détectée pour le moment.',
    null => null,
  };
}

/// Position du téléphone, commune à toutes les cartes de l'app.
///
/// Chaque écran appelait `Geolocator.getCurrentPosition` à sa façon, souvent
/// sans limite de temps : en intérieur, le GPS ne répondait jamais et le
/// bouton tournait sans fin, ou l'erreur tombait sans solution de repli. Ici :
/// - une seule lecture à la fois. Sur iOS, le plugin n'a qu'un gestionnaire
///   de position : un second appel concurrent laissait le premier en attente
///   pour toujours ;
/// - un fix précis d'abord, puis une position réseau (Wi-Fi, antennes), plus
///   rapide en intérieur, puis la dernière position connue ;
/// - chaque étape est bornée dans le temps.
class DeviceLocation {
  DeviceLocation._();

  static const precise = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 10),
  );
  static const approximate = LocationSettings(
    accuracy: LocationAccuracy.low,
    timeLimit: Duration(seconds: 6),
  );

  static Future<DeviceLocationResult>? _running;

  /// Lit la position actuelle, en demandant l'autorisation si besoin.
  ///
  /// Les appels simultanés partagent la même lecture.
  static Future<DeviceLocationResult> current() =>
      _running ??= _locate().whenComplete(() => _running = null);

  static Future<DeviceLocationResult> _locate() async {
    final geolocator = GeolocatorPlatform.instance;
    try {
      if (!await geolocator.isLocationServiceEnabled()) {
        return const DeviceLocationResult.failed(
          LocationFailure.serviceDisabled,
        );
      }
      var permission = await geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult.failed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const DeviceLocationResult.failed(
          LocationFailure.permissionDenied,
        );
      }
    } catch (_) {
      // Demande d'autorisation déjà affichée par un autre écran, ou
      // autorisation absente de l'Info.plist : on ne peut pas aller plus loin.
      return const DeviceLocationResult.failed(
        LocationFailure.permissionDenied,
      );
    }

    var serviceDisabled = false;
    for (final settings in const [precise, approximate]) {
      try {
        return DeviceLocationResult.found(
          await geolocator.getCurrentPosition(locationSettings: settings),
        );
      } on PermissionDeniedException {
        return const DeviceLocationResult.failed(
          LocationFailure.permissionDenied,
        );
      } on LocationServiceDisabledException {
        // Android refuse le mode précis quand l'utilisateur décline la
        // fenêtre « Activer la localisation précise » : le mode réseau peut
        // encore répondre.
        serviceDisabled = true;
      } catch (_) {
        // Délai dépassé ou capteur indisponible : étape suivante.
      }
    }

    try {
      final last = await geolocator.getLastKnownPosition();
      if (last != null) return DeviceLocationResult.found(last);
    } catch (_) {}

    return DeviceLocationResult.failed(
      serviceDisabled
          ? LocationFailure.serviceDisabled
          : LocationFailure.unavailable,
    );
  }

  /// Ouvre les réglages qui débloquent [failure].
  static Future<void> openSettings(LocationFailure? failure) async {
    if (failure == LocationFailure.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// Explique l'échec dans un snackbar, avec un raccourci vers les réglages
  /// quand c'est là que ça se règle. [hint] propose une alternative.
  static void showFailure(DeviceLocationResult result, {String? hint}) {
    final message = result.message;
    if (message == null) return;
    Get.snackbar(
      'Position indisponible',
      hint == null ? message : '$message $hint',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
      mainButton: result.needsSettings
          ? TextButton(
              onPressed: () => openSettings(result.failure),
              child: const Text('Réglages'),
            )
          : null,
    );
  }
}
