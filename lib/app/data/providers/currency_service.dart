import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'api_provider.dart';
import 'storage_service.dart';
import '../models/currency_model.dart';

class CurrencyService extends GetxService {
  static CurrencyService get to => Get.find();

  // Reactive state
  final Rx<CurrencyModel?> _userCurrency = Rx<CurrencyModel?>(null);
  final RxDouble _exchangeRateToXOF = 1.0.obs;
  final RxBool _isLoading = false.obs;
  final RxString _detectedCountry = ''.obs;

  // Getters
  CurrencyModel? get userCurrency => _userCurrency.value;
  double get exchangeRateToXOF => _exchangeRateToXOF.value;
  bool get isLoading => _isLoading.value;
  String get detectedCountry => _detectedCountry.value;
  String get currencyCode => _userCurrency.value?.code ?? 'XOF';
  String get currencySymbol => _userCurrency.value?.symbol ?? 'FCFA';

  @override
  Future<void> onInit() async {
    super.onInit();

    // Check if user has manually selected a country
    final hasSelectedCountry = StorageService.hasSelectedCountry;
    print('💱 CurrencyService onInit - User has selected country: $hasSelectedCountry');

    if (hasSelectedCountry) {
      // User has manually selected a country - load it from storage
      final savedCountry = StorageService.getCountry();
      print('   Loading saved country: $savedCountry');
      _detectedCountry.value = savedCountry ?? '';
      await loadSavedCurrency();
      print('   Loaded currency: ${_userCurrency.value?.code ?? "NULL"}');
    } else {
      // No manual selection - try to load saved currency or detect automatically
      await loadSavedCurrency();
      if (_userCurrency.value == null) {
        print('   No saved currency - will need country selection');
        // Don't auto-detect - let user choose manually
      }
    }
  }

