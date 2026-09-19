import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../controllers/favorites_controller.dart';

class FavoritesView extends GetView<FavoritesController> {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final deviceType = AppThemeSystem.getDeviceType(context);

    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppThemeSystem.getPrimaryTextColor(context),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Mes Favoris',
          style: context.textStyle(
            deviceType == DeviceType.mobile ? FontSizeType.h5 : FontSizeType.h4,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Obx(() {
            if (controller.favoriteProducts.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: AppThemeSystem.errorColor,
              ),
              tooltip: 'Supprimer tout',
              onPressed: controller.removeAllFavorites,
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.favoriteProducts.isEmpty) {
          return _buildLoadingState(context);
        }

        if (controller.favoriteProducts.isEmpty) {
          return _buildEmptyState(context, deviceType);
        }

        return RefreshIndicator(
          onRefresh: controller.refreshFavorites,
          color: AppThemeSystem.primaryColor,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                controller.loadMore();
              }
              return false;
            },
            child: GridView.builder(
              padding: EdgeInsets.all(context.ds.gutter),
              gridDelegate: ProductCard.gridDelegate(context),
              itemCount: controller.favoriteProducts.length + (controller.isLoadingMore.value ? 2 : 0),
              itemBuilder: (context, index) {
                if (index >= controller.favoriteProducts.length) {
                  return ShimmerWidgets.productCardShimmer(context);
                }

                final product = controller.favoriteProducts[index];
                return _buildProductCard(context, product, deviceType);
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(context.ds.gutter),
      gridDelegate: ProductCard.gridDelegate(context),
      itemCount: 6,
      itemBuilder: (context, index) {
        return ShimmerWidgets.productCardShimmer(context);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, DeviceType deviceType) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context) * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    AppThemeSystem.tertiaryColor.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: deviceType == DeviceType.mobile ? 80 : 100,
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.6),
              ),
            ),

            SizedBox(height: AppThemeSystem.getVerticalPadding(context) * 1.5),

            Text(
              'Aucun favori',
              style: context.textStyle(
                deviceType == DeviceType.mobile ? FontSizeType.h4 : FontSizeType.h3,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.getPrimaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppThemeSystem.getElementSpacing(context)),

            Text(
              'Vous n\'avez pas encore ajouté de produits à vos favoris.\nCommencez à explorer pour trouver des produits qui vous plaisent!',
              style: context.textStyle(
                FontSizeType.body1,
                color: isDark ? AppThemeSystem.grey400 : AppThemeSystem.grey600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppThemeSystem.getVerticalPadding(context) * 2),

            ElevatedButton.icon(
              onPressed: () => Get.back(),
              icon: Icon(Icons.explore_rounded, color: Colors.white),
              label: Text(
                'Explorer les produits',
                style: context.textStyle(
                  FontSizeType.body1,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product, DeviceType deviceType) {
    final productId = product['id'] is int
        ? product['id'] as int
        : int.tryParse('${product['id']}') ?? 0;
    final shop = product['shop'] as Map<String, dynamic>?;

    return ProductCard(
      name: product['name']?.toString() ?? 'Produit',
      price: _formatPrice(product),
      location: _getLocation(product),
      isFavorite: true,
      isCertified: shop?['is_certified'] == true,
      imageBuilder: (context) => _buildProductImage(product),
      onTap: () => Get.toNamed('/product', arguments: product),
      onFavoriteTap:
          productId > 0 ? () => controller.toggleFavorite(productId) : null,
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    final primaryImage = product['primary_image'];
    final images = product['images'] as List?;

    String? imageUrl;
    if (primaryImage != null && primaryImage.toString().isNotEmpty) {
      imageUrl = primaryImage.toString();
    } else if (images != null && images.isNotEmpty) {
      imageUrl = images[0] is Map ? images[0]['url'] : images[0].toString();
    }

    if (imageUrl != null && imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: AppThemeSystem.primaryColor,
            ),
          );
        },
      );
    }

    final localImage = product['image'];
    if (localImage != null && localImage.toString().isNotEmpty) {
      return Image.asset(
        localImage.toString(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppThemeSystem.grey200,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: Colors.grey),
      ),
    );
  }

  String _formatPrice(Map<String, dynamic> product) {
    final price = product['price_xaf'] ?? product['price'];
    if (price != null) {
      if (price is num) {
        return controller.formatPrice(price.toDouble());
      }
      final priceValue = double.tryParse(price.toString());
      if (priceValue != null) {
        return controller.formatPrice(priceValue);
      }
      return '$price ${controller.currencySymbol}';
    }
    return 'Prix non défini';
  }

  String _getLocation(Map<String, dynamic> product) {
    return product['location']?.toString() ?? product['shop']?['address']?.toString() ?? '';
  }
}
