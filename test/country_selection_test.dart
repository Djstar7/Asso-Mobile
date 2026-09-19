import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/core/values/country_catalog.dart';
import 'package:asso/app/data/models/currency_model.dart';
import 'package:asso/app/modules/countrySelection/controllers/country_selection_controller.dart';

CurrencyModel _currency(String code, List<String> countries) => CurrencyModel(
      id: 1,
      code: code,
      name: 'Devise $code',
      symbol: code,
      countries: countries,
    );

void main() {
  group('CountryCatalog', () {
    test('rend le drapeau à partir du nom français', () {
      expect(CountryCatalog.flagFor('France'), '🇫🇷');
      expect(CountryCatalog.flagFor('Sénégal'), '🇸🇳');
      expect(CountryCatalog.flagFor("Côte d'Ivoire"), '🇨🇮');
    });

    test('tolère les anciens noms et la casse', () {
      expect(CountryCatalog.flagFor('Ivory Coast'), '🇨🇮');
      expect(CountryCatalog.flagFor('USA'), '🇺🇸');
      expect(CountryCatalog.flagFor('france'), '🇫🇷');
    });

    test('renvoie une chaîne vide pour un pays inconnu', () {
      expect(CountryCatalog.flagFor('Pays imaginaire'), '');
      expect(CountryCatalog.flagFor(''), '');
      expect(CountryCatalog.isoCodeFor('Pays imaginaire'), isNull);
    });

    test('refuse un code ISO mal formé', () {
      expect(CountryCatalog.flagForIsoCode('F'), '');
      expect(CountryCatalog.flagForIsoCode('F1'), '');
      expect(CountryCatalog.flagForIsoCode('fr'), '🇫🇷');
    });
  });

  group('CountryOption', () {
    test('expose le drapeau du pays', () {
      final option = CountryOption(
        country: 'Cameroun',
        currency: _currency('XAF', ['Cameroun']),
      );
      expect(option.flag, '🇨🇲');
    });

    test("range un nom accentué sous l'initiale non accentuée", () {
      final egypte = CountryOption(
        country: 'Égypte',
        currency: _currency('EGP', ['Égypte']),
      );
      expect(egypte.initial, 'E');
    });

    test('la recherche ignore accents et casse', () {
      final senegal = CountryOption(
        country: 'Sénégal',
        currency: _currency('XOF', ['Sénégal']),
      );
      expect(senegal.matches('senegal'), isTrue);
      expect(senegal.matches('sene'), isTrue);
      expect(senegal.matches('xof'), isTrue);
      expect(senegal.matches('mali'), isFalse);
    });
  });

  group('CountrySelectionController', () {
    late CountrySelectionController controller;

    setUp(() {
      controller = CountrySelectionController();
      controller.allCountries.value = [
        CountryOption(
          country: 'Égypte',
          currency: _currency('EGP', ['Égypte']),
        ),
        CountryOption(
          country: 'France',
          currency: _currency('EUR', ['France']),
        ),
        CountryOption(
          country: 'Cameroun',
          currency: _currency('XAF', ['Cameroun']),
        ),
        CountryOption(
          country: 'Sénégal',
          currency: _currency('XOF', ['Sénégal']),
        ),
      ];
    });

    test('sans recherche, la liste est complète et groupée par initiale', () {
      controller.filterCountries('');

      expect(controller.isBrowsing, isTrue);
      expect(controller.filteredCountries.length, 4);
      expect(
        controller.sections.map((s) => s.letter).toList(),
        ['E', 'F', 'C', 'S'],
      );
    });

    test('la recherche filtre sans tenir compte des accents', () {
      controller.filterCountries('senegal');

      expect(controller.isBrowsing, isFalse);
      expect(controller.filteredCountries.single.country, 'Sénégal');
    });

    test('la recherche accepte un code de devise', () {
      controller.filterCountries('eur');
      expect(controller.filteredCountries.single.country, 'France');
    });

    test('les suggestions disparaissent dès qu\'on cherche', () {
      controller.filterCountries('');
      expect(controller.suggestions, isNotEmpty);

      controller.filterCountries('fra');
      expect(controller.suggestions, isEmpty);
    });

    test('les suggestions ignorent un pays absent du backend', () {
      controller.filterCountries('');

      // Seuls Cameroun, Sénégal et France sont chargés ici ; les autres
      // pays suggérés ne doivent pas apparaître.
      expect(
        controller.suggestions.map((s) => s.country).toList(),
        ['Cameroun', 'Sénégal', 'France'],
      );
    });

    test('une fois triée, la liste est alphabétique accents compris', () {
      // Reproduit le tri appliqué au chargement : « Égypte » doit se
      // ranger avec les E, et non après « Zimbabwe ».
      final sorted = controller.allCountries.toList()
        ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

      expect(
        sorted.map((c) => c.country).toList(),
        ['Cameroun', 'Égypte', 'France', 'Sénégal'],
      );
    });

    test('une recherche sans résultat vide la liste', () {
      controller.filterCountries('zzzz');
      expect(controller.filteredCountries, isEmpty);
      expect(controller.sections, isEmpty);
    });
  });
}
