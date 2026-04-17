import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../routes/app_pages.dart';
import '../../../core/base/safe_controller_mixin.dart';

class HomeController extends GetxController with GetSingleTickerProviderStateMixin, SafeControllerMixin {
  // Supprimé scaffoldKey pour éviter les problèmes de GlobalKey duplicate
  // On utilisera Scaffold.of(context) dans la vue à la place

  late TabController tabController;
  final RxInt currentTabIndex = 0.obs;
  final ScrollController nestedScrollController = ScrollController();

  // Flag pour éviter d'utiliser des ressources disposées
  bool _isDisposed = false;

  /// Getter pour vérifier si le controller est sûr à utiliser
  bool get isSafe => !_isDisposed && isClosed == false;

  final List<String> tabNames = [
    'Accueil',
    'Messages',
    'Portefeuille',
    'Tracking',
    'Profile',
  ];

  // Banner
  final PageController bannerController = PageController();
  final RxInt currentBannerIndex = 0.obs;
  final RxList<Map<String, dynamic>> banners = <Map<String, dynamic>>[].obs;

  // Categories
  final RxList<Map<String, dynamic>> apiCategories = <Map<String, dynamic>>[].obs;
  final RxString selectedCategory = 'Tous'.obs;
  final RxInt selectedCategoryId = 0.obs;
  final List<String> categories = ['Tous'];
  final RxList<String> userPreferredCategorySlugs = <String>[].obs;
  final RxMap<String, int> categorySlugToIdMap = <String, int>{}.obs;

  // Products
  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> nearbyProducts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> recentProducts = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingProducts = false.obs;
  final RxBool isLoadingNearby = false.obs;
  final RxBool isLoadingRecent = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMoreProducts = true.obs;
  int _currentPage = 1;

  // Global initial loading flag
  final RxBool isInitialLoading = true.obs;

  // User
  final RxString userName = ''.obs;
  final RxString userAvatar = ''.obs;

  // Fallback banner images (local assets)
  final List<String> fallbackBanners = [
    'assets/images/bann1.png',
    'assets/images/bann2.png',
    'assets/images/bann3.png',
  ];

  @override
  void onInit() {
    print('');
    print('========================================');
    print('🏠 HOME CONTROLLER: onInit() START');
    print('========================================');
    print('  └─ Controller hashCode: ${hashCode}');

    super.onInit();

    // Check for initialTab argument
    final arguments = Get.arguments;
    int initialTab = 0;
    if (arguments != null && arguments is Map && arguments.containsKey('initialTab')) {
      final tabIndex = arguments['initialTab'];
      if (tabIndex is int && tabIndex >= 0 && tabIndex < tabNames.length) {
        initialTab = tabIndex;
        print('  └─ Initial tab set to: $initialTab');
      }
    }

    print('  └─ Creating TabController...');
    tabController = TabController(
      length: tabNames.length,
      vsync: this,
      initialIndex: initialTab,
    );
    tabController.addListener(_onTabChanged);
    currentTabIndex.value = initialTab;
    print('  └─ TabController created: ${tabController.hashCode}');

    // Load user info
    final user = ApiProvider.cachedUser;
    if (user != null) {
      userName.value = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
      userAvatar.value = user['avatar'] ?? '';
      print('  └─ User loaded: ${userName.value}');
    } else {
      print('  └─ No user found');
    }

    // Load data - preferences must be loaded first
    print('  └─ Starting data load...');
    _loadData();

    // Pagination scroll listener
    nestedScrollController.addListener(_onScroll);

    print('✅ HOME CONTROLLER: onInit() COMPLETED');
    print('========================================');
    print('');
  }

  @override
  void onReady() {
    super.onReady();
    print('');
    print('========================================');
    print('🟢 HOME CONTROLLER: onReady() CALLED');
    print('========================================');
    print('  └─ Controller hashCode: ${hashCode}');
    print('  └─ TabController: ${tabController.hashCode}');
    print('  └─ Current tab: ${currentTabIndex.value}');
    print('========================================');
    print('');
  }

  /// Listener pour les changements de tab
  void _onTabChanged() {
    // Vérifier que le controller n'est pas disposé ET que le tabController existe
    if (_isDisposed) return;

    try {
      // Vérifier que l'index n'est pas en train de changer pour éviter les erreurs
      if (!tabController.indexIsChanging) {
        currentTabIndex.value = tabController.index;
      }
    } catch (e) {
      print('  └─ Error in _onTabChanged: $e');
    }
  }

