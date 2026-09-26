import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

import 'package:asso/app/core/utils/address_search.dart';
import 'package:asso/app/modules/storeManagement/controllers/store_management_controller.dart';
import 'package:asso/app/modules/storeManagement/models/store_models.dart';
import 'package:asso/app/modules/storeManagement/views/edit_store_view.dart';

/// Contrôleur sans appel réseau : la boutique est fournie par le test.
class _OfflineStoreController extends StoreManagementController {
  /// Réponse de l'enregistrement simulé.
  bool saveSucceeds = true;

  /// Affiche un snackbar pendant l'enregistrement, comme le fait le vrai
  /// contrôleur (« Succès », « Hors zone de livraison »…).
  bool showsSnackbar = false;

  /// Valeurs reçues au dernier enregistrement.
  Map<String, Object?>? saved;

  @override
  Future<void> loadData() async {}

  @override
  Future<void> loadLocationRequests() async {}

  @override
  Future<void> checkDeliveryAvailability(
    double latitude,
    double longitude,
  ) async {}

  @override
  Future<bool> saveStoreInfo({
    required String name,
    String? description,
    required String address,
    required String city,
    required String phone,
    String? locationCity,
    String? locationCountry,
    double? latitude,
    double? longitude,
    List<String>? categories,
    XFile? logo,
  }) async {
    saved = {
      'description': description,
      'address': address,
      'locationCity': locationCity,
      'locationCountry': locationCountry,
      'latitude': latitude,
      'longitude': longitude,
      'categories': categories,
    };
    if (showsSnackbar) Get.snackbar('Succès', 'Boutique mise à jour');
    return saveSucceeds;
  }
}

/// Boutique déjà placée ([placed]) : son emplacement est en lecture seule.
/// Sinon, premier placement : adresse et repère se modifient librement.
StoreInfo _store({List<String> categories = const [], bool placed = true}) =>
    StoreInfo(
      id: '1',
      name: 'Ma boutique',
      description: 'Boutique high-tech',
      latitude: placed ? 4.05 : 0,
      longitude: placed ? 9.77 : 0,
      address: 'Akwa, Douala',
      city: 'Douala, Cameroun',
      phone: '690000000',
      categories: categories,
    );

