import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/currency_service.dart';

/// Les deux familles de résultats de la recherche.
///
/// L'application vend deux choses très différentes — des articles et du
/// transport de bagage — et les mélanger dans une même liste obligerait
/// l'utilisateur à trier lui-même.
enum SearchScope { products, passcolis }

class SearchController extends GetxController {
  // ================================
  // SERVICES ET STORAGE
  // ================================
  final _storage = GetStorage();
  final TextEditingController searchTextController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final TextEditingController minPriceController = TextEditingController();
  final TextEditingController maxPriceController = TextEditingController();

  // ================================
  // DONNÉES DES PRODUITS
  // ================================
  final RxList<Map<String, dynamic>> allProducts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;

  // ================================
  // DONNÉES PASSCOLIS (offres Diaspo)
  // ================================
  final RxList<DiaspoOffer> passcolisOffers = <DiaspoOffer>[].obs;
  final RxBool isLoadingPasscolis = false.obs;
  final RxBool passcolisLoadFailed = false.obs;
  bool _passcolisLoaded = false;

  /// Onglet actif : produits ou passcolis.
  final Rx<SearchScope> scope = SearchScope.products.obs;

  // ================================
  // ÉTAT DE LA RECHERCHE
  // ================================
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxBool showFilters = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool hasFocus = false.obs;
  final RxBool hasMore = true.obs;
  int _currentPage = 1;

  // ================================
  // FILTRES
  // ================================
  final RxInt selectedCategoryId = 0.obs;
  final RxString selectedCategory = ''.obs;
  final RxDouble minPrice = 0.0.obs;
  final RxDouble maxPrice = 1000000.0.obs;
  final RxDouble currentMinPrice = 0.0.obs;
  final RxDouble currentMaxPrice = 1000000.0.obs;
  final RxString selectedLocation = 'Toutes les villes'.obs;
  final RxString sortBy = 'created_at'.obs;
  final RxString sortOrder = 'desc'.obs;

  // ================================
  // TRI
  // ================================
  final Rx<SortOption> selectedSortOption = SortOption.relevance.obs;

  // ================================
  // CATÉGORIES DISPONIBLES
  // ================================
  final RxList<Map<String, dynamic>> apiCategories =
      <Map<String, dynamic>>[].obs;
  final RxList<String> categories = <String>['Tous'].obs;

  // ================================
  // VILLES DISPONIBLES
  // ================================
  final List<String> cities = [
    'Toutes les villes',
    'Douala',
    'Yaoundé',
    'Bafoussam',
    'Bamenda',
    'Garoua',
  ];

  // ================================
  // HISTORIQUE DE RECHERCHE
  // ================================
  final RxList<String> searchHistory = <String>[].obs;
  final int maxHistoryItems = 10;

  // ================================
  // SUGGESTIONS
  // ================================
  final RxList<String> suggestions = <String>[].obs;

  // ================================
  // NOMBRE DE FILTRES ACTIFS
  // ================================
  int get activeFiltersCount {
    int count = 0;
    if (selectedCategory.value.isNotEmpty && selectedCategory.value != 'Tous')
      count++;
    if (currentMinPrice.value > 0 || currentMaxPrice.value < 1000000) count++;
    if (selectedLocation.value != 'Toutes les villes') count++;
    return count;
  }

  /// Retourne les produits à afficher (recherche ou tous les produits)
  RxList<Map<String, dynamic>> get displayedProducts {
    return searchQuery.value.isNotEmpty ? searchResults : allProducts;
  }

  // ================================
  // BACKWARD COMPATIBILITY GETTERS
  // ================================
  /// Returns searchResults (for backward compatibility)
  RxList<Map<String, dynamic>> get filteredProducts => searchResults;

  // ================================
  // PASSCOLIS
  // ================================

  /// Offres correspondant au texte saisi.
  ///
  /// Le filtrage est local : le catalogue de trajets est court, et l'API ne
  /// sait filtrer que par ville ou pays pris séparément, alors que
  /// l'utilisateur tape indifféremment « Douala » ou « Cameroun ».
  List<DiaspoOffer> get filteredPasscolis {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return passcolisOffers;

    return passcolisOffers.where((offer) {
      return offer.departureCity.toLowerCase().contains(query) ||
          offer.departureCountry.toLowerCase().contains(query) ||
          offer.arrivalCity.toLowerCase().contains(query) ||
          offer.arrivalCountry.toLowerCase().contains(query);
    }).toList();
  }

  /// Bascule d'onglet. Les passcolis ne sont chargés qu'à la première
  /// ouverture de leur onglet : inutile d'appeler l'API pour quelqu'un qui
  /// ne cherche que des produits.
  void changeScope(SearchScope value) {
    if (scope.value == value) return;
    scope.value = value;

    if (value == SearchScope.passcolis && !_passcolisLoaded) {
      loadPasscolisOffers();
    }
  }

