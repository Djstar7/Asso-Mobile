import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:asso/app/core/widgets/autoplay_video.dart';
import 'package:asso/app/core/widgets/masonry_grid.dart';
import 'package:asso/app/core/widgets/product_video_player.dart';
import 'package:asso/app/data/models/wholesale_models.dart';
import 'package:asso/app/modules/import/views/import_view.dart';
import 'package:asso/app/modules/import/views/wholesale_product_view.dart';

/// Lecteur vidéo factice : enregistre les appels au lieu de décoder.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<String> calls = [];
  final Map<int, StreamController<VideoEvent>> _events = {};
  int _nextId = 0;

  int get created => calls.where((c) => c.startsWith('create')).length;
  bool isPlaying(int id) =>
      calls.lastWhere(
        (c) => c == 'play $id' || c == 'pause $id',
        orElse: () => '',
      ) ==
      'play $id';

  int _create(String? uri) {
    final id = _nextId++;
    calls.add('create $uri');
    final events = StreamController<VideoEvent>();
    _events[id] = events;
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(576, 1024),
        duration: const Duration(seconds: 27),
      ),
    );
    return id;
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => _create(dataSource.uri);

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      _create(options.dataSource.uri);

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose $playerId');
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> play(int playerId) async => calls.add('play $playerId');

  @override
  Future<void> pause(int playerId) async => calls.add('pause $playerId');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      calls.add('volume $playerId $volume');

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      calls.add('looping $playerId $looping');

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

/// Participant factice du coordinateur.
class _Client implements AutoplayClient {
  _Client(this.name);
  final String name;
  bool playing = false;
  bool released = false;

  @override
  void setShouldPlay(bool shouldPlay) => playing = shouldPlay;

  @override
  void release() => released = true;

  @override
  String toString() => name;
}

const _videoJson = {
  'id': 1,
  'url': 'http://localhost:8001/api/v1/import/videos/1/video',
  'preview_url': 'http://localhost:8001/api/v1/import/videos/1/preview',
  'poster_url': 'http://localhost:8001/api/v1/import/videos/1/poster',
  'width': 576,
  'height': 1024,
  'aspect_ratio': 0.5625,
  'duration': 26.6,
};

WholesaleProduct _product({bool withVideo = true, int photos = 3}) =>
    WholesaleProduct(
      id: 71,
      name: 'Balle robes crème premium',
      currency: 'XAF',
      priceTiers: const [
        PriceTier(
          id: 1,
          label: 'Balle de 100 pièces',
          unitPrice: 1500,
          unitPriceXaf: 1500,
          currency: 'XAF',
          minQuantity: 100,
          formattedPrice: '1 500 FCFA',
        ),
      ],
      images: [
        for (var i = 0; i < photos; i++)
          'http://localhost:8001/api/v1/import/product-images/$i',
      ],
      video: withVideo ? WholesaleVideo.fromJson(_videoJson) : null,
    );

