import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../controllers/favorites_controller.dart';
import '../../../data/models/wholesale_models.dart';

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
        centerTitle: false,
        leading: const AppBackButton(),
        title: Text(
          'favorites.title'.tr,
          style: Theme.of(context).appBarTheme.titleTextStyle,
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
              tooltip: 'favorites.remove_all'.tr,
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
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200) {
                controller.loadMore();
              }
              return false;
            },
            child: GridView.builder(
              padding: EdgeInsets.all(context.ds.gutter),
              gridDelegate: ProductCard.gridDelegate(context),
              itemCount:
                  controller.favoriteProducts.length +
                  (controller.isLoadingMore.value ? 2 : 0),
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
    return AppEmptyState(
      icon: Icons.favorite_border_rounded,
      title: 'favorites.empty_title'.tr,
      message: 'favorites.empty_message'.tr,
      actionLabel: 'favorites.explore_products'.tr,
      onAction: () => AppNavigation.back(context),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Map<String, dynamic> product,
    DeviceType deviceType,
  ) {
    final productId = product['id'] is int
        ? product['id'] as int
        : int.tryParse('${product['id']}') ?? 0;
    final shop = product['shop'] as Map<String, dynamic>?;

    return ProductCard(
      video: WholesaleVideo.fromJson(product['video']),
      name: product['name']?.toString() ?? 'favorites.product_fallback'.tr,
      price: _formatPrice(product),
      location: _getLocation(product),
      isFavorite: true,
      isCertified: shop?['is_certified'] == true,
      imageBuilder: (context) => _buildProductImage(context, product),
      onTap: () => Get.toNamed('/product', arguments: product),
      onFavoriteTap: productId > 0
          ? () => controller.toggleFavorite(productId)
          : null,
    );
  }

  Widget _buildProductImage(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final primaryImage = product['primary_image'];
    final images = product['images'] as List?;

    String? imageUrl;
    if (primaryImage != null && primaryImage.toString().isNotEmpty) {
      imageUrl = primaryImage.toString();
    } else if (images != null && images.isNotEmpty) {
      imageUrl = images[0] is Map ? images[0]['url'] : images[0].toString();
    }

    if (imageUrl != null && imageUrl.startsWith('http')) {
      // Décodée à la taille de la carte, pas en pleine résolution.
      final cardWidth = ProductCard.widthInGrid(context);
      return AppNetworkImage(
        url: imageUrl,
        decodeSize: Size(cardWidth, cardWidth / ProductCard.imageAspectRatio),
        placeholder: (_) => const SizedBox.expand(),
        showProgress: true,
        errorBuilder: (_) => _buildPlaceholderImage(),
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
    if (product['price'] == null && product['price_xaf'] == null) {
      return 'favorites.price_undefined'.tr;
    }
    return CurrencyService.formatProductPrice(product);
  }

  String _getLocation(Map<String, dynamic> product) {
    return product['location']?.toString() ??
        product['shop']?['address']?.toString() ??
        '';
  }
}
