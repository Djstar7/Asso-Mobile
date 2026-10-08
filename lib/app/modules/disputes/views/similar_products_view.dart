import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/product_card.dart';
import '../controllers/similar_products_controller.dart';

/// « Découvrez une sélection de produits similaires » : uniquement des produits
/// dont le vendeur offre lui-même la livraison.
class SimilarProductsView extends GetView<SimilarProductsController> {
  const SimilarProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text('disputes.similar.title'.tr, style: context.h5.copyWith(fontWeight: FontWeight.w600)),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(context.ds.gutter, 0, context.ds.gutter, AppDesign.space3),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(AppDesign.space3),
                  decoration: BoxDecoration(
                    color: AppDesign.successSubtle,
                    borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('disputes.similar.sorry'.tr, style: context.body2.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppDesign.space1),
                      Text('disputes.similar.free_delivery'.tr, style: context.body2),
                    ],
                  ),
                ),
              ),
            ),
            if (controller.products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'disputes.similar.empty'.tr,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
                sliver: SliverGrid(
                  gridDelegate: ProductCard.gridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = controller.products[index];
                      final image = product['primary_image']?.toString();
                      final cardWidth = ProductCard.widthInGrid(context);
                      return ProductCard(
                        name: product['name']?.toString() ?? '',
                        price: controller.formatPrice(product),
                        location: product['shop']?['name']?.toString(),
                        isCertified: product['shop']?['is_certified'] == true,
                        badgeLabel: 'core.free_delivery.title'.tr,
                        badgeTone: AppBadgeTone.success,
                        imageBuilder: image != null && image.startsWith('http')
                            ? (context) => AppNetworkImage(
                                  url: image,
                                  decodeSize: Size(cardWidth, cardWidth / ProductCard.imageAspectRatio),
                                  errorBuilder: (_) => const SizedBox.expand(),
                                )
                            : null,
                        onTap: () => controller.openProduct(product),
                      );
                    },
                    childCount: controller.products.length,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