  Future<void> loadPasscolisOffers({bool isRefresh = false}) async {
    if (isLoadingPasscolis.value) return;
    if (isRefresh) _passcolisLoaded = false;

    isLoadingPasscolis.value = true;
    passcolisLoadFailed.value = false;

    try {
      if (!Get.isRegistered<DiaspoService>()) {
        Get.put(DiaspoService());
      }

      final response = await Get.find<DiaspoService>().getOffers(perPage: 50);

      if (response['success'] == true) {
        final list = response['data']?['data'] as List? ?? [];
        passcolisOffers.value = list
            .map((json) => DiaspoOffer.fromJson(json))
            .toList();
        _passcolisLoaded = true;
      } else {
        passcolisLoadFailed.value = true;
      }
    } catch (e) {
      passcolisLoadFailed.value = true;
      debugPrint('Erreur chargement passcolis: $e');
    } finally {
      isLoadingPasscolis.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    minPriceController.text = minPrice.value > 0
        ? minPrice.value.toInt().toString()
        : '';
    maxPriceController.text = maxPrice.value > 0
        ? maxPrice.value.toInt().toString()
        : '';
    _loadSearchHistory();
    _loadCategories();
    _setupSearchListener();
    _setupFocusListener();

    // Check if category filter was passed in arguments
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      // Ouverture directe sur l'onglet Passcolis (« Voir tout » de l'accueil).
      if (args['tab'] == 'passcolis') {
        scope.value = SearchScope.passcolis;
        loadPasscolisOffers();
      }

      final categoryId = args['categoryId'] as int?;
      final categoryName = args['categoryName'] as String?;

      if (categoryId != null) {
        selectedCategoryId.value = categoryId;
        if (categoryName != null) {
          selectedCategory.value = categoryName;
        }
        // Load products with the category filter
        loadAllProducts();
        return;
      }
    }

    // Charger tous les produits par défaut
    loadAllProducts();
  }

  @override
  void onClose() {
    searchTextController.dispose();
    searchFocusNode.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.onClose();
  }

  // ================================
  // CHARGEMENT DES DONNÉES
  // ================================