void main() {
  late FakeVideoPlayerPlatform platform;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    await GetStorage.init();
    // Visibilité recalculée à chaque image, sans le délai de production.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(Get.reset);

  group('Modèle', () {
    test('lit la vidéo prête renvoyée par le catalogue', () {
      final product = WholesaleProduct.fromJson({
        'id': 71,
        'name': 'Balle robes',
        'currency': 'XAF',
        'price_tiers': [],
        'video': _videoJson,
      });

      final video = product.video!;
      expect(video.previewUrl, endsWith('/videos/1/preview'));
      expect(video.aspectRatio, closeTo(0.5625, 0.0001));
      expect(video.durationLabel, '0:27');
    });

    test('pas de vidéo, ou pas encore prête : champ vide', () {
      expect(WholesaleVideo.fromJson(null), isNull);
      expect(WholesaleVideo.fromJson({'id': 3, 'url': ''}), isNull);
      expect(
        WholesaleProduct.fromJson({
          'id': 1,
          'name': 'Sans vidéo',
          'currency': 'XAF',
          'price_tiers': [],
        }).video,
        isNull,
      );
    });

    test('sans aperçu dédié, les cartes lisent la version complète', () {
      final video = WholesaleVideo.fromJson({
        'id': 2,
        'url': 'https://x/v.mp4',
      })!;
      expect(video.previewUrl, 'https://x/v.mp4');
      // Format téléphone par défaut quand les dimensions manquent.
      expect(video.aspectRatio, closeTo(9 / 16, 0.0001));
      expect(video.durationLabel, isNull);
    });
  });

  group('Tuile du mur grossiste', () {
    test('prend le format de la vidéo, borné', () {
      expect(wholesaleTileAspectRatio(_product()), closeTo(0.5625, 0.0001));

      final panoramique = WholesaleProduct(
        id: 5,
        name: 'Panoramique',
        currency: 'XAF',
        priceTiers: const [],
        video: WholesaleVideo.fromJson({
          'id': 9,
          'url': 'https://x/v.mp4',
          'width': 2000,
          'height': 500,
        }),
      );
      expect(wholesaleTileAspectRatio(panoramique), 1.25);
    });

    test('sans vidéo, garde le format de mosaïque', () {
      final product = _product(withVideo: false);
      expect(
        wholesaleTileAspectRatio(product),
        masonryAspectRatioFor(product.id),
      );
    });
  });

  group('Coordinateur de lecture', () {
    test('seules les deux cartes les plus visibles jouent', () {
      final coordinator = AutoplayCoordinator();
      final a = _Client('a'), b = _Client('b'), c = _Client('c');

      coordinator.report(a, 0.7);
      coordinator.report(b, 1.0);
      coordinator.report(c, 0.9);

      expect(a.playing, isFalse);
      expect(b.playing, isTrue);
      expect(c.playing, isTrue);

      // b sort de l'écran : a prend sa place.
      coordinator.report(b, 0.1);
      expect(b.playing, isFalse);
      expect(a.playing, isTrue);
    });

    test('une carte à peine visible ne démarre pas', () {
      final coordinator = AutoplayCoordinator();
      final a = _Client('a');
      coordinator.report(a, 0.4);
      expect(a.playing, isFalse);
    });

    test('libère les lecteurs les plus anciens au-delà du quota', () {
      final coordinator = AutoplayCoordinator(maxPlaying: 1, maxAlive: 2);
      final clients = List.generate(4, (i) => _Client('c$i'));

      for (final client in clients) {
        coordinator.report(client, 1.0);
        coordinator.report(client, 0.0); // vue puis dépassée
      }

      expect(clients[0].released, isTrue);
      expect(clients[1].released, isTrue);
      expect(clients[2].released, isFalse);
      expect(clients[3].released, isFalse);
    });
  });

  group('Lecture automatique', () {
    Future<void> pumpTile(WidgetTester tester, {required bool visible}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                if (!visible) const SizedBox(height: 5000),
                SizedBox(
                  width: 200,
                  height: 356,
                  child: AutoplayVideo(
                    url: 'https://x/preview.mp4',
                    poster: const ColoredBox(color: Colors.grey),
                    coordinator: AutoplayCoordinator(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('joue muette et en boucle une fois à l\'écran', (tester) async {
      await pumpTile(tester, visible: true);

      expect(platform.created, 1);
      expect(platform.calls, contains('create https://x/preview.mp4'));
      expect(platform.calls, contains('volume 0 0.0'));
      expect(platform.calls, contains('looping 0 true'));
      expect(platform.isPlaying(0), isTrue);
    });

    testWidgets('hors écran, rien n\'est téléchargé', (tester) async {
      await pumpTile(tester, visible: false);

      expect(platform.created, 0);
    });
  });

  group('Fiche produit', () {
    Future<void> openPage(WidgetTester tester, WholesaleProduct product) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        GetMaterialApp(
          home: WholesaleProductView(
            product: product,
            shippingOptions: const [],
            countryFlag: '🇨🇳',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('la galerie s\'ouvre sur la vidéo, puis les photos', (
      tester,
    ) async {
      await openPage(tester, _product());

      expect(find.byType(ProductGalleryVideo), findsOneWidget);
      // La version complète (avec le son) est lue sur la fiche, muette
      // d'abord. `localhost` est réécrit vers l'hôte de l'API.
      expect(
        platform.calls.where(
          (c) =>
              c.startsWith('create ') &&
              c.endsWith('/api/v1/import/videos/1/video'),
        ),
        hasLength(1),
      );
      expect(platform.calls, contains('volume 0 0.0'));
      expect(platform.isPlaying(0), isTrue);
      expect(find.byTooltip('Activer le son'), findsOneWidget);
      // Le compteur annonce les photos qui suivent.
      expect(find.text('3 photos'), findsOneWidget);

      await tester.tap(find.text('3 photos'));
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
      // La vidéo quittée se met en pause.
      expect(platform.isPlaying(0), isFalse);
    });

    testWidgets('le son s\'active d\'un toucher', (tester) async {
      await openPage(tester, _product());

      await tester.tap(find.byTooltip('Activer le son'));
      await tester.pumpAndSettle();

      expect(platform.calls.last, 'volume 0 1.0');
      expect(find.byTooltip('Couper le son'), findsOneWidget);
    });

    testWidgets('sans vidéo, la galerie reste celle des photos', (
      tester,
    ) async {
      await openPage(tester, _product(withVideo: false));

      expect(find.byType(ProductGalleryVideo), findsNothing);
      expect(platform.created, 0);
      expect(find.text('1/3'), findsOneWidget);
    });
  });
}
