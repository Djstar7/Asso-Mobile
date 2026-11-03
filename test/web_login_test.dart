import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:asso/app/core/values/constants.dart';
import 'package:asso/app/modules/vendorWeb/views/vendor_web_shell.dart';
import 'package:asso/app/modules/webLogin/controllers/web_login_controller.dart';
import 'package:asso/app/routes/app_pages.dart';

void main() {
  group('QR de connexion', () {
    final code = 'a1B2' * 16;

    test('seul un QR ASSO donne un code', () {
      expect(
        WebLoginController.codeFromQr('${AppConstants.webLoginQrPrefix}$code'),
        code,
      );
      expect(
        WebLoginController.codeFromQr(
          '  ${AppConstants.webLoginQrPrefix}$code\n',
        ),
        code,
      );
    });

    test('tout autre contenu est ignoré', () {
      for (final raw in [
        'https://asso-dashboard.sbs/vendor',
        'https://evil.test/${AppConstants.webLoginQrPrefix}$code',
        code,
        '${AppConstants.webLoginQrPrefix}trop-court',
        '${AppConstants.webLoginQrPrefix}${'a' * 200}',
        '${AppConstants.webLoginQrPrefix}$code;autre',
        '',
      ]) {
        expect(WebLoginController.codeFromQr(raw), isNull, reason: raw);
      }
    });

    test('le préfixe n’est pas une adresse ouvrable par un autre lien', () {
      expect(AppConstants.webLoginQrPrefix, isNot(startsWith('http')));
      expect(AppConstants.webLoginQrPrefix, isNot(contains('//')));
    });
  });

  group('Barre latérale de l’espace web', () {
    Future<void> pump(WidgetTester tester, {required Size size}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      VendorWebRouteObserver.current.value = '';

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: Routes.VENDOR_DASHBOARD,
          getPages: [
            GetPage(
              name: Routes.VENDOR_DASHBOARD,
              page: () => const Scaffold(body: Text('tableau')),
            ),
            GetPage(
              name: Routes.LOGIN,
              page: () => const Scaffold(body: Text('connexion')),
            ),
          ],
          navigatorObservers: [VendorWebRouteObserver()],
          builder: (context, child) =>
              VendorWebShell(child: child ?? const SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('présente et sans infobulle sur grand écran', (tester) async {
      await pump(tester, size: const Size(1400, 900));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
      // Cette barre est au-dessus du navigateur : un Tooltip y lèverait
      // « No Overlay widget found » et le toucher serait perdu.
      expect(
        find.ancestor(
          of: find.byIcon(Icons.logout_rounded),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
    });

    testWidgets('absente sur petit écran', (tester) async {
      await pump(tester, size: const Size(600, 900));

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('tableau'), findsOneWidget);
    });

    testWidgets('absente sur la page de connexion', (tester) async {
      await pump(tester, size: const Size(1400, 900));

      Get.offAllNamed(Routes.LOGIN);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('connexion'), findsOneWidget);
    });
  });
}