  @override
  void onClose() {
    print('');
    print('========================================');
    print('🔴 HOME CONTROLLER: onClose() START');
    print('========================================');
    print('  └─ Controller hashCode: $hashCode');
    print('  └─ Disposing controllers...');

    // Marquer comme disposé AVANT de toucher aux controllers
    _isDisposed = true;
    markAsDisposed();

    // Remove listener avant de dispose - avec try-catch pour éviter les erreurs
    try {
      if (tabController.hasListeners) {
        tabController.removeListener(_onTabChanged);
      }
    } catch (e) {
      print('  └─ Error removing tabController listener: $e');
    }

    // Dispose dans l'ordre inverse de création avec protection
    try {
      tabController.dispose();
    } catch (e) {
      print('  └─ Error disposing tabController: $e');
    }

    try {
      if (bannerController.hasClients) {
        bannerController.dispose();
      }
    } catch (e) {
      print('  └─ Error disposing bannerController: $e');
    }

    try {
      if (nestedScrollController.hasClients) {
        nestedScrollController.dispose();
      }
    } catch (e) {
      print('  └─ Error disposing nestedScrollController: $e');
    }

    super.onClose();

    print('✅ HOME CONTROLLER: onClose() COMPLETED');
    print('========================================');
    print('');
  }

  void _onScroll() {
    if (_isDisposed) return;

    if (nestedScrollController.hasClients &&
        nestedScrollController.position.pixels >=
            nestedScrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  /// Load all data in correct order
  Future<void> _loadData() async {
    isInitialLoading.value = true;

    try {
      // Load preferences first, then categories (which need preferences)
      await _loadUserPreferences();
      await _loadCategories();

      // Load other data in parallel and wait for completion
      await Future.wait([
        _loadNearbyProducts(),
        _loadRecentProducts(),
        _loadBanners(),
      ]);

      _startBannerAutoScroll();
    } finally {
      // Marquer le chargement initial comme terminé
      isInitialLoading.value = false;
    }
  }

  /// Load user preferences from backend
  Future<void> _loadUserPreferences() async {
    // Ne pas charger les préférences si l'utilisateur n'est pas connecté
    if (!StorageService.isAuthenticated) {
      developer.log(
        'User not authenticated - skipping preferences load',
        name: 'HomeController',
      );
      return;
    }

    try {
      final response = await AuthService.getPreferences();
      if (response.success && response.data != null) {
        final preferences = response.data!['preferences'] as Map<String, dynamic>?;
        if (preferences != null && preferences['categories'] != null) {
          final categoriesList = preferences['categories'] as List;
          userPreferredCategorySlugs.value = categoriesList
              .map((slug) => slug.toString())
              .where((slug) => slug.isNotEmpty)
              .toList();

          developer.log(
            'User preferred categories loaded: ${userPreferredCategorySlugs.length} slugs',
            name: 'HomeController',
          );
          developer.log(
            'Preferred slugs: ${userPreferredCategorySlugs.take(5).join(", ")}...',
            name: 'HomeController',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Failed to load user preferences',
        name: 'HomeController',
        error: e.toString(),
      );
      // Continue without preferences - will show all categories
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ProductService.getCategories();
      if (response.success && response.data != null) {
        final cats = response.data!['categories'] as List? ?? [];
        apiCategories.value = cats.map((c) => Map<String, dynamic>.from(c)).toList();

        // Build slug to ID mapping
        categorySlugToIdMap.clear();
        for (var cat in apiCategories) {
          final slug = cat['slug']?.toString();
          final id = cat['id'];
          if (slug != null && id != null) {
            categorySlugToIdMap[slug] = id is int ? id : int.tryParse(id.toString()) ?? 0;
          }
        }

        developer.log(
          'Categories loaded: ${apiCategories.length} categories',
          name: 'HomeController',
        );

        // Order categories based on user preferences
        _orderCategoriesByPreferences();
      }
    } catch (e) {
      developer.log(
        'Failed to load categories',
        name: 'HomeController',
        error: e.toString(),
      );
      // Use fallback categories
      categories.clear();
      categories.add('Tous');
      categories.addAll(['Vêtements', 'Électronique', 'Accessoires']);
    }
  }

  /// Order categories: preferred first, then others
  void _orderCategoriesByPreferences() {
    categories.clear();
    categories.add('Tous');

    if (userPreferredCategorySlugs.isEmpty) {
      // No preferences - show all categories in order
      for (var cat in apiCategories) {
        categories.add(cat['name'] ?? '');
      }
      developer.log(
        'No preferences - showing all ${apiCategories.length} categories',
        name: 'HomeController',
      );
    } else {
      // Add preferred categories first
      final preferredCats = <Map<String, dynamic>>[];
      final otherCats = <Map<String, dynamic>>[];

      for (var cat in apiCategories) {
        final catSlug = cat['slug']?.toString() ?? '';
        if (catSlug.isNotEmpty && userPreferredCategorySlugs.contains(catSlug)) {
          preferredCats.add(cat);
        } else {
          otherCats.add(cat);
        }
      }

      // Sort preferred categories by user's preference order
      preferredCats.sort((a, b) {
        final aIndex = userPreferredCategorySlugs.indexOf(a['slug']?.toString() ?? '');
        final bIndex = userPreferredCategorySlugs.indexOf(b['slug']?.toString() ?? '');
        return aIndex.compareTo(bIndex);
      });

      // Add preferred categories
      for (var cat in preferredCats) {
        categories.add(cat['name'] ?? '');
      }

      // Add remaining categories
      for (var cat in otherCats) {
        categories.add(cat['name'] ?? '');
      }

      developer.log(
        'Categories ordered: ${preferredCats.length} preferred, ${otherCats.length} others',
        name: 'HomeController',
      );
    }
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      hasMoreProducts.value = true;
    }

    isLoadingProducts.value = true;

    try {
      final response = await ProductService.getProducts(
        page: _currentPage,
        categoryId: selectedCategoryId.value > 0 ? selectedCategoryId.value : null,
      );

      if (response.success && response.data != null) {
        final productsList = response.data!['products'] as List? ?? [];
        final pagination = response.data!['pagination'] as Map<String, dynamic>? ?? {};

        if (refresh || _currentPage == 1) {
          products.value = productsList.map((p) => Map<String, dynamic>.from(p)).toList();
        } else {
          products.addAll(productsList.map((p) => Map<String, dynamic>.from(p)));
        }

        hasMoreProducts.value = pagination['has_more'] ?? false;

        developer.log(
          'Products loaded: ${productsList.length} items (page $_currentPage, category_id: ${selectedCategoryId.value})',
          name: 'HomeController',
        );
      }
    } catch (e) {
      developer.log(
        'Failed to load products',
        name: 'HomeController',
        error: e.toString(),
      );
    } finally {
      // Afficher immédiatement les produits sans attendre
      // Les images se chargeront progressivement avec leur placeholder
      isLoadingProducts.value = false;
    }
  }

  Future<void> _loadMoreProducts() async {
    if (isLoadingMore.value || !hasMoreProducts.value) return;

    isLoadingMore.value = true;
    _currentPage++;

    try {
      final response = await ProductService.getProducts(
        page: _currentPage,
        categoryId: selectedCategoryId.value > 0 ? selectedCategoryId.value : null,
      );

      if (response.success && response.data != null) {
        final productsList = response.data!['products'] as List? ?? [];
        final pagination = response.data!['pagination'] as Map<String, dynamic>? ?? {};

        products.addAll(productsList.map((p) => Map<String, dynamic>.from(p)));
        hasMoreProducts.value = pagination['has_more'] ?? false;
      }
    } catch (e) {
      _currentPage--;
      developer.log(
        'Failed to load more products',
        name: 'HomeController',
        error: e.toString(),
      );
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> _loadNearbyProducts() async {
    isLoadingNearby.value = true;

    try {
      final response = await ProductService.getNearbyProducts(limit: 6);
      if (response.success && response.data != null) {
        final productsList = response.data!['products'] as List? ?? [];
        nearbyProducts.value = productsList.map((p) => Map<String, dynamic>.from(p)).toList();

        developer.log(
          'Nearby products loaded: ${nearbyProducts.length} items',
          name: 'HomeController',
        );

        // DEBUG: Log shop certification status
        if (nearbyProducts.isNotEmpty) {
          final firstProduct = nearbyProducts.first;
          print('=== DEBUG NEARBY PRODUCT ===');
          print('Product name: ${firstProduct['name']}');
          print('Full product data keys: ${firstProduct.keys.toList()}');
          print('Shop data: ${firstProduct['shop']}');
          if (firstProduct['shop'] != null) {
            print('Shop keys: ${firstProduct['shop'].keys.toList()}');
            print('is_certified value: ${firstProduct['shop']['is_certified']}');
            print('is_certified type: ${firstProduct['shop']['is_certified'].runtimeType}');
          }
          print('========================');
        }
      }
    } catch (e) {
      developer.log(
        'Failed to load nearby products',
        name: 'HomeController',
        error: e.toString(),
      );
    } finally {
      // Afficher immédiatement les produits sans attendre
      // Les images se chargeront progressivement avec leur placeholder
      isLoadingNearby.value = false;
    }
  }

  Future<void> _loadRecentProducts() async {
    isLoadingRecent.value = true;

    try {
      final response = await ProductService.getRecentProducts(limit: 6);
      if (response.success && response.data != null) {
        final productsList = response.data!['products'] as List? ?? [];
        recentProducts.value = productsList.map((p) => Map<String, dynamic>.from(p)).toList();

        developer.log(
          'Recent products loaded: ${recentProducts.length} items',
          name: 'HomeController',
        );

        // DEBUG: Log shop certification status
        if (recentProducts.isNotEmpty) {
          final firstProduct = recentProducts.first;
          print('=== DEBUG RECENT PRODUCT ===');
          print('Product name: ${firstProduct['name']}');
          print('Full product data keys: ${firstProduct.keys.toList()}');
          print('Shop data: ${firstProduct['shop']}');
          if (firstProduct['shop'] != null) {
            print('Shop keys: ${firstProduct['shop'].keys.toList()}');
            print('is_certified value: ${firstProduct['shop']['is_certified']}');
            print('is_certified type: ${firstProduct['shop']['is_certified'].runtimeType}');
          }
          print('========================');
        }
      }
    } catch (e) {
      developer.log(
        'Failed to load recent products',
        name: 'HomeController',
        error: e.toString(),
      );
    } finally {
      // Afficher immédiatement les produits sans attendre
      // Les images se chargeront progressivement avec leur placeholder
      isLoadingRecent.value = false;
    }
  }

  Future<void> _loadBanners() async {
    try {
      final response = await ProductService.getBanners();
      if (response.success && response.data != null) {
        final bannerList = response.data!['banners'] as List? ?? [];
        banners.value = bannerList.map((b) => Map<String, dynamic>.from(b)).toList();
      }
    } catch (e) {
      // Use fallback banners
    }
  }

  void handleTabTap(int index) {
    if (_isDisposed) return;

    // Tabs protégés : Messages (1), Portefeuille (2), Tracking (3), Profile (4)
    // Tab Accueil (0) est accessible sans connexion
    final protectedTabs = [1, 2, 3, 4];
    final tabFeatureNames = {
      1: 'la messagerie',
      2: 'le portefeuille',
      3: 'le tracking de commandes',
      4: 'votre profil',
    };

    if (protectedTabs.contains(index) && AuthGuard.isGuest) {
      // L'utilisateur n'est pas connecté et essaie d'accéder à un tab protégé
      final context = Get.context;
      if (context != null) {
        AppDialogs.showLoginRequiredDialog(
          context,
          featureName: tabFeatureNames[index],
        );
      }
      // Rester sur le tab Accueil - avec protection contre dispose
      try {
        if (!_isDisposed && tabController.index != 0) {
          tabController.animateTo(0);
          currentTabIndex.value = 0;
        }
      } catch (e) {
        print('  └─ Error animating to tab 0: $e');
        currentTabIndex.value = 0;
      }
    } else {
      // Autoriser l'accès au tab
      currentTabIndex.value = index;
    }
  }

  void _startBannerAutoScroll() {
    if (_isDisposed) return;

    safeDelayed(const Duration(seconds: 3), () {
      if (_isDisposed) return;

      final totalBanners = banners.isNotEmpty ? banners.length : fallbackBanners.length;
      if (totalBanners > 0 && bannerController.hasClients) {
        int nextPage = (currentBannerIndex.value + 1) % totalBanners;
        safeAnimateToPage(
          bannerController,
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        currentBannerIndex.value = nextPage;
      }

      // Continue the loop
      if (!_isDisposed) {
        _startBannerAutoScroll();
      }
    });
  }

  void selectCategory(String category) {
    selectedCategory.value = category;

    if (category == 'Tous') {
      selectedCategoryId.value = 0;
      // Reload nearby and recent products for "Tous" view
      _loadNearbyProducts();
      _loadRecentProducts();
    } else {
      final cat = apiCategories.firstWhereOrNull((c) => c['name'] == category);
      selectedCategoryId.value = cat?['id'] ?? 0;
      // Load filtered products for specific category
      _loadProducts(refresh: true);
    }

    developer.log(
      'Category selected: $category (id: ${selectedCategoryId.value})',
      name: 'HomeController',
    );
  }

  void onProductTap(int index) {
    if (index < products.length) {
      final product = products[index];
      Get.toNamed('/product', arguments: product);
    }
  }

  Future<void> refreshProducts() async {
    await Future.wait([
      _loadNearbyProducts(),
      _loadRecentProducts(),
    ]);
  }

  void onSeeAllNearby() {
    // Navigate to search with nearby filter
    Get.toNamed('/search', arguments: {'filter': 'nearby'});
  }

  void onSeeAllRecent() {
    // Navigate to search with recent filter
    Get.toNamed('/search', arguments: {'filter': 'recent'});
  }

  /// Toggle favorite for a product
  Future<void> toggleFavorite(int productId) async {
    try {
      // Check authentication
      if (!StorageService.isAuthenticated) {
        AuthGuard.navigateIfAuthenticated(
          Get.context!,
          '/favorites',
          featureName: 'les favoris',
          useDialog: true,
        );
        return;
      }

      final response = await ProductService.toggleFavorite(productId);

      if (response.success) {
        final isFavorite = response.data?['is_favorite'] ?? false;
        final message = response.data?['message'] ?? (isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris');

        // Update the is_favorite status in all product lists
        updateProductFavoriteStatus(productId, isFavorite);

        Get.snackbar(
          'Succès',
          message,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          backgroundColor: AppThemeSystem.successColor,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de modifier le favori',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    }
  }

  /// Update is_favorite status in all product lists (public for cross-controller sync)
  void updateProductFavoriteStatus(int productId, bool isFavorite) {
    // Update in products list
    final productIndex = products.indexWhere((p) => p['id'] == productId);
    if (productIndex != -1) {
      products[productIndex]['is_favorite'] = isFavorite;
      products.refresh();
    }

    // Update in nearby products list
    final nearbyIndex = nearbyProducts.indexWhere((p) => p['id'] == productId);
    if (nearbyIndex != -1) {
      nearbyProducts[nearbyIndex]['is_favorite'] = isFavorite;
      nearbyProducts.refresh();
    }

    // Update in recent products list
    final recentIndex = recentProducts.indexWhere((p) => p['id'] == productId);
    if (recentIndex != -1) {
      recentProducts[recentIndex]['is_favorite'] = isFavorite;
      recentProducts.refresh();
    }
  }

  /// Refresh categories after preferences update
  Future<void> refreshCategories() async {
    await _loadUserPreferences();
    _orderCategoriesByPreferences();
  }

  /// Handle vendor mode navigation based on user status
  void handleVendorModeNavigation() {
    print('');
    print('========================================');
    print('🏪 HOME: VENDOR MODE NAVIGATION');
    print('========================================');

    final user = StorageService.getUser();

    if (user == null) {
      print('❌ HOME: No user found in storage');
      Get.snackbar(
        'Connexion requise',
        'Veuillez vous connecter pour accéder au mode vendeur',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('========================================');
      return;
    }

    print('👤 HOME: User found');
    print('  └─ Name: ${user.fullName}');
    print('  └─ Role: ${user.role}');
    print('  └─ Is Vendor: ${user.isVendor}');

    if (user.isVendor) {
      print('✅ HOME: User is already a vendor, navigating to dashboard');
      Get.toNamed(Routes.VENDOR_DASHBOARD);
    } else {
      print('📝 HOME: User is not a vendor, navigating to config');
      Get.toNamed(Routes.VENDOR_CONFIG);
    }

    print('========================================');
  }
}
