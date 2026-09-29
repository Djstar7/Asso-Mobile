import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_pages.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/storage_service.dart';

class PreferencesController extends GetxController {
  // Catégories d'intérêt avec sous-catégories
  // Getter : les libellés suivent la langue courante.
  List<CategoryItem> get categories => [
    CategoryItem(
      id: 'fashion',
      name: 'preferences.categories.fashion'.tr,
      svgPath: 'assets/svgs/categories/fashion.svg',
      subcategories: [
        SubcategoryItem(
          id: 'fashion_men',
          name: 'preferences.subcategories.fashion_men'.tr,
        ),
        SubcategoryItem(
          id: 'fashion_women',
          name: 'preferences.subcategories.fashion_women'.tr,
        ),
        SubcategoryItem(
          id: 'fashion_kids',
          name: 'preferences.subcategories.fashion_kids'.tr,
        ),
        SubcategoryItem(
          id: 'fashion_shoes',
          name: 'preferences.subcategories.fashion_shoes'.tr,
        ),
        SubcategoryItem(
          id: 'fashion_accessories',
          name: 'preferences.subcategories.fashion_accessories'.tr,
        ),
      ],
    ),
    CategoryItem(
      id: 'electronics',
      name: 'preferences.categories.electronics'.tr,
      svgPath: 'assets/svgs/categories/electronics.svg',
      subcategories: [
        SubcategoryItem(
          id: 'electronics_phones',
          name: 'preferences.subcategories.electronics_phones'.tr,
        ),
        SubcategoryItem(
          id: 'electronics_computers',
          name: 'preferences.subcategories.electronics_computers'.tr,
        ),
        SubcategoryItem(
          id: 'electronics_tablets',
          name: 'preferences.subcategories.electronics_tablets'.tr,
        ),
        SubcategoryItem(
          id: 'electronics_accessories',
          name: 'preferences.subcategories.electronics_accessories'.tr,
        ),
        SubcategoryItem(
          id: 'electronics_audio',
          name: 'preferences.subcategories.electronics_audio'.tr,
        ),
      ],
    ),
    CategoryItem(
      id: 'food',
      name: 'preferences.categories.food'.tr,
      svgPath: 'assets/svgs/categories/food.svg',
      subcategories: [
        SubcategoryItem(
          id: 'food_fresh',
          name: 'preferences.subcategories.food_fresh'.tr,
        ),
        SubcategoryItem(
          id: 'food_grocery',
          name: 'preferences.subcategories.food_grocery'.tr,
        ),
        SubcategoryItem(
          id: 'food_drinks',
          name: 'preferences.subcategories.food_drinks'.tr,
        ),
        SubcategoryItem(
          id: 'food_snacks',
          name: 'preferences.subcategories.food_snacks'.tr,
        ),
        SubcategoryItem(
          id: 'food_organic',
          name: 'preferences.subcategories.food_organic'.tr,
        ),
      ],
    ),
    CategoryItem(
      id: 'beauty',
      name: 'preferences.categories.beauty'.tr,
      svgPath: 'assets/svgs/categories/beauty.svg',
      subcategories: [
        SubcategoryItem(
          id: 'beauty_skincare',
          name: 'preferences.subcategories.beauty_skincare'.tr,
        ),
        SubcategoryItem(
          id: 'beauty_makeup',
          name: 'preferences.subcategories.beauty_makeup'.tr,
        ),
        SubcategoryItem(
          id: 'beauty_haircare',
          name: 'preferences.subcategories.beauty_haircare'.tr,
        ),
        SubcategoryItem(
          id: 'beauty_perfume',
          name: 'preferences.subcategories.beauty_perfume'.tr,
        ),
        SubcategoryItem(
          id: 'beauty_wellness',
          name: 'preferences.subcategories.beauty_wellness'.tr,
        ),
      ],
    ),
    CategoryItem(
      id: 'sports',
      name: 'preferences.categories.sports'.tr,
      svgPath: 'assets/svgs/categories/sports.svg',
      subcategories: [
        SubcategoryItem(
          id: 'sports_fitness',
          name: 'preferences.subcategories.sports_fitness'.tr,
        ),
        SubcategoryItem(
          id: 'sports_outdoor',
          name: 'preferences.subcategories.sports_outdoor'.tr,
        ),
        SubcategoryItem(
          id: 'sports_team',
          name: 'preferences.subcategories.sports_team'.tr,
        ),
        SubcategoryItem(
          id: 'sports_equipment',
          name: 'preferences.subcategories.sports_equipment'.tr,
        ),
        SubcategoryItem(
          id: 'sports_clothing',
          name: 'preferences.subcategories.sports_clothing'.tr,
        ),
      ],
    ),
    CategoryItem(
      id: 'home',
      name: 'preferences.categories.home'.tr,
      svgPath: 'assets/svgs/categories/home.svg',
      subcategories: [
        SubcategoryItem(
          id: 'home_furniture',
          name: 'preferences.subcategories.home_furniture'.tr,
        ),
        SubcategoryItem(
          id: 'home_decoration',
          name: 'preferences.subcategories.home_decoration'.tr,
        ),
        SubcategoryItem(
          id: 'home_kitchen',
          name: 'preferences.subcategories.home_kitchen'.tr,
        ),
        SubcategoryItem(
          id: 'home_bedding',
          name: 'preferences.subcategories.home_bedding'.tr,
        ),
        SubcategoryItem(
          id: 'home_appliances',
          name: 'preferences.subcategories.home_appliances'.tr,
        ),
      ],
    ),
    CategoryItem(
      id: 'books',
      name: 'preferences.categories.books'.tr,
      svgPath: 'assets/svgs/categories/books.svg',
      subcategories: [
        SubcategoryItem(
          id: 'books_fiction',
          name: 'preferences.subcategories.books_fiction'.tr,
        ),
        SubcategoryItem(
          id: 'books_nonfiction',
          name: 'preferences.subcategories.books_nonfiction'.tr,
        ),
        SubcategoryItem(
          id: 'books_education',
          name: 'preferences.subcategories.books_education'.tr,
        ),
        SubcategoryItem(
          id: 'books_comics',
          name: 'preferences.subcategories.books_comics'.tr,
        ),
        SubcategoryItem(
          id: 'books_magazines',
          name: 'preferences.subcategories.books_magazines'.tr,
        ),
      ],
    ),
    CategoryItem(
      id: 'toys',
      name: 'preferences.categories.toys'.tr,
      svgPath: 'assets/svgs/categories/toys.svg',
      subcategories: [
        SubcategoryItem(
          id: 'toys_baby',
          name: 'preferences.subcategories.toys_baby'.tr,
        ),
        SubcategoryItem(
          id: 'toys_preschool',
          name: 'preferences.subcategories.toys_preschool'.tr,
        ),
        SubcategoryItem(
          id: 'toys_kids',
          name: 'preferences.subcategories.toys_kids'.tr,
        ),
        SubcategoryItem(
          id: 'toys_educational',
          name: 'preferences.subcategories.toys_educational'.tr,
        ),
        SubcategoryItem(
          id: 'toys_games',
          name: 'preferences.subcategories.toys_games'.tr,
        ),
      ],
    ),
    CategoryItem(
      id: 'automotive',
      name: 'preferences.categories.automotive'.tr,
      svgPath: 'assets/svgs/categories/automotive.svg',
      subcategories: [
        SubcategoryItem(
          id: 'automotive_cars',
          name: 'preferences.subcategories.automotive_cars'.tr,
        ),
        SubcategoryItem(
          id: 'automotive_motorcycles',
          name: 'preferences.subcategories.automotive_motorcycles'.tr,
        ),
        SubcategoryItem(
          id: 'automotive_parts',
          name: 'preferences.subcategories.automotive_parts'.tr,
        ),
        SubcategoryItem(
          id: 'automotive_accessories',
          name: 'preferences.subcategories.automotive_accessories'.tr,
        ),
        SubcategoryItem(
          id: 'automotive_maintenance',
          name: 'preferences.subcategories.automotive_maintenance'.tr,
        ),
      ],
    ),
    CategoryItem(
      id: 'services',
      name: 'preferences.categories.services'.tr,
      svgPath: 'assets/svgs/categories/services.svg',
      subcategories: [
        SubcategoryItem(
          id: 'services_home',
          name: 'preferences.subcategories.services_home'.tr,
        ),
        SubcategoryItem(
          id: 'services_repair',
          name: 'preferences.subcategories.services_repair'.tr,
        ),
        SubcategoryItem(
          id: 'services_delivery',
          name: 'preferences.subcategories.services_delivery'.tr,
        ),
        SubcategoryItem(
          id: 'services_cleaning',
          name: 'preferences.subcategories.services_cleaning'.tr,
        ),
        SubcategoryItem(
          id: 'services_professional',
          name: 'preferences.subcategories.services_professional'.tr,
        ),
      ],
    ),
  ];

