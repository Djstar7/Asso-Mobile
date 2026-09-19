import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/location_label.dart';
import '../../../core/widgets/delivery_details_widgets.dart';
import '../../../core/widgets/product_image_viewer.dart';
import '../../../core/widgets/product_variant_selector.dart';
import '../../../core/values/constants.dart';
import '../../../data/providers/storage_service.dart';
import '../../../routes/app_pages.dart';
import '../controllers/product_controller.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../payment/widgets/wallet_payment_confirm_dialog.dart';
import '../../../data/models/delivery_info.dart';
import '../../../data/models/payment_method_option.dart';
import '../../../data/services/stripe_native_service.dart';
import 'map_selection_view.dart';

class ProductView extends GetView<ProductController> {
  const ProductView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    // Récupérer les données du produit depuis les arguments
    final product =
        Get.arguments as Map<String, dynamic>? ??
        {
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
          'seller': {'name': 'Vendeur', 'rating': 4.5, 'reviews': 120},
        };

    // Statistiques vendeur : consultation de la fiche (dédoublonnée).
    controller.trackProductView(product);

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
    print(
      '   latitude: ${product['latitude']} (type: ${product['latitude']?.runtimeType})',
    );
    print(
      '   longitude: ${product['longitude']} (type: ${product['longitude']?.runtimeType})',
    );
    print('');
    print('🏪 SHOP DATA:');
    if (product['shop'] != null) {
      final shop = product['shop'] as Map<String, dynamic>;
      print('   shop.name: ${shop['name']}');
      print('   shop.address: ${shop['address']}');
      print(
        '   shop.latitude: ${shop['latitude']} (type: ${shop['latitude']?.runtimeType})',
      );
      print(
        '   shop.longitude: ${shop['longitude']} (type: ${shop['longitude']?.runtimeType})',
      );
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
            backgroundColor: isDark
                ? AppThemeSystem.darkCardColor
                : Colors.white,
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
              // Ouverte depuis une notification, la fiche n'a pas de page précédente.
              onPressed: () => Navigator.of(context).canPop()
                  ? Get.back()
                  : Get.offAllNamed(Routes.HOME),
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
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
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
                        onAuthenticated: () =>
                            controller.toggleFavorite(productId),
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
                _buildThumbnails(context, product),
                _buildProductHeader(context, product),
                _buildVariantsSection(context, product),
                _buildLocationSection(context, product),
                Divider(height: 32),
                _buildDescriptionSection(context, product),
                _buildProductCharacteristics(context, product),
                Divider(height: 32),
                _buildSellerSection(context, product),
                Divider(height: 32),
                _buildSimilarProductsSection(context, product),
                SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, product),
    );
  }

  Widget _buildImageCarousel(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final images = _getProductImages(product);

    return Stack(
      children: [
        PageView.builder(
          controller: controller.imagePageController,
          itemCount: images.length,
          onPageChanged: (index) {
            controller.currentImageIndex.value = index;
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _openImageViewer(context, images, index),
              child: Hero(
                tag: 'product-image-${product['id']}-$index',
                child: _buildImageWidget(images[index], fit: BoxFit.cover),
              ),
            );
          },
        ),
        // Compteur + invitation à zoomer
        Positioned(
          right: 16,
          bottom: 16,
          child: GestureDetector(
            onTap: () => _openImageViewer(
              context,
              images,
              controller.currentImageIndex.value,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
                  if (images.length > 1) ...[
                    const SizedBox(width: 6),
                    Obx(
                      () => Text(
                        '${controller.currentImageIndex.value + 1}/${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Indicateurs d'images
        if (images.length > 1)
          Positioned(
            bottom: 22,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (index) => AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: controller.currentImageIndex.value == index
                          ? 24
                          : 8,
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
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openImageViewer(
    BuildContext context,
    List<String> images,
    int index,
  ) async {
    final lastIndex = await ProductImageViewer.open(
      context,
      images: images,
      initialIndex: index,
      imageBuilder: (image, fit) => _buildImageWidget(image, fit: fit),
    );
    if (lastIndex != null && lastIndex != controller.currentImageIndex.value) {
      controller.imagePageController.jumpToPage(lastIndex);
      controller.currentImageIndex.value = lastIndex;
    }
  }

  Widget _buildThumbnails(BuildContext context, Map<String, dynamic> product) {
    final images = _getProductImages(product);
    if (images.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Obx(
        () => ProductThumbnailStrip(
          images: images,
          currentIndex: controller.currentImageIndex.value,
          onSelected: controller.goToImage,
          imageBuilder: (image, fit) => _buildImageWidget(image, fit: fit),
        ),
      ),
    );
  }

  Widget _buildProductHeader(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
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
            child: Obx(
              () => Text(
                controller.formatPrice(controller.unitPriceXaf(product)),
                style: context.textStyle(
                  FontSizeType.h3,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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

  Widget _buildProductCharacteristics(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    // Extraire le stock
    final stock = product['stock'];
    final stockValue = stock is int
        ? stock
        : int.tryParse(stock.toString()) ?? 0;
    final hasStock = stock != null;

    // Extraire le poids (PRIORITÉ au poids personnalisé, sinon weight_category)
    final weightCategory = product['weight_category']?.toString();
    final customWeight = product['weight']?.toString();

    String? weightDisplay;

    // PRIORITÉ 1 : Poids personnalisé (weight)
    if (customWeight != null &&
        customWeight.isNotEmpty &&
        customWeight != '0' &&
        customWeight != 'null') {
      // Utiliser le poids personnalisé
      weightDisplay = customWeight.contains('kg') || customWeight.contains('KG')
          ? customWeight
          : '$customWeight kg';
    }
    // PRIORITÉ 2 : Catégorie de poids prédéfinie (weight_category)
    else if (weightCategory != null &&
        weightCategory.isNotEmpty &&
        weightCategory != 'null') {
      // Utiliser la catégorie de poids
      final weightMap = {
        'X-small': '~5 kg',
        '30 Deep': '~30 kg',
        '50 Deep': '~50 kg',
        '60 Deep': '~60 kg',
        'Rainbow XL': '~100 kg',
        'Pallet': '~500 kg',
      };
      weightDisplay = weightMap[weightCategory] ?? weightCategory;
    }

    final hasWeight = weightDisplay != null;
    final characteristics = product['characteristics']?.toString().trim();
    final commercialInformation = product['commercial_information']
        ?.toString()
        .trim();
    final originCode = product['origin_country']
        ?.toString()
        .trim()
        .toUpperCase();
    final originLabel = _originLabel(originCode);
    final sizes =
        (product['sizes'] as List?)
            ?.map((size) => size.toString())
            .where((size) => size.isNotEmpty)
            .toList() ??
        const <String>[];
    final hasDetails =
        characteristics?.isNotEmpty == true ||
        commercialInformation?.isNotEmpty == true ||
        originLabel.isNotEmpty ||
        sizes.isNotEmpty;

    // Si aucune caractéristique n'est disponible, ne rien afficher
    if (!hasStock && !hasWeight && !hasDetails) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
        vertical: 16,
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppThemeSystem.getBorderColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (characteristics?.isNotEmpty == true) ...[
              const Text(
                'Caractéristiques',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                characteristics!,
                style: TextStyle(color: context.secondaryTextColor),
              ),
              const SizedBox(height: 14),
            ],
            if (commercialInformation?.isNotEmpty == true) ...[
              const Text(
                'Informations commerciales',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                commercialInformation!,
                style: TextStyle(color: context.secondaryTextColor),
              ),
              const SizedBox(height: 14),
            ],
            _buildCharacteristicItem(
              context: context,
              icon: Icons.public_rounded,
              label: 'Provenance',
              value: originLabel,
            ),
            const SizedBox(height: 14),
            if (sizes.isNotEmpty) ...[
              const Text(
                'Tailles disponibles',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: sizes.map((size) => Chip(label: Text(size))).toList(),
              ),
              const SizedBox(height: 14),
            ],
            if (hasStock || hasWeight)
              Row(
                children: [
                  // Stock à gauche
                  if (hasStock)
                    Expanded(
                      child: _buildCharacteristicItem(
                        context: context,
                        icon: Icons.inventory_2_rounded,
                        label: 'Stock disponible',
                        value: stockValue > 0
                            ? '$stockValue unité${stockValue > 1 ? "s" : ""}'
                            : 'Rupture de stock',
                      ),
                    ),

                  // Séparateur si les deux sont présents
                  if (hasStock && hasWeight)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      width: 1,
                      height: 50,
                      color: AppThemeSystem.getBorderColor(context),
                    ),

                  // Poids à droite
                  if (hasWeight)
                    Expanded(
                      child: _buildCharacteristicItem(
                        context: context,
                        icon: Icons.scale_rounded,
                        label: 'Poids',
                        value: weightDisplay,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _originLabel(String? code) {
    if (code == null || code.isEmpty || code == 'NULL') return 'Produit local';
    const countries = {
      'CN': 'Chine',
      'AE': 'Dubaï / Émirats arabes unis',
      'TR': 'Turquie',
    };
    return countries[code] ?? code;
  }

  Widget _buildCharacteristicItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String? value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppThemeSystem.primaryColor, size: 22),
        ),
        SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.caption,
                  color: AppThemeSystem.grey600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value ?? '',
                style: context.textStyle(
                  FontSizeType.body1,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final fullLocation =
        product['location']?.toString() ??
        product['shop']?['address']?.toString() ??
        'Non spécifiée';
    // « Ville, Pays » fourni par le serveur ; sinon on raccourcit l'adresse brute.
    final shopLabel = product['shop'] is Map
        ? LocationLabel.fromApi(Map<String, dynamic>.from(product['shop'] as Map))
        : null;
    final shortLocation = shopLabel ?? _getShortLocation(fullLocation);

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
            border: Border.all(color: AppThemeSystem.getBorderColor(context)),
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

  Widget _buildDescriptionSection(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
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
            product['description'] ??
                'Aucune description disponible pour ce produit.',
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

  Widget _buildVariantsSection(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final catalog = VariantCatalog.fromApi(
      product['variants'],
      product['variant_options'],
    );
    if (catalog.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: AppThemeSystem.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Choisissez vos options',
                style: context.textStyle(
                  FontSizeType.subtitle1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(
            () => ProductVariantSelector(
              key: ValueKey(
                'page-variants-${controller.variantSelectorEpoch.value}',
              ),
              catalog: catalog,
              selectedVariantId:
                  controller.selectedVariant.value?['id'] as int?,
              onChanged: (variant) =>
                  controller.onVariantChanged(product, variant),
              formatAdjustment: controller.formatPrice,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerSection(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final shop = product['shop'];
    final seller = product['seller'];

    final shopName =
        shop?['name']?.toString() ?? seller?['name']?.toString() ?? 'Vendeur';
    final shopImage = shop?['image']?.toString() ?? shop?['logo']?.toString();
    final ownerImage = seller?['avatar']
        ?.toString(); // Get seller avatar from seller object
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
          border: Border.all(color: AppThemeSystem.getBorderColor(context)),
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
                          color: AppThemeSystem.primaryColor.withValues(
                            alpha: 0.3,
                          ),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: ownerImage != null && ownerImage.isNotEmpty
                            ? Image.network(
                                ownerImage,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
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
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
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
                    Get.toNamed(
                      '/vendor-details',
                      arguments: {'shop_id': shopId.toString()},
                    );
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
                icon: Icon(Icons.storefront_rounded, size: 18),
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

    // Vérifier si c'est le produit de l'utilisateur connecté
    final currentUser = StorageService.getUser();
    final seller = product['seller'] as Map<String, dynamic>?;
    final sellerId = int.tryParse(seller?['id']?.toString() ?? '');
    final isMyProduct =
        currentUser != null && sellerId != null && currentUser.id == sellerId;

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
        child: isMyProduct
            ? // Bouton pour gérer mes produits
              ElevatedButton.icon(
                onPressed: () {
                  Get.toNamed(Routes.PRODUCT_MANAGEMENT);
                },
                icon: Icon(Icons.edit_rounded, color: Colors.white),
                label: Text(
                  'Gérer mes produits',
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
              )
            : Row(
                children: [
                  // Bouton Message
                  Expanded(
                    child: Obx(
                      () => OutlinedButton.icon(
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
                        label: Text(
                          controller.isStartingConversation.value
                              ? 'Ouverture...'
                              : 'Message',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppThemeSystem.primaryColor,
                          side: BorderSide(
                            color: AppThemeSystem.primaryColor,
                            width: 2,
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
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
                      icon: Icon(
                        Icons.shopping_cart_rounded,
                        color: Colors.white,
                      ),
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

    // Déjà au format « Ville, Pays » (deux segments) : on le garde tel quel.
    if (fullLocation.split(',').length == 2 && fullLocation.length <= 40) {
      return fullLocation.trim();
    }

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
    final location =
        product['location']?.toString() ??
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
                        color: AppThemeSystem.primaryColor.withValues(
                          alpha: 0.15,
                        ),
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
    final location =
        product['location']?.toString() ??
        product['shop']?['address']?.toString();

    final lat = latitude != null
        ? (latitude is num
              ? latitude.toDouble()
              : double.tryParse(latitude.toString()))
        : null;
    final lng = longitude != null
        ? (longitude is num
              ? longitude.toDouble()
              : double.tryParse(longitude.toString()))
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
      lat = latitude is num
          ? latitude.toDouble()
          : double.tryParse(latitude.toString());
    }
    if (longitude != null) {
      lng = longitude is num
          ? longitude.toDouble()
          : double.tryParse(longitude.toString());
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

    // Ouvrir Google Maps avec les coordonnées
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      final canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'Erreur',
          'Impossible d\'ouvrir Google Maps',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue lors de l\'ouverture de Google Maps',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }

  void _showOrderDialog(BuildContext context, Map<String, dynamic> product) {
    final productId = int.tryParse(product['id']?.toString() ?? '') ?? 0;

    // Réinitialiser les valeurs
    controller.withDelivery.value = false;
    controller.selectedPartner.value = null;
    controller.deliveryPrice.value = 0;
    controller.deliveryPartners.clear();
    controller.deliveryQuote.value = null;
    controller.deliveryBlockedMessage.value = null;
    controller.orderQuantity.value =
        1; // réinitialiser la quantité à chaque ouverture

    // Position GPS seulement si aucune adresse n'a déjà été choisie : une
    // adresse modifiée par l'acheteur ne doit pas être écrasée.
    final locationReady = controller.hasValidLocation
        ? Future<void>.value()
        : controller.fetchCurrentLocation();
    locationReady.then((_) {
      if (controller.hasValidLocation) {
        controller.loadDeliveryPartners(productId);
      }
    });

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                                AppThemeSystem.primaryColor.withValues(
                                  alpha: 0.2,
                                ),
                                AppThemeSystem.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
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
              Obx(() {
                                final variantLabel = VariantCatalog.labelOf(
                                  controller.selectedVariant.value,
                                );
                                return Text(
                                  '${product['name']}${variantLabel.isNotEmpty ? ' ($variantLabel)' : ''} — ${controller.formatPrice(controller.unitPriceXaf(product))}',
                                  style: context.textStyle(
                                    FontSizeType.caption,
                                    color: AppThemeSystem.grey600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    _buildOrderVariantSection(context, product),

                    // Adresse de livraison
                    _buildDeliveryAddressCard(context, productId),

                    SizedBox(height: 12),

                    TextField(
                      controller: controller.addressDetailsController,
                      maxLines: 2,
                      maxLength: 500,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Complément d’adresse (facultatif)',
                        hintText: 'Quartier, rue, portail, étage, point de repère…',
                        prefixIcon: Icon(Icons.signpost_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    SizedBox(height: 8),

                    TextField(
                      controller: controller.customerPhoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'Numéro à contacter *',
                        hintText: 'Ex. 6XXXXXXXX',
                        helperText: 'Le livreur appellera ce numéro',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Section partenaires de livraison
                    Text(
                      'Choisir un partenaire de livraison',
                      style: context.textStyle(
                        FontSizeType.body1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    _buildDeliveryPartnersSection(context),

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
                          color: AppThemeSystem.primaryColor.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Obx(
                        () => Column(
                          children: [
                            // Sélecteur de quantité (produit normal)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Quantité',
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    color: AppThemeSystem.grey600,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: controller.decrementQuantity,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppThemeSystem.primaryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          size: 18,
                                          color: AppThemeSystem.primaryColor,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Text(
                                        '${controller.orderQuantity.value}',
                                        style: context.textStyle(
                                          FontSizeType.body1,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () =>
                                          controller.incrementQuantity(product),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppThemeSystem.primaryColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Prix du produit${controller.orderQuantity.value > 1 ? ' (×${controller.orderQuantity.value})' : ''}',
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    color: AppThemeSystem.grey600,
                                  ),
                                ),
                                Text(
                                  controller.formatPrice(
                                    controller.subtotal(
                                    controller.unitPriceXaf(product),
                                  ),
                                  ),
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (controller.withDelivery.value &&
                                controller.selectedPartner.value != null) ...[
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Livraison (${controller.selectedPartner.value!['company_name']})',
                                      style: context.textStyle(
                                        FontSizeType.body2,
                                        color: AppThemeSystem.grey600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    controller.formatPrice(
                                      controller.deliveryPrice.value,
                                    ),
                                    style: context.textStyle(
                                      FontSizeType.body2,
                                      fontWeight: FontWeight.w600,
                                      color: AppThemeSystem.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (controller.deliveryWeightKg != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Poids total : ${formatKg(controller.deliveryWeightKg)}',
                                    style: context.caption,
                                  ),
                                ),
                            ],
                            Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total',
                                  style: context.textStyle(
                                    FontSizeType.h5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  controller.formatPrice(
                                    controller.calculateTotal(
                                      controller.unitPriceXaf(product),
                                    ),
                                  ),
                                  style: context.textStyle(
                                    FontSizeType.h5,
                                    fontWeight: FontWeight.bold,
                                    color: AppThemeSystem.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Étapes manquantes puis résumé avant paiement
                    Obx(() {
                      final missing = controller.missingOrderSteps(product);
                      final ready =
                          missing.isEmpty &&
                          !controller.isLoadingPartners.value &&
                          !controller.isCreatingOrder.value;

                      return Column(
                        children: [
                          if (missing.isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppThemeSystem.warningColor.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppThemeSystem.warningColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pour continuer :',
                                    style: context.textStyle(
                                      FontSizeType.body2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...missing.map(
                                    (step) => Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.radio_button_unchecked,
                                            size: 14,
                                            color: AppThemeSystem.warningColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              step,
                                              style: context.textStyle(
                                                FontSizeType.caption,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: ready
                                  ? () => _showOrderSummary(context, product)
                                  : null,
                              icon: controller.isCreatingOrder.value
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.fact_check_rounded,
                                      color: Colors.white,
                                    ),
                              label: Text(
                                'Vérifier ma commande',
                                style: context.textStyle(
                                  FontSizeType.body1,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeSystem.primaryColor,
                                disabledBackgroundColor: AppThemeSystem.grey400,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: ready ? 4 : 0,
                              ),
                            ),
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
    ).then((_) {
      // La variante a pu changer dans la feuille : resynchroniser la fiche.
      controller.variantSelectorEpoch.value++;
    });
  }

  /// Partenaires de livraison chiffrés au poids réel (poids × quantité), avec
  /// catégorie, mode, trajet, délai, prix et accès au détail complet.
  Widget _buildDeliveryPartnersSection(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingPartners.value) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppThemeSystem.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Calcul des tarifs de livraison...',
                  style: context.textStyle(
                    FontSizeType.caption,
                    color: AppThemeSystem.grey600,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final blocked = controller.deliveryBlockedMessage.value;
      if (blocked != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DeliveryNotice(
              blocked,
              icon: Icons.scale_outlined,
              color: AppThemeSystem.errorColor,
            ),
            const SizedBox(height: 8),
            Text(
              'La commande avec livraison n’est pas possible tant que le vendeur n’a pas indiqué le poids réel du produit. Vous pouvez lui écrire pour le lui demander.',
              style: context.caption,
            ),
          ],
        );
      }

      if (controller.deliveryPartners.isEmpty) {
        final message = controller.deliveryQuote.value?['message']?.toString();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppThemeSystem.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppThemeSystem.getBorderColor(context)),
          ),
          child: Text(
            message?.isNotEmpty == true
                ? message!
                : 'Aucun partenaire de livraison disponible à ${controller.currentLocation.value}',
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.body2,
              color: AppThemeSystem.grey600,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      final weight = controller.deliveryWeightKg;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (weight != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.scale_outlined, size: 16, color: AppThemeSystem.grey600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Poids total du colis : ${formatKg(weight)} (${controller.orderQuantity.value} article${controller.orderQuantity.value > 1 ? 's' : ''})',
                      style: context.caption,
                    ),
                  ),
                ],
              ),
            ),
          for (final raw in controller.deliveryPartners)
            _buildPartnerCard(context, DeliveryPartnerQuote(raw)),
        ],
      );
    });
  }

  Widget _buildPartnerCard(BuildContext context, DeliveryPartnerQuote partner) {
    final selectedRaw = controller.selectedPartner.value;
    final isSelected =
        selectedRaw != null && DeliveryPartnerQuote(selectedRaw).key == partner.key;
    final logo = partner.companyLogo;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => controller.selectPartner(partner.raw),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppThemeSystem.grey200,
                    ),
                    child: ClipOval(
                      child: logo != null
                          ? Image.network(
                              logo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.local_shipping_rounded,
                                color: AppThemeSystem.grey600,
                              ),
                            )
                          : Icon(
                              Icons.local_shipping_rounded,
                              color: AppThemeSystem.grey600,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.companyName,
                          style: context.textStyle(
                            FontSizeType.body1,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppThemeSystem.primaryColor : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            DeliveryChip(
                              partner.categoryLabel,
                              color: deliveryCategoryColor(partner.serviceType),
                            ),
                            DeliveryChip(
                              partner.isAgencyToAgency
                                  ? 'Agence → agence'
                                  : 'À domicile',
                              color: AppThemeSystem.grey700,
                              icon: partner.isAgencyToAgency
                                  ? Icons.store_mall_directory_outlined
                                  : Icons.home_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        controller.formatPrice(partner.price),
                        style: context.textStyle(
                          FontSizeType.body1,
                          fontWeight: FontWeight.bold,
                          color: AppThemeSystem.primaryColor,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppThemeSystem.primaryColor,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (partner.routeOrZone != null)
                _partnerInfoRow(context, Icons.alt_route_rounded, partner.routeOrZone!),
              if (partner.leadTime != null)
                _partnerInfoRow(
                  context,
                  Icons.schedule_rounded,
                  'Délai : ${partner.leadTime}',
                ),
              if (partner.distanceKm != null)
                _partnerInfoRow(
                  context,
                  Icons.location_on_outlined,
                  '${partner.distanceKm!.toStringAsFixed(1)} km',
                ),
              _partnerInfoRow(
                context,
                partner.isAgencyToAgency
                    ? Icons.store_mall_directory_outlined
                    : Icons.home_outlined,
                partner.serviceModeLabel,
              ),
              if (partner.pickupNotice != null) ...[
                const SizedBox(height: 6),
                DeliveryNotice(
                  partner.pickupNotice!,
                  icon: Icons.store_mall_directory_outlined,
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => showDeliveryQuoteDetails(
                    context,
                    partner,
                    formatPrice: controller.formatPrice,
                    weightKg: controller.deliveryWeightKg,
                    onChoose: () => controller.selectPartner(partner.raw),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Détails'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppThemeSystem.primaryColor,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partnerInfoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppThemeSystem.grey600),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: context.caption)),
        ],
      ),
    );
  }

  /// Choix des options (taille, pointure, couleur…) directement dans la feuille
  /// de commande, pour pouvoir le faire ou le corriger juste avant de payer.
  Widget _buildOrderVariantSection(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final catalog = VariantCatalog.fromApi(
      product['variants'],
      product['variant_options'],
    );
    if (catalog.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeSystem.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: AppThemeSystem.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Vos options',
                style: context.textStyle(
                  FontSizeType.body1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProductVariantSelector(
            catalog: catalog,
            selectedVariantId: controller.selectedVariant.value?['id'] as int?,
            onChanged: (variant) =>
                controller.onVariantChanged(product, variant),
            formatAdjustment: controller.formatPrice,
          ),
        ],
      ),
    );
  }

  /// Adresse de livraison : position GPS automatique, modification sur la carte,
  /// et explication claire quand la localisation est indisponible.
  Widget _buildDeliveryAddressCard(BuildContext context, int productId) {
    return Obx(() {
      final isLocating = controller.isLoadingLocation.value;
      final issue = controller.locationIssue.value;
      final hasAddress = controller.hasValidLocation;

      final issueText = switch (issue) {
        LocationIssue.serviceDisabled =>
          'La localisation de votre téléphone est désactivée.',
        LocationIssue.permissionDenied =>
          'Autorisez l’accès à votre position pour la détecter automatiquement.',
        LocationIssue.deniedForever =>
          'L’accès à la position est bloqué. Activez-le dans les réglages de l’application.',
        LocationIssue.failed => 'Votre position n’a pas pu être détectée.',
        LocationIssue.none => null,
      };

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemeSystem.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasAddress || isLocating
                ? AppThemeSystem.primaryColor.withValues(alpha: 0.2)
                : AppThemeSystem.warningColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isLocating
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
                      : Icon(
                          Icons.location_on_rounded,
                          color: AppThemeSystem.primaryColor,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adresse de livraison',
                        style: context.textStyle(
                          FontSizeType.caption,
                          color: AppThemeSystem.grey600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLocating
                            ? 'Détection de votre position…'
                            : hasAddress
                            ? controller.currentLocation.value
                            : 'Aucune adresse sélectionnée',
                        style: context.textStyle(
                          FontSizeType.body2,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isLocating && !hasAddress && issueText != null) ...[
              const SizedBox(height: 8),
              Text(
                issueText,
                style: context.textStyle(
                  FontSizeType.caption,
                  color: AppThemeSystem.warningColor,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLocating
                        ? null
                        : () async {
                            if (issue == LocationIssue.serviceDisabled ||
                                issue == LocationIssue.deniedForever) {
                              await controller.openLocationSettings();
                              return;
                            }
                            await controller.fetchCurrentLocation();
                            if (controller.hasValidLocation) {
                              await controller.loadDeliveryPartners(productId);
                            }
                          },
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(
                      issue == LocationIssue.serviceDisabled ||
                              issue == LocationIssue.deniedForever
                          ? 'Réglages'
                          : 'Ma position',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeSystem.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLocating
                        ? null
                        : () => _showChangeAddressDialog(context),
                    icon: const Icon(
                      Icons.edit_location_alt_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      hasAddress ? 'Modifier' : 'Choisir sur la carte',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Résumé complet de la commande, affiché avant tout paiement.
  Future<void> _showOrderSummary(
    BuildContext context,
    Map<String, dynamic> product,
  ) async {
    final unitPrice = controller.unitPriceXaf(product);
    final quantity = controller.orderQuantity.value;
    final partner = controller.selectedPartner.value;
    final quote = partner == null ? null : DeliveryPartnerQuote(partner);
    final variant = controller.selectedVariant.value;
    final details = controller.addressDetailsController.text.trim();
    final total = controller.calculateTotal(unitPrice);
    final images = _getProductImages(product);

    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.body2,
                color: AppThemeSystem.grey600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.textStyle(
                strong ? FontSizeType.h5 : FontSizeType.body2,
                fontWeight: strong ? FontWeight.bold : FontWeight.w600,
                color: strong ? AppThemeSystem.primaryColor : null,
              ),
            ),
          ),
        ],
      ),
    );

    Widget section(IconData icon, String title, List<Widget> children) =>
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppThemeSystem.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppThemeSystem.getBorderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppThemeSystem.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: context.textStyle(
                      FontSizeType.body1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        );

    final confirmed = await Get.bottomSheet<bool>(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppThemeSystem.getBackgroundColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Modifier la commande',
                      onPressed: () => Get.back(result: false),
                    ),
                    Expanded(
                      child: Text(
                        'Résumé de la commande',
                        style: context.textStyle(
                          FontSizeType.h5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Column(
                    children: [
                      section(Icons.shopping_bag_rounded, 'Article', [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: _buildImageWidget(images.first),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                product['name']?.toString() ?? 'Produit',
                                style: context.textStyle(
                                  FontSizeType.body1,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (variant != null)
                          ...VariantCatalog.attributesOf(
                            variant,
                          ).entries.map((e) => line(e.key, e.value)),
                        line('Prix unitaire', controller.formatPrice(unitPrice)),
                        line('Quantité', '$quantity'),
                      ]),
                      section(Icons.local_shipping_rounded, 'Livraison', [
                        line('Adresse', controller.currentLocation.value),
                        if (details.isNotEmpty) line('Complément', details),
                        line('Numéro à contacter', controller.customerPhone.value),
                        if (quote != null) ...[
                          line('Partenaire', quote.companyName),
                          line('Catégorie', quote.serviceTypeLabel),
                          line('Mode', quote.serviceModeLabel),
                          if (quote.routeOrZone != null)
                            line('Trajet', quote.routeOrZone!),
                          if (quote.leadTime != null)
                            line('Délai', quote.leadTime!),
                          if (quote.pickupNotice != null) ...[
                            const SizedBox(height: 6),
                            DeliveryNotice(
                              quote.pickupNotice!,
                              icon: Icons.store_mall_directory_outlined,
                            ),
                          ],
                        ],
                      ]),
                      if (quote != null)
                        section(Icons.scale_outlined, 'Prix de la livraison', [
                          DeliveryBreakdownView(
                            breakdown: quote.breakdown,
                            priceGrid: quote.priceGrid,
                            conditions: quote.conditions,
                            weightKg: controller.deliveryWeightKg,
                            fallbackTotal: quote.price,
                            formatPrice: controller.formatPrice,
                          ),
                        ]),
                      section(Icons.receipt_long_rounded, 'Montant', [
                        line(
                          'Sous-total',
                          controller.formatPrice(controller.subtotal(unitPrice)),
                        ),
                        line(
                          controller.deliveryWeightKg != null
                              ? 'Livraison (${formatKg(controller.deliveryWeightKg)})'
                              : 'Livraison',
                          controller.formatPrice(controller.deliveryPrice.value),
                        ),
                        const Divider(height: 16),
                        line(
                          'Total à payer',
                          controller.formatPrice(total),
                          strong: true,
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(result: false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Modifier'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => Get.back(result: true),
                        icon: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          'Confirmer et payer',
                          style: context.textStyle(
                            FontSizeType.body1,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeSystem.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );

    if (confirmed == true && context.mounted) {
      await _choosePaymentAndOrder(context, product, total);
    }
  }

  /// Ouvre le sélecteur STANDARD de moyen de paiement puis lance le sous-parcours
  /// correspondant. Seuls les rails acceptés par /v1/orders sont proposés.
  Future<void> _choosePaymentAndOrder(
    BuildContext context,
    Map<String, dynamic> product,
    double total,
  ) async {
    final method = await PaymentMethodSelector.show(
      amount: total,
      currency: 'XAF',
      amountLabel: 'Total à payer',
      allowedCodes: const {'kpay', 'stripe'},
      includeWallet: true,
    );
    if (method == null) return; // annulé

    switch (method.code) {
      case 'wallet':
        await _payViaWallet(product, total, method);
        break;
      case 'kpay':
        await _payViaMobileMoney(product, total);
        break;
      case 'stripe':
        await _payViaCard(product);
        break;
      default:
        Get.snackbar(
          'Indisponible',
          "Ce moyen de paiement n'est pas encore disponible pour les commandes.",
          snackPosition: SnackPosition.BOTTOM,
        );
    }
  }

  /// Paiement avec le solde du Wallet ASSO : fonds réservés immédiatement, prélevés
  /// à la validation du vendeur et rendus disponibles en cas d'annulation/refus.
  Future<void> _payViaWallet(
    Map<String, dynamic> product,
    double total,
    PaymentMethodOption method,
  ) async {
    final confirmed = await WalletPaymentConfirmDialog.show(
      itemLabel: product['name']?.toString() ?? 'Commande',
      amount: total,
      balance: method.balance ?? 0,
    );
    if (!confirmed) return;

    final data = await controller.createOrder(
      product: product,
      paymentMode: 'wallet',
    );
    if (data == null) return; // snackbar déjà affiché

    _showOrderConfirmation(
      data,
      'Payée avec votre Wallet ASSO. En cas de refus ou d\'annulation, le montant vous est rendu immédiatement.',
    );
  }

  /// Paiement Mobile Money (KPay direct, validation USSD sur le téléphone).
  Future<void> _payViaMobileMoney(
    Map<String, dynamic> product,
    double total,
  ) async {
    final selection = await KpayDirectPaymentSheet.show(
      amount: total,
      amountLabel: 'Total à payer',
    );
    if (selection == null) return; // paiement annulé

    final data = await controller.createOrder(
      product: product,
      paymentMode: 'kpay_direct',
      kpayProvider: selection['provider'],
      kpayPhone: selection['phone'],
    );
    if (data == null) return; // snackbar déjà affiché

    controller.pollOrderPayment(_orderIdOf(data));
    _showOrderConfirmation(
      data,
      'Validez le paiement sur votre téléphone (USSD). Vous serez notifié dès sa confirmation.',
    );
  }

  /// Paiement par CARTE (Payment Sheet Stripe native), confirmé côté serveur.
  Future<void> _payViaCard(Map<String, dynamic> product) async {
    if (!StripeNativeService.isSupported) {
      Get.snackbar(
        'Indisponible',
        "Le paiement par carte est disponible sur l'application mobile.",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final data = await controller.createOrder(
      product: product,
      paymentMode: 'stripe_direct',
    );
    if (data == null) return; // échec (snackbar déjà affiché)

    final orderId = _orderIdOf(data);
    final clientSecret = data['client_secret']?.toString() ?? '';
    final publishableKey = data['publishable_key']?.toString() ?? '';
    if (clientSecret.isEmpty || publishableKey.isEmpty) {
      Get.snackbar(
        'Erreur',
        'Données de paiement carte indisponibles. Votre commande reste en attente.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      final ok = await StripeNativeService().payWithCard(
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );
      if (!ok) {
        Get.snackbar(
          'Paiement annulé',
          "Le paiement n'a pas été finalisé. Votre commande reste en attente.",
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      controller.pollOrderPayment(orderId);
      _showOrderConfirmation(
        data,
        'Votre paiement par carte est en cours de confirmation. Vous serez notifié.',
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  int _orderIdOf(Map<String, dynamic> data) =>
      int.tryParse(
        (data['order_id'] ?? data['order']?['id'])?.toString() ?? '',
      ) ??
      0;

  /// Confirmation de commande : ferme la feuille puis propose le suivi ou le
  /// retour à l'accueil (le retour depuis le suivi ramène aussi à l'accueil).
  void _showOrderConfirmation(Map<String, dynamic> data, String message) {
    Get.back(); // fermer la feuille de commande
    final order = data['order'] as Map?;
    final orderNumber = order?['order_number']?.toString();
    final total = (order?['total'] as num?)?.toDouble();

    void leaveTo(String? route) {
      Get.back(); // fermer la confirmation
      Get.until((r) => r.settings.name == Routes.HOME || r.isFirst);
      if (Get.currentRoute != Routes.HOME && route == null) {
        Get.offAllNamed(Routes.HOME);
      } else if (route != null) {
        Get.toNamed(route);
      }
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 56,
        ),
        title: const Text('Commande enregistrée', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (orderNumber != null)
              Text(
                'N° $orderNumber',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (total != null) ...[
              const SizedBox(height: 4),
              Text(controller.formatPrice(total)),
            ],
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => leaveTo(null),
            child: const Text('Retour à l’accueil'),
          ),
          ElevatedButton(
            onPressed: () => leaveTo(Routes.SHIPMENT),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeSystem.primaryColor,
            ),
            child: const Text(
              'Suivre ma commande',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _showChangeAddressDialog(BuildContext context) async {
    final hasPosition = controller.hasValidLocation;
    final result = await Get.to<Map<String, dynamic>>(
      () => MapSelectionView(
        initialLatitude: hasPosition ? controller.clientLatitude.value : null,
        initialLongitude: hasPosition ? controller.clientLongitude.value : null,
        locationName: hasPosition ? controller.currentLocation.value : null,
      ),
      transition: Transition.rightToLeft,
    );
    if (result == null) return; // annulé

    final lat = (result['latitude'] as num?)?.toDouble();
    final lon = (result['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return;

    controller.isLoadingLocation.value = true;
    try {
      await controller.setDeliveryPosition(
        lat,
        lon,
        fallbackAddress: result['address']?.toString(),
      );
    } finally {
      controller.isLoadingLocation.value = false;
    }

    // Les tarifs de livraison dépendent de la position.
    if (controller.currentProductId.value != 0) {
      await controller.loadDeliveryPartners(controller.currentProductId.value);
    }

    Get.snackbar(
      'Adresse mise à jour',
      'Votre adresse de livraison a été modifiée',
      snackPosition: SnackPosition.BOTTOM,
      icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
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
    if (product['primary_image'] != null &&
        product['primary_image'].toString().isNotEmpty) {
      final primaryImage = product['primary_image'].toString();
      if (!images.contains(primaryImage)) {
        images.insert(0, primaryImage);
      }
    }

    // Try single image field
    if (images.isEmpty &&
        product['image'] != null &&
        product['image'].toString().isNotEmpty) {
      images.add(product['image'].toString());
    }

    // Fallback to placeholder
    if (images.isEmpty) {
      images.add('assets/images/p1.jpeg');
    }

    return images;
  }

  /// Build image widget (network or asset)
  Widget _buildImageWidget(String imageUrl, {BoxFit fit = BoxFit.cover}) {
    final resolvedUrl = _resolveImageUrl(imageUrl);
    if (resolvedUrl.startsWith('http://') ||
        resolvedUrl.startsWith('https://')) {
      return Image.network(
        resolvedUrl,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppThemeSystem.primaryColor,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: double.infinity,
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
        resolvedUrl,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: double.infinity,
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

  /// Les URLs d'images viennent parfois de APP_URL côté Laravel (IP de
  /// développement différente de celle utilisée par l'application). On garde
  /// le chemin du fichier, mais on l'aligne sur l'hôte réel de l'API.
  String _resolveImageUrl(String value) {
    final image = Uri.tryParse(value.trim());
    final api = Uri.tryParse(AppConstants.baseUrl);
    if (image == null || api == null) return value;

    if (image.hasScheme && image.host.isNotEmpty) {
      return image
          .replace(
            scheme: api.scheme,
            host: api.host,
            port: api.hasPort ? api.port : null,
          )
          .toString();
    }

    if (value.startsWith('/')) {
      return api.replace(path: value, query: null, fragment: null).toString();
    }
    return value;
  }

  /// Build similar products section
  Widget _buildSimilarProductsSection(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final categoryName =
        product['category']?['name']?.toString() ?? 'cette catégorie';
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
                    Get.toNamed(
                      '/search',
                      arguments: {
                        'categoryId': categoryId,
                        'categoryName': categoryName,
                      },
                    );
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
  Widget _buildSimilarProductCard(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final productName = product['name']?.toString() ?? 'Produit';
    final productPrice = product['price_xaf'] ?? product['price'] ?? 0;
    final productStock = product['stock'] ?? 0;

    // Get product image
    String? productImage;
    if (product['primary_image'] != null &&
        product['primary_image'].toString().isNotEmpty) {
      productImage = product['primary_image'].toString();
    } else if (product['images'] != null &&
        product['images'] is List &&
        (product['images'] as List).isNotEmpty) {
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
        Get.offNamed('/product', arguments: product, preventDuplicates: false);
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
                  AppThemeSystem.getBorderRadius(
                    context,
                    BorderRadiusType.medium,
                  ),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
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
                    controller.formatPrice(
                      double.tryParse(productPrice.toString()) ?? 0,
                    ),
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