  /// Charge tous les produits par défaut avec pagination
  Future<void> loadAllProducts({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      allProducts.clear();
    }

    isLoading.value = true;
    try {
      final response = await ProductService.getProducts(
        page: _currentPage,
        perPage: 20,
        categoryId: selectedCategoryId.value > 0
            ? selectedCategoryId.value
            : null,
        minPrice: currentMinPrice.value > 0 ? currentMinPrice.value : null,
        maxPrice: currentMaxPrice.value < 1000000
            ? currentMaxPrice.value
            : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );

      if (response.success && response.data != null) {
        final products = response.data!['products'] as List? ?? [];
        final pagination =
            response.data!['pagination'] as Map<String, dynamic>? ?? {};

        if (isRefresh) {
          allProducts.value = products
              .map((p) => Map<String, dynamic>.from(p))
              .toList();
        } else {
          allProducts.addAll(products.map((p) => Map<String, dynamic>.from(p)));
        }

        hasMore.value = pagination['has_more'] ?? false;
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de charger les produits',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Charge les catégories depuis l'API
  Future<void> _loadCategories() async {
    try {
      final response = await ProductService.getCategories();
      if (response.success && response.data != null) {
        final cats = response.data!['categories'] as List? ?? [];
        apiCategories.value = cats
            .map((c) => Map<String, dynamic>.from(c))
            .toList();

        // Build category names list
        categories.clear();
        categories.add('Tous');
        for (var cat in apiCategories) {
          categories.add(cat['name'] ?? '');
        }
      }
    } catch (e) {
      // Use fallback categories
      categories.value = [
        'Tous',
        'Vêtements',
        'Électronique',
        'Accessoires',
        'Maison',
        'Sport',
        'Beauté',
        'Livres',
        'Autres',
      ];
    }
  }

  // ================================
  // RECHERCHE
  // ================================

  /// Configure l'écoute des changements de texte
  void _setupSearchListener() {
    // Debounce pour éviter trop de requêtes lors de la saisie
    debounce(searchQuery, (_) {
      if (searchQuery.value.isNotEmpty) {
        _performSearch();
      }
    }, time: const Duration(milliseconds: 500));
  }

  /// Configure l'écoute des changements de focus
  void _setupFocusListener() {
    searchFocusNode.addListener(() {
      hasFocus.value = searchFocusNode.hasFocus;
    });
  }

  /// Effectue la recherche (appelé depuis l'historique ou suggestions)
  void performSearch(String query) {
    searchQuery.value = query;
    searchTextController.text = query;
    isSearching.value = query.isNotEmpty;

    // Ajouter à l'historique et lancer immédiatement (sans debounce)
    if (query.isNotEmpty) {
      _addToSearchHistory(query);
      // Annuler tout debounce en cours et lancer immédiatement
      _performSearchImmediate();
    }

    // Masquer le focus du champ de recherche
    searchFocusNode.unfocus();
  }

  /// Lance la recherche immédiatement sans debounce
  Future<void> _performSearchImmediate() async {
    if (searchQuery.value.isEmpty) {
      searchResults.clear();
      return;
    }

    _currentPage = 1;
    isLoading.value = true;

    try {
      final response = await ProductService.getProducts(
        page: _currentPage,
        search: searchQuery.value,
        categoryId: selectedCategoryId.value > 0
            ? selectedCategoryId.value
            : null,
        minPrice: minPrice.value > 0 ? minPrice.value : null,
        maxPrice: maxPrice.value < 1000000 ? maxPrice.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );

      if (response.success && response.data != null) {
        final productsList = response.data!['products'] as List? ?? [];
        final pagination =
            response.data!['pagination'] as Map<String, dynamic>? ?? {};
        searchResults.value = productsList
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        hasMore.value = pagination['has_more'] ?? false;
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de rechercher',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Effectue la recherche via l'API
  Future<void> _performSearch() async {
    if (searchQuery.value.isEmpty) {
      searchResults.clear();
      return;
    }

    _currentPage = 1;
    isLoading.value = true;

    try {
      final response = await ProductService.getProducts(
        page: _currentPage,
        search: searchQuery.value,
        categoryId: selectedCategoryId.value > 0
            ? selectedCategoryId.value
            : null,
        minPrice: minPrice.value > 0 ? minPrice.value : null,
        maxPrice: maxPrice.value < 1000000 ? maxPrice.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );

      if (response.success && response.data != null) {
        final products = response.data!['products'] as List? ?? [];
        final pagination =
            response.data!['pagination'] as Map<String, dynamic>? ?? {};
        searchResults.value = products
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        hasMore.value = pagination['has_more'] ?? false;
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de rechercher',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Efface la recherche
  void clearSearch() {
    searchQuery.value = '';
    searchTextController.clear();
    isSearching.value = false;
    suggestions.clear();
    searchResults.clear();
  }

  // ================================
  // FILTRES ET PAGINATION
  // ================================

  /// Charge plus de résultats (recherche ou tous les produits)
  Future<void> loadMore() async {
    if (!hasMore.value || isLoading.value) return;
    _currentPage++;

    try {
      final response = await ProductService.getProducts(
        page: _currentPage,
        search: searchQuery.value.isNotEmpty ? searchQuery.value : null,
        categoryId: selectedCategoryId.value > 0
            ? selectedCategoryId.value
            : null,
        minPrice: currentMinPrice.value > 0 ? currentMinPrice.value : null,
        maxPrice: currentMaxPrice.value < 1000000
            ? currentMaxPrice.value
            : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );

      if (response.success && response.data != null) {
        final products = response.data!['products'] as List? ?? [];
        final pagination =
            response.data!['pagination'] as Map<String, dynamic>? ?? {};

        // Ajouter aux bons résultats selon le contexte
        if (searchQuery.value.isNotEmpty) {
          searchResults.addAll(
            products.map((p) => Map<String, dynamic>.from(p)),
          );
        } else {
          allProducts.addAll(products.map((p) => Map<String, dynamic>.from(p)));
        }

        hasMore.value = pagination['has_more'] ?? false;
      }
    } catch (e) {
      _currentPage--;
    }
  }

  /// Change la catégorie
  void selectCategory(String category) {
    selectedCategory.value = category;

    // Update category ID based on selected category name
    if (category == 'Tous' || category.isEmpty) {
      selectedCategoryId.value = 0;
    } else {
      final cat = apiCategories.firstWhereOrNull((c) => c['name'] == category);
      selectedCategoryId.value = cat?['id'] ?? 0;
    }

    // Si on a déjà une recherche active, relancer avec le nouveau filtre
    if (searchQuery.value.isNotEmpty) {
      _performSearchImmediate();
    } else {
      // Sinon recharger tous les produits avec le nouveau filtre
      loadAllProducts(isRefresh: true);
    }
  }

  /// Change la plage de prix
  void setPriceRange(double min, double max) {
    minPrice.value = min;
    maxPrice.value = max;
    if (searchQuery.value.isNotEmpty) {
      _performSearch();
    }
  }

  /// Applique les filtres de prix
  void applyPriceFilters() {
    currentMinPrice.value = minPrice.value;
    currentMaxPrice.value = maxPrice.value;

    if (searchQuery.value.isNotEmpty) {
      _performSearchImmediate();
    } else {
      loadAllProducts(isRefresh: true);
    }
  }

  /// Change la localisation
  void selectLocation(String location) {
    selectedLocation.value = location;
    _performSearch();
  }

  /// Change l'option de tri
  void selectSortOption(SortOption option) {
    selectedSortOption.value = option;
    _updateSortParams(option);
    if (searchQuery.value.isNotEmpty) {
      _performSearch();
    } else {
      loadAllProducts(isRefresh: true);
    }
  }

  /// Met à jour les paramètres de tri selon l'option sélectionnée
  void _updateSortParams(SortOption option) {
    switch (option) {
      case SortOption.relevance:
        sortBy.value = 'relevance';
        sortOrder.value = 'desc';
        break;
      case SortOption.priceAsc:
        sortBy.value = 'price';
        sortOrder.value = 'asc';
        break;
      case SortOption.priceDesc:
        sortBy.value = 'price';
        sortOrder.value = 'desc';
        break;
      case SortOption.dateDesc:
        sortBy.value = 'created_at';
        sortOrder.value = 'desc';
        break;
      case SortOption.dateAsc:
        sortBy.value = 'created_at';
        sortOrder.value = 'asc';
        break;
    }
  }

  /// Réinitialise tous les filtres
  void resetFilters() {
    selectedCategory.value = '';
    selectedCategoryId.value = 0;
    minPrice.value = 0.0;
    maxPrice.value = 1000000.0;
    currentMinPrice.value = 0.0;
    currentMaxPrice.value = 1000000.0;
    minPriceController.clear();
    maxPriceController.clear();
    selectedLocation.value = 'Toutes les villes';
    selectedSortOption.value = SortOption.relevance;
    sortBy.value = 'created_at';
    sortOrder.value = 'desc';
    if (searchQuery.value.isNotEmpty) {
      _performSearch();
    } else {
      loadAllProducts(isRefresh: true);
    }
  }

  /// Toggle affichage des filtres
  void toggleFilters() {
    showFilters.value = !showFilters.value;
  }

  // ================================
  // HISTORIQUE
  // ================================

  /// Charge l'historique de recherche
  void _loadSearchHistory() {
    final history = _storage.read<List>('search_history');
    if (history != null) {
      searchHistory.value = history.cast<String>();
    }
  }

  /// Ajoute une recherche à l'historique
  void _addToSearchHistory(String query) {
    // Retirer si déjà présent
    searchHistory.remove(query);

    // Ajouter en première position
    searchHistory.insert(0, query);

    // Limiter la taille
    if (searchHistory.length > maxHistoryItems) {
      searchHistory.removeRange(maxHistoryItems, searchHistory.length);
    }

    // Sauvegarder
    _storage.write('search_history', searchHistory);
  }

  /// Supprime un élément de l'historique
  void removeFromHistory(String query) {
    searchHistory.remove(query);
    _storage.write('search_history', searchHistory);
  }

  /// Efface tout l'historique
  void clearHistory() {
    searchHistory.clear();
    _storage.remove('search_history');
  }

  // ================================
  // ACTIONS SUR LES PRODUITS
  // ================================

  /// Navigue vers les détails du produit.
  ///
  /// Asso Ads : une ouverture venue d'une carte sponsorisée porte `from_ad`,
  /// sans quoi le clic ne serait jamais compté et le vendeur verrait un
  /// retour sous-évalué sur une campagne qu'il a payée.
  void onProductTap(Map<String, dynamic> product) {
    Get.toNamed(
      '/product',
      arguments: product['is_sponsored'] == true
          ? {...product, 'from_ad': true}
          : product,
    );
  }

  /// Applique les filtres et relance la recherche
  void applyFilters({
    int? categoryId,
    double? min,
    double? max,
    String? sort,
    String? order,
  }) {
    if (categoryId != null) selectedCategoryId.value = categoryId;
    if (min != null) minPrice.value = min;
    if (max != null) maxPrice.value = max;
    if (sort != null) sortBy.value = sort;
    if (order != null) sortOrder.value = order;
    _performSearch();
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

// ================================
// ENUMS
// ================================

enum SortOption { relevance, priceAsc, priceDesc, dateDesc, dateAsc }

extension SortOptionExtension on SortOption {
  String get label {
    switch (this) {
      case SortOption.relevance:
        return 'Pertinence';
      case SortOption.priceAsc:
        return 'Prix croissant';
      case SortOption.priceDesc:
        return 'Prix décroissant';
      case SortOption.dateDesc:
        return 'Plus récents';
      case SortOption.dateAsc:
        return 'Plus anciens';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.relevance:
        return Icons.star_outline;
      case SortOption.priceAsc:
        return Icons.arrow_upward;
      case SortOption.priceDesc:
        return Icons.arrow_downward;
      case SortOption.dateDesc:
        return Icons.access_time;
      case SortOption.dateAsc:
        return Icons.history;
    }
  }
}