  // Préférences sélectionnées
  final RxSet<String> selectedSubcategories = <String>{}.obs;

  // Catégories expandues
  final RxSet<String> expandedCategories = <String>{}.obs;

  // Loading state
  final isLoading = false.obs;

  /// true seulement quand la page est l'étape d'onboarding (splash, OTP) :
  /// c'est le seul cas où un compte qui a déjà ses préférences est renvoyé
  /// vers l'accueil. Ouverte depuis le profil, le menu ou ailleurs, la page
  /// restait ouverte 300 ms puis se refermait d'elle-même.
  late final bool _isOnboarding;

  @override
  void onInit() {
    super.onInit();
    // Lu une fois ici : après l'appel réseau, Get.arguments peut désigner
    // une autre route.
    _isOnboarding = (Get.arguments as Map?)?['onboarding'] == true;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // Mode vitrine (invite): pas de token, on n'appelle pas l'API et on laisse
    // l'utilisateur parcourir/selectionner ses centres d'interet librement.
    if (!StorageService.isAuthenticated) {
      // Mode invité : pas de compte à interroger, mais les choix déjà faits
      // sur cet appareil sont repris — et resserviront à l'inscription.
      _restoreLocalSelection();
      return;
    }

    try {
      isLoading.value = true;
      print('📥 Loading preferences from backend...');

      final response = await AuthService.getPreferences();

      if (response.success && response.data != null) {
        final preferences = response.data!['preferences'];
        print('✅ Preferences loaded: $preferences');

        // If preferences exist and have categories, pre-select them
        if (preferences is Map && preferences['categories'] != null) {
          final categories = preferences['categories'] as List;
          selectedSubcategories.clear();
          selectedSubcategories.addAll(categories.map((c) => c.toString()));

          print('✅ Pre-selected ${selectedSubcategories.length} categories');
          print('📋 Selected: ${selectedSubcategories.toList()}');

          // AUTO-NAVIGATE : uniquement en onboarding, jamais en consultation.
          if (_isOnboarding && selectedSubcategories.isNotEmpty) {
            print(
              '🏠 AUTO-NAVIGATE: User has existing preferences, navigating to HOME',
            );
            await Future.delayed(const Duration(milliseconds: 300));
            if (!isClosed) Get.offAllNamed(Routes.HOME);
          }
        }
      } else {
        print('ℹ️ No preferences found on backend');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading preferences: $e');
      print('Stack trace: $stackTrace');
    } finally {
      isLoading.value = false;
    }
  }

  void toggleCategory(String categoryId) {
    if (expandedCategories.contains(categoryId)) {
      expandedCategories.remove(categoryId);
    } else {
      expandedCategories.add(categoryId);
    }
  }

  void toggleSubcategory(String subcategoryId) {
    if (selectedSubcategories.contains(subcategoryId)) {
      selectedSubcategories.remove(subcategoryId);
    } else {
      selectedSubcategories.add(subcategoryId);
    }
  }

  bool isCategorySelected(String categoryId) {
    final category = categories.firstWhere((cat) => cat.id == categoryId);
    return category.subcategories.any(
      (sub) => selectedSubcategories.contains(sub.id),
    );
  }

  int getCategorySelectionCount(String categoryId) {
    final category = categories.firstWhere((cat) => cat.id == categoryId);
    return category.subcategories
        .where((sub) => selectedSubcategories.contains(sub.id))
        .length;
  }

  Future<void> saveAndContinue() async {
    // Le bouton est désactivé tant que rien n'est choisi : on ne peut pas
    // arriver ici les mains vides, et il n'y a donc plus d'alerte à afficher.
    if (selectedSubcategories.isEmpty) return;

    // Sauvegarder les préférences via l'API
    final prefs = {'categories': selectedSubcategories.toList()};

    // Toujours conservées sur l'appareil : en mode invité c'est le seul
    // endroit, et à l'inscription elles évitent de tout redemander.
    StorageService.savePreferences(prefs);
    StorageService.setPreferencesPrompted();

    if (StorageService.isAuthenticated) {
      try {
        await AuthService.updatePreferences(prefs);
      } catch (e) {
        // L'échec réseau ne fait pas perdre la sélection, déjà enregistrée.
      }
    }

    // Afficher un message de succès
    Get.snackbar(
      'preferences.saved_title'.tr,
      (selectedSubcategories.length > 1
              ? 'preferences.saved_many'
              : 'preferences.saved_one')
          .trParams({'count': '${selectedSubcategories.length}'}),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );

    await Future.delayed(const Duration(milliseconds: 500));
    _leave();
  }

  void skipPreferences() {
    // Passer compte comme une réponse : l'écran ne sera pas reproposé.
    StorageService.setPreferencesPrompted();
    _leave();
  }

  /// Ouverte par-dessus un autre écran : on y revient. Racine de
  /// l'onboarding : on part vers l'accueil.
  void _leave() {
    if (isClosed) return;
    final navigator = Get.key.currentState;
    // Navigator.pop et non Get.back : Get.back refermerait seulement le
    // snackbar de confirmation encore affiché.
    if (!_isOnboarding && navigator != null && navigator.canPop()) {
      navigator.pop(true);
    } else {
      Get.offAllNamed(Routes.HOME);
    }
  }

  /// Reprend la sélection enregistrée sur l'appareil, s'il y en a une.
  void _restoreLocalSelection() {
    final saved = StorageService.getPreferences();
    final categories = saved?['categories'];
    if (categories is List) {
      selectedSubcategories
        ..clear()
        ..addAll(categories.map((c) => c.toString()));
    }
  }
}

class CategoryItem {
  final String id;
  final String name;
  final String svgPath;
  final List<SubcategoryItem> subcategories;

  CategoryItem({
    required this.id,
    required this.name,
    required this.svgPath,
    required this.subcategories,
  });
}

class SubcategoryItem {
  final String id;
  final String name;

  SubcategoryItem({required this.id, required this.name});
}
