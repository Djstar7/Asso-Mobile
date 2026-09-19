import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/core/widgets/auth_scaffold.dart';
import 'package:asso/app/modules/login/controllers/login_controller.dart';
import 'package:asso/app/modules/login/views/login_view.dart';
import 'package:asso/app/modules/welcomer/controllers/welcomer_controller.dart';
import 'package:asso/app/modules/welcomer/views/welcomer_view.dart';

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

  /// Les deux écrans embarquent une animation Lottie, dont l'horloge ne
  /// s'arrête jamais : on pompe des images comptées plutôt que d'attendre
  /// une stabilisation qui n'arrive pas.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('Connexion', () {
    setUp(() => Get.put(LoginController()));

    testWidgets('propose la visite sans compte', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
      await settle(tester);

      // C'est la demande explicite : pouvoir passer depuis la connexion,
      // et plus seulement depuis l'inscription.
      expect(find.text('Passer'), findsOneWidget);
    });

    testWidgets('affiche titre, champs et action principale', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
      await settle(tester);

      expect(find.text('Bon retour'), findsOneWidget);
      expect(find.text('Adresse e-mail'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    });

    testWidgets('renvoie vers la création de compte', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
      await settle(tester);

      // AuthSwitchLink rend un Text.rich : la question et l'action sont
      // deux portées d'un même widget, d'où la recherche sur le texte rendu.
      expect(
        find.textContaining("S'inscrire", findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('ne déborde pas à la mise en page', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
      await settle(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('garde « Passer » atteignable clavier ouvert', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
      await settle(tester);

      // Le bandeau se replie sous le clavier ; la sortie sans compte ne
      // doit pas disparaître avec lui.
      expect(find.text('Passer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Inscription', () {
    setUp(() => Get.put(WelcomerController()));

    testWidgets('propose aussi la visite sans compte', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: WelcomerView()));
      await settle(tester);

      expect(find.text('Passer'), findsOneWidget);
    });

    testWidgets('affiche le formulaire complet', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: WelcomerView()));
      await settle(tester);

      expect(find.text('Créer votre compte'), findsOneWidget);
      expect(find.text('Confirmer le mot de passe'), findsOneWidget);
      expect(find.text('Créer mon compte'), findsOneWidget);
      expect(
        find.textContaining('Se connecter', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('ne déborde pas à la mise en page', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: WelcomerView()));
      await settle(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('Ossature partagée', () {
    testWidgets('le bouton Passer disparaît sans action fournie', (
      tester,
    ) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: AuthScaffold(
            animationAsset: 'assets/lotties/Ecommerce.json',
            title: 'Titre',
            subtitle: 'Sous-titre',
            children: [],
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Passer'), findsNothing);
      expect(find.text('Titre'), findsOneWidget);
    });
  });
}
