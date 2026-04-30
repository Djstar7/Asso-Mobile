import 'package:get/get.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/models/currency_model.dart';
import '../../../routes/app_pages.dart';

class CountrySelectionController extends GetxController {
  final RxList<Map<String, dynamic>> allCountries = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredCountries = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final Rx<CurrencyModel?> selectedCurrency = Rx<CurrencyModel?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchAllCountriesWithCurrencies();
  }

  /// Fetch all countries with their currencies from backend
  Future<void> fetchAllCountriesWithCurrencies() async {
    try {
      isLoading.value = true;
      print('🌍 Fetching all countries and currencies from API...');

      final response = await ApiProvider.get('/v1/currencies/all-with-countries');

      print('📡 API Response - Success: ${response.success}');
      print('📡 API Response - Data null?: ${response.data == null}');

      if (response.success && response.data != null) {
        final List currencies = response.data!['data'];
        print('💱 Received ${currencies.length} currencies from API');

        // Transform data to country list with currency info
        List<Map<String, dynamic>> countries = [];

        for (var currency in currencies) {
          final currencyModel = CurrencyModel.fromJson(currency);
          print('   Processing: ${currencyModel.code} with ${currencyModel.countries.length} countries');

          // Add each country from this currency
          for (var country in currencyModel.countries) {
            countries.add({
              'country': country,
              'currency': currencyModel,
            });
          }
        }

        print('📋 Total countries created: ${countries.length}');

        // Sort countries alphabetically
        countries.sort((a, b) =>
          (a['country'] as String).compareTo(b['country'] as String)
        );

        allCountries.value = countries;
        filteredCountries.value = countries;
        print('✅ Countries loaded successfully!');
      } else {
        print('❌ API call failed or no data');
        print('   Message: ${response.message}');
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching countries: $e');
      print('Stack trace: $stackTrace');
      Get.snackbar(
        'Erreur',
        'Impossible de charger la liste des pays',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Filter countries based on search query
  void filterCountries(String query) {
    searchQuery.value = query;

    if (query.isEmpty) {
      filteredCountries.value = allCountries;
    } else {
      filteredCountries.value = allCountries.where((item) {
        final country = (item['country'] as String).toLowerCase();
        final currency = (item['currency'] as CurrencyModel);
        final currencyCode = currency.code.toLowerCase();
        final currencyName = currency.name.toLowerCase();
        final search = query.toLowerCase();

        return country.contains(search) ||
               currencyCode.contains(search) ||
               currencyName.contains(search);
      }).toList();
    }
  }

  /// Select a country and its currency
  Future<void> selectCountry(Map<String, dynamic> countryData) async {
    try {
      final CurrencyModel currency = countryData['currency'];
      final String country = countryData['country'];

      isLoading.value = true;

      // Set the currency using CurrencyService
      await CurrencyService.to.setCountryAndCurrency(country, currency);

      // Navigate to next screen based on user state
      // If user is not authenticated, enable guest mode before going to HOME
      if (!StorageService.isAuthenticated && !StorageService.isGuestMode) {
        print('🔓 User not authenticated - enabling guest mode');
        StorageService.enableGuestMode();
      }

      Get.offAllNamed(Routes.HOME);
    } catch (e) {
      print('Error selecting country: $e');
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
