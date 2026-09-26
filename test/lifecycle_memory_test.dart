import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:asso/app/core/utils/app_binding.dart';
import 'package:asso/app/core/utils/app_navigation.dart';
import 'package:asso/app/core/utils/cover_resize_image.dart';
import 'package:asso/app/core/utils/route_stack_guard.dart';
import 'package:asso/app/core/widgets/autoplay_video.dart';
import 'package:asso/app/core/widgets/scoped_controller_page.dart';

class _Client implements AutoplayClient {
  bool playing = false;
  bool released = false;

  @override
  void setShouldPlay(bool shouldPlay) => playing = shouldPlay;

  @override
  void release() => released = true;
}

class _PageController extends GetxController {
  _PageController(this.label);
  final String label;
  bool closed = false;

  @override
  void onClose() {
    closed = true;
    super.onClose();
  }
}

void main() {
  group('Décodage à la taille de la case', () {
    test('une photo 12 Mpx en vignette est décodée à la taille de la case', () {
      // 4000 × 3000 (paysage) dans une case portrait de 540 × 675 px.
      final size = CoverResizeImage.coverSize(4000, 3000, 540, 675);

      // La hauteur couvre la case, la largeur suit les proportions : ni
      // flou (agrandissement), ni pleine résolution.
      expect(size.height, 675);
      expect(size.width, 900);
    });

    test('une photo portrait couvre la case par sa largeur', () {
      final size = CoverResizeImage.coverSize(3000, 4000, 540, 675);
      expect(size.width, 540);
      expect(size.height, 720);
    });

    test('une petite image n’est jamais agrandie', () {
      final size = CoverResizeImage.coverSize(300, 200, 540, 675);
      expect(size.width, isNull);
      expect(size.height, isNull);
    });
  });

  group('Plafond global de décodage', () {
    test('une image sans taille demandée est ramenée au plafond', () {
      final size = AppBinding.cappedSize(
        const ui.TargetImageSize(),
        4000,
        3000,
      );
      expect(size.width, AppBinding.maxDecodedDimension);
      expect(size.height, isNull);
    });

    test('une image portrait est plafonnée par sa hauteur', () {
      final size = AppBinding.cappedSize(
        const ui.TargetImageSize(),
        3000,
        4000,
      );
      expect(size.width, isNull);
      expect(size.height, AppBinding.maxDecodedDimension);
    });

    test('une taille demandée explicitement est respectée', () {
      final size = AppBinding.cappedSize(
        const ui.TargetImageSize(width: 2400),
        4000,
        3000,
      );
      expect(size.width, 2400);
    });

    test('une image déjà petite reste intacte', () {
      final size = AppBinding.cappedSize(
        const ui.TargetImageSize(),
        1200,
        900,
      );
      expect(size.width, isNull);
      expect(size.height, isNull);
    });
  });

  group('Lecteurs vidéo en mémoire faible', () {
    test('releaseIdle ferme les lecteurs à l’arrêt, garde ceux qui jouent', () {
      final coordinator = AutoplayCoordinator(maxPlaying: 1, maxAlive: 4);
      final a = _Client();
      final b = _Client();

      coordinator.report(a, 1.0);
      coordinator.report(b, 0.9); // b perd face à a : ouvert mais à l’arrêt
      coordinator.report(b, 1.0); // b passe devant : a s’arrête
      coordinator.report(a, 0.0);

      coordinator.releaseIdle();

      expect(a.released, isTrue);
      expect(b.released, isFalse);
      expect(b.playing, isTrue);
    });
  });

  group('Contrôleur propre à chaque page', () {
    tearDown(Get.reset);

    testWidgets('deux pages empilées ont chacune leur contrôleur', (
      tester,
    ) async {
      final built = <_PageController>[];
      Widget page(String label) => ScopedControllerPage<_PageController>(
        create: () => _PageController(label),
        builder: (controller) {
          built.add(controller);
          return Scaffold(body: Text(controller.label));
        },
      );

      await tester.pumpWidget(
        GetMaterialApp(home: const Scaffold(body: Text('Accueil'))),
      );

      Get.to(() => page('A'), preventDuplicates: false);
      await tester.pumpAndSettle();
      Get.to(() => page('B'), preventDuplicates: false);
      await tester.pumpAndSettle();

      final a = built.firstWhere((c) => c.label == 'A');
      final b = built.firstWhere((c) => c.label == 'B');
      expect(identical(a, b), isFalse);

      // Fermer B libère B, pas A, qui reste affiché et utilisable.
      Get.back();
      await tester.pumpAndSettle();
      expect(b.closed, isTrue);
      expect(a.closed, isFalse);
      expect(find.text('A'), findsOneWidget);

      Get.back();
      await tester.pumpAndSettle();
      expect(a.closed, isTrue);
      expect(find.text('Accueil'), findsOneWidget);
    });
  });

  group('Profondeur de la pile', () {
    tearDown(Get.reset);

    testWidgets('les rebonds produit → produit ne s’empilent pas sans fin', (
      tester,
    ) async {
      final guard = RouteStackGuard(maxPages: 5);
      await tester.pumpWidget(
        GetMaterialApp(
          home: const Scaffold(body: Text('Accueil')),
          navigatorObservers: [guard],
          getPages: [
            GetPage(
              name: '/product',
              page: () => Scaffold(body: Text('Produit ${Get.arguments}')),
            ),
          ],
        ),
      );

      for (var i = 1; i <= 12; i++) {
        Get.toNamed('/product', arguments: i, preventDuplicates: false);
        await tester.pumpAndSettle();
      }

      expect(guard.pageCount, lessThanOrEqualTo(5));
      expect(find.text('Produit 12'), findsOneWidget);

      // Les retours redescendent les fiches récentes, puis l'accueil,
      // jamais retiré : la pile ne se vide jamais.
      for (var i = 0; i < 10; i++) {
        Get.back();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Accueil'), findsOneWidget);
    });
  });

  group('Fermeture d’une page après une attente', () {
    tearDown(Get.reset);

    testWidgets('ferme le dialogue ouvert par-dessus puis la page', (
      tester,
    ) async {
      late BuildContext pageContext;
      Object? result;
      await tester.pumpWidget(
        GetMaterialApp(home: const Scaffold(body: Text('Accueil'))),
      );

      Get.to<Object?>(
        () => Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('Paiement'));
          },
        ),
      )!.then((value) => result = value);
      await tester.pumpAndSettle();

      // « Annuler ? » ouvert quand le paiement aboutit : il attend un bool.
      showDialog<bool>(
        context: pageContext,
        builder: (_) => const AlertDialog(content: Text('Annuler ?')),
      );
      await tester.pumpAndSettle();

      AppNavigation.closeRoute(pageContext, {'success': true});
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Accueil'), findsOneWidget);
      expect(result, {'success': true});
    });

    testWidgets('ne ferme rien si la page est déjà en train de partir', (
      tester,
    ) async {
      late BuildContext pageContext;
      await tester.pumpWidget(
        GetMaterialApp(home: const Scaffold(body: Text('Accueil'))),
      );
      Get.to(
        () => Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('Boutique'));
          },
        ),
      );
      await tester.pumpAndSettle();

      Get.back(); // retour pressé pendant l'enregistrement
      await tester.pump(const Duration(milliseconds: 50));
      AppNavigation.closeRoute(pageContext);
      await tester.pumpAndSettle();

      // L'accueil, en dessous, n'a pas été fermé à sa place.
      expect(find.text('Accueil'), findsOneWidget);
    });
  });
}
