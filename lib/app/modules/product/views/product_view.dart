import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/delivery_delay.dart';
import '../../../core/utils/location_label.dart';
import '../../../core/widgets/delivery_details_widgets.dart';
import '../../../core/widgets/deposit_widgets.dart';
import '../../../core/widgets/free_delivery_widgets.dart';
import '../../../core/widgets/product_image_viewer.dart';
import '../../../core/widgets/product_video_player.dart';
import '../../../core/utils/media_url.dart';
import '../../../data/models/wholesale_models.dart';
import '../../../core/widgets/product_variant_selector.dart';
import '../../../core/values/constants.dart';
import '../../../data/providers/storage_service.dart';
import '../../../routes/app_pages.dart';
import '../controllers/product_controller.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../payment/widgets/mobile_money_waiting.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../payment/widgets/wallet_payment_confirm_dialog.dart';
import '../../../data/models/delivery_info.dart';
import '../../../data/models/payment_method_option.dart';
import '../../../data/services/stripe_native_service.dart';
import 'map_selection_view.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/scoped_controller_page.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../../core/widgets/variant_combo_picker.dart';
import '../../../core/utils/app_navigation.dart';

/// Fiche produit telle que la route l'ouvre : chaque fiche empilée
/// (produit similaire, boutique, lien partagé…) possède son propre
/// [ProductController] (voir [ScopedControllerPage]).
class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScopedControllerPage<ProductController>(
      create: ProductController.new,
      builder: (controller) => ProductView(pageController: controller),
    );
  }
}

class ProductView extends GetView<ProductController> {
  const ProductView({super.key, this.pageController});

  /// Contrôleur propre à la fiche (voir [ProductPage]). Tenu directement
  /// plutôt que recherché à chaque accès : un rappel qui se termine après la
  /// fermeture de la fiche ne lève pas « controller not found ». Sans lui, la
  /// vue retombe sur le contrôleur partagé, comme dans les tests.
  final ProductController? pageController;

