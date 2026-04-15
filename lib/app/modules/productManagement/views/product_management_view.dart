import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/product_management_controller.dart';

class ProductManagementView extends GetView<ProductManagementController> {
  const ProductManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: context.primaryTextColor,
          ),
          onPressed: () {
            if (Get.isOverlaysOpen) {
              Get.back();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Obx(() {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mes Produits',
                style: context.h5.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (controller.totalProducts.value > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${controller.totalProducts.value}',
                    style: context.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.products.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppThemeSystem.primaryColor,
              ),
            ),
          );
        }

        if (controller.products.isEmpty) {
          return _buildEmptyState(context);
        }

        return _buildProductsList(context);
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.navigateToAddProduct,
        backgroundColor: AppThemeSystem.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Ajouter',
          style: context.button.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.horizontalPadding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 100,
              color: context.borderColor,
            ),
            SizedBox(height: context.elementSpacing),
            Text(
              'Aucun produit publié',
              style: context.h6.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.elementSpacing / 2),
            Text(
              'Commencez à vendre en ajoutant votre premier produit',
              style: context.body2.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.sectionSpacing),
            ElevatedButton.icon(
              onPressed: controller.navigateToAddProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Ajouter mon premier produit',
                style: context.button.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build products list
  Widget _buildProductsList(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refreshProducts,
      color: AppThemeSystem.primaryColor,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!controller.isLoading.value &&
              controller.hasMore.value &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            controller.loadMoreProducts();
          }
          return false;
        },
        child: ListView.builder(
          padding: EdgeInsets.all(context.horizontalPadding),
          itemCount: controller.products.length + (controller.hasMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == controller.products.length) {
              // Loading indicator for pagination
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Obx(() {
                    return controller.isLoading.value
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppThemeSystem.primaryColor,
                            ),
                          )
                        : const SizedBox.shrink();
                  }),
                ),
              );
            }

            final product = controller.products[index];
            return _buildProductCard(context, product);
          },
        ),
      ),
    );
  }

  /// Build product card
  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final images = product['images'] as List?;
    final imageUrl = images != null && images.isNotEmpty
        ? images[0]['url'] as String?
        : null;
    final status = product['status'] as String? ?? 'inactive';

    return Container(
      margin: EdgeInsets.only(bottom: context.elementSpacing),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Product Image and Info
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(
                        context.deviceType == DeviceType.mobile ? 12 : 16,
                      ),
                      bottomLeft: Radius.circular(
                        context.deviceType == DeviceType.mobile ? 12 : 16,
                      ),
                    ),
                  ),
                  child: imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(
                              context.deviceType == DeviceType.mobile ? 12 : 16,
                            ),
                            bottomLeft: Radius.circular(
                              context.deviceType == DeviceType.mobile ? 12 : 16,
                            ),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppThemeSystem.primaryColor,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.image_not_supported,
                              color: AppThemeSystem.grey400,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.image,
                          size: 40,
                          color: AppThemeSystem.grey400,
                        ),
                ),

                // Info
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(context.horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(
                          product['name'] ?? '',
                          style: context.subtitle1.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Price
                        Text(
                          product['formatted_price'] ?? '',
                          style: context.h6.copyWith(
                            color: AppThemeSystem.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Status Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(status),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getStatusLabel(status),
                                style: context.caption.copyWith(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => controller.editProduct(product),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppThemeSystem.infoColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Modifier',
                            style: context.button.copyWith(
                              color: AppThemeSystem.infoColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: context.borderColor,
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => controller.deleteProduct(
                      product['id'] as int,
                      product['name'] as String,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppThemeSystem.errorColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: context.button.copyWith(
                              color: AppThemeSystem.errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppThemeSystem.successColor;
      case 'pending':
        return AppThemeSystem.warningColor;
      case 'inactive':
      default:
        return AppThemeSystem.grey500;
    }
  }

  /// Get status label
  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Actif';
      case 'pending':
        return 'En attente';
      case 'inactive':
      default:
        return 'Inactif';
    }
  }
}
