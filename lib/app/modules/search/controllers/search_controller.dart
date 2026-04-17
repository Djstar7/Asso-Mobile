import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/providers/product_service.dart';

class SearchController extends GetxController {
  // ================================
  // SERVICES ET STORAGE
  // ================================
  final _storage = GetStorage();
  final _imagePicker = ImagePicker();
  final TextEditingController searchTextController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  // ================================
  // DONNÉES DES PRODUITS
  // ================================
  final RxList<Map<String, dynamic>> allProducts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;

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
  final RxBool isImageSearchMode = false.obs;

  // ================================
  // TRI
  // ================================
  final Rx<SortOption> selectedSortOption = SortOption.relevance.obs;

  // ================================
  // CATÉGORIES DISPONIBLES
  // ================================
  final RxList<Map<String, dynamic>> apiCategories = <Map<String, dynamic>>[].obs;
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
    if (selectedCategory.value.isNotEmpty && selectedCategory.value != 'Tous') count++;
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

  @override
  void onInit() {
    super.onInit();
    _loadSearchHistory();
    _loadCategories();
    _setupSearchListener();
    _setupFocusListener();

    // Check if category filter was passed in arguments
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
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
        categoryId: selectedCategoryId.value > 0 ? selectedCategoryId.value : null,
        minPrice: currentMinPrice.value > 0 ? currentMinPrice.value : null,
        maxPrice: currentMaxPrice.value < 1000000 ? currentMaxPrice.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );

      if (response.success && response.data != null) {
        final products = response.data!['products'] as List? ?? [];
        final pagination = response.data!['pagination'] as Map<String, dynamic>? ?? {};

        if (isRefresh) {
          allProducts.value = products.map((p) => Map<String, dynamic>.from(p)).toList();
        } else {
          allProducts.addAll(products.map((p) => Map<String, dynamic>.from(p)));
        }

        hasMore.value = pagination['has_more'] ?? false;
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de charger les produits',
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
        apiCategories.value = cats.map((c) => Map<String, dynamic>.from(c)).toList();

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
        categoryId: selectedCategoryId.value > 0 ? selectedCategoryId.value : null,
        minPrice: minPrice.value > 0 ? minPrice.value : null,
        maxPrice: maxPrice.value < 1000000 ? maxPrice.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );

      if (response.success && response.data != null) {
        final productsList = response.data!['products'] as List? ?? [];
        final pagination = response.data!['pagination'] as Map<String, dynamic>? ?? {};
        searchResults.value = productsList.map((p) => Map<String, dynamic>.from(p)).toList();
        hasMore.value = pagination['has_more'] ?? false;
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de rechercher',
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
        categoryId: selectedCategoryId.value > 0 ? selectedCategoryId.value : null,
        minPrice: minPrice.value > 0 ? minPrice.value : null,
        maxPrice: maxPrice.value < 1000000 ? maxPrice.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );

      if (response.success && response.data != null) {
        final products = response.data!['products'] as List? ?? [];
        final pagination = response.data!['pagination'] as Map<String, dynamic>? ?? {};
        searchResults.value = products.map((p) => Map<String, dynamic>.from(p)).toList();
        hasMore.value = pagination['has_more'] ?? false;
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de rechercher',
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
    isImageSearchMode.value = false;
    suggestions.clear();
    searchResults.clear();
  }

  /// Lance la recherche par image
  Future<void> searchByImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        isImageSearchMode.value = true;
        isLoading.value = true;

        // TODO: Implémenter l'appel API pour la recherche par image
        // Pour l'instant, on affiche un message
        Get.snackbar(
          'Recherche par image',
          'Image sélectionnée : ${image.name}',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 2),
        );

        // Simuler une recherche (à remplacer par l'appel API réel)
        await Future.delayed(const Duration(seconds: 1));
        isLoading.value = false;

        // Note: Quand l'API sera prête, envoyer l'image et récupérer les résultats
        // final bytes = await image.readAsBytes();
        // final response = await ProductService.searchByImage(bytes);
        // searchResults.value = response.data...
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Erreur', 'Impossible de sélectionner l\'image',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
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
        categoryId: selectedCategoryId.value > 0 ? selectedCategoryId.value : null,
        minPrice: currentMinPrice.value > 0 ? currentMinPrice.value : null,
        maxPrice: currentMaxPrice.value < 1000000 ? currentMaxPrice.value : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );

      if (response.success && response.data != null) {
        final products = response.data!['products'] as List? ?? [];
        final pagination = response.data!['pagination'] as Map<String, dynamic>? ?? {};

        // Ajouter aux bons résultats selon le contexte
        if (searchQuery.value.isNotEmpty) {
          searchResults.addAll(products.map((p) => Map<String, dynamic>.from(p)));
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

  /// Navigue vers les détails du produit
  void onProductTap(Map<String, dynamic> product) {
    Get.toNamed('/product', arguments: product);
  }

  /// Applique les filtres et relance la recherche
  void applyFilters({int? categoryId, double? min, double? max, String? sort, String? order}) {
    if (categoryId != null) selectedCategoryId.value = categoryId;
    if (min != null) minPrice.value = min;
    if (max != null) maxPrice.value = max;
    if (sort != null) sortBy.value = sort;
    if (order != null) sortOrder.value = order;
    _performSearch();
  }
}

// ================================
// ENUMS
// ================================

enum SortOption {
  relevance,
  priceAsc,
  priceDesc,
  dateDesc,
  dateAsc,
}

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
