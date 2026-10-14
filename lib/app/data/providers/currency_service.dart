import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'api_provider.dart';
import 'storage_service.dart';
import '../models/currency_model.dart';

class CurrencyService extends GetxService {
  static CurrencyService get to => Get.find();

  /// Devise pivot du backend : commandes, Wallet et `price_xaf` sont en XAF.
  static const String pivot = 'XAF';

  /// Le XOF a la même parité fixe avec l'euro que le XAF : 1 XOF = 1 XAF.
  static const Set<String> _pivotEquivalents = {'XAF', 'XOF'};

  /// Devises sans centimes à l'affichage.
  static const Set<String> _zeroDecimal = {
    'XAF', 'XOF', 'JPY', 'KRW', 'GNF', 'RWF', 'UGX', 'KMF', 'BIF', 'DJF', 'VND', 'CLP', 'PYG', 'ISK',
  };

  /// Au-delà, le taux enregistré est rafraîchi (il reste utilisé si l'API échoue).
  static const Duration _rateMaxAge = Duration(hours: 6);

  // Reactive state
  final Rx<CurrencyModel?> _userCurrency = Rx<CurrencyModel?>(null);

  /// « 1 unité de la devise utilisateur = X XAF ». Null tant qu'aucun taux n'est
  /// connu : les montants restent alors affichés en FCFA, jamais avec un faux taux.
  final RxnDouble _rateToPivot = RxnDouble();
  final RxBool _isLoading = false.obs;

  /// « 1 [code] = X XAF » des autres devises (offres Diaspo…), gardés en mémoire
  /// le temps de la session, sans toucher au taux enregistré de l'utilisateur.
  final RxMap<String, double> _foreignRates = <String, double>{}.obs;
  final Set<String> _pendingRates = {};
  final RxString _detectedCountry = ''.obs;

  // Getters
  CurrencyModel? get userCurrency => _userCurrency.value;

  /// Devise observable : permet à un écran de se redessiner quand le vendeur
  /// change de devise d'affichage, sans rappeler l'API.
  Rx<CurrencyModel?> get userCurrencyRx => _userCurrency;
  double? get rateToPivot => _rateToPivot.value;
  bool get isLoading => _isLoading.value;
  String get detectedCountry => _detectedCountry.value;

  /// Devise choisie par l'utilisateur (saisie d'un prix, devise d'une offre…).
  String get currencyCode => _userCurrency.value?.code ?? pivot;

  /// Devise dans laquelle les montants convertis sont réellement affichés : celle
  /// de l'utilisateur si son taux est connu, sinon le FCFA.
  String get displayCurrencyCode {
    final code = currencyCode.toUpperCase();
    if (_pivotEquivalents.contains(code) || _rateToPivot.value != null) return code;
    return pivot;
  }

  /// Symbole des montants affichés (suit [displayCurrencyCode]).
  String get currencySymbol => getSymbolForCode(displayCurrencyCode);

  static int decimalsFor(String code) => _zeroDecimal.contains(code.toUpperCase()) ? 0 : 2;

  /// Fallback synchrone code -> symbole (pour l'affichage d'une devise
  /// indépendante de la devise utilisateur, ex: devise réelle d'une offre Diaspo).
  static const Map<String, String> fallbackSymbols = {
    'XAF': 'FCFA',
    'XOF': 'FCFA',
    'EUR': '€',
    'USD': '\$',
    'GBP': '£',
    'CAD': 'CA\$',
    'CHF': 'CHF',
    'CNY': '¥',
    'JPY': '¥',
    'MAD': 'DH',
    'DZD': 'DA',
    'TND': 'DT',
    'NGN': '₦',
    'GHS': 'GH₵',
    'ZAR': 'R',
    'AED': 'AED',
  };

  /// Retourne le symbole associé à un code devise donné.
  /// Cherche d'abord dans la devise utilisateur chargée (si le code correspond),
  /// puis dans la table de fallback, sinon renvoie le code lui-même.
  static String getSymbolForCode(String code) {
    if (code.isEmpty) return 'FCFA';
    final upper = code.toUpperCase();
    if (Get.isRegistered<CurrencyService>()) {
      final uc = CurrencyService.to.userCurrency;
      if (uc != null && uc.code.toUpperCase() == upper && uc.symbol.isNotEmpty) {
        return uc.symbol;
      }
    }
    return fallbackSymbols[upper] ?? code;
  }

