import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/core/widgets/masonry_grid.dart';
import 'package:asso/app/core/widgets/masonry_product_tile.dart';
import 'package:asso/app/core/widgets/product_video_player.dart';
import 'package:asso/app/data/models/wholesale_models.dart';
import 'package:asso/app/modules/search/controllers/search_controller.dart'
    as search_ctrl;

Map<String, dynamic> _local(int id) => {'id': id, 'name': 'Produit $id'};

search_ctrl.SearchWholesaleEntry _wholesale(
  int id, {
  String country = 'CN',
  bool withVideo = false,
}) {
  return search_ctrl.SearchWholesaleEntry(
    product: WholesaleProduct.fromJson({
      'id': id,
      'name': 'Lot $id',
      'origin_country': country,
      'currency': 'XAF',
      'price_tiers': const [],
      'video': withVideo
          ? {
              'id': id,
              'url': 'https://x/$id.mp4',
              'preview_url': 'https://x/$id-preview.mp4',
              'width': 576,
              'height': 1024,
              'duration': 27,
            }
          : null,
    }),
    countryFlag: '🏳️',
    shippingOptions: const [],
  );
}

/// Identifiants du mur, préfixés : `p` local, `w` gros.
List<String> _ids(List<search_ctrl.SearchFeedItem> feed) => [
  for (final item in feed)
    switch (item) {
      search_ctrl.LocalFeedItem(:final product) => 'p${product['id']}',
      search_ctrl.WholesaleFeedItem(:final entry) => 'w${entry.product.id}',
    },
];

void main() {
  group('Mélange du mur', () {
    test('un article de gros après chaque groupe de trois produits', () {
      final feed = search_ctrl.mixSearchFeed(
        [for (var i = 1; i <= 7; i++) _local(i)],
        [_wholesale(100), _wholesale(101), _wholesale(102)],
        localComplete: false,
      );

      expect(_ids(feed), [
        'p1', 'p2', 'p3', 'w100', //
        'p4', 'p5', 'p6', 'w101', //
        'p7',
      ]);
    });

    test('le reste du gros attend la fin du catalogue local', () {
      final local = [_local(1), _local(2)];
      final wholesale = [_wholesale(100), _wholesale(101)];

      // Des pages locales restent à charger : les poser maintenant les
      // séparerait des produits qui vont arriver.
      expect(
        _ids(search_ctrl.mixSearchFeed(local, wholesale, localComplete: false)),
        ['p1', 'p2'],
      );
      expect(
        _ids(search_ctrl.mixSearchFeed(local, wholesale, localComplete: true)),
        ['p1', 'p2', 'w100', 'w101'],
      );
    });

    test('recherche sans résultat local : le gros seul', () {
      final feed = search_ctrl.mixSearchFeed(const [], [
        _wholesale(100),
      ], localComplete: true);
      expect(_ids(feed), ['w100']);
    });

    test('une page de plus prolonge le mur sans déplacer les tuiles', () {
      // Une tuile déplacée sous le doigt, c'est une vidéo qui saute d'une
      // colonne à l'autre pendant le défilement.
      final wholesale = [for (var i = 100; i < 110; i++) _wholesale(i)];
      final firstPage = [for (var i = 1; i <= 20; i++) _local(i)];
      final twoPages = [for (var i = 1; i <= 40; i++) _local(i)];

      final before = _ids(
        search_ctrl.mixSearchFeed(firstPage, wholesale, localComplete: false),
      );
      final after = _ids(
        search_ctrl.mixSearchFeed(twoPages, wholesale, localComplete: false),
      );

      expect(after.take(before.length), before);
    });
  });

  group('Ordre du gros', () {
    test('les vidéos d’abord, puis un pays après l’autre', () {
      final ordered = search_ctrl.interleaveWholesale([
        [_wholesale(1), _wholesale(2, withVideo: true), _wholesale(3)],
        [
          _wholesale(10, country: 'TR'),
          _wholesale(11, country: 'TR', withVideo: true),
        ],
      ]);

      expect(ordered.map((e) => e.product.id), [2, 11, 1, 10, 3]);
    });
  });

  group('Gros et filtres', () {
    late search_ctrl.SearchController controller;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '.',
          );
      await GetStorage.init();
    });

    setUp(() => controller = search_ctrl.SearchController());
    tearDown(Get.reset);

    test('présent sur le mur par défaut', () {
      expect(controller.wholesaleApplies, isTrue);
    });

    test('écarté par une catégorie : il n’en a aucune du catalogue local', () {
      controller.selectedCategoryId.value = 4;
      expect(controller.wholesaleApplies, isFalse);
    });

    test('écarté par un filtre de prix en FCFA', () {
      controller.currentMaxPrice.value = 20000;
      expect(controller.wholesaleApplies, isFalse);
    });

    test('écarté par un tri sur le prix', () {
      controller.sortBy.value = 'price';
      controller.sortOrder.value = 'asc';
      expect(controller.wholesaleApplies, isFalse);
    });

    test('masqué du mur dès qu’il ne s’applique plus', () {
      controller.searchQuery.value = 'robe';
      final wall = controller.wall;
      wall.products.assignAll([_local(1)]);
      wall.wholesale.assignAll([_wholesale(100)]);
      wall.hasMore.value = false;

      expect(_ids(controller.feed), ['p1', 'w100']);

      controller.selectedCategoryId.value = 4;
      expect(_ids(controller.feed), ['p1']);
    });

    test('un texte dont les résultats n’ont pas été reçus est en attente', () {
      controller.searchQuery.value = 'robe';
      expect(controller.isSearchPending, isTrue);

      controller.wall.query.value = 'robe';
      expect(controller.isSearchPending, isFalse);
    });
  });

  group('Tuile du mur', () {
    Widget host(Widget sliver) => MaterialApp(
      home: MediaQuery(
        // Animations réduites : la tuile vidéo ne montre que son affiche,
        // sans ouvrir de lecteur.
        data: const MediaQueryData(
          size: Size(360, 800),
          disableAnimations: true,
        ),
        child: Scaffold(body: CustomScrollView(slivers: [sliver])),
      ),
    );

    testWidgets('titre long et méta tiennent dans une colonne étroite', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SliverMasonryGrid(
            itemCount: 4,
            itemBuilder: (_, i) => MasonryProductTile(
              aspectRatio: masonryAspectRatioFor(i),
              image: const MasonryTileImage(url: null),
              name:
                  'Robe longue en wax imprimé, coupe évasée, taille unique ' *
                  2,
              price: '12 500 FCFA',
              meta: 'Akwa, Douala, Cameroun — boutique principale',
              metaIcon: Icons.location_on_outlined,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Rendu paresseux : seules les tuiles à l'écran sont construites.
      expect(find.byType(MasonryProductTile), findsWidgets);
    });

    testWidgets('une vidéo garde son format et annonce sa durée', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SliverToBoxAdapter(
            child: SizedBox(
              width: 180,
              child: MasonryProductTile(
                aspectRatio: masonryVideoAspectRatio(576 / 1024),
                image: const MasonryTileImage(url: null),
                videoUrl: 'https://x/preview.mp4',
                videoDurationLabel: '0:27',
                name: 'Lot de sacs',
                price: '3 000 FCFA',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VideoDurationPill), findsOneWidget);
      expect(find.text('0:27'), findsOneWidget);

      final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ratio.aspectRatio, closeTo(576 / 1024, 0.001));
    });

    test('une vidéo très étirée est bornée', () {
      expect(masonryVideoAspectRatio(0.3), 9 / 16);
      expect(masonryVideoAspectRatio(3), 1.25);
    });
  });
}
