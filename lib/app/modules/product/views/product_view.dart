import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../controllers/product_controller.dart';
import 'map_selection_view.dart';

class ProductView extends GetView<ProductController> {
  const ProductView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Récupérer les données du produit depuis les arguments
    final product = Get.arguments as Map<String, dynamic>? ?? {
      'name': 'Produit',
      'price': '0',
      'location': 'Non spécifiée',
      'description': 'Aucune description disponible',
      'image': 'assets/images/p1.jpeg',
      'images': [
        'assets/images/p1.jpeg',
        'assets/images/p2.jpeg',
        'assets/images/p3.jpeg',
      ],
      'seller': {
        'name': 'Vendeur',
        'rating': 4.5,
        'reviews': 120,
      },
    };

    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: CustomScrollView(
        slivers: [
          // App Bar avec images
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: isDark ? AppThemeSystem.darkCardColor : Colors.white,
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Get.back(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  Get.snackbar(
                    'Partager',
                    'Partagez ce produit avec vos amis',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
              ),
              SizedBox(width: 8),
              Obx(() => IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    controller.isFavorite.value
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: controller.isFavorite.value
                        ? Colors.red
                        : Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  AuthGuard.requireAuth(
                    context,
                    onAuthenticated: controller.toggleFavorite,
                    featureName: 'les favoris',
                    useDialog: false,
                  );
                },
              )),
              SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildImageCarousel(context, product),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prix et nom
                _buildProductHeader(context, product),

                // Localisation
                _buildLocationSection(context, product),

                Divider(height: 32),

                // Description
                _buildDescriptionSection(context, product),

                Divider(height: 32),

                // Info vendeur
                _buildSellerSection(context, product),

                SizedBox(height: 100), // Espace pour les boutons fixes
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, product),
    );
  }

  Widget _buildImageCarousel(BuildContext context, Map<String, dynamic> product) {
    final images = _getProductImages(product);

    return Stack(
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: (index) {
            controller.currentImageIndex.value = index;
          },
          itemBuilder: (context, index) {
            return _buildImageWidget(images[index]);
          },
        ),
        // Indicateurs d'images
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: controller.currentImageIndex.value == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: controller.currentImageIndex.value == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            )),
          ),
      ],
    );
  }

  Widget _buildProductHeader(BuildContext context, Map<String, dynamic> product) {
    return Padding(
      padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prix
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppThemeSystem.primaryColor,
                  AppThemeSystem.primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '${product['price']} FCFA',
              style: context.textStyle(
                FontSizeType.h3,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 16),
          // Nom du produit
          Text(
            product['name'],
            style: context.textStyle(
              FontSizeType.h4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context, Map<String, dynamic> product) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
      ),
      child: InkWell(
        onTap: () => _openMap(product['location']),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeSystem.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppThemeSystem.getBorderColor(context),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: AppThemeSystem.primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Localisation',
                      style: context.textStyle(
                        FontSizeType.caption,
                        color: AppThemeSystem.grey600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      product['location'],
                      style: context.textStyle(
                        FontSizeType.body1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                color: AppThemeSystem.primaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, Map<String, dynamic> product) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_rounded,
                color: AppThemeSystem.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Description',
                style: context.textStyle(
                  FontSizeType.h5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            product['description'] ?? 'Aucune description disponible pour ce produit.',
            style: context.textStyle(
              FontSizeType.body1,
              color: AppThemeSystem.getSecondaryTextColor(context),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerSection(BuildContext context, Map<String, dynamic> product) {
    final seller = product['seller'] ?? {
      'name': 'Vendeur',
      'rating': 4.5,
      'reviews': 120,
    };

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppThemeSystem.getBorderColor(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.store_rounded,
                  color: AppThemeSystem.primaryColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Vendeur',
                  style: context.textStyle(
                    FontSizeType.h5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppThemeSystem.primaryColor,
                        AppThemeSystem.tertiaryColor,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seller['name'],
                        style: context.textStyle(
                          FontSizeType.body1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '${seller['rating']}',
                            style: context.textStyle(
                              FontSizeType.body2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '(${seller['reviews']} avis)',
                            style: context.textStyle(
                              FontSizeType.caption,
                              color: AppThemeSystem.grey600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Map<String, dynamic> product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Bouton Message
            Expanded(
              child: Obx(() => OutlinedButton.icon(
                onPressed: controller.isStartingConversation.value
                    ? null
                    : () {
                        AuthGuard.requireAuth(
                          context,
                          onAuthenticated: () {
                            controller.openConversationWithSeller(
                              product: product,
                            );
                          },
                          featureName: 'la messagerie',
                        );
                      },
                icon: controller.isStartingConversation.value
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppThemeSystem.primaryColor,
                          ),
                        ),
                      )
                    : Icon(Icons.chat_bubble_outline_rounded),
                label: Text(controller.isStartingConversation.value
                    ? 'Ouverture...'
                    : 'Message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeSystem.primaryColor,
                  side: BorderSide(color: AppThemeSystem.primaryColor, width: 2),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )),
            ),
            SizedBox(width: 12),
            // Bouton Commander
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  AuthGuard.requireAuth(
                    context,
                    onAuthenticated: () {
                      _showOrderDialog(context, product);
                    },
                    featureName: 'passer une commande',
                  );
                },
                icon: Icon(Icons.shopping_cart_rounded, color: Colors.white),
                label: Text(
                  'Commander',
                  style: context.textStyle(
                    FontSizeType.body1,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMap(String location) {
    Get.snackbar(
      'Ouvrir sur Maps',
      'Localisation: $location',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 3),
    );
  }

  void _showOrderDialog(BuildContext context, Map<String, dynamic> product) {
    final productPrice = double.tryParse(product['price'].toString().replaceAll(' ', '')) ?? 0.0;
    final productId = int.tryParse(product['id']?.toString() ?? '') ?? 0;

    // Réinitialiser les valeurs
    controller.withDelivery.value = false;
    controller.selectedPartner.value = null;
    controller.deliveryPrice.value = 0;
    controller.deliveryPartners.clear();

    // Charger la position + partenaires
    controller.fetchCurrentLocation().then((_) {
      controller.loadDeliveryPartners(productId);
    });

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: AppThemeSystem.getBackgroundColor(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppThemeSystem.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                                AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.shopping_cart_rounded,
                            color: AppThemeSystem.primaryColor,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Passer commande',
                                style: context.textStyle(
                                  FontSizeType.h5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${product['name']} — ${productPrice.toStringAsFixed(0)} FCFA',
                                style: context.textStyle(
                                  FontSizeType.caption,
                                  color: AppThemeSystem.grey600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Adresse de livraison
                    Obx(() => InkWell(
                      onTap: () => _showChangeAddressDialog(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: controller.isLoadingLocation.value
                                  ? SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppThemeSystem.primaryColor),
                                      ),
                                    )
                                  : Icon(Icons.location_on_rounded, color: AppThemeSystem.primaryColor, size: 20),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Adresse de livraison',
                                    style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
                                  SizedBox(height: 4),
                                  Text(controller.currentLocation.value,
                                    style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            if (!controller.isLoadingLocation.value)
                              Icon(Icons.edit_outlined, color: AppThemeSystem.primaryColor, size: 20),
                          ],
                        ),
                      ),
                    )),

                    SizedBox(height: 20),

                    // Section partenaires de livraison
                    Text(
                      'Choisir un partenaire de livraison',
                      style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),

                    Obx(() {
                      if (controller.isLoadingPartners.value) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(AppThemeSystem.primaryColor),
                                ),
                                SizedBox(height: 12),
                                Text('Chargement des partenaires...',
                                  style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
                              ],
                            ),
                          ),
                        );
                      }

                      if (controller.deliveryPartners.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppThemeSystem.getSurfaceColor(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppThemeSystem.getBorderColor(context)),
                          ),
                          child: Center(
                            child: Text('Aucun partenaire de livraison disponible',
                              style: context.textStyle(FontSizeType.body2, color: AppThemeSystem.grey600)),
                          ),
                        );
                      }

                      return Column(
                        children: controller.deliveryPartners.map((partner) {
                          final isSelected = controller.selectedPartner.value?['company_id'] == partner['company_id']
                              && controller.selectedPartner.value?['zone_id'] == partner['zone_id'];
                          final price = (partner['delivery_price'] as num?)?.toDouble() ?? 0;

                          return GestureDetector(
                            onTap: () {
                              controller.selectPartner(partner);
                              controller.withDelivery.value = true;
                            },
                            child: Container(
                              margin: EdgeInsets.only(bottom: 10),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppThemeSystem.primaryColor.withValues(alpha: 0.08)
                                    : AppThemeSystem.getSurfaceColor(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppThemeSystem.primaryColor
                                      : AppThemeSystem.getBorderColor(context),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (isSelected)
                                    Padding(
                                      padding: EdgeInsets.only(right: 10),
                                      child: Icon(Icons.check_circle_rounded, color: AppThemeSystem.primaryColor, size: 22),
                                    ),
                                  Expanded(
                                    child: Text(
                                      partner['company_name'] ?? 'Partenaire',
                                      style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    '${price.toStringAsFixed(0)} FCFA',
                                    style: context.textStyle(FontSizeType.body1,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppThemeSystem.primaryColor : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }),

                    SizedBox(height: 20),

                    // Récapitulatif des prix
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                            AppThemeSystem.primaryColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Obx(() => Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Prix du produit', style: context.textStyle(FontSizeType.body2, color: AppThemeSystem.grey600)),
                              Text('${productPrice.toStringAsFixed(0)} FCFA', style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (controller.withDelivery.value && controller.selectedPartner.value != null) ...[
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('Livraison (${controller.selectedPartner.value!['company_name']})',
                                    style: context.textStyle(FontSizeType.body2, color: AppThemeSystem.grey600),
                                    overflow: TextOverflow.ellipsis),
                                ),
                                Text('${controller.deliveryPrice.value.toStringAsFixed(0)} FCFA',
                                  style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600, color: AppThemeSystem.primaryColor)),
                              ],
                            ),
                          ],
                          Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total', style: context.textStyle(FontSizeType.h5, fontWeight: FontWeight.bold)),
                              Text('${controller.calculateTotal(productPrice).toStringAsFixed(0)} FCFA',
                                style: context.textStyle(FontSizeType.h5, fontWeight: FontWeight.bold, color: AppThemeSystem.primaryColor)),
                            ],
                          ),
                        ],
                      )),
                    ),

                    SizedBox(height: 20),

                    // Boutons Wallet (FreeMoPay / PayPal)
                    Obx(() {
                      final hasPartner = controller.selectedPartner.value != null;

                      return Column(
                        children: [
                          // Bouton FreeMoPay
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: !hasPartner || controller.isCreatingOrder.value
                                  ? null
                                  : () => _confirmOrder(context, product, productId, 'freemopay'),
                              icon: controller.isCreatingOrder.value
                                  ? SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(Icons.phone_android_rounded, color: Colors.white),
                              label: Text('Payer avec FreeMoPay',
                                style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasPartner ? AppThemeSystem.primaryColor : AppThemeSystem.grey400,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: hasPartner ? 4 : 0,
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          // Bouton PayPal
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: !hasPartner || controller.isCreatingOrder.value
                                  ? null
                                  : () => _confirmOrder(context, product, productId, 'paypal'),
                              icon: Icon(Icons.credit_card_rounded,
                                color: hasPartner ? AppThemeSystem.primaryColor : AppThemeSystem.grey400),
                              label: Text('Payer avec PayPal / Carte',
                                style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppThemeSystem.primaryColor,
                                side: BorderSide(
                                  color: hasPartner ? AppThemeSystem.primaryColor : AppThemeSystem.grey300,
                                  width: 2,
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if (!hasPartner)
                            Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text('Sélectionnez un partenaire de livraison pour continuer',
                                style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey500),
                                textAlign: TextAlign.center),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      enableDrag: true,
    );
  }

  /// Confirmer et créer la commande
  void _confirmOrder(BuildContext context, Map<String, dynamic> product, int productId, String walletProvider) async {
    final success = await controller.createOrder(
      productId: productId,
      quantity: 1,
      walletProvider: walletProvider,
    );

    if (success) {
      Get.back(); // Fermer le bottomsheet
      Get.snackbar(
        'Commande créée !',
        'Vos fonds sont bloqués en attente de validation du vendeur.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
      // Naviguer vers mes commandes
      Get.toNamed('/shipment');
    }
  }

  Future<void> _showChangeAddressDialog(BuildContext context) async {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_location_rounded,
                      color: AppThemeSystem.primaryColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Modifier l\'adresse',
                      style: context.textStyle(
                        FontSizeType.h5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Choisissez comment définir votre adresse de livraison',
                style: context.textStyle(
                  FontSizeType.body2,
                  color: AppThemeSystem.grey600,
                ),
              ),
              SizedBox(height: 20),

              // Option 1: Ouvrir la carte
              InkWell(
                onTap: () async {
                  Get.back();
                  final result = await Get.to<Map<String, dynamic>>(
                    () => MapSelectionView(),
                    transition: Transition.rightToLeft,
                  );

                  if (result != null) {
                    controller.currentLocation.value = result['address'];
                    Get.snackbar(
                      'Position mise à jour',
                      'Votre position de livraison a été modifiée',
                      snackPosition: SnackPosition.BOTTOM,
                      icon: Icon(Icons.check_circle_rounded, color: Colors.green),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.map_rounded,
                          color: AppThemeSystem.primaryColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choisir sur la carte',
                              style: context.textStyle(
                                FontSizeType.body1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Sélectionnez votre position sur OpenStreetMap',
                              style: context.textStyle(
                                FontSizeType.caption,
                                color: AppThemeSystem.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 12),

              // Option 2: Entrer manuellement
              InkWell(
                onTap: () {
                  Get.back();
                  _showManualAddressDialog(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppThemeSystem.getBorderColor(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.grey200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: AppThemeSystem.grey700,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Entrer manuellement',
                              style: context.textStyle(
                                FontSizeType.body1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Saisissez votre adresse complète',
                              style: context.textStyle(
                                FontSizeType.caption,
                                color: AppThemeSystem.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppThemeSystem.grey400,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Bouton annuler
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Annuler'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualAddressDialog(BuildContext context) {
    final TextEditingController addressController = TextEditingController(
      text: controller.currentLocation.value,
    );

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: AppThemeSystem.primaryColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Entrer l\'adresse',
                      style: context.textStyle(
                        FontSizeType.h5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Adresse de livraison',
                style: context.textStyle(
                  FontSizeType.body2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ex: Douala, Bonapriso - Rue des Cocotiers',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppThemeSystem.getBorderColor(context),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppThemeSystem.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Annuler'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (addressController.text.trim().isNotEmpty) {
                          controller.currentLocation.value = addressController.text.trim();
                          Get.back();
                          Get.snackbar(
                            'Adresse mise à jour',
                            'Votre adresse de livraison a été modifiée',
                            snackPosition: SnackPosition.BOTTOM,
                            icon: Icon(Icons.check_circle_rounded, color: Colors.green),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeSystem.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Enregistrer',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get product images from various possible fields
  List<String> _getProductImages(Map<String, dynamic> product) {
    final images = <String>[];

    // Try images array
    if (product['images'] != null) {
      if (product['images'] is List) {
        for (final item in product['images'] as List) {
          if (item is String && item.isNotEmpty) {
            images.add(item);
          } else if (item is Map && item['url'] != null) {
            images.add(item['url'].toString());
          }
        }
      }
    }

    // Try primary_image field
    if (product['primary_image'] != null && product['primary_image'].toString().isNotEmpty) {
      final primaryImage = product['primary_image'].toString();
      if (!images.contains(primaryImage)) {
        images.insert(0, primaryImage);
      }
    }

    // Try single image field
    if (images.isEmpty && product['image'] != null && product['image'].toString().isNotEmpty) {
      images.add(product['image'].toString());
    }

    // Fallback to placeholder
    if (images.isEmpty) {
      images.add('assets/images/p1.jpeg');
    }

    return images;
  }

  /// Build image widget (network or asset)
  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppThemeSystem.primaryColor),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppThemeSystem.grey200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: AppThemeSystem.grey400,
                ),
                SizedBox(height: 8),
                Text(
                  'Image non disponible',
                  style: context.textStyle(
                    FontSizeType.caption,
                    color: AppThemeSystem.grey600,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Try as local asset
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppThemeSystem.grey200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 64,
                  color: AppThemeSystem.grey400,
                ),
                SizedBox(height: 8),
                Text(
                  'Image non disponible',
                  style: context.textStyle(
                    FontSizeType.caption,
                    color: AppThemeSystem.grey600,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }
}