  @override
  ProductController get controller => pageController ?? super.controller;

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    // Les arguments de CETTE page, et non `Get.arguments` : ce dernier suit la
    // route au sommet de la pile. Dès qu'une visionneuse d'image, une feuille
    // ou un dialogue s'ouvrait par-dessus, une reconstruction de la fiche
    // (clavier, retour de la visionneuse…) lisait leurs arguments, vides, et
    // affichait le produit de démonstration à la place du vrai.
    //
    // Sans arguments, on n'invente plus de produit : l'ancien produit de
    // démonstration (un t-shirt) s'affichait à la place du vrai et semblait
    // être « la mauvaise photo ».
    final product =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (product == null) {
      return Scaffold(
        backgroundColor: AppThemeSystem.getBackgroundColor(context),
        appBar: AppBar(leading: const AppBackButton()),
        body: AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'product.not_found.title'.tr,
          message: 'product.not_found.message'.tr,
        ),
      );
    }

    // Statistiques vendeur : consultation de la fiche (dédoublonnée).
    controller.trackProductView(product);

    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: CustomScrollView(
        slivers: [
          // App Bar avec images
          SliverAppBar(
            // Hauteur proportionnelle : 400 px fixes mangeaient la moitié
            // d'un petit écran et paraissaient timides sur une tablette.
            expandedHeight: (MediaQuery.sizeOf(context).height * 0.42).clamp(
              280.0,
              460.0,
            ),
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
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              tooltip: 'product.back'.tr,
              // Ouverte depuis une notification, la fiche n'a pas de page
              // précédente : le retour ramène alors à l'accueil.
              onPressed: () => AppNavigation.back(context),
            ),
            actions: [
              // Partage masqué en attendant la mise en ligne : les liens
              // n'ouvriront la fiche que lorsque le domaine servira les
              // fichiers d'association renseignés (empreinte Android, Team ID
              // Apple). D'ici là, un lien partagé ne ferait que renvoyer vers
              // la boutique d'applications.
              //
              // Pour le rétablir : décommenter ce bloc. Le reste de la chaîne
              // est en place — AppConstants.productUrl, shareProduct() et
              // DeepLinkService.
              //
              // IconButton(
              //   icon: Container(
              //     padding: EdgeInsets.all(8),
              //     decoration: BoxDecoration(
              //       color: Colors.black.withValues(alpha: 0.3),
              //       shape: BoxShape.circle,
              //       border: Border.all(
              //         color: Colors.white.withValues(alpha: 0.3),
              //         width: 1,
              //       ),
              //     ),
              //     child: Icon(
              //       Icons.share_rounded,
              //       color: Colors.white,
              //       size: 20,
              //     ),
              //   ),
              //   onPressed: () {
              //     // Rectangle d'ancrage réclamé par iPad : sans lui, iOS
              //     // refuse d'afficher la feuille.
              //     final box = context.findRenderObject() as RenderBox?;
              //     controller.shareProduct(
              //       product,
              //       origin: box == null
              //           ? null
              //           : box.localToGlobal(Offset.zero) & box.size,
              //     );
              //   },
              // ),
              // SizedBox(width: 8),
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
                      color: isFav ? AppDesign.danger : Colors.white,
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
                        featureName: 'product.feature.favorites'.tr,
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
                // Blocs posés sur la surface, séparés par des bandes de
                // fond : la page se lit par paliers au lieu d'une coulée
                // continue de cartes flottantes.
                _buildProductHeader(context, product),
                _sectionGap(context),
                _buildVariantsSection(context, product),
                _buildLocationSection(context, product),
                _sectionGap(context),
                _buildDescriptionSection(context, product),
                _buildProductCharacteristics(context, product),
                _sectionGap(context),
                _buildSellerSection(context, product),
                _sectionGap(context),
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
    final video = WholesaleVideo.fromJson(product['video']);
    // La vidéo, quand il y en a une, ouvre la galerie ; les photos suivent.
    final offset = video == null ? 0 : 1;
    final mediaCount = images.length + offset;
    if (mediaCount == 0) {
      return const _ImagePlaceholder(icon: Icons.image_outlined);
    }

    return Stack(
      children: [
        PageView.builder(
          controller: controller.imagePageController,
          itemCount: mediaCount,
          onPageChanged: (index) {
            controller.currentImageIndex.value = index;
          },
          itemBuilder: (context, index) {
            if (video != null && index == 0) {
              return Obx(
                () => ProductGalleryVideo(
                  url: resolveMediaUrl(video.url),
                  poster: _buildImageWidget(
                    _videoPoster(video, images),
                    fit: BoxFit.cover,
                  ),
                  active: controller.currentImageIndex.value == 0,
                ),
              );
            }
            final photo = index - offset;
            return GestureDetector(
              onTap: () => _openImageViewer(context, images, photo, offset),
              child: Hero(
                tag: 'product-image-${product['id']}-$photo',
                child: _buildImageWidget(images[photo], fit: BoxFit.cover),
              ),
            );
          },
        ),
        // Compteur + invitation à zoomer
        if (images.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: () {
                final photo = controller.currentImageIndex.value - offset;
                // Sur la vidéo, le bouton mène aux photos qui suivent.
                if (photo < 0) {
                  controller.goToImage(offset);
                } else {
                  _openImageViewer(context, images, photo, offset);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.zoom_in_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    if (images.length > 1) ...[
                      const SizedBox(width: 6),
                      Obx(
                        () => Text(
                          controller.currentImageIndex.value < offset
                              ? '${images.length}'
                              : '${controller.currentImageIndex.value - offset + 1}/${images.length}',
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
        // Indicateurs d'images (la vidéo compte pour une page)
        if (mediaCount > 1)
          Positioned(
            bottom: 22,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    mediaCount,
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

  /// Visionneuse plein écran des photos ; [photoIndex] ne compte pas la
  /// vidéo, [offset] la place qu'elle occupe en tête de galerie.
  Future<void> _openImageViewer(
    BuildContext context,
    List<String> images,
    int photoIndex, [
    int offset = 0,
  ]) async {
    final lastPhoto = await ProductImageViewer.open(
      context,
      images: images,
      initialIndex: photoIndex,
      imageBuilder: (image, fit) => _buildImageWidget(image, fit: fit),
    );
    if (lastPhoto == null) return;
    final page = lastPhoto + offset;
    if (page != controller.currentImageIndex.value) {
      controller.imagePageController.jumpToPage(page);
      controller.currentImageIndex.value = page;
    }
  }

  /// Affiche de la vidéo, sinon la première photo du produit.
  String _videoPoster(WholesaleVideo video, List<String> images) =>
      video.posterUrl ?? (images.isNotEmpty ? images.first : '');

  /// Clé de la vignette vidéo dans le bandeau (jamais une URL de photo).
  static const _videoThumbKey = '__video__';

  Widget _buildThumbnails(BuildContext context, Map<String, dynamic> product) {
    final images = _getProductImages(product);
    final video = WholesaleVideo.fromJson(product['video']);
    final media = [if (video != null) _videoThumbKey, ...images];
    if (media.length < 2) return const SizedBox.shrink();

    Widget thumb(String value, BoxFit fit) {
      final image = _buildImageWidget(
        value == _videoThumbKey ? _videoPoster(video!, images) : value,
        fit: fit,
        decodeSize: const Size.square(60),
      );
      if (value != _videoThumbKey) return image;
      // La vidéo se distingue par un symbole lecture.
      return Stack(
        fit: StackFit.expand,
        children: [
          image,
          const ColoredBox(color: Color(0x33000000)),
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Obx(
        () => ProductThumbnailStrip(
          images: media,
          currentIndex: controller.currentImageIndex.value,
          onSelected: controller.goToImage,
          imageBuilder: thumb,
        ),
      ),
    );
  }

  /// En-tête : le prix domine, puis le nom, puis la boutique et la note.
  ///
  /// L'ordre suit celui des places de marché : on regarde l'image, on lit le
  /// prix, puis on identifie l'article. Le prix était auparavant relégué
  /// sous le nom, à une taille voisine, et ne ressortait pas.
  Widget _buildProductHeader(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final shopName = product['shop']?['name']?.toString() ?? '';

    return Container(
      color: context.ds.surface,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space4,
        context.ds.gutter,
        AppDesign.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => Text(
              controller.formatPrice(controller.unitPriceXaf(product)),
              style: context.textStyle(
                FontSizeType.h2,
                fontWeight: FontWeight.w800,
                color: AppDesign.accent,
                height: 1.1,
              ),
            ),
          ),
          if (readFreeDelivery(product['free_delivery'])) ...[
            SizedBox(height: AppDesign.space2),
            const FreeDeliveryBadge(),
          ],
          if (DepositProduct.enabled(product)) ...[
            SizedBox(height: AppDesign.space3),
            Obx(() {
              final price = controller.unitPriceXaf(product);
              final deposit = DepositProduct.depositFor(
                price,
                DepositProduct.rate(product),
              );
              return DepositInfoCard(
                total: controller.formatPrice(price),
                deposit: controller.formatPrice(deposit),
                balance: controller.formatPrice(price - deposit),
              );
            }),
          ],
          SizedBox(height: AppDesign.space2),
          Text(
            product['name']?.toString() ?? 'product.fallback_name'.tr,
            style: context.textStyle(
              FontSizeType.body1,
              fontWeight: FontWeight.w600,
              color: context.ds.textPrimary,
              height: 1.35,
            ),
          ),
          if (shopName.isNotEmpty) ...[
            SizedBox(height: AppDesign.space2),
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 15,
                  color: context.ds.textTertiary,
                ),
                SizedBox(width: AppDesign.space1 + 2),
                Flexible(
                  child: Text(
                    shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.caption,
                      fontWeight: FontWeight.w600,
                      color: context.ds.textSecondary,
                    ),
                  ),
                ),
                if (ProductCard.isShopCertified(product)) ...[
                  SizedBox(width: AppDesign.space2),
                  AppBadge(
                    label: 'product.verified'.tr,
                    tone: AppBadgeTone.info,
                    icon: Icons.verified_rounded,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Bande grise séparant deux blocs, à la manière des places de marché.
  ///
  /// Remplace les Divider pleine largeur : elle marque une rupture franche
  /// entre des sections qui, sinon, se lisaient comme une seule coulée.
  Widget _sectionGap(BuildContext context) =>
      Container(height: AppDesign.space2, color: context.ds.canvas);

  /// Ligne compacte libellé / valeur.
  ///
  /// Les caractéristiques occupaient chacune une carte à pastille colorée ;
  /// en lignes, elles se comparent d'un coup d'œil et tiennent sur un écran.
  Widget _specRow(
    BuildContext context, {
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: AppDesign.space3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.caption,
                color: context.ds.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.caption,
                fontWeight: FontWeight.w600,
                color: context.ds.textPrimary,
              ),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.ds.textTertiary,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }

  /// Détails textuels du produit : caractéristiques, mentions commerciales,
  /// tailles.
  ///
  /// Stock, poids et provenance ne figurent plus ici : ils ont rejoint le
  /// bloc d'informations pratiques, où ils se comparent en lignes.
  Widget _buildProductCharacteristics(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final characteristics = product['characteristics']?.toString().trim();
    final commercialInformation = product['commercial_information']
        ?.toString()
        .trim();
    final sizes =
        (product['sizes'] as List?)
            ?.map((size) => size.toString())
            .where((size) => size.isNotEmpty)
            .toList() ??
        const <String>[];

    final rows = <Widget>[
      if (characteristics?.isNotEmpty == true)
        _specRow(context, label: 'product.specs.characteristics'.tr, value: characteristics!),
      if (commercialInformation?.isNotEmpty == true)
        _specRow(context, label: 'product.specs.information'.tr, value: commercialInformation!),
      if (sizes.isNotEmpty)
        _specRow(context, label: 'product.specs.sizes'.tr, value: sizes.join(' · ')),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      color: context.ds.surface,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) AppDivider(),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// Bloc des informations pratiques : lieu, stock, poids, origine.
  ///
  /// Chacune occupait auparavant sa propre carte, avec pastille colorée et
  /// grandes marges : trois écrans pour trois valeurs. Regroupées en lignes,
  /// elles se lisent d'un coup.
  Widget _buildLocationSection(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final fullLocation =
        product['location']?.toString() ??
        product['shop']?['address']?.toString() ??
        'product.location.unspecified'.tr;
    final shopLabel = product['shop'] is Map
        ? LocationLabel.fromApi(
            Map<String, dynamic>.from(product['shop'] as Map),
          )
        : null;
    final shortLocation = shopLabel ?? _getShortLocation(fullLocation);

    final stock = product['stock'];
    final stockValue = stock is int ? stock : int.tryParse(stock.toString());
    final weight = _weightDisplay(product);
    final origin = _originLabel(
      product['origin_country']?.toString().trim().toUpperCase(),
    );
    final deliveryDelay = DeliveryDelay.fromApi(product['delivery_delay']);

    return Container(
      color: context.ds.surface,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _specRow(
            context,
            label: 'product.specs.ships_from'.tr,
            value: shortLocation,
            onTap: () => _openMapOptions(context, product),
          ),
          if (stockValue != null) ...[
            AppDivider(),
            _specRow(
              context,
              label: 'product.specs.stock'.tr,
              value: stockValue > 0
                  ? (stockValue > 1
                            ? 'product.specs.units_plural'
                            : 'product.specs.units_singular')
                        .trParams({'count': '$stockValue'})
                  : 'product.out_of_stock'.tr,
            ),
          ],
          if (weight != null) ...[
            AppDivider(),
            _specRow(context, label: 'product.specs.weight'.tr, value: weight),
          ],
          if (origin.isNotEmpty) ...[
            AppDivider(),
            _specRow(context, label: 'product.specs.origin'.tr, value: origin),
          ],
          if (deliveryDelay != null) ...[
            AppDivider(),
            _specRow(
              context,
              label: 'product.specs.delivery_delay'.tr,
              value: deliveryDelay.label,
            ),
          ],
        ],
      ),
    );
  }

  /// Pays d'origine en clair. Absent, l'article est considéré local.
  String _originLabel(String? code) {
    if (code == null || code.isEmpty || code == 'NULL') {
      return 'product.origin.local'.tr;
    }
    final countries = {
      'CN': 'product.origin.china'.tr,
      'AE': 'product.origin.uae'.tr,
      'TR': 'product.origin.turkey'.tr,
    };
    return countries[code] ?? code;
  }

  /// Poids affichable : mesure personnalisée si elle existe, sinon la
  /// catégorie prédéfinie traduite en ordre de grandeur.
  String? _weightDisplay(Map<String, dynamic> product) {
    final custom = product['weight']?.toString();
    if (custom != null &&
        custom.isNotEmpty &&
        custom != '0' &&
        custom != 'null') {
      return custom.toLowerCase().contains('kg') ? custom : '$custom kg';
    }

    final category = product['weight_category']?.toString();
    if (category == null || category.isEmpty || category == 'null') return null;

    const map = {
      'X-small': '~5 kg',
      '30 Deep': '~30 kg',
      '50 Deep': '~50 kg',
      '60 Deep': '~60 kg',
      'Rainbow XL': '~100 kg',
      'Pallet': '~500 kg',
    };
    return map[category] ?? category;
  }

  Widget _buildDescriptionSection(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    return Container(
      color: context.ds.surface,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space4,
        context.ds.gutter,
        AppDesign.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre seul, sans icône : la section se nomme déjà, et l'icône
          // ajoutait une couleur de plus sans rien apprendre.
          Text(
            'product.description.title'.tr,
            style: context.textStyle(
              FontSizeType.body1,
              fontWeight: FontWeight.w700,
              color: context.ds.textPrimary,
            ),
          ),
          SizedBox(height: AppDesign.space3),
          Text(
            product['description'] ??
                'product.description.empty'.tr,
            style: context.textStyle(
              FontSizeType.caption,
              color: context.ds.textSecondary,
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
                color: context.ds.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'product.variants.title'.tr,
                style: context.textStyle(
                  FontSizeType.subtitle1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Le choix se fait dans la feuille de commande, où plusieurs
          // combinaisons peuvent être prises à la fois.
          Text(
            'product.variants.hint'.tr,
            style: context.textStyle(
              FontSizeType.caption,
              color: context.ds.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          VariantOptionsPreview(catalog: catalog),
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
        shop?['name']?.toString() ??
        seller?['name']?.toString() ??
        'product.seller'.tr;
    final shopImage = shop?['image']?.toString() ?? shop?['logo']?.toString();
    final ownerImage = seller?['avatar']
        ?.toString(); // Get seller avatar from seller object
    final isCertified = _isShopCertified(product);
    final rating = seller?['rating'] ?? shop?['rating'] ?? 4.5;
    final reviewCount = seller?['reviews_count'] ?? shop?['reviews_count'] ?? 0;

    return Container(
      color: context.ds.surface,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.all(context.ds.gutter),
        // La carte à bordure flottait au milieu d'une page désormais faite
        // de bandes pleine largeur ; elle s'aligne sur le même principe.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.store_rounded,
                  color: context.ds.textSecondary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'product.seller'.tr,
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
                      color: AppDesign.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppDesign.info.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppDesign.info,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'product.certified'.tr,
                          style: context.textStyle(
                            FontSizeType.overline,
                            color: AppDesign.info,
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
                            ? Image(
                                image: AppNetworkImage.provider(
                                  context,
                                  ownerImage,
                                  const Size.square(50),
                                ),
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
                                  color: context.ds.surfaceMuted,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: context.ds.textSecondary,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Container(
                                // Avatar de repli : un aplat orange plein
                                // rivalisait avec le bouton Commander.
                                color: context.ds.surfaceMuted,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: context.ds.textSecondary,
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
                            color: AppDesign.info,
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
                        ? Image(
                            image: AppNetworkImage.provider(
                              context,
                              shopImage,
                              const Size.square(56),
                            ),
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
                          // La note n'est pas une alerte : le jeton warning
                          // (#9A6700) y introduisait une couleur de plus.
                          Icon(
                            Icons.star_rounded,
                            color: AppDesign.accent,
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
                            'product.reviews_count'.trParams({
                              'count': '$reviewCount',
                            }),
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
                      'product.error'.tr,
                      'product.shop_access_error'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppThemeSystem.errorColor,
                      colorText: Colors.white,
                    );
                  }
                },
                icon: Icon(Icons.storefront_rounded, size: 18),
                label: Text('product.view_shop'.tr),
                // Contour neutre : en orange, ce bouton faisait un second
                // appel coloré à quelques pixels de « Commander », alors
                // qu'il mène seulement à la boutique.
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.ds.textPrimary,
                  side: BorderSide(color: context.ds.borderStrong),
                  padding: EdgeInsets.symmetric(vertical: AppDesign.space3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barre d'achat, ancrée en bas de la fiche.
  ///
  /// Une seule action y est colorée. « Message » et « Commander » portaient
  /// tous deux l'orange — l'un plein, l'autre en contour épais — et se
  /// disputaient le regard ; le contact vendeur redevient une action
  /// discrète. L'ombre portée qui séparait la barre du contenu cède la place
  /// à un filet, et le prix y est rappelé : c'est le montant qu'on engage en
  /// appuyant.
  Widget _buildBottomBar(BuildContext context, Map<String, dynamic> product) {
    final currentUser = StorageService.getUser();
    final seller = product['seller'] as Map<String, dynamic>?;
    final sellerId = int.tryParse(seller?['id']?.toString() ?? '');
    final isMyProduct =
        currentUser != null && sellerId != null && currentUser.id == sellerId;

    return Container(
      decoration: BoxDecoration(
        color: context.ds.surface,
        border: Border(top: BorderSide(color: context.ds.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space3,
        context.ds.gutter,
        AppDesign.space3,
      ),
      child: SafeArea(
        top: false,
        child: isMyProduct
            ? AppButton(
                label: 'product.manage_products'.tr,
                size: AppButtonSize.large,
                icon: Icons.edit_rounded,
                onPressed: () => Get.toNamed(Routes.PRODUCT_MANAGEMENT),
              )
            : Row(
                children: [
                  // Contact vendeur : action secondaire, en retrait.
                  Obx(
                    () => _SecondaryAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: controller.isStartingConversation.value
                          ? 'product.opening'.tr
                          : 'product.message'.tr,
                      busy: controller.isStartingConversation.value,
                      onPressed: controller.isStartingConversation.value
                          ? null
                          : () => AuthGuard.requireAuth(
                              context,
                              onAuthenticated: () => controller
                                  .openConversationWithSeller(product: product),
                              featureName: 'product.feature.messaging'.tr,
                            ),
                    ),
                  ),
                  SizedBox(width: AppDesign.space3),
                  Expanded(
                    child: _OrderButton(
                      label: DepositProduct.enabled(product)
                          ? 'core.deposit.pay_deposit'.tr
                          : 'product.order_button'.tr,
                      priceLabel: () {
                        final price = controller.unitPriceXaf(product);
                        return controller.formatPrice(
                          DepositProduct.enabled(product)
                              ? DepositProduct.depositFor(
                                  price,
                                  DepositProduct.rate(product),
                                )
                              : price,
                        );
                      },
                      onPressed: () => AuthGuard.requireAuth(
                        context,
                        onAuthenticated: () =>
                            _showOrderDialog(context, product),
                        featureName: 'product.feature.order'.tr,
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
    if (fullLocation.isEmpty || fullLocation == 'product.location.unspecified'.tr) {
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
        'product.location.unspecified'.tr;

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
                        'product.map_options.title'.tr,
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
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.10),
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
                            'product.map_options.asso_map'.tr,
                            style: context.textStyle(
                              FontSizeType.body1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'product.map_options.asso_map_hint'.tr,
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
                            'product.map_options.google_maps_hint'.tr,
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
                child: Text('product.cancel'.tr),
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
        'product.map_options.position_unavailable_title'.tr,
        'product.map_options.position_unavailable_message'.tr,
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
        'product.map_options.position_unavailable_title'.tr,
        'product.map_options.position_unavailable_message'.tr,
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
          'product.error'.tr,
          'product.map_options.google_maps_open_error'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        'product.error'.tr,
        'product.map_options.google_maps_error'.tr,
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
    // Quantités remises à zéro à chaque ouverture ; la variante regardée sur
    // la fiche est proposée d'office.
    controller.resetOrderQuantities(product);
    final hasVariants = controller.productHasVariants(product);

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

    AppSheet.show(
      AppSheet(
        title: 'product.order.sheet_title'.tr,
        // Le contenu est fait de cartes : elles se détachent mieux sur le fond
        // d'écran que sur une surface blanche.
        color: context.ds.canvas,
        // Le bouton reste épinglé au-dessus du clavier : au bout du contenu,
        // il passait dessous dès qu'on saisissait le numéro à contacter.
        footer: Obx(() {
          final missing = controller.missingOrderSteps(product);
          final ready =
              missing.isEmpty &&
              !controller.isLoadingPartners.value &&
              !controller.isCreatingOrder.value;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // L'étape qui bloque, juste au-dessus du bouton qu'elle
              // débloque. La liste complète, en bas du contenu, sortait du
              // champ : le bouton restait grisé sans explication visible.
              if (missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDesign.space2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppDesign.warning,
                      ),
                      const SizedBox(width: AppDesign.space2),
                      Expanded(
                        child: Text(
                          'product.order.to_continue'.trParams({
                            'step': missing.first,
                          }),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyle(
                            FontSizeType.caption,
                            color: AppDesign.warningText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ElevatedButton.icon(
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
                  'product.order.review'.tr,
                  style: context.textStyle(
                    FontSizeType.body1,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  disabledBackgroundColor: AppThemeSystem.grey400,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          );
        }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avec options, chaque option affiche son propre prix plus bas.
            Text(
              hasVariants
                  ? '${product['name']}'
                  : '${product['name']} — ${controller.formatPrice(controller.unitPriceXaf(product))}',
              style: context.textStyle(
                FontSizeType.caption,
                color: AppThemeSystem.grey600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 16),


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
                labelText: 'product.order.address_details_label'.tr,
                hintText: 'product.order.address_details_hint'.tr,
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
                labelText: 'product.order.contact_phone_label'.tr,
                hintText: 'product.order.contact_phone_hint'.tr,
                helperText: 'product.order.contact_phone_helper'.tr,
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Section partenaires de livraison
            Text(
              'product.order.step_partner'.tr,
              style: context.textStyle(
                FontSizeType.body1,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            _buildDeliveryPartnersSection(context, product),

            SizedBox(height: 20),

            // Récapitulatif des prix
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.ds.surface,
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
                    // Produit sans options : quantité aux boutons ou au
                    // clavier. Avec options, elle se règle option par option
                    // plus haut.
                    if (!hasVariants) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'product.order.quantity'.tr,
                            style: context.textStyle(
                              FontSizeType.body2,
                              color: AppThemeSystem.grey600,
                            ),
                          ),
                          QuantityStepper(
                            compact: true,
                            min: 1,
                            value: controller.orderQuantity.value,
                            max: controller.maxQuantity(product),
                            onChanged: (quantity) =>
                                controller.setOrderQuantity(product, quantity),
                            onMaxReached: () => controller.notifyStockLimit(
                              controller.maxQuantity(product) ?? 0,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'product.order.items_count'.trParams({
                            'count': '${controller.orderQuantity.value}',
                          }),
                          style: context.textStyle(
                            FontSizeType.body2,
                            color: AppThemeSystem.grey600,
                          ),
                        ),
                        Text(
                          controller.formatPrice(
                            controller.orderSubtotal(product),
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
                              'product.order.delivery_with'.trParams({
                                'company':
                                    '${controller.selectedPartner.value!['company_name']}',
                              }),
                              style: context.textStyle(
                                FontSizeType.body2,
                                color: AppThemeSystem.grey600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DeliveryPriceText(
                            price: controller.formatPrice(
                              controller.deliveryPrice.value,
                            ),
                            isFree: controller.deliveryIsFree,
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
                            'product.order.total_weight'.trParams({
                              'weight': formatKg(controller.deliveryWeightKg),
                            }),
                            style: context.caption,
                          ),
                        ),
                    ],
                    Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DepositProduct.enabled(product)
                                ? 'core.deposit.deposit_now'.tr
                                : 'product.order.total'.tr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.h5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          controller.formatPrice(
                            controller.orderAmountDue(product),
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
          ],
        ),
      ),
    );
  }

  /// Partenaires de livraison chiffrés au poids réel (poids × quantité), avec
  /// catégorie, mode, trajet, délai, prix et accès au détail complet.
  /// Quartier de livraison pour les grilles zone à zone (ex. SOLEX Douala) :
  /// le prix dépend de la zone du quartier de l'acheteur. Null hors grille.
  Widget? _buildQuarterPicker(BuildContext context) {
    final grid = controller.deliveryQuote.value?['city_grid'];
    // La position choisie sur la carte suffit : les partenaires qui couvrent la zone sont
    // proposés directement. Rien à afficher, sauf si la position n'est dans aucune zone.
    if (grid is! Map || grid['quarter_required'] != true) return null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeSystem.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeSystem.primaryColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'product.delivery.no_courier_in_city'.trParams({
              'city': '${grid['city']}',
            }),
            style: context.textStyle(
              FontSizeType.body2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'product.delivery.place_pin_hint'.tr,
            style: context.caption,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showChangeAddressDialog(context),
              icon: const Icon(Icons.map_rounded, color: Colors.white),
              label: Text(
                'product.delivery.view_zones'.tr,
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPartnersSection(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
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
                  'product.delivery.computing_rates'.tr,
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
              'product.delivery.weight_required_explanation'.tr,
              style: context.caption,
            ),
          ],
        );
      }

      final quarterPicker = _buildQuarterPicker(context);
      final quarterRequired =
          controller.deliveryQuote.value?['city_grid'] is Map &&
          controller.deliveryQuote.value!['city_grid']['quarter_required'] ==
              true;

      if (controller.deliveryPartners.isEmpty) {
        final message = controller.deliveryQuote.value?['message']?.toString();
        if (quarterPicker != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              quarterPicker,
              if (!quarterRequired) ...[
                const SizedBox(height: 12),
                Text(
                  message ?? 'product.delivery.no_partner'.tr,
                  style: context.caption,
                ),
              ],
            ],
          );
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppThemeSystem.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppThemeSystem.getBorderColor(context)),
          ),
          // Le nom de ville vient du serveur : sans retour à la ligne ni
          // centrage, la phrase était coupée net.
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: context.ds.textTertiary,
              ),
              SizedBox(width: AppDesign.space2),
              Expanded(
                child: Text(
                  message?.isNotEmpty == true
                      ? message!
                      : 'product.delivery.no_partner_at'.trParams({
                          'location': controller.currentLocation.value,
                        }),
                  style: context.textStyle(
                    FontSizeType.caption,
                    color: context.ds.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final weight = controller.deliveryWeightKg;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?quarterPicker,
          if (weight != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.scale_outlined,
                    size: 16,
                    color: AppThemeSystem.grey600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (controller.orderQuantity.value > 1
                              ? 'product.delivery.parcel_weight_plural'
                              : 'product.delivery.parcel_weight_singular')
                          .trParams({
                            'weight': formatKg(weight),
                            'count': '${controller.orderQuantity.value}',
                          }),
                      style: context.caption,
                    ),
                  ),
                ],
              ),
            ),
          if (DepositProduct.enabled(product))
            ..._buildPickupChoice(context)
          else
            for (final raw in controller.deliveryPartners)
              _buildPartnerCard(context, DeliveryPartnerQuote(raw)),
        ],
      );
    });
  }

  /// Produit sur commande : le client choisit dès l'acompte entre le retrait
  /// dans un point partenaire ASSO et la livraison à domicile. Pour une
  /// commande internationale, l'acheminement jusqu'au pays reste compris.
  List<Widget> _buildPickupChoice(BuildContext context) {
    final quotes = controller.deliveryPartners.map(DeliveryPartnerQuote.new);
    final pickup = quotes.where((q) => q.isAgencyPickup).toList();
    final home = quotes.where((q) => !q.isAgencyPickup).toList();

    Widget title(IconData icon, String text, String hint) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppDesign.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(hint, style: context.caption),
              ],
            ),
          ),
        ],
      ),
    );

    return [
      if (pickup.isNotEmpty) ...[
        title(
          Icons.storefront_rounded,
          'core.deposit.pickup_title'.tr,
          'core.deposit.pickup_hint'.tr,
        ),
        for (final quote in pickup) _buildPartnerCard(context, quote),
      ],
      if (home.isNotEmpty) ...[
        title(
          Icons.home_rounded,
          'core.deposit.home_title'.tr,
          'core.deposit.home_hint'.tr,
        ),
        for (final quote in home) _buildPartnerCard(context, quote),
      ],
    ];
  }

  Widget _buildPartnerCard(BuildContext context, DeliveryPartnerQuote partner) {
    final selectedRaw = controller.selectedPartner.value;
    final isSelected =
        selectedRaw != null &&
        DeliveryPartnerQuote(selectedRaw).key == partner.key;
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
                          ? Image(
                              image: AppNetworkImage.provider(
                                context,
                                logo,
                                const Size.square(44),
                              ),
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
                            color: isSelected
                                ? AppThemeSystem.primaryColor
                                : null,
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
                            if (partner.vehicleLabel != null)
                              DeliveryChip(
                                partner.vehicleLabel!,
                                color: AppThemeSystem.primaryColor,
                                icon: Icons.local_shipping_outlined,
                              ),
                            DeliveryChip(
                              partner.isAgencyToAgency
                                  ? 'product.delivery.agency_to_agency'.tr
                                  : 'product.delivery.home'.tr,
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
                      DeliveryPriceText(
                        price: controller.formatPrice(partner.price),
                        isFree: partner.isFree,
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
                _partnerInfoRow(
                  context,
                  Icons.alt_route_rounded,
                  partner.routeOrZone!,
                ),
              if (partner.leadTime != null)
                _partnerInfoRow(
                  context,
                  Icons.schedule_rounded,
                  'product.delivery.estimated'.trParams({
                    'time': '${partner.leadTime}',
                  }),
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
                  label: Text('product.details'.tr),
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
                'product.variants.order_title'.tr,
                style: context.textStyle(
                  FontSizeType.body1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'product.variants.order_hint'.tr,
            style: context.textStyle(
              FontSizeType.caption,
              color: context.ds.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => VariantComboPicker(
              catalog: catalog,
              quantities: Map<int, int>.from(controller.variantQuantities),
              onChanged: controller.setVariantQuantities,
              priceOf: (variant) =>
                  controller.formatPrice(controller.variantPriceXaf(product, variant)),
              onStockLimit: (_, stock) => controller.notifyStockLimit(stock),
            ),
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
          'product.location.service_disabled'.tr,
        LocationIssue.permissionDenied =>
          'product.location.permission_denied'.tr,
        LocationIssue.deniedForever =>
          'product.location.denied_forever'.tr,
        LocationIssue.failed => 'product.location.failed'.tr,
        LocationIssue.none => null,
      };

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.ds.surface,
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
                        'product.location.delivery_address'.tr,
                        style: context.textStyle(
                          FontSizeType.caption,
                          color: AppThemeSystem.grey600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLocating
                            ? 'product.map.detecting_position'.tr
                            : hasAddress
                            ? controller.currentLocation.value
                            : 'product.location.no_address'.tr,
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
                          ? 'product.location.settings'.tr
                          : 'product.location.my_position'.tr,
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
                  child: OutlinedButton.icon(
                    onPressed: isLocating
                        ? null
                        : () => _showChangeAddressDialog(context),
                    icon: Icon(
                      Icons.edit_location_alt_rounded,
                      size: 18,
                      color: context.ds.textPrimary,
                    ),
                    label: Text(
                      hasAddress
                          ? 'product.edit'.tr
                          : 'product.location.pick_on_map'.tr,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.ds.textPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.ds.borderStrong),
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
    final orderLines = controller.orderLines(product);
    final partner = controller.selectedPartner.value;
    final quote = partner == null ? null : DeliveryPartnerQuote(partner);
    final details = controller.addressDetailsController.text.trim();
    final total = controller.orderTotal(product);
    final hasDeposit = DepositProduct.enabled(product);
    final amountDue = controller.orderAmountDue(product);
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

    final confirmed = await AppSheet.show<bool>(
      AppSheet(
        title: 'product.summary.title'.tr,
        color: context.ds.canvas,
        // La flèche ramène à la feuille de commande, restée ouverte dessous :
        // c'est une étape du parcours, pas une sortie. Une croix en plus
        // ferait la même chose sous un autre signe.
        onBack: () => AppNavigation.pop(false),
        showClose: false,
        footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => AppNavigation.pop(false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('product.edit'.tr),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => AppNavigation.pop(true),
              icon: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                'product.summary.confirm_and_pay'.tr,
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
        child: Column(
          children: [
            section(Icons.shopping_bag_rounded, 'product.summary.item'.tr, [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: images.isEmpty
                          ? const _ImagePlaceholder(icon: Icons.image_outlined)
                          : _buildImageWidget(
                              images.first,
                              decodeSize: const Size.square(64),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      product['name']?.toString() ?? 'product.fallback_name'.tr,
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
              // Une ligne par option commandée : « Rouge · 42 — 3 × 12 000 ».
              for (final orderLine in orderLines)
                line(
                  orderLine.label.isEmpty
                      ? 'product.order.quantity'.tr
                      : orderLine.label,
                  '${orderLine.quantity} × ${controller.formatPrice(orderLine.unitPriceXaf)}',
                ),
            ]),
            section(Icons.local_shipping_rounded, 'product.summary.delivery'.tr, [
              line('product.summary.address'.tr, controller.currentLocation.value),
              if (details.isNotEmpty) line('product.summary.address_details'.tr, details),
              line(
                'product.summary.contact_phone'.tr,
                controller.customerPhone.value,
              ),
              if (quote != null) ...[
                line(
                  'product.summary.courier'.tr,
                  quote.vehicleLabel != null
                      ? '${quote.companyName} · ${quote.vehicleLabel}'
                      : quote.companyName,
                ),
                line('product.summary.mode'.tr, quote.deliveryOptionLabel),
                if (quote.leadTime != null)
                  line('product.summary.lead_time'.tr, quote.leadTime!),
                if (DeliveryDelay.fromApi(product['delivery_delay']) case final delay?)
                  line('product.specs.delivery_delay'.tr, delay.label),
                if (quote.pickupNotice != null) ...[
                  const SizedBox(height: 6),
                  DeliveryNotice(
                    quote.pickupNotice!,
                    icon: Icons.store_mall_directory_outlined,
                  ),
                ],
              ],
            ]),
            section(Icons.receipt_long_rounded, 'product.summary.amount'.tr, [
              line(
                'product.summary.subtotal'.tr,
                controller.formatPrice(
                  controller.orderSubtotal(product),
                ),
              ),
              if (controller.deliveryIsFree)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'product.summary.delivery'.tr,
                          style: context.textStyle(
                            FontSizeType.body2,
                            color: AppThemeSystem.grey600,
                          ),
                        ),
                      ),
                      DeliveryPriceText(
                        price: controller.formatPrice(
                          controller.deliveryPrice.value,
                        ),
                        isFree: true,
                        style: context.textStyle(
                          FontSizeType.body2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                line(
                  'product.summary.delivery'.tr,
                  controller.formatPrice(
                    controller.deliveryPrice.value,
                  ),
                ),
              const Divider(height: 16),
              if (hasDeposit) ...[
                line('core.deposit.total_price'.tr, controller.formatPrice(total)),
                line(
                  'core.deposit.balance_later'.tr,
                  controller.formatPrice(total - amountDue),
                ),
                line(
                  'core.deposit.deposit_now'.tr,
                  controller.formatPrice(amountDue),
                  strong: true,
                ),
                const SizedBox(height: 6),
                DeliveryNotice(
                  'core.deposit.verification_notice'.tr,
                  icon: Icons.verified_user_outlined,
                ),
              ] else
                line(
                  'product.summary.total_to_pay'.tr,
                  controller.formatPrice(total),
                  strong: true,
                ),
            ]),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await _choosePaymentAndOrder(context, product, amountDue);
    }
  }

  /// Ouvre le sélecteur STANDARD de moyen de paiement puis lance le sous-parcours
  /// correspondant. Seuls les rails acceptés par /v1/orders sont proposés.
  Future<void> _choosePaymentAndOrder(
    BuildContext context,
    Map<String, dynamic> product,
    double total,
  ) async {
    final amountLabel = DepositProduct.enabled(product)
        ? 'core.deposit.deposit_now'.tr
        : 'product.summary.total_to_pay'.tr;
    final method = await PaymentMethodSelector.show(
      amount: total,
      currency: 'XAF',
      amountLabel: amountLabel,
      allowedCodes: const {'kpay', 'stripe'},
      includeWallet: true,
    );
    if (method == null) return; // annulé

    switch (method.code) {
      case 'wallet':
        await _payViaWallet(product, total, method);
        break;
      case 'kpay':
        await _payViaMobileMoney(product, total, amountLabel);
        break;
      case 'stripe':
        await _payViaCard(product);
        break;
      default:
        Get.snackbar(
          'product.payment.unavailable_title'.tr,
          'product.payment.method_unavailable'.tr,
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
      itemLabel: product['name']?.toString() ?? 'product.payment.order_fallback'.tr,
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
      'product.payment.wallet_paid'.tr,
    );
  }

  /// Paiement Mobile Money (KPay direct, validation USSD sur le téléphone).
  Future<void> _payViaMobileMoney(
    Map<String, dynamic> product,
    double total,
    String amountLabel,
  ) async {
    final selection = await KpayDirectPaymentSheet.show(
      amount: total,
      amountLabel: amountLabel,
    );
    if (selection == null) return; // paiement annulé

    final data = await controller.createOrder(
      product: product,
      paymentMode: 'kpay_direct',
      kpayProvider: selection['provider'],
      kpayPhone: selection['phone'],
    );
    if (data == null) return; // snackbar déjà affiché

    // La commande n'est confirmée qu'une fois le paiement validé sur le
    // téléphone : on attend la réponse de l'opérateur avant d'annoncer quoi
    // que ce soit. La feuille de commande reste ouverte derrière, pour
    // réessayer aussitôt en cas de refus.
    final orderId = _orderIdOf(data);
    final outcome = await MobileMoneyWaiting.run(
      amount: total,
      provider: selection['provider']!,
      phone: selection['phone']!,
      formatAmount: controller.formatPrice,
      check: () => controller.orderPaymentState(orderId),
      failureNote: 'product.payment.failed_order_cancelled'.tr,
    );

    switch (outcome.status) {
      case 'paid':
        _showOrderConfirmation(data, 'product.payment.confirmed_message'.tr);
      case 'failed':
        break; // motif déjà expliqué ; la feuille reste ouverte pour réessayer
      default:
        // Toujours en attente : l'acheteur est prévenu dès la réponse.
        controller.pollOrderPayment(orderId);
        _showOrderConfirmation(
          data,
          'product.payment.mobile_money_pending'.tr,
          paid: false,
        );
    }
  }

  /// Paiement par CARTE (Payment Sheet Stripe native), confirmé côté serveur.
  Future<void> _payViaCard(Map<String, dynamic> product) async {
    if (!StripeNativeService.isSupported) {
      Get.snackbar(
        'product.payment.unavailable_title'.tr,
        'product.payment.card_mobile_only'.tr,
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
        'product.error'.tr,
        'product.payment.card_data_missing'.tr,
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
          'product.payment.cancelled_title'.tr,
          'product.payment.cancelled_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      controller.pollOrderPayment(orderId);
      _showOrderConfirmation(
        data,
        'product.payment.card_pending'.tr,
      );
    } catch (e) {
      Get.snackbar(
        'product.error'.tr,
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
  /// [paid] faux : commande enregistrée mais paiement pas encore confirmé.
  void _showOrderConfirmation(
    Map<String, dynamic> data,
    String message, {
    bool paid = true,
  }) {
    // `AppNavigation.pop` et non `Get.back()` : un snackbar encore affiché
    // (paiement, adresse) aurait été fermé à la place de la feuille, et la
    // confirmation se serait ouverte par-dessus une commande déjà passée.
    AppNavigation.pop(); // fermer la feuille de commande
    final order = data['order'] as Map?;
    final orderNumber = order?['order_number']?.toString();
    final total = (order?['total'] as num?)?.toDouble();

    void leaveTo(String? route) {
      AppNavigation.pop(); // fermer la confirmation
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
        // Une croix pour rester sur la fiche : les deux boutons quittaient la
        // page, et la fenêtre ne se fermait pas autrement.
        icon: Row(
          children: [
            const SizedBox(width: AppDesign.minTapTarget),
            Expanded(
              child: Icon(
                paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                color: paid ? AppDesign.success : AppDesign.warning,
                size: 56,
              ),
            ),
            AppIconButton(
              icon: Icons.close_rounded,
              tooltip: 'product.close'.tr,
              onPressed: () => AppNavigation.pop(),
            ),
          ],
        ),
        title: Text(
          paid
              ? 'product.confirmation.title'.tr
              : 'product.confirmation.pending_title'.tr,
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (orderNumber != null)
              Text(
                'product.confirmation.order_number'.trParams({
                  'number': orderNumber,
                }),
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
            child: Text('product.confirmation.back_home'.tr),
          ),
          ElevatedButton(
            onPressed: () => leaveTo(Routes.SHIPMENT),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeSystem.primaryColor,
            ),
            child: Text(
              'product.confirmation.track_order'.tr,
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

    // La position choisie sur la carte décide de la zone de livraison.
    controller.deliveryQuarter.value = null;

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
      'product.location.updated_title'.tr,
      'product.location.updated_message'.tr,
      snackPosition: SnackPosition.BOTTOM,
      icon: const Icon(Icons.check_circle_rounded, color: AppDesign.success),
    );
  }

  /// Photos du produit, dans l'ordre des cartes du catalogue : la photo
  /// principale d'abord, puis la galerie, puis l'ancien champ `image`, sans
  /// doublon. La fiche et le récapitulatif ouvraient sinon sur une autre
  /// photo que celle de la carte touchée. Vide si le produit n'a pas de
  /// photo : l'appelant affiche alors un pictogramme neutre.
  List<String> _getProductImages(Map<String, dynamic> product) {
    final images = <String>[];
    void add(Object? value) {
      final url = value is Map ? value['url']?.toString() : value?.toString();
      if (url != null && url.trim().isNotEmpty && !images.contains(url)) {
        images.add(url);
      }
    }

    add(product['primary_image']);
    final gallery = product['images'];
    if (gallery is List) gallery.forEach(add);
    add(product['image']);

    return images;
  }

  /// Build image widget (network or asset)
  ///
  /// [decodeSize] : taille logique de la case, pour les vignettes. Sans elle,
  /// la photo est décodée au plafond global (carrousel, visionneuse).
  Widget _buildImageWidget(
    String imageUrl, {
    BoxFit fit = BoxFit.cover,
    Size? decodeSize,
  }) {
    final resolvedUrl = _resolveImageUrl(imageUrl);
    if (resolvedUrl.startsWith('http://') ||
        resolvedUrl.startsWith('https://')) {
      return Image(
        image: decodeSize == null
            ? NetworkImage(resolvedUrl)
            : AppNetworkImage.provider(Get.context!, resolvedUrl, decodeSize),
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
          return _ImagePlaceholder(icon: Icons.broken_image_outlined);
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
          return _ImagePlaceholder(icon: Icons.image_outlined);
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
        product['category']?['name']?.toString() ?? 'product.similar.this_category'.tr;
    final categoryId = product['category']?['id'];

    return Obx(() {
      // Rien de proche à proposer : la section disparaît au lieu d'afficher
      // un bloc vide en bas de fiche.
      if (!controller.isLoadingSimilarProducts.value &&
          controller.similarProducts.isEmpty) {
        return const SizedBox.shrink();
      }
      return _similarProductsBody(context, categoryName, categoryId);
    });
  }

  Widget _similarProductsBody(
    BuildContext context,
    String categoryName,
    dynamic categoryId,
  ) {
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
                'product.similar.title'.tr,
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
                  'product.similar.see_more'.tr,
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
          //
          // Même gabarit que l'accueil et la recherche : la largeur et la
          // hauteur viennent de `ProductCard`, qui calcule la place réelle de
          // son bloc texte. L'ancienne carte imposait 240 px pour un contenu
          // plus court, d'où le vide sous le prix.
          Obx(() {
            final cardWidth = ProductCard.widthInGrid(context);
            final cardHeight = ProductCard.totalHeight(context, cardWidth);

            if (controller.isLoadingSimilarProducts.value) {
              return SizedBox(
                height: cardHeight,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppThemeSystem.primaryColor,
                    ),
                  ),
                ),
              );
            }

            return SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: controller.similarProducts.length,
                separatorBuilder: (_, _) => SizedBox(width: AppDesign.space3),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildSimilarProductCard(
                      context,
                      controller.similarProducts[index],
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Vignette d'un produit similaire.
  ///
  /// Reprend `ProductCard`, le gabarit partagé par l'accueil et la recherche,
  /// plutôt qu'une carte maison : l'utilisateur retrouve le même objet
  /// visuel d'un écran à l'autre, et la hauteur suit le contenu au lieu
  /// d'être fixée à 240 px.
  Widget _buildSimilarProductCard(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    final productStock = product['stock'] ?? 0;
    final isOutOfStock = (productStock is num ? productStock : 0) <= 0;
    final productImage = _similarProductImageUrl(product);

    final rawPrice = product['price_xaf'] ?? product['price'] ?? 0;
    final price = controller.formatPrice(
      double.tryParse(rawPrice.toString()) ?? 0,
    );

    return ProductCard(
      name: product['name']?.toString() ?? 'product.fallback_name'.tr,
      price: price,
      location:
          product['location']?.toString() ??
          product['shop']?['address']?.toString(),
      isCertified: ProductCard.isShopCertified(product),
      badgeLabel: isOutOfStock ? 'product.out_of_stock'.tr : null,
      badgeTone: AppBadgeTone.danger,
      imageBuilder: (context) {
        if (productImage == null) {
          return const _ImagePlaceholder(icon: Icons.image_outlined);
        }
        final cardWidth = ProductCard.widthInGrid(context);
        return AppNetworkImage(
          url: productImage,
          decodeSize: Size(cardWidth, cardWidth / ProductCard.imageAspectRatio),
          placeholder: (_) => const SizedBox.expand(),
          errorBuilder: (_) =>
              const _ImagePlaceholder(icon: Icons.image_outlined),
        );
      },
      // `offNamed` : on remplace la fiche courante au lieu d'empiler des
      // écrans produit à l'infini au fil des rebonds.
      onTap: () => Get.offNamed(
        '/product',
        arguments: product,
        preventDuplicates: false,
      ),
    );
  }

  /// Première image exploitable d'un produit similaire.
  ///
  /// L'API renvoie soit `primary_image`, soit une liste d'images faite
  /// d'URL nues ou d'objets `{url: …}`.
  String? _similarProductImageUrl(Map<String, dynamic> product) {
    final primary = product['primary_image']?.toString();
    if (primary != null && primary.isNotEmpty) return primary;

    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      final url = first is Map ? first['url']?.toString() : first.toString();
      if (url != null && url.isNotEmpty) return url;
    }

    return null;
  }
}

/// Substitut affiché quand une image produit est absente ou illisible.
///
/// Il s'adapte à la taille qu'on lui donne : en vignette (60 px) seule
/// l'icône apparaît, en grand format le libellé s'y ajoute. L'ancienne
/// version imposait une icône de 64 px et un texte, ce qui débordait des
/// miniatures et affichait le bandeau d'overflow de Flutter.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final compact = side < 120;
        final iconSize = compact ? (side * 0.4).clamp(16.0, 40.0) : 56.0;

        return ColoredBox(
          color: context.ds.surfaceMuted,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: context.ds.textTertiary),
                if (!compact) ...[
                  SizedBox(height: AppDesign.space2),
                  Text(
                    'product.image_unavailable'.tr,
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: context.ds.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Action secondaire de la barre d'achat : contacter le vendeur.
///
/// Un bouton à contour orange épais rivalisait avec « Commander ». Réduit à
/// une icône encadrée de neutre, il reste atteignable sans se disputer
/// l'attention avec l'action principale.
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDesign.radiusSm),
          child: Container(
            width: 56,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.ds.surface,
              border: Border.all(color: context.ds.borderStrong),
              borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            ),
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.ds.textSecondary,
                      ),
                    ),
                  )
                : Icon(icon, size: 21, color: context.ds.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Action principale de la barre d'achat.
///
/// Porte le prix sous son libellé : c'est le montant qu'on engage en
/// appuyant, et le rappeler évite de remonter la page pour le vérifier.
class _OrderButton extends StatelessWidget {
  const _OrderButton({
    required this.label,
    required this.priceLabel,
    required this.onPressed,
  });

  /// « Commander », ou « Payer l'acompte » pour un produit sur commande.
  final String label;

  /// Évalué à la construction pour suivre la devise et la variante choisie.
  final String Function() priceLabel;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesign.accent,
      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: AppDesign.space3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shopping_cart_rounded,
                size: 19,
                color: Colors.white,
              ),
              SizedBox(width: AppDesign.space2),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    Obx(
                      () => Text(
                        priceLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.overline,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.2,
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
    );
  }
}
