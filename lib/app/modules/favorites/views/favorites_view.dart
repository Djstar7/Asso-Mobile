import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../../../core/widgets/verified_badge.dart';
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
              padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: deviceType == DeviceType.mobile ? 2 : 3,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
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
    final deviceType = AppThemeSystem.getDeviceType(context);

    return GridView.builder(
      padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: deviceType == DeviceType.mobile ? 2 : 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
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
    return GestureDetector(
      onTap: () => controller.goToProductDetails(product),
      child: Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppThemeSystem.getBorderColor(context).withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: SizedBox.expand(
                      child: _buildProductImage(product),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        final productId = product['id'] is int
                            ? product['id']
                            : int.tryParse(product['id'].toString()) ?? 0;
                        controller.toggleFavorite(productId);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 18,
                          color: AppThemeSystem.errorColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Produit',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatPrice(product),
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (product['shop'] != null && product['shop']['name'] != null)
                    Row(
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 14,
                          color: AppThemeSystem.grey600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product['shop']['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.caption,
                              color: AppThemeSystem.grey700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        VerifiedBadge(
                          isCertified: product['shop']['is_certified'] ?? false,
                          size: 14,
                        ),
                      ],
                    ),
                  if (product['shop'] != null && product['shop']['name'] != null)
                    const SizedBox(height: 8),
                  if (_getLocation(product).isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: AppThemeSystem.grey600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getLocation(product),
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
              ),
            ),
          ],
        ),
      ),
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
    final formattedPrice = product['formatted_price'];
    if (formattedPrice != null) return formattedPrice.toString();

    final price = product['price'];
    if (price != null) {
      if (price is num) {
        return '${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]} ')} FCFA';
      }
      return '$price FCFA';
    }
    return 'Prix non défini';
  }

  String _getLocation(Map<String, dynamic> product) {
    return product['location']?.toString() ?? product['shop']?['address']?.toString() ?? '';
  }
}