  /// Detect user's country and set currency
  Future<void> detectAndSetUserCurrency() async {
    try {
      _isLoading.value = true;

      // Check location permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Default to XOF
        await _setDefaultCurrency();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await _setDefaultCurrency();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await _setDefaultCurrency();
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Get country from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final country = placemarks.first.country ?? '';
        _detectedCountry.value = country;

        // Get currency for this country from API
        await _fetchCurrencyByCountry(country);
      } else {
        await _setDefaultCurrency();
      }
    } catch (e) {
      print('Error detecting country: $e');
      await _setDefaultCurrency();
    } finally {
      _isLoading.value = false;
    }
  }

  /// Fetch currency by country name from API
  Future<void> _fetchCurrencyByCountry(String country) async {
    try {
      print('🌍 Fetching currency for country: $country');
      final response = await ApiProvider.get(
        '/v1/currencies/by-country',
        queryParams: {'country': country},
      );

      print('📡 API Response - Success: ${response.success}');
      print('📡 API Response - Data: ${response.data}');

      if (response.success && response.data != null) {
        final currencyData = response.data!['data'];
        print('💱 Currency data received: $currencyData');
        final currency = CurrencyModel.fromJson(currencyData);
        print('✅ Currency parsed: ${currency.code} - ${currency.name}');
        await _setUserCurrency(currency);
      } else {
        print('⚠️ API failed or no data, using default XOF');
        print('   Message: ${response.message}');
        await _setDefaultCurrency();
      }
    } catch (e) {
      print('❌ Error fetching currency by country: $e');
      await _setDefaultCurrency();
    }
  }

  /// Set default currency (XOF)
  Future<void> _setDefaultCurrency() async {
    final defaultCurrency = CurrencyModel(
      id: 1,
      code: 'XOF',
      name: 'West African CFA franc',
      symbol: 'FCFA',
      countries: ['Benin', 'Burkina Faso', 'Ivory Coast', 'Guinea-Bissau', 'Mali', 'Niger', 'Senegal', 'Togo'],
      isActive: true,
    );
    await _setUserCurrency(defaultCurrency);
  }

  /// Set user currency and save to storage
  Future<void> _setUserCurrency(CurrencyModel currency) async {
    _userCurrency.value = currency;
    StorageService.saveCurrency(currency.toJson());

    // Fetch exchange rate to XOF if not XOF
    if (currency.code != 'XOF') {
      await _fetchExchangeRateToXOF(currency.code);
    } else {
      _exchangeRateToXOF.value = 1.0;
    }
  }

  /// Fetch exchange rate from user currency to XOF
  Future<void> _fetchExchangeRateToXOF(String currencyCode) async {
    try {
      final response = await ApiProvider.get(
        '/v1/currencies/exchange-rate',
        queryParams: {'from': currencyCode, 'to': 'XOF'},
      );

      if (response.success && response.data != null) {
        final rate = response.data!['data']['rate'];
        _exchangeRateToXOF.value = double.tryParse(rate.toString()) ?? 1.0;
      } else {
        _exchangeRateToXOF.value = 1.0;
      }
    } catch (e) {
      print('Error fetching exchange rate: $e');
      _exchangeRateToXOF.value = 1.0;
    }
  }

  /// Load saved currency from storage
  Future<void> loadSavedCurrency() async {
    final savedCurrency = StorageService.getCurrency();
    if (savedCurrency != null) {
      _userCurrency.value = CurrencyModel.fromJson(savedCurrency);
      if (_userCurrency.value!.code != 'XOF') {
        await _fetchExchangeRateToXOF(_userCurrency.value!.code);
      }
    }
  }

  /// Manually set currency by code
  Future<void> setCurrencyByCode(String currencyCode) async {
    try {
      _isLoading.value = true;

      final response = await ApiProvider.get('/v1/currencies');
      if (response.success && response.data != null) {
        final currencies = (response.data!['data'] as List)
            .map((e) => CurrencyModel.fromJson(e))
            .toList();

        final currency = currencies.firstWhereOrNull((c) => c.code == currencyCode);
        if (currency != null) {
          await _setUserCurrency(currency);
        }
      }
    } catch (e) {
      print('Error setting currency by code: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Convert amount from XOF to user currency
  double convertFromXOF(double amountInXOF) {
    if (userCurrency == null || userCurrency!.code == 'XOF') {
      return amountInXOF;
    }
    // Rate is: 1 XOF = X user_currency
    // So: amount_in_XOF * rate = amount_in_user_currency
    return amountInXOF * (1 / _exchangeRateToXOF.value);
  }

  /// Convert amount from user currency to XOF
  double convertToXOF(double amountInUserCurrency) {
    if (userCurrency == null || userCurrency!.code == 'XOF') {
      return amountInUserCurrency;
    }
    return amountInUserCurrency * _exchangeRateToXOF.value;
  }

  /// Format price with user currency
  String formatPrice(double priceInXOF, {bool showSymbol = true}) {
    final convertedPrice = convertFromXOF(priceInXOF);
    final formattedAmount = convertedPrice.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        );

    if (showSymbol) {
      return '$formattedAmount ${currencySymbol}';
    }
    return formattedAmount;
  }

  /// Get all available currencies
  Future<List<CurrencyModel>> getAllCurrencies() async {
    try {
      final response = await ApiProvider.get('/v1/currencies');
      if (response.success && response.data != null) {
        return (response.data!['data'] as List)
            .map((e) => CurrencyModel.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching all currencies: $e');
      return [];
    }
  }

  /// Reset to default currency
  Future<void> resetToDefault() async {
    await _setDefaultCurrency();
  }

  /// Manually set country and currency (used after user selection)
  Future<void> setCountryAndCurrency(String country, CurrencyModel currency) async {
    try {
      _detectedCountry.value = country;
      StorageService.saveCountry(country); // Save selected country
      await _setUserCurrency(currency);
      print('✅ Country and currency set: $country - ${currency.code}');
    } catch (e) {
      print('❌ Error setting country and currency: $e');
      rethrow;
    }
  }
}
