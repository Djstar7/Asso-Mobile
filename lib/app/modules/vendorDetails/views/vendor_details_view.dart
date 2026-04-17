import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/vendor_details_controller.dart';

class VendorDetailsView extends GetView<VendorDetailsController> {
  const VendorDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: Obx(() {
        if (controller.isLoading.value) {
          return _buildLoadingState(context);
        }

        if (controller.hasError.value) {
          return _buildErrorState(context);
        }

        return _buildContent(context);
      }),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              AppThemeSystem.primaryColor,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement de la boutique...',
            style: context.textStyle(
              FontSizeType.body1,
              color: AppThemeSystem.grey600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: AppThemeSystem.errorColor,
            ),
            SizedBox(height: 16),
            Text(
              'Erreur',
              style: context.textStyle(
                FontSizeType.h5,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              controller.errorMessage.value,
              style: context.textStyle(
                FontSizeType.body1,
                color: AppThemeSystem.grey600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Get.back(),
              icon: Icon(Icons.arrow_back_rounded),
              label: Text('Retour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final shop = controller.shopData.value;
    if (shop == null) return SizedBox.shrink();

    final deviceType = AppThemeSystem.getDeviceType(context);
    final isTablet = deviceType == DeviceType.tablet ||
        deviceType == DeviceType.largeTablet ||
        deviceType == DeviceType.iPadPro13 ||
        deviceType == DeviceType.desktop;

    return CustomScrollView(
      slivers: [
        // App Bar with shop header
        _buildAppBar(context, shop),

        // Shop Info Section
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(
              AppThemeSystem.getHorizontalPadding(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShopInfo(context, shop),
                SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
                _buildShopStats(context),
                SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
                _buildProductsHeader(context),
              ],
            ),
          ),
        ),

        // Products Grid
        Obx(() {
          if (controller.products.isEmpty) {
            return SliverToBoxAdapter(
              child: _buildEmptyProducts(context),
            );
          }

          return SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemeSystem.getHorizontalPadding(context),
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                childAspectRatio: 0.7,
                mainAxisSpacing: AppThemeSystem.getElementSpacing(context),
                crossAxisSpacing: AppThemeSystem.getElementSpacing(context),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = controller.products[index];
                  return _buildProductCard(context, product);
                },
                childCount: controller.products.length,
              ),
            ),
          );
        }),

