import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../controllers/search_controller.dart' as search_ctrl;

/// Vue de recherche moderne et responsive
class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialiser le controller s'il n'existe pas
    if (!Get.isRegistered<search_ctrl.SearchController>()) {
      Get.put(search_ctrl.SearchController());
    }

    return const _SearchViewContent();
  }
}

class _SearchViewContent extends GetView<search_ctrl.SearchController> {
  const _SearchViewContent();

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            // Barre de recherche fixe
            _buildSearchHeader(context, isDark),

            // Contenu scrollable
            Expanded(
              child: Obx(() => _buildContent(context, isDark)),
            ),
          ],
        ),
      ),
    );
  }

  /// Header avec barre de recherche
  Widget _buildSearchHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Champ de recherche
          Row(
            children: [
              // Bouton retour
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: AppThemeSystem.getPrimaryTextColor(context),
                ),
                onPressed: () => Get.back(),
              ),

              // Champ de recherche
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppThemeSystem.grey300,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: controller.searchTextController,
                    focusNode: controller.searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      controller.searchQuery.value = value;
                    },
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        controller.performSearch(value);
                      }
                    },
                    style: TextStyle(
                      color: AppThemeSystem.blackColor,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rechercher des produits...',
                      hintStyle: TextStyle(
                        color: AppThemeSystem.grey500,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppThemeSystem.primaryColor,
                      ),
                      suffixIcon: Obx(() =>
                        controller.searchQuery.value.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: AppThemeSystem.grey500,
                                ),
                                onPressed: controller.clearSearch,
                              )
                            : const SizedBox.shrink(),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Filtres rapides (catégories)
          const SizedBox(height: 12),
          _buildQuickFilters(context, isDark),
        ],
      ),
    );
  }

  /// Filtres rapides (catégories)
  Widget _buildQuickFilters(BuildContext context, bool isDark) {
    return SizedBox(
      height: 40,
      child: Obx(() {
        if (controller.categories.isEmpty) return const SizedBox.shrink();

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: controller.categories.length,
          itemBuilder: (context, index) {
            final category = controller.categories[index];

            // Chaque chip doit observer selectedCategory individuellement
            return Obx(() {
              final isSelected = index == 0
                  ? controller.selectedCategory.value.isEmpty || controller.selectedCategory.value == 'Tous'
                  : controller.selectedCategory.value == category;

              return _buildFilterChip(
                context,
                isDark,
                label: category,
                icon: index == 0 ? Icons.grid_view_rounded : null,
                isSelected: isSelected,
                onTap: () {
                  controller.selectCategory(category);
                },
              );
            });
          },
        );
      }),
    );
  }

  /// Chip de filtre
  Widget _buildFilterChip(
    BuildContext context,
    bool isDark, {
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppThemeSystem.primaryColor,
                      AppThemeSystem.tertiaryColor,
                    ],
                  )
                : null,
            color: isSelected
                ? null
                : isDark
                    ? AppThemeSystem.grey800
                    : AppThemeSystem.grey200,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? null
                : Border.all(
                    color: isDark
                        ? AppThemeSystem.grey700
                        : AppThemeSystem.grey300,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : AppThemeSystem.getPrimaryTextColor(context),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.body2,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : AppThemeSystem.getPrimaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Contenu principal
  Widget _buildContent(BuildContext context, bool isDark) {
    // État de chargement
    if (controller.isLoading.value) {
      return _buildLoadingState(context);
    }

    // Historique de recherche (si aucune recherche en cours)
    if (!controller.isSearching.value && controller.searchQuery.value.isEmpty) {
      return _buildSearchHistory(context, isDark);
    }

    // Résultats de recherche
    if (controller.searchResults.isEmpty && controller.searchQuery.value.isNotEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return _buildResults(context, isDark);
  }

  /// État de chargement
  Widget _buildLoadingState(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            AppThemeSystem.getDeviceType(context) == DeviceType.mobile ? 2 : 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => ShimmerWidgets.productCardShimmer(context),
    );
  }

  /// Historique de recherche
  Widget _buildSearchHistory(BuildContext context, bool isDark) {
    return Obx(() {
      if (controller.searchHistory.isEmpty) {
        return _buildInitialState(context, isDark);
      }

      return SingleChildScrollView(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recherches récentes',
                  style: context.textStyle(
                    FontSizeType.h5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: controller.clearHistory,
                  child: Text(
                    'Effacer tout',
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...controller.searchHistory.map((query) => InkWell(
                onTap: () => controller.performSearch(query),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppThemeSystem.darkCardColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppThemeSystem.grey800
                          : AppThemeSystem.grey200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: AppThemeSystem.grey500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          query,
                          style: context.textStyle(FontSizeType.body1),
                        ),
                      ),
                      Icon(
                        Icons.north_west_rounded,
                        color: AppThemeSystem.grey400,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              )),
          ],
        ),
      );
    });
  }

  /// État initial (suggestions)
  Widget _buildInitialState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    AppThemeSystem.tertiaryColor.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                size: 64,
                color: AppThemeSystem.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recherchez des produits',
              style: context.textStyle(
                FontSizeType.h4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trouvez ce que vous cherchez parmi\ndes milliers de produits',
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.body2,
                color: AppThemeSystem.grey600,
              ),
            ),
            const SizedBox(height: 32),
            // Suggestions de recherche
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                'Vêtements',
                'Électronique',
                'Chaussures',
                'Accessoires',
              ].map((tag) {
                return InkWell(
                  onTap: () {
                    controller.searchTextController.text = tag;
                    controller.searchQuery.value = tag;
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppThemeSystem.grey800
                          : AppThemeSystem.grey100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppThemeSystem.grey700
                            : AppThemeSystem.grey300,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: context.textStyle(FontSizeType.body2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// État vide (aucun résultat)
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark
                    ? AppThemeSystem.grey800
                    : AppThemeSystem.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64,
                color: AppThemeSystem.grey500,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun résultat trouvé',
              style: context.textStyle(
                FontSizeType.h4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec des mots-clés différents\nou parcourez les catégories',
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.body2,
                color: AppThemeSystem.grey600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: controller.clearSearch,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Nouvelle recherche'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Résultats de recherche
  Widget _buildResults(BuildContext context, bool isDark) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          controller.loadMore();
        }
        return true;
      },
      child: CustomScrollView(
        slivers: [
          // En-tête des résultats
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() => Text(
                        '${controller.searchResults.length} produit${controller.searchResults.length > 1 ? 's' : ''}',
                        style: context.textStyle(
                          FontSizeType.body1,
                          fontWeight: FontWeight.w600,
                        ),
                      )),
                  // Bouton tri (optionnel)
                  IconButton(
                    icon: Icon(
                      Icons.tune_rounded,
                      color: AppThemeSystem.primaryColor,
                    ),
                    onPressed: () => _showFiltersBottomSheet(context, isDark),
                  ),
                ],
              ),
            ),
          ),

          // Grille de produits
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemeSystem.getHorizontalPadding(context),
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    AppThemeSystem.getDeviceType(context) == DeviceType.mobile
                        ? 2
                        : 3,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = controller.searchResults[index];
                  return _buildProductCard(context, isDark, product);
                },
                childCount: controller.searchResults.length,
              ),
            ),
          ),

          // Loading more indicator
          Obx(() {
            if (controller.isLoading.value && controller.searchResults.isNotEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                ),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }),

          // Espacement en bas
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppThemeSystem.getVerticalPadding(context) * 2,
            ),
          ),
        ],
      ),
    );
  }

  /// Card de produit
  Widget _buildProductCard(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> product,
  ) {
    final primaryImage = product['primary_image']?.toString();
    final name = product['name']?.toString() ?? 'Produit';
    final formattedPrice = product['formatted_price']?.toString() ?? '';
    final location = product['location']?.toString() ?? '';

    return GestureDetector(
      onTap: () => controller.onProductTap(product),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppThemeSystem.grey800
                : AppThemeSystem.grey200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: primaryImage != null && primaryImage.isNotEmpty
                    ? Image.network(
                        primaryImage,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),

            // Infos
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      formattedPrice,
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppThemeSystem.grey600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.caption,
                              color: AppThemeSystem.grey600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      color: AppThemeSystem.grey200,
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: AppThemeSystem.grey400,
      ),
    );
  }

  /// Affiche la modal de filtres
  void _showFiltersBottomSheet(BuildContext context, bool isDark) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtres',
                  style: context.textStyle(
                    FontSizeType.h5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Options de tri
            Text(
              'Trier par',
              style: context.textStyle(
                FontSizeType.body1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: search_ctrl.SortOption.values.map((option) {
                final isSelected = controller.selectedSortOption.value == option;
                return InkWell(
                  onTap: () {
                    controller.selectSortOption(option);
                    Get.back();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppThemeSystem.primaryColor,
                                AppThemeSystem.tertiaryColor,
                              ],
                            )
                          : null,
                      color: isSelected
                          ? null
                          : isDark
                              ? AppThemeSystem.grey800
                              : AppThemeSystem.grey200,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isDark
                                  ? AppThemeSystem.grey700
                                  : AppThemeSystem.grey300,
                            ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option.icon,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : AppThemeSystem.getPrimaryTextColor(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          option.label,
                          style: context.textStyle(
                            FontSizeType.body2,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppThemeSystem.getPrimaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )),

            const SizedBox(height: 24),

            // Bouton réinitialiser
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  controller.resetFilters();
                  Get.back();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réinitialiser les filtres'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeSystem.primaryColor,
                  side: BorderSide(color: AppThemeSystem.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
      isDismissible: true,
      enableDrag: true,
    );
  }
}
