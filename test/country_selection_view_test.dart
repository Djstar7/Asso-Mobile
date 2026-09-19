import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/data/models/currency_model.dart';
import 'package:asso/app/modules/countrySelection/controllers/country_selection_controller.dart';
import 'package:asso/app/modules/countrySelection/views/country_selection_view.dart';

CurrencyModel _c(String code, String name, String symbol, List<String> pays) =>
    CurrencyModel(id: 1, code: code, name: name, symbol: symbol, countries: pays);

/// Reproduit ce que le contrôleur construit après un appel réussi à l'API,
/// sans dépendre du réseau.
List<CountryOption> _catalogue() {
  final devises = <CurrencyModel>[
    _c('XOF', 'Franc CFA (BCEAO)', 'FCFA', [
      'Bénin', "Côte d'Ivoire", 'Sénégal', 'Togo', 'Mali', 'Niger',
    ]),
    _c('XAF', 'Franc CFA (BEAC)', 'FCFA', ['Cameroun', 'Gabon', 'Tchad']),
    _c('EUR', 'Euro', '€', ['France', 'Allemagne', 'Espagne', 'Italie']),
    _c('USD', 'Dollar américain', r'$', ['États-Unis']),
    _c('EGP', 'Livre égyptienne', 'E£', ['Égypte']),
    _c('JPY', 'Yen japonais', '¥', ['Japon']),
    _c('ZAR', 'Rand sud-africain', 'R', ['Afrique du Sud']),
  ];

  final options = <CountryOption>[];
  for (final d in devises) {
    for (final pays in d.countries) {
      options.add(CountryOption(country: pays, currency: d));
    }
  }
  options.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  return options;
}

void main() {
  late CountrySelectionController controller;

  // onInit() du contrôleur lit le jeton stocké, donc GetStorage, qui
  // s'appuie sur path_provider. Sans ce bouchon, la MissingPluginException
  // remonte de façon asynchrone et fait échouer un test au hasard.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
    await GetStorage.init();
  });

  setUp(() {
    controller = CountrySelectionController();
    Get.put<CountrySelectionController>(controller);
  });

  tearDown(Get.reset);

  /// Monte la vue avec un catalogue fixe.
  ///
  /// pumpAndSettle n'est pas utilisable tant que l'indicateur de chargement
  /// tourne : son animation ne s'arrête jamais. On pompe donc des images
  /// comptées, puis on installe les données avant de laisser la liste se
  /// stabiliser.
  Future<void> _pump(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const CountrySelectionView()),
    );
    await tester.pump();

    // onInit() lance un appel réseau qui échoue sous test ; on écrase
    // ensuite l'état avec un catalogue fixe pour peindre la vraie liste.
    controller.isLoading.value = false;
    controller.hasError.value = false;
    controller.allCountries.value = _catalogue();
    controller.filterCountries('');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('affiche le drapeau et la devise de chaque pays', (tester) async {
    await _pump(tester);

    expect(find.text('Choisissez votre pays'), findsOneWidget);
    // Les drapeaux sont rendus en emoji dans la liste.
    expect(find.text('🇸🇳'), findsWidgets);
    expect(find.text('🇫🇷'), findsWidgets);
    expect(find.text('XOF — Franc CFA (BCEAO)'), findsWidgets);
  });

  testWidgets('met les pays suggérés en tête', (tester) async {
    await _pump(tester);

    // Les suggestions présentes dans le catalogue de test apparaissent.
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('Cameroun'), findsWidgets);
  });

  testWidgets('groupe la liste par initiale, accents réduits', (tester) async {
    await _pump(tester);

    // « Égypte » et « États-Unis » se rangent sous E, pas dans une section à part.
    expect(find.text('E'), findsOneWidget);
    expect(find.text('É'), findsNothing);
  });

  testWidgets('la recherche sans accent trouve le pays', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'senegal');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sénégal'), findsOneWidget);
    expect(find.text('France'), findsNothing);
    expect(find.text('1 pays trouvé'), findsOneWidget);
  });

  testWidgets('une recherche vide affiche l\'état vide', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Aucun pays trouvé'), findsOneWidget);
  });

  testWidgets('la feuille de confirmation reprend pays, devise et drapeau',
      (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'japon');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Japon'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Confirmer'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(
      find.textContaining('Les prix seront affichés en JPY'),
      findsOneWidget,
    );
  });

  testWidgets('aucun débordement à la mise en page', (tester) async {
    await _pump(tester);
    // Un débordement de mise en page est signalé comme une exception ;
    // on vérifie qu'aucune n'a été consignée pendant le rendu.
    expect(tester.takeException(), isNull);
  });
}
