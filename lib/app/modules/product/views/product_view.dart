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
    final isDark = AppThemeSystem.isDarkMode(context);

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

    // 🔍 DEBUG: Afficher tous les détails du produit
    print('');
    print('═══════════════════════════════════════════════════════════════');
    print('🔍 PRODUCT VIEW - DÉTAILS DU PRODUIT');
    print('═══════════════════════════════════════════════════════════════');
    print('📦 Nom: ${product['name']}');
    print('💰 Prix: ${product['price']}');
    print('📍 Location: ${product['location']}');
    print('');
    print('🗺️ COORDONNÉES GPS DIRECTES:');
    print('   latitude: ${product['latitude']} (type: ${product['latitude']?.runtimeType})');
    print('   longitude: ${product['longitude']} (type: ${product['longitude']?.runtimeType})');
    print('');
    print('🏪 SHOP DATA:');
    if (product['shop'] != null) {
      final shop = product['shop'] as Map<String, dynamic>;
      print('   shop.name: ${shop['name']}');
      print('   shop.address: ${shop['address']}');
      print('   shop.latitude: ${shop['latitude']} (type: ${shop['latitude']?.runtimeType})');
      print('   shop.longitude: ${shop['longitude']} (type: ${shop['longitude']?.runtimeType})');
      print('   shop.is_certified: ${shop['is_certified']}');
      print('   Toutes les clés shop: ${shop.keys.toList()}');
    } else {
      print('   ❌ Pas de données shop');
    }
    print('');
    print('📋 TOUTES LES CLÉS DU PRODUIT:');
    print('   ${product.keys.toList()}');
    print('═══════════════════════════════════════════════════════════════');
    print('');

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
              Obx(() {
                final isFav = controller.isFavorite.value;
                return IconButton(
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
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? Colors.red : Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    final productId = product['id'] is int
                        ? product['id']
                        : int.tryParse(product['id'].toString()) ?? 0;
                    if (productId > 0) {
                      AuthGuard.requireAuth(
                        context,
                        onAuthenticated: () => controller.toggleFavorite(productId),
                        featureName: 'les favoris',
                        useDialog: false,
                      );
                    }
                  },
                );
              }),
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

                Divider(height: 32),

                // Produits similaires
                _buildSimilarProductsSection(context, product),

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
    final fullLocation = product['location']?.toString() ?? product['shop']?['address']?.toString() ?? 'Non spécifiée';
    final shortLocation = _getShortLocation(fullLocation);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
      ),
      child: InkWell(
        onTap: () => _openMapOptions(context, product),
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
                      shortLocation,
                      style: context.textStyle(
                        FontSizeType.body1,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (fullLocation.length > shortLocation.length)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'Toucher pour voir sur la carte',
                          style: context.textStyle(
                            FontSizeType.overline,
                            color: AppThemeSystem.primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.map_rounded,
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
    final shop = product['shop'];
    final seller = product['seller'];

    final shopName = shop?['name']?.toString() ?? seller?['name']?.toString() ?? 'Vendeur';
    final shopImage = shop?['image']?.toString() ?? shop?['logo']?.toString();
    final ownerImage = seller?['avatar']?.toString(); // Get seller avatar from seller object
    final isCertified = _isShopCertified(product);
    final rating = seller?['rating'] ?? shop?['rating'] ?? 4.5;
    final reviewCount = seller?['reviews_count'] ?? shop?['reviews_count'] ?? 0;

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
                if (isCertified) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E88E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Color(0xFF1E88E5).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: Color(0xFF1E88E5),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Certifié',
                          style: context.textStyle(
                            FontSizeType.overline,
                            color: Color(0xFF1E88E5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                // Avatar du vendeur
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: ownerImage != null && ownerImage.isNotEmpty
                            ? Image.network(
                                ownerImage,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppThemeSystem.primaryColor,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
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
                                    size: 24,
                                  ),
                                ),
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
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                    if (isCertified)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Color(0xFF1E88E5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppThemeSystem.getSurfaceColor(context),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.star_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 12),
                // Logo boutique - toujours afficher
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCertified
                          ? AppThemeSystem.primaryColor.withValues(alpha: 0.5)
                          : AppThemeSystem.getBorderColor(context),
                      width: isCertified ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: shopImage != null && shopImage.isNotEmpty
                        ? Image.network(
                            shopImage,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppThemeSystem.primaryColor,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppThemeSystem.grey300,
                                    AppThemeSystem.grey200,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.store_rounded,
                                color: AppThemeSystem.grey600,
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppThemeSystem.grey300,
                                  AppThemeSystem.grey200,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.store_rounded,
                              color: AppThemeSystem.grey600,
                              size: 24,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: context.textStyle(
                          FontSizeType.body1,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '${rating is num ? rating.toStringAsFixed(1) : rating}',
                            style: context.textStyle(
                              FontSizeType.body2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '($reviewCount avis)',
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
            SizedBox(height: 16),
            // Bouton voir la boutique
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final shopId = shop?['id'];
                  if (shopId != null) {
                    Get.toNamed('/vendor-details', arguments: {
                      'shop_id': shopId.toString(),
                    });
                  } else {
                    Get.snackbar(
                      'Erreur',
                      'Impossible d\'accéder à la boutique',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppThemeSystem.errorColor,
                      colorText: Colors.white,
                    );
                  }
                },
                icon: Icon(
                  Icons.storefront_rounded,
                  size: 18,
                ),
                label: Text('Voir la boutique'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeSystem.primaryColor,
                  side: BorderSide(
                    color: AppThemeSystem.primaryColor,
                    width: 1.5,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Map<String, dynamic> product) {
    final isDark = AppThemeSystem.isDarkMode(context);

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

  /// Extract short location (city name) from full address
  String _getShortLocation(String fullLocation) {
    if (fullLocation.isEmpty || fullLocation == 'Non spécifiée') {
      return fullLocation;
    }

    // Try to extract city name from common address formats
    // Format examples: "Douala, Bonapriso" -> "Douala"
    //                  "Yaoundé - Centre Ville" -> "Yaoundé"
    //                  "Bafoussam, Quartier..." -> "Bafoussam"

    // Split by common separators
    final separators = [',', '-', '–', '|', '/'];
    for (final separator in separators) {
      if (fullLocation.contains(separator)) {
        final parts = fullLocation.split(separator);
        if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
          return parts[0].trim();
        }
      }
    }

    // If no separator found, try to limit by word count (max 3 words)
    final words = fullLocation.split(' ');
    if (words.length > 3) {
      return '${words.take(3).join(' ')}...';
    }

    // Return as is if short enough (< 30 chars)
    if (fullLocation.length <= 30) {
      return fullLocation;
    }

    // Otherwise truncate
    return '${fullLocation.substring(0, 27)}...';
  }

  /// Check if shop is certified
  bool _isShopCertified(Map<String, dynamic> product) {
    final shop = product['shop'];
    if (shop == null) return false;

    final isCertified = shop['is_certified'];

    if (isCertified is bool) return isCertified;
    if (isCertified is int) return isCertified == 1;
    if (isCertified is String) {
      return isCertified == '1' || isCertified.toLowerCase() == 'true';
    }

    return false;
  }

  /// Open map options (Google Maps or Asso Map)
  void _openMapOptions(BuildContext context, Map<String, dynamic> product) {
    final location = product['location']?.toString() ??
                    product['shop']?['address']?.toString() ??
                    'Non spécifiée';

    final latitude = product['latitude'] ?? product['shop']?['latitude'];
    final longitude = product['longitude'] ?? product['shop']?['longitude'];

    // 🔍 DEBUG: Vérifier les coordonnées
    print('');
    print('🗺️ ════════════════════════════════════════════════════════════');
    print('🗺️ OUVERTURE DES OPTIONS DE CARTE');
    print('🗺️ ════════════════════════════════════════════════════════════');
    print('📍 Location: $location');
    print('📌 Latitude brute: $latitude (type: ${latitude?.runtimeType})');
    print('📌 Longitude brute: $longitude (type: ${longitude?.runtimeType})');
    print('');
    print('🔍 Vérification des sources:');
    print('   product[latitude]: ${product['latitude']}');
    print('   product[longitude]: ${product['longitude']}');
    print('   product[shop][latitude]: ${product['shop']?['latitude']}');
    print('   product[shop][longitude]: ${product['shop']?['longitude']}');
    print('🗺️ ════════════════════════════════════════════════════════════');
    print('');

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.getBackgroundColor(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: EdgeInsets.only(bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeSystem.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
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
                        'Voir la localisation',
                        style: context.textStyle(
                          FontSizeType.h5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        location,
                        style: context.textStyle(
                          FontSizeType.caption,
                          color: AppThemeSystem.grey600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Option 1: Carte Asso (bottomsheet)
            InkWell(
              onTap: () {
                Get.back();
                _openAssoMap(context, product);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                      AppThemeSystem.primaryColor.withValues(alpha: 0.05),
                    ],
                  ),
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
                        color: AppThemeSystem.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_searching_rounded,
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
                            'Carte Asso',
                            style: context.textStyle(
                              FontSizeType.body1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Voir sur la carte interactive Asso',
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

            // Option 2: Google Maps (toujours affichée)
            InkWell(
                onTap: () {
                  Get.back();
                  _openGoogleMaps(latitude, longitude);
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
                          Icons.map_outlined,
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
                              'Google Maps',
                              style: context.textStyle(
                                FontSizeType.body1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Ouvrir dans Google Maps',
                              style: context.textStyle(
                                FontSizeType.caption,
                                color: AppThemeSystem.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: AppThemeSystem.grey600,
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 20),

            // Cancel button
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

            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
      isDismissible: true,
      enableDrag: true,
    );
  }

  /// Open Asso map in bottom sheet
  void _openAssoMap(BuildContext context, Map<String, dynamic> product) async {
    final latitude = product['latitude'] ?? product['shop']?['latitude'];
    final longitude = product['longitude'] ?? product['shop']?['longitude'];
    final location = product['location']?.toString() ?? product['shop']?['address']?.toString();

    final lat = latitude != null
        ? (latitude is num ? latitude.toDouble() : double.tryParse(latitude.toString()))
        : null;
    final lng = longitude != null
        ? (longitude is num ? longitude.toDouble() : double.tryParse(longitude.toString()))
        : null;

    if (lat != null && lng != null) {
      // Ouvrir la carte en mode lecture seule avec les coordonnées
      await Get.to<Map<String, dynamic>>(
        () => MapSelectionView(
          initialLatitude: lat,
          initialLongitude: lng,
          readOnly: true,
          locationName: location,
        ),
        transition: Transition.rightToLeft,
      );
    } else {
      // Pas de coordonnées disponibles
      Get.snackbar(
        'Position non disponible',
        'Les coordonnées GPS ne sont pas disponibles pour ce produit',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.warningColor,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }

  /// Open Google Maps with coordinates
  void _openGoogleMaps(dynamic latitude, dynamic longitude) async {
    double? lat;
    double? lng;

    if (latitude != null) {
      lat = latitude is num ? latitude.toDouble() : double.tryParse(latitude.toString());
    }
    if (longitude != null) {
      lng = longitude is num ? longitude.toDouble() : double.tryParse(longitude.toString());
    }

    if (lat == null || lng == null) {
      Get.snackbar(
        'Position non disponible',
        'Les coordonnées GPS ne sont pas disponibles pour ce produit',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.warningColor,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      return;
    }

    // Note: In a real implementation, you would use url_launcher package
    // For now, just show a message
    Get.snackbar(
      'Google Maps',
      'Ouverture de Google Maps à la position: $lat, $lng',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 3),
      backgroundColor: AppThemeSystem.successColor,
      colorText: Colors.white,
    );

    // TODO: Implement actual Google Maps opening with url_launcher
    // final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    // if (await canLaunchUrl(Uri.parse(url))) {
    //   await launchUrl(Uri.parse(url));
    // }
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

  /// Build similar products section
  Widget _buildSimilarProductsSection(BuildContext context, Map<String, dynamic> product) {
    final categoryName = product['category']?['name']?.toString() ?? 'cette catégorie';
    final categoryId = product['category']?['id'];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Produits similaires',
                style: context.textStyle(
                  FontSizeType.h5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  if (categoryId != null) {
                    Get.toNamed('/search', arguments: {
                      'categoryId': categoryId,
                      'categoryName': categoryName,
                    });
                  }
                },
                child: Text(
                  'Voir plus',
                  style: context.textStyle(
                    FontSizeType.body2,
                    color: AppThemeSystem.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // Products list
          Obx(() {
            if (controller.isLoadingSimilarProducts.value) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppThemeSystem.primaryColor,
                    ),
                  ),
                ),
              );
            }

            if (controller.similarProducts.isEmpty) {
              return SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Aucun produit similaire trouvé',
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: AppThemeSystem.grey600,
                    ),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.similarProducts.length,
                itemBuilder: (context, index) {
                  final similarProduct = controller.similarProducts[index];
                  return _buildSimilarProductCard(context, similarProduct);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Build similar product card
  Widget _buildSimilarProductCard(BuildContext context, Map<String, dynamic> product) {
    final productName = product['name']?.toString() ?? 'Produit';
    final productPrice = product['price'] ?? 0;
    final productStock = product['stock'] ?? 0;

    // Get product image
    String? productImage;
    if (product['primary_image'] != null && product['primary_image'].toString().isNotEmpty) {
      productImage = product['primary_image'].toString();
    } else if (product['images'] != null && product['images'] is List && (product['images'] as List).isNotEmpty) {
      final images = product['images'] as List;
      if (images.isNotEmpty) {
        // Check if it's a map with 'url' key or direct string
        final firstImage = images[0];
        if (firstImage is Map && firstImage['url'] != null) {
          productImage = firstImage['url'].toString();
        } else {
          productImage = firstImage.toString();
        }
      }
    }

    return GestureDetector(
      onTap: () {
        // Navigate to new product with preventDuplicates: false to force route recreation
        Get.offNamed(
          '/product',
          arguments: product,
          preventDuplicates: false,
        );
      },
      child: Container(
        width: 160,
        margin: EdgeInsets.only(right: 12),
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
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(
                  AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
                ),
              ),
              child: Stack(
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    child: productImage != null && productImage.isNotEmpty
                        ? Image.network(
                            productImage,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppThemeSystem.primaryColor,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: AppThemeSystem.grey200,
                              child: Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: AppThemeSystem.grey400,
                              ),
                            ),
                          )
                        : Container(
                            color: AppThemeSystem.grey200,
                            child: Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: AppThemeSystem.grey400,
                            ),
                          ),
                  ),
                  // Stock badge
                  if (productStock <= 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
            // Product Info
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  SizedBox(height: 4),
                  Text(
                    '${productPrice} FCFA',
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: FontWeight.bold,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
