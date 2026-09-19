import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../data/providers/shop_service.dart';
import '../../../data/providers/currency_service.dart';

/// Critères de tri du catalogue d'une boutique.
enum ShopProductSort {
  recent('Nouveautés'),
  priceAsc('Prix croissant'),
  priceDesc('Prix décroissant'),
  nameAsc('A → Z');

  const ShopProductSort(this.label);

  final String label;
}

class VendorDetailsController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  final Rxn<Map<String, dynamic>> shopData = Rxn<Map<String, dynamic>>();
  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> shopStats = Rxn<Map<String, dynamic>>();

  /// Recherche dans le catalogue de la boutique.
  ///
  /// Une boutique bien fournie devient vite illisible à la seule molette :
  /// on cherche un produit précis, pas la vingtième vignette.
  final TextEditingController searchController = TextEditingController();
  final RxString query = ''.obs;
  final Rx<ShopProductSort> sort = ShopProductSort.recent.obs;

  /// N'afficher que ce qui est réellement commandable.
  final RxBool inStockOnly = false.obs;

  String? shopId;

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Catalogue après recherche, filtre et tri.
  List<Map<String, dynamic>> get visibleProducts {
    final terms = query.value.trim().toLowerCase();
    final result = products.where((product) {
      if (inStockOnly.value && _stockOf(product) <= 0) return false;
      if (terms.isEmpty) return true;
      // La description compte aussi : on cherche souvent « bissap » ou
      // « piment » sans que le mot figure dans le nom du produit.
      final category = product['category'];
      final haystack = [
        product['name'],
        product['description'],
        // La catégorie arrive tantôt en objet, tantôt en simple libellé
        // selon l'endpoint : lire ['name'] à l'aveugle plantait sur le second.
        if (category is Map) category['name'] else category,
      ].whereType<Object>().map((v) => v.toString().toLowerCase()).join(' ');
      return haystack.contains(terms);
    }).toList();

    switch (sort.value) {
      case ShopProductSort.recent:
        break;
      case ShopProductSort.priceAsc:
        result.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
      case ShopProductSort.priceDesc:
        result.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
      case ShopProductSort.nameAsc:
        result.sort(
          (a, b) => _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase()),
        );
    }
    return result;
  }

  /// Vrai dès qu'une recherche ou un filtre restreint la liste.
  bool get hasActiveFilters =>
      query.value.trim().isNotEmpty || inStockOnly.value;

  void onSearchChanged(String value) => query.value = value;

  void clearSearch() {
    searchController.clear();
    query.value = '';
  }

  void setSort(ShopProductSort value) => sort.value = value;

  void toggleInStockOnly() => inStockOnly.value = !inStockOnly.value;

  /// Remet le catalogue à plat, recherche comprise.
  void resetFilters() {
    clearSearch();
    inStockOnly.value = false;
    sort.value = ShopProductSort.recent;
  }

  static double _priceOf(Map<String, dynamic> product) {
    final raw = product['price_xaf'] ?? product['price'] ?? 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw') ?? 0;
  }

  static num _stockOf(Map<String, dynamic> product) {
    final raw = product['stock'] ?? 0;
    if (raw is num) return raw;
    return num.tryParse('$raw') ?? 0;
  }

  static String _nameOf(Map<String, dynamic> product) =>
      product['name']?.toString() ?? '';

  @override
  void onInit() {
    super.onInit();

    // Get shop ID from arguments
    final args = Get.arguments as Map<String, dynamic>?;
    shopId = args?['shop_id']?.toString();

    if (shopId != null) {
      fetchShopDetails();
    } else {
      hasError.value = true;
      errorMessage.value = 'ID de boutique invalide';
      isLoading.value = false;
    }
  }

  Future<void> fetchShopDetails() async {
    if (shopId == null) return;

    try {
      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';

      print('🏪 Fetching shop details for ID: $shopId');

      final response = await ShopService.getPublicShop(shopId!);

      if (response.success && response.data != null) {
        shopData.value = response.data!['shop'] as Map<String, dynamic>?;
        shopStats.value = response.data!['stats'] as Map<String, dynamic>?;

        // Extract products from shop data
        final shopProducts = shopData.value?['products'] as List<dynamic>?;
        if (shopProducts != null) {
          products.value = shopProducts.cast<Map<String, dynamic>>();
        }

        print('✅ Shop details loaded successfully');
        print('   Shop name: ${shopData.value?['name']}');
        print('   Products count: ${products.length}');
      } else {
        hasError.value = true;
        errorMessage.value = response.message.isNotEmpty
            ? response.message
            : 'Impossible de charger les détails de la boutique';
      }
    } catch (e) {
      print('❌ Error fetching shop details: $e');
      hasError.value = true;
      errorMessage.value = 'Une erreur est survenue lors du chargement';
    } finally {
      isLoading.value = false;
    }
  }

  void onProductTap(Map<String, dynamic> product) {
    // Navigate to product details
    Get.toNamed('/product', arguments: product);
  }

  Future<void> refreshShopDetails() async {
    await fetchShopDetails();
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format price with user's currency
  String formatPrice(double priceInXOF, {bool showSymbol = true}) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: showSymbol);
  }

  /// Get currency symbol
  String get currencySymbol {
    if (!Get.isRegistered<CurrencyService>()) {
      return 'FCFA';
    }
    return CurrencyService.to.currencySymbol;
  }
}
