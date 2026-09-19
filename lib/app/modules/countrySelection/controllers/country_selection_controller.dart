import 'package:get/get.dart';

import '../../../core/values/country_catalog.dart';
import '../../../data/models/currency_model.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/currency_service.dart';
import '../../../routes/app_pages.dart';

/// Un pays sélectionnable, avec sa devise et son drapeau.
///
/// Remplace la `Map<String, dynamic>` d'origine : la liste est parcourue à
/// chaque frappe dans la recherche, et un type concret évite autant de casts.
class CountryOption {
  CountryOption({required this.country, required this.currency})
      : flag = CountryCatalog.flagFor(country),
        _searchKey = _normalize(
          '$country ${currency.code} ${currency.name}',
        );

  final String country;
  final CurrencyModel currency;

  /// Drapeau en emoji, vide si le pays n'est pas dans le catalogue.
  final String flag;

  /// Nom, code et libellé de devise, sans accents ni casse : la recherche
  /// compare sur cette clé pour que « senegal » trouve « Sénégal ».
  final String _searchKey;

  /// Nom sans accents ni casse, utilisé pour trier : l'ordre des codes
  /// UTF-16 rejetterait sinon « Égypte » et « États-Unis » après « Zimbabwe ».
  String get sortKey => _normalize(country);

  /// Initiale utilisée pour regrouper la liste ; les accents sont réduits
  /// afin que « Égypte » se range sous « E » et non dans une section à part.
  String get initial {
    final normalized = sortKey;
    return normalized.isEmpty ? '#' : normalized[0].toUpperCase();
  }

  bool matches(String normalizedQuery) => _searchKey.contains(normalizedQuery);

  /// Minuscule sans accents, pour comparer des chaînes saisies au clavier.
  static String _normalize(String input) {
    const accented = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyyoa';

    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = accented.indexOf(char);
      buffer.write(index == -1 ? char : plain[index]);
    }
    return buffer.toString();
  }
}

/// Une section de la liste : une initiale et les pays qu'elle regroupe.
class CountrySection {
  const CountrySection({required this.letter, required this.countries});

  final String letter;
  final List<CountryOption> countries;
}

class CountrySelectionController extends GetxController {
  /// Pays mis en avant au-dessus de la liste : ils couvrent l'essentiel des
  /// utilisateurs et évitent de faire défiler 199 entrées au premier lancement.
  static const List<String> suggestedCountries = [
    'Cameroun',
    "Côte d'Ivoire",
    'Sénégal',
    'France',
    'Bénin',
    'Gabon',
  ];

  final RxList<CountryOption> allCountries = <CountryOption>[].obs;
  final RxList<CountryOption> filteredCountries = <CountryOption>[].obs;
  final RxList<CountrySection> sections = <CountrySection>[].obs;
  final RxList<CountryOption> suggestions = <CountryOption>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString searchQuery = ''.obs;

  /// Vrai tant que l'utilisateur n'a rien tapé : on affiche alors les
  /// suggestions et les en-têtes de section.
  bool get isBrowsing => searchQuery.value.trim().isEmpty;

  @override
  void onInit() {
    super.onInit();
    fetchAllCountriesWithCurrencies();
  }

  /// Charge les pays et leurs devises depuis le backend.
  Future<void> fetchAllCountriesWithCurrencies() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final response = await ApiProvider.get(
        '/v1/currencies/all-with-countries',
      );

      if (!response.success || response.data == null) {
        hasError.value = true;
        return;
      }

      final List currencies = response.data!['data'] as List;
      final options = <CountryOption>[];

      for (final currency in currencies) {
        final currencyModel = CurrencyModel.fromJson(
          currency as Map<String, dynamic>,
        );
        for (final country in currencyModel.countries) {
          options.add(
            CountryOption(country: country, currency: currencyModel),
          );
        }
      }

      // Tri sur la clé normalisée : sinon « Égypte » et « États-Unis » se
      // retrouvent rejetés après « Zimbabwe » par l'ordre des codes UTF-16.
      options.sort((a, b) => a.sortKey.compareTo(b.sortKey));

      allCountries.value = options;
      _applyFilter('');
    } catch (e) {
      hasError.value = true;
      Get.snackbar(
        'Erreur',
        'Impossible de charger la liste des pays',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Filtre la liste sur le nom du pays, le code ou le nom de la devise.
  void filterCountries(String query) {
    searchQuery.value = query;
    _applyFilter(query);
  }

  void _applyFilter(String query) {
    final normalized = CountryOption._normalize(query.trim());

    final matches = normalized.isEmpty
        ? allCountries.toList()
        : allCountries.where((c) => c.matches(normalized)).toList();

    filteredCountries.value = matches;
    sections.value = _groupByInitial(matches);
    suggestions.value = normalized.isEmpty ? _buildSuggestions() : const [];
  }

  /// Regroupe les pays par initiale, en conservant l'ordre déjà trié.
  List<CountrySection> _groupByInitial(List<CountryOption> countries) {
    final grouped = <String, List<CountryOption>>{};
    for (final country in countries) {
      grouped.putIfAbsent(country.initial, () => []).add(country);
    }
    return [
      for (final letter in grouped.keys)
        CountrySection(letter: letter, countries: grouped[letter]!),
    ];
  }

  /// Les pays suggérés, dans l'ordre déclaré, en ignorant ceux que le
  /// backend ne renvoie pas.
  List<CountryOption> _buildSuggestions() {
    final result = <CountryOption>[];
    for (final name in suggestedCountries) {
      final match = allCountries.firstWhereOrNull((c) => c.country == name);
      if (match != null) result.add(match);
    }
    return result;
  }

  /// Enregistre le pays choisi et sa devise, puis poursuit l'onboarding.
  Future<void> selectCountry(CountryOption option) async {
    try {
      isLoading.value = true;
      await CurrencyService.to.setCountryAndCurrency(
        option.country,
        option.currency,
      );
      Get.offAllNamed(Routes.ONBOARDING);
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de définir le pays sélectionné',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