        // Bottom padding
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppThemeSystem.getSectionSpacing(context),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, Map<String, dynamic> shop) {
    final shopName = shop['name']?.toString() ?? 'Boutique';
    final shopLogo = shop['logo']?.toString();

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppThemeSystem.getSurfaceColor(context),
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          shopName,
          style: context.textStyle(
            FontSizeType.h6,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        background: shopLogo != null && shopLogo.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    shopLogo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppThemeSystem.primaryColor,
                            AppThemeSystem.tertiaryColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppThemeSystem.primaryColor,
                      AppThemeSystem.tertiaryColor,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.store_rounded,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildShopInfo(BuildContext context, Map<String, dynamic> shop) {
    final shopName = shop['name']?.toString() ?? 'Boutique';
    final shopDescription = shop['description']?.toString() ?? '';
    final shopAddress = shop['address']?.toString() ?? 'Adresse non spécifiée';
    final isCertified = shop['is_certified'] == true || shop['is_certified'] == 1;
    final ownerName = shop['owner']?['name']?.toString() ?? 'Propriétaire';
    final ownerAvatar = shop['owner']?['profile_picture']?.toString();

    return Container(
      padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop Name with certification badge
          Row(
            children: [
              Expanded(
                child: Text(
                  shopName,
                  style: context.textStyle(
                    FontSizeType.h4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isCertified)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E88E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(0xFF1E88E5).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFF1E88E5),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Certifié',
                        style: context.textStyle(
                          FontSizeType.caption,
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (shopDescription.isNotEmpty) ...[
            SizedBox(height: AppThemeSystem.getElementSpacing(context)),
            Text(
              shopDescription,
              style: context.textStyle(
                FontSizeType.body2,
                color: AppThemeSystem.getSecondaryTextColor(context),
                height: 1.5,
              ),
            ),
          ],

          SizedBox(height: AppThemeSystem.getElementSpacing(context)),
          Divider(),
          SizedBox(height: AppThemeSystem.getElementSpacing(context)),

          // Owner info
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: ownerAvatar != null && ownerAvatar.isNotEmpty
                      ? Image.network(
                          ownerAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildOwnerAvatarPlaceholder(),
                        )
                      : _buildOwnerAvatarPlaceholder(),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Propriétaire',
                      style: context.textStyle(
                        FontSizeType.caption,
                        color: AppThemeSystem.grey600,
                      ),
                    ),
                    Text(
                      ownerName,
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: AppThemeSystem.getElementSpacing(context)),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_rounded,
                color: AppThemeSystem.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  shopAddress,
                  style: context.textStyle(
                    FontSizeType.body2,
                    color: AppThemeSystem.getSecondaryTextColor(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerAvatarPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeSystem.primaryColor,
            AppThemeSystem.tertiaryColor,
          ],
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildShopStats(BuildContext context) {
    final stats = controller.shopStats.value;
    if (stats == null) return SizedBox.shrink();

    final productsCount = stats['products_count'] ?? 0;
    final averageRating = stats['average_rating'] ?? 0.0;
    final reviewsCount = stats['reviews_count'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.inventory_2_rounded,
            label: 'Produits',
            value: productsCount.toString(),
          ),
        ),
        SizedBox(width: AppThemeSystem.getElementSpacing(context)),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.star_rounded,
            label: 'Note moyenne',
            value: averageRating is num ? averageRating.toStringAsFixed(1) : averageRating.toString(),
            valueColor: Colors.amber,
          ),
        ),
        SizedBox(width: AppThemeSystem.getElementSpacing(context)),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.rate_review_rounded,
            label: 'Avis',
            value: reviewsCount.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
        ),
        border: Border.all(
          color: AppThemeSystem.getBorderColor(context),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppThemeSystem.primaryColor,
            size: 24,
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: context.textStyle(
              FontSizeType.h5,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: context.textStyle(
              FontSizeType.caption,
              color: AppThemeSystem.grey600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Produits',
          style: context.textStyle(
            FontSizeType.h5,
            fontWeight: FontWeight.bold,
          ),
        ),
        Obx(() => Text(
              '${controller.products.length} article${controller.products.length > 1 ? 's' : ''}',
              style: context.textStyle(
                FontSizeType.body2,
                color: AppThemeSystem.grey600,
              ),
            )),
      ],
    );
  }

  Widget _buildEmptyProducts(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context) * 2),
      child: Column(
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppThemeSystem.grey400,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun produit disponible',
            style: context.textStyle(
              FontSizeType.body1,
              color: AppThemeSystem.grey600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final productName = product['name']?.toString() ?? 'Produit';
    final productPrice = product['price'] ?? 0;
    final productStock = product['stock'] ?? 0;

    // Get images - prioritize primary_image, then try images array
    String? productImage;
    if (product['primary_image'] != null && product['primary_image'].toString().isNotEmpty) {
      productImage = product['primary_image'].toString();
    } else if (product['images'] != null && product['images'] is List && (product['images'] as List).isNotEmpty) {
      final images = product['images'] as List;
      if (images.isNotEmpty) {
        productImage = images[0].toString();
      }
    }

    return InkWell(
      onTap: () => controller.onProductTap(product),
      borderRadius: BorderRadius.circular(
        AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(
            AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(
                    AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    productImage != null && productImage.isNotEmpty
                        ? Image.network(
                            productImage,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppThemeSystem.primaryColor,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                    // Stock badge
                    if (productStock <= 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppThemeSystem.errorColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Épuisé',
                            style: context.textStyle(
                              FontSizeType.overline,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      productName,
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${productPrice} FCFA',
                      style: context.textStyle(
                        FontSizeType.body1,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppThemeSystem.grey200,
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: AppThemeSystem.grey400,
      ),
    );
  }
}
