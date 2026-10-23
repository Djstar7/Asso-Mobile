import 'dart:convert';
import 'dart:io';

import 'package:asso/app/data/models/real_estate_models.dart';
import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/modules/immo/views/immo_listing_view.dart';
import 'package:asso/app/modules/immo/widgets/immo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory storageDirectory;
  final data = <String, dynamic>{
    'id': 1,
    'type': 'land',
    'title': 'Terrain à vendre',
    'city': 'Yaoundé',
    'price': 40000000,
    'reference': 'TER-TEST',
    'units_available': 1,
    'cabinet': {
      'id': 8,
      'name': 'PARTENAIRE-PRIVE',
      'logo_url': 'https://example.com/private-logo.png',
    },
    'commission_cabinet': {
      'id': 8,
      'name': 'PARTENAIRE-PRIVE',
      'logo_url': 'https://example.com/private-logo.png',
    },
  };
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp(
      'asso-immo-privacy-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storageDirectory.path,
        );
    await GetStorage.init();
  });
  tearDownAll(() => storageDirectory.delete(recursive: true));
  tearDown(Get.reset);

  testWidgets(
    'la carte terrain masque même un partenaire présent dans une ancienne réponse API',
    (tester) async {
      Get.put(CurrencyService());
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ImmoLandCard(
                listing: RealEstateListing.fromJson(data),
                onTap: () {},
                onFavorite: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yaoundé'), findsOneWidget);
      expect(find.text('PARTENAIRE-PRIVE'), findsNothing);
      expect(find.byType(ImmoCabinetLogo), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la fiche terrain ne présente plus la carte du partenaire', (
    tester,
  ) async {
    Get.put(CurrencyService());
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'success': true, 'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const GetMaterialApp(home: ImmoListingView(listingId: 1)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Terrain à vendre'), findsWidgets);
      expect(find.text('PARTENAIRE-PRIVE'), findsNothing);
      expect(find.byType(ImmoCabinetLogo), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
