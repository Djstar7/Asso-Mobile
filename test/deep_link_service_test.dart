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

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: Routes.HOME,
      getPages: [
        GetPage(name: Routes.HOME, page: () => const Text('accueil')),
        GetPage(name: Routes.PRODUCT, page: () => const Text('fiche')),
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
}
