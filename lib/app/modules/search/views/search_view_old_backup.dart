import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/product_service.dart';
import '../controllers/search_controller.dart' as search;
import '../../../core/utils/app_design.dart';

class SearchView extends GetView<search.SearchController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: Obx(() {
        // Si chargement
        if (controller.isLoading.value) {
          return _buildLoadingState(context);
        }

        // Si pas de résultats après recherche
        if (controller.filteredProducts.isEmpty &&
            controller.searchQuery.value.isNotEmpty) {
          return CustomScrollView(
            slivers: [
              // Barre de recherche épinglée
              _buildStickySearchBar(context),
              // Catégories épinglées
              _buildStickyCategories(context),
              // Barre de filtres épinglée
              _buildStickyFiltersBar(context),
              // Empty state
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              ),
            ],
          );
        }

        // État initial (pas de recherche)
        if (controller.filteredProducts.isEmpty) {
          return CustomScrollView(
            slivers: [
              // Barre de recherche épinglée
              _buildStickySearchBar(context),
              // Catégories épinglées
              _buildStickyCategories(context),
              // Initial state
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildInitialState(context),
              ),
            ],
          );
        }

        // Affichage des produits avec scroll et éléments épinglés
        return CustomScrollView(
          slivers: [
            // Barre de recherche épinglée
            _buildStickySearchBar(context),

            // Catégories épinglées
            _buildStickyCategories(context),

            // Barre de filtres épinglée
            _buildStickyFiltersBar(context),

            // Grille de produits scrollable
            _buildProductSliverGrid(context),
          ],
        );
      }),
    );
  }

  // ================================
  // HEADERS ÉPINGLÉS (STICKY)
  // ================================

  Widget _buildStickySearchBar(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        minHeight: 70,
        maxHeight: 70,
        child: _buildSearchBar(context),
      ),
    );
  }

  Widget _buildStickyCategories(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        minHeight: 62,
        maxHeight: 62,
        child: Container(
          color: AppThemeSystem.getBackgroundColor(context),
          child: _buildCategories(context),
        ),
      ),
    );
  }

  Widget _buildStickyFiltersBar(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        minHeight: 50,
        maxHeight: 50,
        child: Container(
          color: AppThemeSystem.getBackgroundColor(context),
          child: _buildFiltersBar(context),
        ),
      ),
    );
  }

  // ================================
  // BARRE DE RECHERCHE
  // ================================

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
        vertical: AppThemeSystem.getElementSpacing(context) * 0.8,
      ),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppThemeSystem.grey800
              : AppThemeSystem.grey100,
          borderRadius: BorderRadius.circular(
            AppThemeSystem.getBorderRadius(
              context,
              BorderRadiusType.medium,
            ),
          ),
        ),
        child: TextField(
          controller: controller.searchTextController,
          focusNode: controller.searchFocusNode,
          onSubmitted: (query) => controller.performSearch(query),
          decoration: InputDecoration(
            hintText: 'Rechercher des produits...',
            hintStyle: context.textStyle(
              FontSizeType.body1,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
            suffixIcon: Obx(
              () => controller.searchQuery.value.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: controller.clearSearch,
                      color: AppThemeSystem.getSecondaryTextColor(
                        context,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          style: context.textStyle(FontSizeType.body1),
        ),
      ),
    );
  }

  // ================================
  // CATÉGORIES
  // ================================

  Widget _buildCategories(BuildContext context) {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(
        vertical: AppThemeSystem.getElementSpacing(context) * 0.5,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppThemeSystem.getHorizontalPadding(context),
        ),
        itemCount: controller.categories.length,
        itemBuilder: (context, index) {
          final category = controller.categories[index];

          return Obx(
            () {
              final isSelected = controller.selectedCategory.value == category;

              return GestureDetector(
                onTap: () => controller.selectCategory(category),
                child: Container(
                  margin: EdgeInsets.only(
                    right: AppThemeSystem.getElementSpacing(context),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppThemeSystem.getHorizontalPadding(context),
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppThemeSystem.primaryColor
                        : AppThemeSystem.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(
                      AppThemeSystem.getBorderRadius(
                        context,
                        BorderRadiusType.large,
                      ),
                    ),
                    border: Border.all(
                      color: isSelected
                          ? AppThemeSystem.primaryColor
                          : AppThemeSystem.getBorderColor(context),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      category,
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? AppThemeSystem.whiteColor
                            : AppThemeSystem.getPrimaryTextColor(context),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ================================
  // BARRE DE FILTRES
  // ================================

  Widget _buildFiltersBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
        vertical: AppThemeSystem.getElementSpacing(context) * 0.5,
      ),
      child: Row(
        children: [
          // Bouton Filtres
          Obx(
            () => _buildFilterButton(
              context,
              icon: Icons.filter_list,
              label: 'Filtres',
              badge: controller.activeFiltersCount > 0
                  ? controller.activeFiltersCount.toString()
                  : null,
              onTap: () => _showFiltersBottomSheet(context),
            ),
          ),

          SizedBox(width: AppThemeSystem.getElementSpacing(context)),

          // Bouton Tri
          Obx(
            () => _buildFilterButton(
              context,
              icon: controller.selectedSortOption.value.icon,
              label: 'Trier',
              onTap: () => _showSortBottomSheet(context),
            ),
          ),

          const Spacer(),

          // Nombre de résultats
          Obx(
            () => Text(
              '${controller.filteredProducts.length} résultats',
              style: context.textStyle(
                FontSizeType.body2,
                color: AppThemeSystem.getSecondaryTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppThemeSystem.getHorizontalPadding(context) * 0.75,
          vertical: AppThemeSystem.getElementSpacing(context),
        ),
        decoration: BoxDecoration(
          color: badge != null
              ? AppThemeSystem.primaryColor.withOpacity(0.1)
              : AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(
            AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
          ),
          border: Border.all(
            color: badge != null
                ? AppThemeSystem.primaryColor
                : AppThemeSystem.getBorderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: badge != null
                  ? AppThemeSystem.primaryColor
                  : AppThemeSystem.getPrimaryTextColor(context),
            ),
            SizedBox(width: AppThemeSystem.getElementSpacing(context) * 0.5),
            Text(
              label,
              style: context.textStyle(
                FontSizeType.body2,
                fontWeight: FontWeight.w500,
                color: badge != null
                    ? AppThemeSystem.primaryColor
                    : AppThemeSystem.getPrimaryTextColor(context),
              ),
            ),
            if (badge != null) ...[
              SizedBox(width: AppThemeSystem.getElementSpacing(context) * 0.5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: context.textStyle(
                    FontSizeType.caption,
                    color: AppThemeSystem.whiteColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================================
  // GRILLE DE PRODUITS (SLIVER)
  // ================================

  Widget _buildProductSliverGrid(BuildContext context) {
    final deviceType = AppThemeSystem.getDeviceType(context);
    int crossAxisCount;
    double childAspectRatio;

    switch (deviceType) {
      case DeviceType.mobile:
        crossAxisCount = 2;
        childAspectRatio = 0.62;
        break;
      case DeviceType.tablet:
      case DeviceType.largeTablet:
        crossAxisCount = 3;
        childAspectRatio = 0.68;
        break;
      case DeviceType.iPadPro13:
      case DeviceType.desktop:
        crossAxisCount = 4;
        childAspectRatio = 0.72;
        break;
    }

    return Obx(
      () => SliverPadding(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppThemeSystem.getElementSpacing(context),
            mainAxisSpacing: AppThemeSystem.getElementSpacing(context),
            childAspectRatio: childAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final product = controller.filteredProducts[index];
              return _buildProductCard(context, product);
            },
            childCount: controller.filteredProducts.length,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final imageUrl = _getProductImageUrl(product);
    final isFavorite = product['is_favorite'] == true;
    final condition = product['condition'] as String?;
    final conditionLabel = _getConditionLabel(condition);
    final locationCity = product['location'] ?? product['shop']?['address'] ?? '';
    final productName = product['name'] ?? '';
    final formattedPrice = product['formatted_price'] ?? '${product['price']} FCFA';

    return GestureDetector(
      onTap: () => controller.onProductTap(product),
      child: Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(
            AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image du produit
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      AppThemeSystem.getBorderRadius(
                        context,
                        BorderRadiusType.medium,
                      ),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppThemeSystem.grey200,
                                child: const Center(
                                  child: Icon(Icons.image, size: 50),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: AppThemeSystem.grey200,
                            child: const Center(
                              child: Icon(Icons.image, size: 50),
                            ),
                          ),
                  ),
                ),

                // Bouton favori
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(product),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.whiteColor.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16,
                        color: isFavorite
                            ? AppDesign.danger
                            : AppThemeSystem.grey600,
                      ),
                    ),
                  ),
                ),

                // Badge condition (si différent de "nouveau")
                if (condition != null && condition != 'nouveau')
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.infoColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        conditionLabel,
                        style: context.textStyle(
                          FontSizeType.overline,
                          color: AppThemeSystem.whiteColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Infos du produit
            Padding(
              padding: EdgeInsets.all(
                AppThemeSystem.getElementSpacing(context) * 0.7,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nom du produit
                  Text(
                    productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.caption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  SizedBox(
                    height: AppThemeSystem.getElementSpacing(context) * 0.25,
                  ),

                  // Prix
                  Text(
                    formattedPrice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.caption,
                      fontWeight: FontWeight.bold,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),

                  SizedBox(
                    height: AppThemeSystem.getElementSpacing(context) * 0.25,
                  ),

                  // Localisation
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 10,
                        color: AppThemeSystem.getSecondaryTextColor(context),
                      ),
                      SizedBox(
                        width:
                            AppThemeSystem.getElementSpacing(context) * 0.15,
                      ),
                      Expanded(
                        child: Text(
                          locationCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyle(
                            FontSizeType.overline,
                            color:
                                AppThemeSystem.getSecondaryTextColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================
  // HELPER METHODS
  // ================================

  /// Extracts image URL from product map
  String _getProductImageUrl(Map<String, dynamic> product) {
    final mainImage = product['main_image'] as String?;
    if (mainImage != null && mainImage.isNotEmpty) {
      return mainImage;
    }

    final images = product['images'] as List?;
    if (images != null && images.isNotEmpty) {
      final firstImage = images[0] as Map<String, dynamic>?;
      if (firstImage != null && firstImage['url'] != null) {
        return firstImage['url'] as String;
      }
    }

    return '';
  }

  /// Maps condition string to French label
  String _getConditionLabel(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'nouveau':
        return 'Neuf';
      case 'bon':
        return 'Bon';
      case 'excellent':
        return 'Excellent';
      case 'acceptable':
        return 'Acceptable';
      case 'occasion':
        return 'Occasion';
      default:
        return 'État inconnu';
    }
  }

  /// Toggle favorite status for product
  void _toggleFavorite(Map<String, dynamic> product) async {
    final productId = product['id'] as int?;
    if (productId == null) return;

    try {
      await ProductService.toggleFavorite(productId);
      // Update the local favorite status
      product['is_favorite'] = !(product['is_favorite'] == true);
      controller.searchResults.refresh();
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de mettre à jour le favori',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ================================
  // ÉTATS
  // ================================

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppThemeSystem.primaryColor,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
            SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
            Text(
              'Aucun résultat trouvé',
              style: context.h5,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppThemeSystem.getElementSpacing(context)),
            Text(
              'Essayez avec d\'autres mots-clés ou modifiez vos filtres',
              style: context.textStyle(
                FontSizeType.body1,
                color: AppThemeSystem.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
            if (controller.activeFiltersCount > 0)
              ElevatedButton.icon(
                onPressed: controller.resetFilters,
                icon: const Icon(Icons.refresh),
                label: const Text('Réinitialiser les filtres'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: AppThemeSystem.whiteColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
            SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
            Text(
              'Recherchez des produits',
              style: context.h5,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppThemeSystem.getElementSpacing(context)),
            Text(
              'Utilisez la barre de recherche pour trouver ce que vous cherchez',
              style: context.textStyle(
                FontSizeType.body1,
                color: AppThemeSystem.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),

            // Historique de recherche
            Obx(() {
              if (controller.searchHistory.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                children: [
                  SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recherches récentes',
                        style: context.textStyle(
                          FontSizeType.subtitle1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: controller.clearHistory,
                        child: Text(
                          'Effacer',
                          style: context.textStyle(
                            FontSizeType.body2,
                            color: AppThemeSystem.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: AppThemeSystem.getElementSpacing(context),
                  ),
                  ...controller.searchHistory.take(5).map(
                        (query) => ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(query),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                controller.removeFromHistory(query),
                          ),
                          onTap: () => controller.performSearch(query),
                        ),
                      ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ================================
  // BOTTOM SHEETS
  // ================================

  void _showFiltersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FiltersBottomSheet(controller: controller),
    );
  }

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SortBottomSheet(controller: controller),
    );
  }
}

// ================================
// SLIVER PERSISTENT HEADER DELEGATE
// ================================

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

// ================================
// BOTTOM SHEET DES FILTRES
// ================================

class _FiltersBottomSheet extends StatelessWidget {
  final search.SearchController controller;

  const _FiltersBottomSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: AppThemeSystem.getBottomSheetPadding(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppThemeSystem.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemeSystem.getHorizontalPadding(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filtres', style: context.h5),
                TextButton(
                  onPressed: () {
                    controller.resetFilters();
                    Get.back();
                  },
                  child: Text(
                    'Réinitialiser',
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Filters content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppThemeSystem.getHorizontalPadding(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prix
                  Text('Plage de prix', style: context.subtitle1),
                  SizedBox(height: AppThemeSystem.getElementSpacing(context)),
                  Obx(
                    () => RangeSlider(
                      values: RangeValues(
                        controller.minPrice.value,
                        controller.maxPrice.value,
                      ),
                      min: 0,
                      max: 1000000,
                      divisions: 100,
                      activeColor: AppThemeSystem.primaryColor,
                      labels: RangeLabels(
                        '${controller.minPrice.value.toStringAsFixed(0)} FCFA',
                        '${controller.maxPrice.value.toStringAsFixed(0)} FCFA',
                      ),
                      onChanged: (values) {
                        controller.setPriceRange(values.start, values.end);
                      },
                    ),
                  ),
                  Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${controller.minPrice.value.toStringAsFixed(0)} FCFA',
                          style: context.caption,
                        ),
                        Text(
                          '${controller.maxPrice.value.toStringAsFixed(0)} FCFA',
                          style: context.caption,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

                  // Localisation
                  Text('Localisation', style: context.subtitle1),
                  SizedBox(height: AppThemeSystem.getElementSpacing(context)),
                  Obx(
                    () => Wrap(
                      spacing: AppThemeSystem.getElementSpacing(context),
                      runSpacing: AppThemeSystem.getElementSpacing(context),
                      children: controller.cities.map((city) {
                        final isSelected =
                            controller.selectedLocation.value == city;
                        return ChoiceChip(
                          label: Text(city),
                          selected: isSelected,
                          onSelected: (selected) {
                            controller.selectLocation(city);
                          },
                          selectedColor: AppThemeSystem.primaryColor,
                          labelStyle: context.textStyle(
                            FontSizeType.body2,
                            color: isSelected
                                ? AppThemeSystem.whiteColor
                                : AppThemeSystem.getPrimaryTextColor(context),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: EdgeInsets.all(
              AppThemeSystem.getHorizontalPadding(context),
            ),
            child: SizedBox(
              width: double.infinity,
              height: AppThemeSystem.getButtonHeight(context),
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: AppThemeSystem.whiteColor,
                ),
                child: Text(
                  'Appliquer les filtres',
                  style: context.button,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================
// BOTTOM SHEET DU TRI
// ================================

class _SortBottomSheet extends StatelessWidget {
  final search.SearchController controller;

  const _SortBottomSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: AppThemeSystem.getBottomSheetPadding(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppThemeSystem.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemeSystem.getHorizontalPadding(context),
            ),
            child: Row(
              children: [
                Text('Trier par', style: context.h5),
              ],
            ),
          ),

          const Divider(),

          // Sort options
          Obx(
            () => Column(
              children: search.SortOption.values.map((option) {
                final isSelected = controller.selectedSortOption.value == option;
                return ListTile(
                  leading: Icon(
                    option.icon,
                    color: isSelected
                        ? AppThemeSystem.primaryColor
                        : AppThemeSystem.getSecondaryTextColor(context),
                  ),
                  title: Text(
                    option.label,
                    style: context.textStyle(
                      FontSizeType.body1,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? AppThemeSystem.primaryColor
                          : AppThemeSystem.getPrimaryTextColor(context),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check,
                          color: AppThemeSystem.primaryColor,
                        )
                      : null,
                  onTap: () {
                    controller.selectSortOption(option);
                    Get.back();
                  },
                );
              }).toList(),
            ),
          ),

          SizedBox(height: AppThemeSystem.getElementSpacing(context)),
        ],
      ),
    );
  }
}
