import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:asso/app/data/providers/api_provider.dart';
import 'package:asso/app/data/services/deep_link_service.dart';
import 'package:asso/app/routes/app_pages.dart';

ApiResponse _ok(Map<String, dynamic> data) =>
    ApiResponse(success: true, message: '', statusCode: 200, data: data);

ApiResponse _failed(int status) =>
    ApiResponse(success: false, message: '', statusCode: status);

final _uri = Uri.parse('https://asso-dashboard.sbs/produit/7');

Future<void> _pumpApp(
  WidgetTester tester, {
  String initialRoute = Routes.HOME,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: initialRoute,
      navigatorObservers: [DeepLinkRouteObserver()],
      getPages: [
        GetPage(name: Routes.HOME, page: () => const Text('accueil')),
        GetPage(name: Routes.PRODUCT, page: () => const Text('fiche')),
        GetPage(
          name: Routes.VENDOR_DETAILS,
          page: () => const Text('boutique'),
        ),
        GetPage(
          name: Routes.PREFERENCES,
          page: () => const Text('preferences'),
        ),
        GetPage(name: Routes.WELCOMER, page: () => const Text('bienvenue')),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

/// Aucun lien venu du système : seuls les touchers nous intéressent ici.
class _NoSystemLinks implements AppLinks {
  @override
  Stream<Uri> get uriLinkStream => const Stream.empty();

  @override
  Future<Uri?> getInitialLink() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  testWidgets('ouvre la fiche sur un écran au repos, sans autre toucher', (
    tester,
  ) async {
    await _pumpApp(tester);
    final service = DeepLinkService(
      appLinks: _NoSystemLinks(),
      loadProduct: (_) async => _ok({
        'product': {'id': 7},
      }),
    );
    await service.start();

    await service.handleExternal(_uri);

    // Aucune image entre les deux : c'est ce qui bloquait la fiche.
    expect(Get.currentRoute, Routes.PRODUCT);
    await tester.pumpAndSettle();
    expect(find.text('fiche'), findsOneWidget);
  });

  testWidgets('rouvrir la même annonce aussitôt après le retour fonctionne', (
    tester,
  ) async {
    await _pumpApp(tester);
    var loads = 0;
    final service = DeepLinkService(
      appLinks: _NoSystemLinks(),
      loadProduct: (_) async {
        loads++;
        return _ok({
          'product': {'id': 7},
        });
      },
    );
    await service.start();

    await service.handleExternal(_uri);
    await tester.pumpAndSettle();
    Get.back();
    await tester.pumpAndSettle();
    await service.handleExternal(_uri);
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(Get.currentRoute, Routes.PRODUCT);
  });

  testWidgets('un produit importé passe par le catalogue gros', (tester) async {
    await _pumpApp(tester);
    Map<String, dynamic>? opened;
    final service = DeepLinkService(
      appLinks: _NoSystemLinks(),
      loadProduct: (_) async => _failed(404),
      loadWholesaleProduct: (_) async => _ok({
        'product': {'id': 7},
        'shipping_options': [],
      }),
      wholesaleOpener: (body) async =>
          () => opened = body,
    );
    await service.start();

    await service.handleExternal(_uri);
    await tester.pumpAndSettle();

    expect(opened?['product'], {'id': 7});
  });

  testWidgets('une panne réseau ne cherche pas ailleurs et n’ouvre rien', (
    tester,
  ) async {
    await _pumpApp(tester);
    var wholesaleLoads = 0;
    final service = DeepLinkService(
      appLinks: _NoSystemLinks(),
      loadProduct: (_) async => _failed(0),
      loadWholesaleProduct: (_) async {
        wholesaleLoads++;
        return _failed(404);
      },
    );
    await service.start();

    await service.handleExternal(_uri);
    await tester.pump();

    expect(wholesaleLoads, 0);
    expect(Get.currentRoute, Routes.HOME);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('le chargeur est refermé une fois la fiche ouverte', (
    tester,
  ) async {
    await _pumpApp(tester);
    final service = DeepLinkService(
      appLinks: _NoSystemLinks(),
      loadProduct: (_) async => _ok({
        'product': {'id': 7},
      }),
    );
    await service.start();

    await service.handleExternal(_uri);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('fiche'), findsOneWidget);
  });

  testWidgets('une boutique s’ouvre par /b/{id}', (tester) async {
    await _pumpApp(tester);
    final service = DeepLinkService(appLinks: _NoSystemLinks());
    Get.put<DeepLinkService>(service);
    await service.start();

    await service.handleExternal(Uri.parse('https://asso-dashboard.sbs/b/12'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.VENDOR_DETAILS);
  });

  testWidgets('le lien attend la fin des écrans de mise en route', (
    tester,
  ) async {
    await _pumpApp(tester, initialRoute: Routes.PREFERENCES);
    final service = DeepLinkService(
      appLinks: _NoSystemLinks(),
      loadProduct: (_) async => _ok({
        'product': {'id': 7},
      }),
    );
    Get.put<DeepLinkService>(service);
    await service.start();

    await service.handleExternal(_uri);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.PREFERENCES);
    expect(service.hasPendingLink, isTrue);

    Get.offAllNamed(Routes.HOME);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.PRODUCT);
    expect(service.hasPendingLink, isFalse);
    // Le retour ramène à l'accueil, pas à la mise en route.
    Get.back();
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.HOME);
  });

  testWidgets('sur l’accueil de bienvenue, un visiteur entre en invité', (
    tester,
  ) async {
    await _pumpApp(tester, initialRoute: Routes.WELCOMER);
    var guestEntries = 0;
    final service = DeepLinkService(
      appLinks: _NoSystemLinks(),
      loadProduct: (_) async => _ok({
        'product': {'id': 7},
      }),
      enterAsGuest: () async {
        guestEntries++;
        Get.offAllNamed(Routes.HOME);
      },
    );
    Get.put<DeepLinkService>(service);
    await service.start();

    await service.handleExternal(_uri);
    await tester.pumpAndSettle();

    expect(guestEntries, 1);
    expect(Get.currentRoute, Routes.PRODUCT);
  });

  testWidgets('le lien le plus récent l’emporte pendant un chargement', (
    tester,
  ) async {
    await _pumpApp(tester);
    final loads = <int>[];
    final first = Completer<ApiResponse>();
    final service = DeepLinkService(
      appLinks: _NoSystemLinks(),
      loadProduct: (id) {
        loads.add(id);
        return id == 7
            ? first.future
            : Future.value(
                _ok({
                  'product': {'id': id},
                }),
              );
      },
    );
    await service.start();

    unawaited(service.handleExternal(_uri));
    await tester.pump();
    unawaited(
      service.handleExternal(Uri.parse('https://asso-dashboard.sbs/p/8')),
    );
    await tester.pump();
    first.complete(
      _ok({
        'product': {'id': 7},
      }),
    );
    await tester.pumpAndSettle();

    expect(loads, [7, 8]);
  });

  test('seuls les liens du domaine et les bons chemins sont acceptés', () {
    bool ok(String url) => DeepLinkService.isShareLink(Uri.parse(url));

    expect(ok('https://asso-dashboard.sbs/p/1'), isTrue);
    expect(ok('https://asso-dashboard.sbs/b/1'), isTrue);
    expect(ok('https://asso-dashboard.sbs/produit/1'), isTrue);
    expect(ok('assomarket://asso-dashboard.sbs/p/1'), isTrue);

    expect(ok('https://evil.test/p/1'), isFalse);
    expect(ok('http://asso-dashboard.sbs/p/1'), isFalse);
    expect(ok('evil://asso-dashboard.sbs/p/1'), isFalse);
    expect(ok('https://asso-dashboard.sbs/p/abc'), isFalse);
    expect(ok('https://asso-dashboard.sbs/p/1/x'), isFalse);
    expect(ok('https://asso-dashboard.sbs/admin/login'), isFalse);
    expect(ok('assomarket://asso-dashboard.sbs/wallet/1'), isFalse);
  });

  test('Flutter ne traite pas les liens à la place du service', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      allOf(
        contains(
          'android:name="flutter_deeplinking_enabled" android:value="false"',
        ),
        contains('android:pathPrefix="/p/"'),
        contains('android:pathPrefix="/b/"'),
        isNot(contains('android:pathPrefix="/produit"')),
      ),
    );
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      allOf(
        matches(RegExp(r'FlutterDeepLinkingEnabled</key>\s*<false/>')),
        contains('<string>assomarket</string>'),
      ),
    );
  });
}
