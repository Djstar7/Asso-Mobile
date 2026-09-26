import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:asso/app/core/utils/device_location.dart';

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime(2026),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// Téléphone simulé : chaque lecture de position consomme la réponse
/// suivante de [answers] (une position, ou une erreur à lever).
class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission afterRequest = LocationPermission.whileInUse;
  List<Object> answers = [];
  Position? lastKnown;
  Completer<void>? gate;

  final requestedAccuracies = <LocationAccuracy>[];
  int permissionRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission = afterRequest;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requestedAccuracies.add(locationSettings!.accuracy);
    await gate?.future;
    final answer = answers.removeAt(0);
    if (answer is Position) return answer;
    throw answer;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnown;
}

void main() {
  late _FakeGeolocator phone;

  setUp(() => GeolocatorPlatform.instance = phone = _FakeGeolocator());

  test('rend le fix précis quand le GPS répond', () async {
    phone.answers = [_position(4.05, 9.77)];

    final result = await DeviceLocation.current();

    expect(result.position?.latitude, 4.05);
    expect(result.failure, isNull);
    expect(phone.requestedAccuracies, [LocationAccuracy.high]);
  });

  test('sans fix GPS à temps, se contente de la position réseau', () async {
    phone.answers = [TimeoutException('GPS'), _position(4.06, 9.78)];

    final result = await DeviceLocation.current();

    expect(result.position?.latitude, 4.06);
    expect(phone.requestedAccuracies, [
      LocationAccuracy.high,
      LocationAccuracy.low,
    ]);
  });

  test('en dernier recours, prend la dernière position connue', () async {
    phone.answers = [
      TimeoutException('GPS'),
      const PositionUpdateException('kCLErrorDomain 2'),
    ];
    phone.lastKnown = _position(4.07, 9.79);

    final result = await DeviceLocation.current();

    expect(result.position?.latitude, 4.07);
  });

  test('sans aucune position, explique que la détection a échoué', () async {
    phone.answers = [TimeoutException('GPS'), TimeoutException('réseau')];

    final result = await DeviceLocation.current();

    expect(result.failure, LocationFailure.unavailable);
    expect(result.message, isNotNull);
    expect(result.needsSettings, isFalse);
  });

  test('mode précis refusé sur Android : la position réseau suffit', () async {
    phone.answers = [
      const LocationServiceDisabledException(),
      _position(4.08, 9.7),
    ];

    final result = await DeviceLocation.current();

    expect(result.position?.latitude, 4.08);
  });

  test(
    'localisation du téléphone coupée : renvoie vers les réglages',
    () async {
      phone.serviceEnabled = false;

      final result = await DeviceLocation.current();

      expect(result.failure, LocationFailure.serviceDisabled);
      expect(result.needsSettings, isTrue);
      expect(phone.requestedAccuracies, isEmpty);
    },
  );

  test('demande l’autorisation, et respecte un refus', () async {
    phone.permission = LocationPermission.denied;
    phone.afterRequest = LocationPermission.denied;

    final result = await DeviceLocation.current();

    expect(phone.permissionRequests, 1);
    expect(result.failure, LocationFailure.permissionDenied);
    expect(result.needsSettings, isFalse);
  });

  test('autorisation bloquée : renvoie vers les réglages', () async {
    phone.permission = LocationPermission.deniedForever;

    final result = await DeviceLocation.current();

    expect(phone.permissionRequests, 0);
    expect(result.failure, LocationFailure.deniedForever);
    expect(result.needsSettings, isTrue);
  });

  test('deux appels simultanés partagent une seule lecture', () async {
    // Sur iOS, une seconde lecture concurrente laissait la première en
    // attente pour toujours.
    phone.gate = Completer<void>();
    phone.answers = [_position(4.05, 9.77)];

    final first = DeviceLocation.current();
    final second = DeviceLocation.current();
    await Future<void>.delayed(Duration.zero);
    phone.gate!.complete();

    expect((await first).position?.latitude, 4.05);
    expect((await second).position?.latitude, 4.05);
    expect(phone.requestedAccuracies, [LocationAccuracy.high]);

    // La lecture terminée, un nouvel appel relit bien la position.
    phone.gate = null;
    phone.answers = [_position(4.1, 9.8)];
    expect((await DeviceLocation.current()).position?.latitude, 4.1);
  });
}