  /// Formate un montant déjà exprimé dans [currencyCode], sans effectuer une
  /// nouvelle conversion (prix Import convertis par le backend, offre Diaspo…).
  /// 0 décimale pour XAF/XOF/JPY…, 2 pour les autres devises.
  static String formatAmountInCurrency(double amount, String currencyCode, {bool showSymbol = true}) {
    final parts = amount.toStringAsFixed(decimalsFor(currencyCode)).split('.');
    final integer = parts.first.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    );
    final formatted = parts.length == 2 ? '$integer,${parts.last}' : integer;
    return showSymbol ? '$formatted ${getSymbolForCode(currencyCode)}' : formatted;
  }

  /// Formate un montant exprimé dans la devise pivot (XAF) dans la devise de
  /// l'utilisateur — LE formateur de l'app : 0 décimale pour XAF/XOF/JPY…,
  /// 2 pour les autres (100 FCFA ≈ 0,15 € et non « 0 € »).
  /// À appeler dans un Obx pour suivre un changement de devise.
  static String formatFromPivot(double amountXaf, {bool showSymbol = true}) {
    final display = displayFromPivot(amountXaf);
    return formatAmountInCurrency(display.amount, display.currency, showSymbol: showSymbol);
  }

  /// Montant exprimé dans [currencyCode] (prix d'une offre Diaspo…) affiché dans
  /// la devise de l'utilisateur, via le pivot XAF. Tant que le taux n'est pas
  /// connu, le montant reste dans sa devise d'origine (jamais un faux taux).
  /// À appeler dans un Obx : l'affichage se met à jour à l'arrivée du taux.
  static String formatFromCurrency(double amount, String currencyCode, {bool showSymbol = true}) {
    final code = currencyCode.trim().toUpperCase();
    if (code.isEmpty || code == 'FCFA' || _pivotEquivalents.contains(code)) {
      return formatFromPivot(amount, showSymbol: showSymbol);
    }
    if (!Get.isRegistered<CurrencyService>()) {
      return formatAmountInCurrency(amount, code, showSymbol: showSymbol);
    }
    final service = CurrencyService.to;
    if (code == service.displayCurrencyCode.toUpperCase()) {
      return formatAmountInCurrency(amount, code, showSymbol: showSymbol);
    }
    final rate = service._rateToPivotFor(code);
    if (rate == null) return formatAmountInCurrency(amount, code, showSymbol: showSymbol);
    return formatFromPivot(amount * rate, showSymbol: showSymbol);
  }

  /// Taux « 1 [code] = X XAF » connu, sinon null et demande à l'API (une seule
  /// requête à la fois par devise).
  double? _rateToPivotFor(String code) {
    if (code == currencyCode.toUpperCase() && _rateToPivot.value != null) {
      return _rateToPivot.value;
    }
    final rate = _foreignRates[code];
    if (rate == null && _pendingRates.add(code)) {
      _requestRateToPivot(code).then((fresh) {
        if (fresh != null) _foreignRates[code] = fresh;
      }).whenComplete(() => _pendingRates.remove(code));
    }
    return rate;
  }

  /// Prix XAF d'un produit renvoyé par l'API : [xafKey] s'il est fourni, sinon
  /// [priceKey] quand le produit est déjà en FCFA (ou sans devise, anciens
  /// payloads). Null pour un prix en devise étrangère sans équivalent XAF : il ne
  /// doit pas être lu comme du FCFA.
  static double? productPriceXaf(
    Map product, {
    String priceKey = 'price',
    String xafKey = 'price_xaf',
  }) {
    final xaf = double.tryParse('${product[xafKey] ?? ''}');
    if (xaf != null) return xaf;
    final code = '${product['currency'] ?? ''}'.toUpperCase();
    if (code.isEmpty || _pivotEquivalents.contains(code) || code == 'FCFA') {
      return double.tryParse('${product[priceKey] ?? ''}');
    }
    return null;
  }

  /// Prix d'un produit de l'API, dans la devise de l'utilisateur ; à défaut de
  /// taux côté serveur, dans la devise du produit (jamais un faux FCFA).
  static String formatProductPrice(
    Map product, {
    String priceKey = 'price',
    String xafKey = 'price_xaf',
  }) {
    final xaf = productPriceXaf(product, priceKey: priceKey, xafKey: xafKey);
    if (xaf != null) return formatFromPivot(xaf);
    final price = double.tryParse('${product[priceKey] ?? ''}') ?? 0;
    return formatAmountInCurrency(price, '${product['currency']}');
  }

  /// Montant pivot (XAF) converti dans la devise affichée + code de cette devise,
  /// pour les composants qui attendent un couple (montant, devise).
  static ({double amount, String currency}) displayFromPivot(double amountXaf) {
    if (!Get.isRegistered<CurrencyService>()) {
      return (amount: amountXaf.roundToDouble(), currency: pivot);
    }
    final service = CurrencyService.to;
    final code = service.displayCurrencyCode;
    final converted = service.convertFromPivot(amountXaf);
    final factor = decimalsFor(code) == 0 ? 1 : 100;
    return (amount: (converted * factor).roundToDouble() / factor, currency: code);
  }

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
        print('⚠️ API failed or no data, using default XAF');
        print('   Message: ${response.message}');
        await _setDefaultCurrency();
      }
    } catch (e) {
      print('❌ Error fetching currency by country: $e');
      await _setDefaultCurrency();
    }
  }

  /// Devise par défaut : le FCFA (XAF), devise pivot du backend.
  Future<void> _setDefaultCurrency() async {
    final defaultCurrency = CurrencyModel(
      id: 1,
      code: 'XAF',
      name: 'Franc CFA (CEMAC)',
      symbol: 'FCFA',
      countries: ['Cameroun', 'Centrafrique', 'Congo', 'Gabon', 'Guinée équatoriale', 'Tchad'],
      isActive: true,
    );
    await _setUserCurrency(defaultCurrency);
  }

  /// Change de devise. Le taux de la nouvelle devise est obtenu AVANT de la
  /// publier : un écran ne s'affiche jamais avec le nouveau symbole et l'ancien taux.
  Future<void> _setUserCurrency(CurrencyModel currency) async {
    final code = currency.code.toUpperCase();
    final saved = StorageService.getExchangeRate(code);
    final rate = _pivotEquivalents.contains(code)
        ? null
        : (await _fetchRateToPivot(code)) ?? saved?.rate;

    _rateToPivot.value = rate;
    _userCurrency.value = currency;
    StorageService.saveCurrency(currency.toJson());
  }

  /// Taux « 1 [code] = X XAF » depuis l'API, enregistré pour les prochains
  /// démarrages. Null si l'API ne répond pas.
  Future<double?> _fetchRateToPivot(String code) async {
    final rate = await _requestRateToPivot(code);
    if (rate != null) StorageService.saveExchangeRate(code, rate);
    return rate;
  }

  /// Taux « 1 [code] = X XAF » depuis l'API, sans l'enregistrer. Null si l'API
  /// ne répond pas.
  Future<double?> _requestRateToPivot(String code) async {
    try {
      final response = await ApiProvider.get(
        '/v1/currencies/exchange-rate',
        queryParams: {'from': code, 'to': pivot},
      );
      if (response.success && response.data != null) {
        final rate = double.tryParse(response.data!['data']['rate'].toString());
        if (rate != null && rate > 0) return rate;
      }
    } catch (e) {
      print('Error fetching exchange rate: $e');
    }
    return null;
  }

  /// Recharge la devise enregistrée avec son dernier taux connu (affichage
  /// immédiat, même hors ligne), puis rafraîchit ce taux s'il est ancien.
  Future<void> loadSavedCurrency() async {
    final savedCurrency = StorageService.getCurrency();
    if (savedCurrency == null) return;

    final currency = CurrencyModel.fromJson(savedCurrency);
    final code = currency.code.toUpperCase();
    final saved = StorageService.getExchangeRate(code);
    _rateToPivot.value = saved?.rate;
    _userCurrency.value = currency;

    if (_pivotEquivalents.contains(code)) return;
    final stale = saved == null || DateTime.now().difference(saved.fetchedAt) > _rateMaxAge;
    if (stale) {
      final fresh = await _fetchRateToPivot(code);
      if (fresh != null && _userCurrency.value?.code.toUpperCase() == code) {
        _rateToPivot.value = fresh;
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

  /// Montant XAF → devise affichée ([displayCurrencyCode]). Sans taux connu, le
  /// montant reste en XAF (et s'affiche en FCFA).
  double convertFromPivot(double amountXaf) {
    final rate = _rateToPivot.value;
    if (rate == null || _pivotEquivalents.contains(displayCurrencyCode)) {
      return amountXaf;
    }
    return amountXaf / rate;
  }

  /// Montant saisi dans la devise affichée → XAF (ex. bornes du filtre de prix).
  double convertToPivot(double amountDisplayed) {
    final rate = _rateToPivot.value;
    if (rate == null || _pivotEquivalents.contains(displayCurrencyCode)) {
      return amountDisplayed;
    }
    return amountDisplayed * rate;
  }

  /// Montant XAF formaté dans la devise affichée (alias de [formatFromPivot]).
  String formatPrice(double amountXaf, {bool showSymbol = true}) =>
      formatFromPivot(amountXaf, showSymbol: showSymbol);

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