/// Ouvre l'écran d'édition par-dessus un écran d'origine, comme depuis
/// « Ma boutique ».
Future<_OfflineStoreController> _openEditor(
  WidgetTester tester, {
  StoreInfo? store,
}) async {
  // Écran large : la police de test dessine chaque lettre en carré plein
  // et ferait déborder les titres de section.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = _OfflineStoreController();
  Get.put<StoreManagementController>(controller);
  controller.storeInfo.value = store ?? _store();

  await tester.pumpWidget(
    const GetMaterialApp(home: Scaffold(body: Text('Ma boutique'))),
  );
  Get.to(() => const EditStoreView());
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _tapSave(WidgetTester tester) async {
  // Clavier et propositions d'adresse refermés, comme quand le vendeur
  // touche le bouton : sinon le panneau qui s'ouvre décale le bouton.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final save = find.text('Enregistrer les modifications');
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Un appui qui manque sa cible fait échouer le test au lieu de passer
    // sans rien vérifier.
    WidgetController.hitTestWarningShouldBeFatal = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    await GetStorage.init();
  });

  tearDown(() {
    Get.reset();
    AddressSearch.newClient = http.Client.new;
  });

  testWidgets('l’adresse saisie survit à l’ouverture et à la fermeture du '
      'clavier', (tester) async {
    await _openEditor(tester, store: _store(placed: false));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Akwa, Douala'),
      'Bonamoussadi, Douala',
    );

    // Le clavier s'ouvre puis se referme (défilement vers « Enregistrer ») :
    // l'écran se reconstruit, l'adresse saisie doit rester.
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    await tester.pump();
    tester.view.resetViewInsets();
    await tester.pump();

    expect(find.text('Bonamoussadi, Douala'), findsOneWidget);
    expect(find.text('Akwa, Douala'), findsNothing);
  });

  testWidgets('le champ en cours de saisie garde le focus quand la boutique '
      'est relue ou pendant l’enregistrement', (tester) async {
    final controller = await _openEditor(tester);
    final nameField = find.byType(TextFormField).first;
    await tester.tap(nameField);
    await tester.enterText(nameField, 'Ma boutique Akwa');
    EditableText editable() => tester.widget<EditableText>(
      find.descendant(of: nameField, matching: find.byType(EditableText)),
    );
    expect(editable().focusNode.hasFocus, isTrue);
    controller.storeInfo.value = StoreInfo(
      id: '1',
      name: 'Ma boutique',
      latitude: 4.05,
      longitude: 9.77,
      address: 'Akwa, Douala',
      city: 'Douala, Cameroun',
      phone: '699999999',
    );
    await tester.pump();
    for (final busy in [controller.isLoading, controller.isSaving]) {
      busy.value = true;
      await tester.pump();
      busy.value = false;
      await tester.pump();
    }

    expect(editable().focusNode.hasFocus, isTrue);
    expect(editable().controller.text, 'Ma boutique Akwa');
  });

  testWidgets('une fois enregistré, l’écran se referme même quand un snackbar '
      'est affiché', (tester) async {
    final controller = await _openEditor(tester);
    controller.showsSnackbar = true;

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(controller.saved, isNotNull);
    // `Get.back()` fermait le snackbar à la place de l'écran : le vendeur
    // restait sur le formulaire et croyait l'enregistrement perdu.
    expect(find.byType(EditStoreView), findsNothing);
    expect(find.text('Ma boutique'), findsOneWidget);

    // Laisse le snackbar se refermer avant la fin du test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('un enregistrement refusé laisse le formulaire en place', (
    tester,
  ) async {
    final controller = await _openEditor(tester, store: _store(placed: false));
    controller.saveSucceeds = false;

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Akwa, Douala'),
      'Bonamoussadi, Douala',
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(controller.saved, isNotNull);
    expect(find.byType(EditStoreView), findsOneWidget);
    expect(find.text('Bonamoussadi, Douala'), findsOneWidget);
  });

  testWidgets('une adresse proposée pendant la saisie place le repère, la '
      'ville et le pays', (tester) async {
    AddressSearch.newClient = () => MockClient(
      (request) async => http.Response.bytes(
        utf8.encode(
          json.encode({
            'features': [
              {
                'type': 'Feature',
                'properties': {
                  'osm_key': 'place',
                  'osm_value': 'city',
                  'name': 'Bafoussam',
                  'state': 'Ouest',
                  'country': 'Cameroun',
                  'countrycode': 'CM',
                },
                'geometry': {
                  'type': 'Point',
                  'coordinates': [10.4176, 5.4781],
                },
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final controller = await _openEditor(tester, store: _store(placed: false));

    final address = find.widgetWithText(TextFormField, 'Akwa, Douala');
    await tester.ensureVisible(address);
    await tester.tap(address);
    await tester.enterText(address, 'Bafou');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final suggestion = find.text('Bafoussam');
    expect(suggestion, findsOneWidget);
    await tester.tap(suggestion);
    await tester.pumpAndSettle();

    expect(find.text('Bafoussam, Cameroun'), findsWidgets);

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(controller.saved?['address'], 'Bafoussam, Cameroun');
    expect(controller.saved?['locationCity'], 'Bafoussam');
    expect(controller.saved?['locationCountry'], 'Cameroun');
    expect(controller.saved?['latitude'], 5.4781);
    expect(controller.saved?['longitude'], 10.4176);
  });

  testWidgets('une boutique placée ne change d’emplacement que par une '
      'demande', (tester) async {
    final controller = await _openEditor(tester);

    // Adresse affichée, plus modifiable dans le formulaire.
    expect(find.widgetWithText(TextFormField, 'Akwa, Douala'), findsNothing);
    expect(find.text('Akwa, Douala'), findsOneWidget);
    expect(find.text('Demander un changement d’emplacement'), findsOneWidget);

    // Demande en cours : son état et « Modifier ma demande ».
    controller.pendingLocationRequest.value = {
      'address': 'Bonamoussadi, Douala',
      'created_at': '2026-09-24T10:00:00Z',
      'status': 'pending',
    };
    await tester.pump();
    expect(find.text('Demande en attente de validation'), findsOneWidget);
    expect(find.text('Modifier ma demande'), findsOneWidget);

    // Le reste du formulaire s'enregistre toujours.
    await _tapSave(tester);
    await tester.pumpAndSettle();
    expect(controller.saved, isNotNull);
  });

  testWidgets('description et catégories peuvent être vidées, et une '
      'catégorie hors catalogue reste visible pour être retirée', (
    tester,
  ) async {
    final controller = await _openEditor(
      tester,
      store: _store(categories: ['Ancienne catégorie']),
    );

    final legacy = find.widgetWithText(FilterChip, 'Ancienne catégorie');
    await tester.ensureVisible(legacy);
    expect(tester.widget<FilterChip>(legacy).selected, isTrue);
    await tester.tap(legacy);
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Boutique high-tech'),
      '',
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(controller.saved?['description'], '');
    expect(controller.saved?['categories'], isEmpty);
  });
}
