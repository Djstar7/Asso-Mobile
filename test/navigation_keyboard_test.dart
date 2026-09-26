import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/core/widgets/app_sheet.dart';
import 'package:asso/app/core/widgets/app_ui.dart';
import 'package:asso/app/modules/login/controllers/login_controller.dart';
import 'package:asso/app/modules/login/views/login_view.dart';

/// Page empilée minimale : une AppBar portant le bouton retour commun.
class _Pushed extends StatelessWidget {
  const _Pushed({this.guarded = false, this.onBlocked});

  final bool guarded;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Page')),
    );
    if (!guarded) return page;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBlocked?.call();
      },
      child: page,
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    await GetStorage.init();
  });

  tearDown(Get.reset);

  group('Bouton retour', () {
    testWidgets('revient à l’écran précédent', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: Text('Origine'))),
      );
      Get.to(() => const _Pushed());
      await tester.pumpAndSettle();
      expect(find.text('Page'), findsOneWidget);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('Origine'), findsOneWidget);
      expect(find.text('Page'), findsNothing);
    });

    testWidgets('passe par la même garde que le retour système', (
      tester,
    ) async {
      var blocked = 0;
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: Text('Origine'))),
      );
      Get.to(() => _Pushed(guarded: true, onBlocked: () => blocked++));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      // Un brouillon protégé par PopScope ne doit pas être quitté en
      // contournant sa confirmation.
      expect(find.text('Page'), findsOneWidget);
      expect(blocked, 1);
    });

    testWidgets('sans écran précédent, ramène à l’accueil', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/seule',
          getPages: [
            GetPage(
              name: '/home',
              page: () => const Scaffold(body: Text('Accueil')),
            ),
            GetPage(name: '/seule', page: () => const _Pushed()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Ouverte depuis un lien ou une notification : le bouton ne doit pas
      // être une impasse.
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('Accueil'), findsOneWidget);
    });
  });

  group('Clavier', () {
    Widget form(FocusNode focus, VoidCallback onSend) => GetMaterialApp(
      builder: (context, child) => AppKeyboardDismisser(child: child!),
      home: Scaffold(
        body: Column(
          children: [
            TextField(focusNode: focus),
            ElevatedButton(onPressed: onSend, child: const Text('Envoyer')),
            const Expanded(child: SizedBox.expand(key: Key('vide'))),
          ],
        ),
      ),
    );

    testWidgets('se ferme au toucher hors d’un champ', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(form(focus, () {}));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      await tester.tap(find.byKey(const Key('vide')));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('reste ouvert quand on touche un bouton', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var sent = 0;
      await tester.pumpWidget(form(focus, () => sent++));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      await tester.pump();

      // Envoyer un message ne doit pas refermer le clavier entre deux
      // saisies : le bouton garde la priorité sur le toucher.
      expect(sent, 1);
      expect(focus.hasFocus, isTrue);
    });
  });

  group('Feuille modale', () {
    Future<void> openSheet(WidgetTester tester, {int lines = 3}) async {
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: Text('Fond'))),
      );
      AppSheet.show(
        AppSheet(
          title: 'Paiement',
          footer: ElevatedButton(
            onPressed: () {},
            child: const Text('Payer maintenant'),
          ),
          child: Column(
            children: [
              const TextField(),
              for (var i = 0; i < lines; i++)
                const SizedBox(height: 80, child: Text('Ligne')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('garde l’action principale au-dessus du clavier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.reset);

      await openSheet(tester, lines: 10);

      final screenHeight = tester.view.physicalSize.height / 3;
      final keyboardTop = screenHeight - 900 / 3;
      final button = tester.getRect(find.text('Payer maintenant'));

      expect(button.bottom, lessThanOrEqualTo(keyboardTop));
      expect(tester.takeException(), isNull);
    });

    testWidgets('s’arrête sous la barre d’état, même au contenu long', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 132);
      addTearDown(tester.view.reset);

      await openSheet(tester, lines: 40);

      final sheetTop = tester.getTopLeft(find.byType(AppSheet)).dy;
      expect(sheetTop, greaterThanOrEqualTo(132 / 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('se referme avec sa croix', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSheet), findsNothing);
    });
  });

  group('Connexion ouverte par-dessus un écran', () {
    setUp(() => Get.put(LoginController()));

    // L'animation Lottie ne s'arrête jamais : on pompe des images comptées.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('propose de revenir à l’écran d’origine', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: Text('Fiche produit'))),
      );
      Get.to(() => const LoginView());
      await settle(tester);

      expect(find.byTooltip('Retour'), findsOneWidget);
    });

    testWidgets('n’affiche pas de retour en premier écran', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
      await settle(tester);

      expect(find.byTooltip('Retour'), findsNothing);
    });
  });
}
