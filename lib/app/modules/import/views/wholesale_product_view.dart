import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/free_delivery_widgets.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/widgets/product_image_viewer.dart';
import '../../../core/widgets/product_video_player.dart';
import '../../../core/widgets/product_variant_selector.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../../core/widgets/variant_combo_picker.dart';
import '../../../core/widgets/variant_quantity_list.dart';
import '../../../core/controllers/app_config_controller.dart';
import '../../../data/models/wholesale_models.dart';
import '../../../data/providers/import_service.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/conversation_service.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../payment/widgets/wallet_payment_confirm_dialog.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../wallet/views/payment_webview.dart';
import '../../../data/services/stripe_native_service.dart';
import '../../../data/providers/currency_service.dart';
import '../widgets/wholesale_delivery.dart';

/// Fiche produit GROS + tunnel de commande : palier (cota) → quantité →
/// expédition jusqu'à Douala → livraison depuis Douala (SOLEX) → moyen de
/// paiement (sélecteur unifié). Le client paie les deux trajets à la commande.
///
/// Une page plutôt qu'une feuille : photos, conditionnements, expédition et
/// récapitulatif s'entassaient dans une feuille qui couvrait déjà l'écran, les
/// photos y étaient réduites à un bandeau, et le clavier de la quantité
/// masquait le reste. La page donne toute sa hauteur à la galerie, range le
/// contenu en cartes, et garde le total et l'action au-dessus du clavier.
class WholesaleProductView extends StatefulWidget {
  final WholesaleProduct product;
  final List<ShippingOption> shippingOptions;
  final String countryFlag;

  const WholesaleProductView({
    super.key,
    required this.product,
    required this.shippingOptions,
    required this.countryFlag,
  });

  static Future<void>? open({
    required WholesaleProduct product,
    required List<ShippingOption> shippingOptions,
    required String countryFlag,
  }) {
    return Get.to<void>(
      () => WholesaleProductView(
        product: product,
        shippingOptions: shippingOptions,
        countryFlag: countryFlag,
      ),
    );
  }

  @override
  State<WholesaleProductView> createState() => _WholesaleProductViewState();
}

class _WholesaleProductViewState extends State<WholesaleProductView> {
  ShippingOption? _shipping;
  /// Quantité d'un produit sans options.
  int _singleQuantity = 0;

  /// Quantité par option (identifiant de variante → quantité) : un client
  /// peut prendre 300 rouges et 200 noires dans la même commande.
  Map<int, int> _variantQuantities = {};

  /// Combinaison en cours de saisie : c'est elle que touche un palier.
  int? _focusedVariantId;
  bool _submitting = false;
  bool _contactingSupport = false;
  int _imageIndex = 0;
  late final VariantCatalog _variantCatalog = VariantCatalog.fromApi(
    widget.product.variants,
    widget.product.variantOptions,
  );
  final PageController _galleryController = PageController();

  /// Livraison de l'entrepôt ASSO de Douala jusqu'au client, chiffrée au poids.
  late final WholesaleDelivery _delivery = WholesaleDelivery(
    items: () => _orderItems,
  )..addListener(_onDeliveryChanged);
  Timer? _requote;

  late final List<String> _images = [
    ...widget.product.images,
    if (widget.product.images.isEmpty &&
        widget.product.image?.isNotEmpty == true)
      widget.product.image!,
  ];

  /// Vidéo de présentation : première page de la galerie, avant les photos,
  /// pour prolonger ce que la carte montrait déjà.
  late final WholesaleVideo? _video = widget.product.video;

  /// Clé de la miniature vidéo dans le bandeau (les autres sont des URL).
  static const _videoThumbKey = '__video__';

  /// Décalage entre la page de la galerie et l'index de la photo.
  int get _mediaOffset => _video == null ? 0 : 1;
  int get _mediaCount => _mediaOffset + _images.length;
  bool get _onVideoPage => _video != null && _imageIndex == 0;

  @override
  void initState() {
    super.initState();
    _singleQuantity = widget.product.firstTier?.minQuantity ?? 1;
    if (widget.shippingOptions.isNotEmpty) {
      _shipping = widget.shippingOptions.first;
    }
  }

  @override
  void dispose() {
    _requote?.cancel();
    _delivery
      ..removeListener(_onDeliveryChanged)
      ..dispose();
    _galleryController.dispose();
    super.dispose();
  }

  void _onDeliveryChanged() {
    if (mounted) setState(() {});
  }

  /// Le prix de livraison dépend du poids : nouveau devis quand la quantité
  /// se stabilise.
  void _quantityChanged() {
    _requote?.cancel();
    _requote = Timer(
      const Duration(milliseconds: 600),
      _delivery.refreshIfItemsChanged,
    );
  }

  String _fmt(double valueInXaf) => Get.isRegistered<CurrencyService>()
      ? CurrencyService.to.formatPrice(valueInXaf)
      : '${valueInXaf.toStringAsFixed(0)} FCFA';

  String _fmtConverted(double amount, String currency) =>
      CurrencyService.formatAmountInCurrency(amount, currency);

  bool get _hasVariants => !_variantCatalog.isEmpty;

  /// Variantes commandées, avec leur quantité, dans l'ordre du catalogue.
  List<(Map<String, dynamic>, int)> get _variantLines => [
    for (final variant in _variantCatalog.variants)
      if ((_variantQuantities[VariantQuantityList.idOf(variant)] ?? 0) > 0)
        (variant, _variantQuantities[VariantQuantityList.idOf(variant)]!),
  ];

  /// Quantité totale : le palier se lit sur ce total, toutes options
  /// confondues, si le produit les cumule (le serveur applique la même règle).
  int get _quantity => _hasVariants
      ? VariantQuantityList.totalOf(_variantQuantities)
      : _singleQuantity;

  /// Rappel lisible pour le fournisseur : « Couleur: Rouge × 300 ; … ».
  String? _variantNote() {
    final lines = _variantLines;
    if (lines.isEmpty) return null;
    return 'Variantes : ${lines.map((line) => '${VariantCatalog.attributesOf(line.$1).entries.map((e) => '${e.key}: ${e.value}').join(', ')} × ${line.$2}').join(' ; ')}';
  }

  bool _requireVariant() {
    if (!_hasVariants || _variantQuantities.isNotEmpty) return true;
    Get.snackbar(
      'Faites votre choix',
      'Indiquez la quantité d’au moins une option.',
      snackPosition: SnackPosition.BOTTOM,
    );
    return false;
  }

  List<PriceTier> get _tiers => widget.product.sortedTiers;

  /// Le palier se lit sur le total du produit, sauf si l'équipe a choisi que
  /// chaque option atteigne son palier seule.
  bool get _mixVariants => !_hasVariants || widget.product.tierMixVariants;

  /// Lignes commandées : (variante, quantité), variante nulle sans options.
  List<(int?, int)> get _lines => _hasVariants
      ? [
          for (final (variant, quantity) in _variantLines)
            (VariantQuantityList.idOf(variant), quantity),
        ]
      : [if (_singleQuantity > 0) (null, _singleQuantity)];

  /// Palier appliqué à une ligne : celui que la quantité atteint (sous le
  /// premier seuil, le premier palier). Même règle que le serveur.
  PriceTier? _tierFor(int lineQuantity) =>
      PriceTier.forQuantity(_tiers, _mixVariants ? _quantity : lineQuantity);

  /// Palier mis en avant : celui du total, ou de l'option en cours de saisie.
  PriceTier? get _tier => _tierFor(
    _mixVariants ? _quantity : (_variantQuantities[_focusedVariantId] ?? 0),
  );

  /// Pas de minimum de commande : sous le premier seuil, le client paie le
  /// prix du premier palier. Il faut seulement une quantité.
  bool get _quantityTooLow => _lines.isEmpty;

  double get _subtotal => _lines.fold(
    0,
    (sum, line) => sum + (_tierFor(line.$2)?.unitPriceXaf ?? 0) * line.$2,
  );

  /// Lignes envoyées au serveur (commande et devis de livraison).
  List<Map<String, int>> get _orderItems => [
    for (final (variantId, quantity) in _lines)
      {
        'product_id': widget.product.id,
        'quantity': quantity,
        'price_tier_id': ?_tierFor(quantity)?.id,
        'variant_id': ?variantId,
      },
  ];

  double get _shippingCost {
    final s = _shipping;
    if (s == null) return 0;
    switch (s.rateType) {
      case 'per_kg':
        return s.rateAmountXaf * _shippingWeightKg;
      case 'per_cbm':
        return 0; // le volume doit être configuré/calculé par l'équipe côté serveur
      default:
        return s.rateAmountXaf; // flat
    }
  }

  double get _total => _subtotal + _shippingCost + _delivery.buyerPrice;

  /// Ville d'arrivée de l'import, d'où part la livraison locale.
  String get _hubCity => _shipping?.destination ?? 'Douala';

  bool get _needsWeight => _shipping?.rateType == 'per_kg';
  bool get _needsCbm => _shipping?.rateType == 'per_cbm';
  /// Poids d'une unité commandée : celui du palier (un pack, un bidon…),
  /// sinon celui de la fiche.
  double get _shippingWeightKg => _lines.fold(
    0,
    (sum, line) =>
        sum +
        (_tierFor(line.$2)?.weightKg ?? widget.product.unitWeightKg ?? 0) *
            line.$2,
  );

  /// Toucher un palier y amène la quantité : 100 pour « à partir de 100 ».
  /// Avec options cumulées, c'est l'option en cours de saisie qui comble
  /// l'écart ; sinon elle prend la quantité du palier.
  void _selectTier(PriceTier tier) {
    if (!_hasVariants) {
      setState(() => _singleQuantity = tier.minQuantity);
      _quantityChanged();
      return;
    }
    final id = _focusedVariantId ?? _lines.lastOrNull?.$1;
    if (id == null) {
      Get.snackbar(
        'Choisissez une option',
        'Sélectionnez d’abord une couleur ou une taille, puis le palier.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final current = _variantQuantities[id] ?? 0;
    final next = _mixVariants
        ? tier.minQuantity - (_quantity - current)
        : tier.minQuantity;
    if (next < 1) {
      Get.snackbar(
        'Quantités déjà supérieures',
        'Vos autres options font déjà ${_quantity - current} au total : réduisez-les pour revenir à « ${tier.label} ».',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    setState(() => _variantQuantities = {..._variantQuantities, id: next});
    _quantityChanged();
  }

  // ─────────────────────────── Page ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      backgroundColor: context.ds.canvas,
      // La barre d'action vit dans le corps, et non dans `bottomNavigationBar` :
      // elle remonte ainsi avec le clavier, et le total reste lisible pendant
      // qu'on tape la quantité.
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                _buildGalleryAppBar(context),
                SliverToBoxAdapter(
                  child: AppContentWidth(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.ds.gutter,
                        AppDesign.space3,
                        context.ds.gutter,
                        AppDesign.space6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_mediaCount > 1) ...[
                            ProductThumbnailStrip(
                              images: [
                                if (_video != null) _videoThumbKey,
                                ..._images,
                              ],
                              currentIndex: _imageIndex,
                              onSelected: _goToImage,
                              imageBuilder: _thumbnail,
                            ),
                            const SizedBox(height: AppDesign.space3),
                          ],
                          _buildHeaderCard(context, p),
                          // Les paliers viennent d'abord : ils disent quel prix
                          // chaque quantité obtient.
                          if (p.priceTiers.isNotEmpty) ...[
                            const SizedBox(height: AppDesign.space3),
                            _section(
                              context,
                              title: 'Prix selon la quantité',
                              subtitle: _mixVariants
                                  ? 'Le prix suit la quantité totale. Touchez un palier pour l’appliquer.'
                                  : 'Chaque option a le prix de sa propre quantité. Touchez un palier pour l’appliquer à l’option choisie.',
                              child: Column(
                                children: _tiers.map(_tierTile).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppDesign.space3),
                          _hasVariants
                              ? _section(
                                  context,
                                  title: 'Options et quantités',
                                  subtitle:
                                      'Choisissez une combinaison, saisissez sa quantité, puis passez à la suivante.',
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // En gros, le stock saisi sur une
                                      // variante n'a pas de sens : toutes les
                                      // options restent commandables.
                                      VariantComboPicker(
                                        catalog: _variantCatalog,
                                        quantities: _variantQuantities,
                                        limitToStock: false,
                                        priceOf: (variant) {
                                          final id = VariantQuantityList.idOf(
                                            variant,
                                          );
                                          final tier = _tierFor(
                                            _variantQuantities[id] ?? 0,
                                          );
                                          return tier == null
                                              ? ''
                                              : '${_fmtConverted(tier.unitPrice, tier.currency)} / unité';
                                        },
                                        onFocusChanged: (id) =>
                                            _focusedVariantId = id,
                                        onChanged: (next) {
                                          setState(
                                            () => _variantQuantities = next,
                                          );
                                          _quantityChanged();
                                        },
                                      ),
                                      const SizedBox(height: AppDesign.space3),
                                      _buildQuantityHint(context),
                                    ],
                                  ),
                                )
                              : _section(
                                  context,
                                  title: 'Quantité souhaitée',
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      QuantityStepper(
                                        value: _singleQuantity,
                                        min: 1,
                                        hasError: _quantityTooLow,
                                        onChanged: (value) {
                                          setState(
                                            () => _singleQuantity = value,
                                          );
                                          _quantityChanged();
                                        },
                                      ),
                                      const SizedBox(height: AppDesign.space2),
                                      _buildQuantityHint(context),
                                    ],
                                  ),
                                ),
                          if (widget.shippingOptions.isNotEmpty) ...[
                            const SizedBox(height: AppDesign.space3),
                            _section(
                              context,
                              title: 'Expédition jusqu’à $_hubCity',
                              subtitle:
                                  'Quelle que soit la provenance, la commande arrive à l’entrepôt ASSO de $_hubCity.',
                              child: Column(
                                children: [
                                  ...widget.shippingOptions.map(_shippingTile),
                                  if (_needsWeight || _needsCbm)
                                    _shippingMeasureInfo(context),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppDesign.space3),
                          _section(
                            context,
                            title: 'Livraison depuis $_hubCity',
                            subtitle:
                                'De l’entrepôt ASSO jusqu’à votre adresse, au prix calculé selon votre adresse et le poids du colis.',
                            child: WholesaleDeliverySection(
                              delivery: _delivery,
                              formatPrice: _fmt,
                            ),
                          ),
                          ..._buildDetailSections(context, p),
                          const SizedBox(height: AppDesign.space3),
                          _section(
                            context,
                            title: 'Récapitulatif',
                            child: _summary(context),
                          ),
                          const SizedBox(height: AppDesign.space4),
                          // Contacter le support ASSO à propos de cette
                          // commande en gros.
                          AppButton(
                            label: _contactingSupport
                                ? 'Ouverture…'
                                : 'Poser une question au support',
                            icon: Icons.chat_bubble_outline_rounded,
                            variant: AppButtonVariant.secondary,
                            isLoading: _contactingSupport,
                            onPressed: _contactSupport,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildActionBar(context),
        ],
      ),
    );
  }

  // ─────────────────────────── Galerie ───────────────────────────

  /// En-tête photo : les images occupent toute la largeur et une grande part
  /// de l'écran, puis cèdent la place au titre en défilant.
  Widget _buildGalleryAppBar(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * 0.45).clamp(
      280.0,
      480.0,
    );

    return SliverAppBar(
      pinned: true,
      expandedHeight: _mediaCount == 0 ? null : height,
      backgroundColor: context.ds.surface,
      surfaceTintColor: Colors.transparent,
      // Pastille sombre : la flèche reste lisible sur une photo claire.
      leading: Padding(
        padding: const EdgeInsets.all(AppDesign.space1),
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: AppBackButton(
            color: Colors.white,
            onPressed: () => AppNavigation.back(context),
          ),
        ),
      ),
      flexibleSpace: _mediaCount == 0
          ? null
          : FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _galleryController,
                    itemCount: _mediaCount,
                    onPageChanged: (index) =>
                        setState(() => _imageIndex = index),
                    itemBuilder: (_, index) {
                      final video = _video;
                      if (video != null && index == 0) {
                        return ProductGalleryVideo(
                          url: resolveMediaUrl(video.url),
                          poster: _image(_videoPoster(video), BoxFit.cover),
                          active: _imageIndex == 0,
                        );
                      }
                      final photo = index - _mediaOffset;
                      return GestureDetector(
                        onTap: () => _openViewer(context, photo),
                        child: _image(_images[photo], BoxFit.cover),
                      );
                    },
                  ),
                  // Compteur et invitation à agrandir. Sur la vidéo, il
                  // annonce les photos qui suivent et y mène.
                  Positioned(
                    right: AppDesign.space4,
                    bottom: AppDesign.space4,
                    child: GestureDetector(
                      onTap: _onVideoPage
                          ? (_images.isEmpty
                                ? null
                                : () => _goToImage(_mediaOffset))
                          : () => _openViewer(
                              context,
                              _imageIndex - _mediaOffset,
                            ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.space3,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusPill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _onVideoPage
                                  ? Icons.photo_library_outlined
                                  : Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            if (_onVideoPage && _images.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                _images.length == 1
                                    ? '1 photo'
                                    : '${_images.length} photos',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (!_onVideoPage && _images.length > 1) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${_imageIndex - _mediaOffset + 1}/${_images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Drapeau d'origine, comme sur la tuile du catalogue.
                  Positioned(
                    left: AppDesign.space4,
                    bottom: AppDesign.space4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDesign.space2,
                        vertical: AppDesign.space1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(
                          AppDesign.radiusPill,
                        ),
                      ),
                      child: Text(
                        widget.countryFlag,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _goToImage(int index) {
    setState(() => _imageIndex = index);
    if (_galleryController.hasClients) {
      _galleryController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// Visionneuse plein écran des photos ; [photoIndex] ne compte pas la vidéo.
  Future<void> _openViewer(BuildContext context, int photoIndex) async {
    final lastPhoto = await ProductImageViewer.open(
      context,
      images: _images,
      initialIndex: photoIndex,
      imageBuilder: _image,
    );
    if (!mounted || lastPhoto == null) return;
    final page = lastPhoto + _mediaOffset;
    if (page == _imageIndex) return;
    setState(() => _imageIndex = page);
    if (_galleryController.hasClients) _galleryController.jumpToPage(page);
  }

  /// Affiche de la vidéo, sinon la première photo du produit.
  String _videoPoster(WholesaleVideo video) =>
      video.posterUrl ??
      (_images.isNotEmpty ? _images.first : widget.product.image ?? '');

  /// Miniature du bandeau : la vidéo se distingue par un symbole lecture.
  Widget _thumbnail(String value, BoxFit fit) {
    final video = _video;
    if (value != _videoThumbKey || video == null) return _image(value, fit);
    return Stack(
      fit: StackFit.expand,
      children: [
        _image(_videoPoster(video), fit),
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

  Widget _imagePlaceholder() => Container(
    color: context.ds.surfaceMuted,
    alignment: Alignment.center,
    child: Icon(Icons.inventory_2_outlined, color: context.ds.textTertiary),
  );

  /// Image du produit à la taille de son conteneur.
  Widget _image(String value, BoxFit fit) {
    final url = _resolveImageUrl(value);
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _imagePlaceholder(),
      );
    }
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _imagePlaceholder(),
      errorBuilder: (_, _, _) => _imagePlaceholder(),
    );
  }

  /// Aligne l'URL d'une image sur l'hôte réel de l'API : le serveur renvoie
  /// parfois `localhost` ou un chemin `/storage/storage/` doublé.
  String _resolveImageUrl(String value) => resolveMediaUrl(value);

  // ─────────────────────────── Sections ───────────────────────────

  /// Carte d'en-tête : nature de la commande, nom, puis prix d'entrée — le
  /// prix est ce qu'on cherche des yeux juste après la photo.
  Widget _buildHeaderCard(BuildContext context, WholesaleProduct p) {
    final entry = p.entryTier;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppDesign.space2,
            runSpacing: AppDesign.space2,
            children: [
              const AppBadge(
                label: 'Commande en gros',
                tone: AppBadgeTone.accent,
                icon: Icons.inventory_2_outlined,
              ),
              if (p.freeDelivery) const FreeDeliveryBadge(),
            ],
          ),
          const SizedBox(height: AppDesign.space3),
          Text(
            p.name,
            style: context.textStyle(
              FontSizeType.h5,
              fontWeight: FontWeight.w700,
              color: context.ds.textPrimary,
            ),
          ),
          if (entry != null) ...[
            const SizedBox(height: AppDesign.space2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'À partir de ',
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: context.ds.textSecondary,
                    ),
                  ),
                  TextSpan(
                    text: _fmtConverted(entry.unitPrice, entry.currency),
                    style: context.textStyle(
                      FontSizeType.h5,
                      fontWeight: FontWeight.w800,
                      color: AppDesign.accent,
                    ),
                  ),
                  TextSpan(
                    text: ' / unité',
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: context.ds.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (p.priceTiers.length > 1) ...[
              const SizedBox(height: AppDesign.space1),
              Text(
                'Prix dégressif selon la quantité',
                style: context.textStyle(
                  FontSizeType.caption,
                  color: context.ds.textSecondary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Carte titrée : chaque étape de la commande a la sienne, ce qui donne
  /// des repères nets au lieu d'un long ruban de texte.
  Widget _section(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: context.textStyle(
              FontSizeType.subtitle1,
              fontWeight: FontWeight.w700,
              color: context.ds.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: context.textStyle(
                FontSizeType.caption,
                color: context.ds.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppDesign.space3),
          child,
        ],
      ),
    );
  }

  /// Description, caractéristiques et informations commerciales : chacune sa
  /// carte, et seulement si le fournisseur l'a renseignée.
  List<Widget> _buildDetailSections(BuildContext context, WholesaleProduct p) {
    final blocks = <(String, String?)>[
      ('Description', p.description),
      ('Caractéristiques', p.characteristics),
      ('Informations commerciales', p.commercialInformation),
    ];

    return [
      for (final (title, text) in blocks)
        if (text != null && text.trim().isNotEmpty) ...[
          const SizedBox(height: AppDesign.space3),
          _section(
            context,
            title: title,
            child: Text(
              text.trim(),
              style: context.textStyle(
                FontSizeType.body2,
                color: context.ds.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
    ];
  }

  Widget _tierTile(PriceTier t) {
    final selected = _tier?.id == t.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space2),
      child: Material(
        color: selected ? AppDesign.accentSubtle : context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        child: InkWell(
          onTap: () => _selectTier(t),
          borderRadius: BorderRadius.circular(AppDesign.radiusSm),
          child: Container(
            padding: const EdgeInsets.all(AppDesign.space3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              border: Border.all(
                color: selected ? AppDesign.accent : context.ds.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppDesign.accent : context.ds.icon,
                  size: 20,
                ),
                const SizedBox(width: AppDesign.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.body2,
                          fontWeight: FontWeight.w600,
                          color: context.ds.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.id == _tiers.first.id
                            ? (_tiers.length > 1
                                  ? 'Jusqu’à ${_tiers[1].minQuantity - 1}'
                                  : 'Toute quantité')
                            : 'À partir de ${t.minQuantity}',
                        style: context.textStyle(
                          FontSizeType.caption,
                          color: context.ds.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDesign.space2),
                Text(
                  _fmtConverted(t.unitPrice, t.currency),
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w800,
                    color: AppDesign.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Total, prix du palier atteint et quantité manquante pour le suivant.
  /// Avec options cumulées, il porte sur le total de toutes les options.
  Widget _buildQuantityHint(BuildContext context) {
    final tooLow = _quantityTooLow;
    final String text;
    if (tooLow) {
      text = _hasVariants
          ? 'Choisissez une option et indiquez sa quantité'
          : 'Indiquez une quantité';
    } else if (!_mixVariants) {
      text = 'Total : $_quantity unités · chaque option a le prix de sa quantité';
    } else {
      final tier = _tier;
      final price = tier == null
          ? ''
          : ' à ${_fmtConverted(tier.unitPrice, tier.currency)} / unité';
      // Palier suivant : combien il manque pour le prix plus bas.
      final next = _tiers
          .where((t) => t.minQuantity > _quantity)
          .firstOrNull;
      final nudge = next == null
          ? ''
          : ' · encore ${next.minQuantity - _quantity} pour ${_fmtConverted(next.unitPrice, next.currency)} / unité';
      text = 'Total : $_quantity$price$nudge';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          tooLow ? Icons.error_outline_rounded : Icons.info_outline_rounded,
          size: 14,
          color: tooLow ? AppDesign.danger : context.ds.textTertiary,
        ),
        const SizedBox(width: AppDesign.space1),
        Expanded(
          child: Text(
            text,
            style: context.textStyle(
              FontSizeType.caption,
              fontWeight: _hasVariants && !tooLow ? FontWeight.w600 : null,
              color: tooLow
                  ? AppDesign.dangerText
                  : (_hasVariants
                        ? context.ds.textPrimary
                        : context.ds.textTertiary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _shippingTile(ShippingOption s) {
    final selected = _shipping?.id == s.id;
    final rate =
        '${_fmtConverted(s.rateAmount, s.currency)}${s.rateType == 'per_kg'
            ? ' / kg'
            : s.rateType == 'per_cbm'
            ? ' / CBM'
            : ''}';
    final details = [
      rate,
      if (s.leadTimeDays != null) '≈ ${s.leadTimeDays} jours',
      if (s.expeditionNote != null && s.expeditionNote!.isNotEmpty)
        s.expeditionNote!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space2),
      child: Material(
        color: selected ? AppDesign.accentSubtle : context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        child: InkWell(
          onTap: () => setState(() => _shipping = s),
          borderRadius: BorderRadius.circular(AppDesign.radiusSm),
          child: Container(
            padding: const EdgeInsets.all(AppDesign.space3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              border: Border.all(
                color: selected ? AppDesign.accent : context.ds.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _shipIcon(s.mode),
                  color: selected ? AppDesign.accent : context.ds.icon,
                ),
                const SizedBox(width: AppDesign.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.modeLabel,
                        style: context.textStyle(
                          FontSizeType.body2,
                          fontWeight: FontWeight.w600,
                          color: context.ds.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.caption,
                          color: context.ds.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppDesign.accent,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _shipIcon(String mode) {
    switch (mode) {
      case 'air':
        return Icons.flight_takeoff_rounded;
      case 'sea':
        return Icons.directions_boat_filled_rounded;
      default:
        return Icons.local_shipping_rounded;
    }
  }

  Widget _shippingMeasureInfo(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppDesign.space3),
    decoration: BoxDecoration(
      color: AppDesign.infoSubtle,
      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
    ),
    child: Row(
      children: [
        Icon(
          _needsWeight ? Icons.scale_rounded : Icons.view_in_ar_rounded,
          color: AppDesign.info,
          size: 20,
        ),
        const SizedBox(width: AppDesign.space3),
        Expanded(
          child: Text(
            _needsWeight && _shippingWeightKg > 0
                ? 'Poids calculé par ASSO : ${_shippingWeightKg.toStringAsFixed(2)} kg'
                : 'Le poids/volume d\'expédition est renseigné par ASSO.',
            style: context.textStyle(
              FontSizeType.caption,
              color: AppDesign.infoText,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _summary(BuildContext context) {
    return Column(
      children: [
        _sumRow(
          context,
          _mixVariants
              ? 'Produit ($_quantity × ${_tier?.label ?? ''})'
              : 'Produit ($_quantity unités)',
          _fmt(_subtotal),
        ),
        const SizedBox(height: AppDesign.space2),
        _sumRow(
          context,
          'Expédition jusqu’à $_hubCity (${_shipping?.modeLabel ?? '—'})',
          _fmt(_shippingCost),
        ),
        const SizedBox(height: AppDesign.space2),
        _sumRow(
          context,
          _delivery.selected == null
              ? 'Livraison depuis $_hubCity'
              : 'Livraison ${_delivery.selected!.companyName} jusqu’à vous',
          _delivery.selected == null ? '—' : _fmt(_delivery.price),
          struck: _delivery.isFree,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppDesign.space3),
          child: AppDivider(),
        ),
        _sumRow(context, 'Total', _fmt(_total), bold: true),
      ],
    );
  }

  Widget _sumRow(
    BuildContext c,
    String l,
    String v, {
    bool bold = false,
    bool struck = false,
  }) =>
      Row(
        children: [
          Expanded(
            child: Text(
              l,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: c.textStyle(
                bold ? FontSizeType.body1 : FontSizeType.body2,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                color: bold ? c.ds.textPrimary : c.ds.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.space2),
          // Course offerte par le vendeur : prix barré, suivi de « Offerte ».
          DeliveryPriceText(
            price: v,
            isFree: struck,
            style: c.textStyle(
              bold ? FontSizeType.body1 : FontSizeType.body2,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? AppDesign.accent : c.ds.textPrimary,
            ),
          ),
        ],
      );

  /// Barre d'action : le total, mis à jour à chaque chiffre saisi, et la
  /// commande. Elle suit le clavier (voir [build]).
  Widget _buildActionBar(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.ds.surface,
        border: Border(top: BorderSide(color: context.ds.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.ds.gutter,
            AppDesign.space3,
            context.ds.gutter,
            AppDesign.space3,
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: context.ds.textSecondary,
                    ),
                  ),
                  Text(
                    _fmt(_total),
                    style: context.textStyle(
                      FontSizeType.h6,
                      fontWeight: FontWeight.w800,
                      color: context.ds.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppDesign.space4),
              Expanded(
                child: AppButton(
                  label: 'Commander',
                  icon: Icons.lock_rounded,
                  size: AppButtonSize.large,
                  isLoading: _submitting,
                  onPressed: _pay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Paiement ───────────────────────────
  Future<void> _pay() async {
    AppNavigation.dismissKeyboard();
    // En mode invité, ne pas ouvrir un sélecteur vide ("aucun moyen disponible") :
    // exiger la connexion d'abord.
    if (!AuthGuard.checkAuthWithAlert(context, featureName: 'le paiement')) {
      return;
    }
    if (!_requireVariant()) return;
    final tier = _tier, shipping = _shipping;
    if (tier == null || shipping == null || _lines.isEmpty) {
      Get.snackbar(
        'Erreur',
        'Choisissez un conditionnement et une expédition.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_needsWeight && _shippingWeightKg <= 0) {
      Get.snackbar(
        'Poids indisponible',
        'ASSO doit encore renseigner le poids de ce colis avant le paiement.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_needsCbm) {
      Get.snackbar(
        'Volume indisponible',
        'ASSO doit encore valider le volume de ce colis avant le paiement.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final deliveryMissing = _delivery.missingStep;
    if (deliveryMissing != null) {
      Get.snackbar(
        'Livraison depuis $_hubCity',
        deliveryMissing,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final currency = Get.isRegistered<CurrencyService>()
        ? CurrencyService.to
        : null;
    final displayAmount = currency?.convertFromXOF(_total) ?? _total;
    final displayCurrency = currency?.currencyCode ?? 'XAF';
    final method = await PaymentMethodSelector.show(
      amount: displayAmount,
      currency: displayCurrency,
      amountLabel: 'Total à payer',
      allowedCodes: const {'kpay', 'stripe'},
      includeWallet: true,
    );
    if (method == null) return;

    // Une ligne par option commandée, au palier que sa quantité atteint.
    final items = _orderItems;
    final weight = _needsWeight ? _shippingWeightKg : null;
    final cbm = null;

    if (method.code == 'wallet') {
      final confirmed = await WalletPaymentConfirmDialog.show(
        itemLabel: 'Commande en gros — ${widget.product.name}',
        amount: _total,
        balance: method.balance ?? 0,
      );
      if (!confirmed) return;
      await _create('wallet', items, shipping.id, weight, cbm);
    } else if (method.code == 'kpay') {
      final sel = await KpayDirectPaymentSheet.show(
        amount: _total,
        amountLabel: 'Total à payer',
      );
      if (sel == null) return;
      await _create(
        'kpay_direct',
        items,
        shipping.id,
        weight,
        cbm,
        provider: sel['provider'],
        phone: sel['phone'],
      );
    } else if (method.code == 'stripe') {
      await _createCard(items, shipping.id, weight, cbm);
    } else {
      Get.snackbar(
        'Indisponible',
        "Ce moyen n'est pas disponible pour les commandes en gros.",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _create(
    String mode,
    List<Map<String, dynamic>> items,
    int shippingId,
    double? weight,
    double? cbm, {
    String? provider,
    String? phone,
  }) async {
    setState(() => _submitting = true);
    try {
      final res = await ImportService.createOrder(
        items: items,
        shippingOptionId: shippingId,
        shippingWeightKg: weight,
        shippingCbm: cbm,
        paymentMode: mode,
        provider: provider,
        phoneNumber: phone,
        delivery: _delivery.orderFields(),
        notes: _variantNote(),
      );
      if (!res.success) {
        Get.snackbar(
          'Erreur',
          res.message.isNotEmpty ? res.message : 'Échec de la commande',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final orderId = res.data?['order_id'] as int?;
      final approvalUrl = res.data?['approval_url']?.toString();
      // `AppNavigation.pop` : `Get.back()` fermerait d'abord un snackbar
      // encore affiché et laisserait la fiche ouverte.
      AppNavigation.pop(); // fermer la fiche : la commande est passée

      if (mode == 'wallet') {
        Get.snackbar(
          'Commande payée',
          'Payée avec votre Wallet ASSO. En cas de refus, le montant vous est rendu immédiatement.',
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      if (mode == 'kpay_direct') {
        _pollOrder(orderId);
        Get.snackbar(
          'Commande créée',
          'Validez le paiement sur votre téléphone (USSD).',
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // paypal/stripe : ouvrir le checkout (WebView mobile, navigateur sinon), puis polling.
      if (approvalUrl == null || approvalUrl.isEmpty) {
        Get.snackbar(
          'Erreur',
          'Lien de paiement indisponible.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      if (GetPlatform.isAndroid || GetPlatform.isIOS) {
        await Get.to(
          () => PaymentWebView(
            paymentUrl: approvalUrl,
            paymentMethod: mode == 'paypal_direct' ? 'paypal' : 'stripe',
            paymentId: orderId ?? 0,
          ),
        );
      } else {
        await launchUrl(
          Uri.parse(approvalUrl),
          mode: LaunchMode.externalApplication,
        );
      }
      _pollOrder(orderId);
      Get.snackbar(
        'Paiement en cours',
        'La confirmation est automatique. Vous serez notifié.',
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Commande en gros payée par CARTE (Payment Sheet Stripe native).
  Future<void> _createCard(
    List<Map<String, dynamic>> items,
    int shippingId,
    double? weight,
    double? cbm,
  ) async {
    if (!StripeNativeService.isSupported) {
      Get.snackbar(
        'Indisponible',
        "Le paiement par carte est disponible sur l'application mobile.",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ImportService.createOrder(
        items: items,
        shippingOptionId: shippingId,
        shippingWeightKg: weight,
        shippingCbm: cbm,
        paymentMode: 'stripe_direct',
        delivery: _delivery.orderFields(),
        notes: _variantNote(),
      );
      if (!res.success) {
        Get.snackbar(
          'Erreur',
          res.message.isNotEmpty ? res.message : 'Échec de la commande',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final orderId = res.data?['order_id'] as int?;
      final clientSecret = res.data?['client_secret']?.toString();
      final publishableKey = res.data?['publishable_key']?.toString();
      if (orderId == null ||
          clientSecret == null ||
          clientSecret.isEmpty ||
          publishableKey == null ||
          publishableKey.isEmpty) {
        Get.snackbar(
          'Erreur',
          'Données de paiement carte indisponibles.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final ok = await StripeNativeService().payWithCard(
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );
      if (!ok) {
        Get.snackbar(
          'Paiement annulé',
          "Le paiement n'a pas été finalisé. Votre commande reste en attente.",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // `AppNavigation.pop` : `Get.back()` fermerait d'abord un snackbar
      // encore affiché et laisserait la fiche ouverte.
      AppNavigation.pop(); // fermer la fiche : la commande est passée
      _pollOrder(orderId);
      Get.snackbar(
        'Paiement en cours',
        'La confirmation est automatique. Vous serez notifié.',
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _pollOrder(int? orderId) async {
    if (orderId == null) return;
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        final res = await OrderService.orderPaymentStatus(orderId);
        final status = res.data?['data']?['payment_status'];
        if (status == 'paid') {
          Get.snackbar(
            'Paiement confirmé',
            'Votre commande en gros est payée. En attente de validation du vendeur.',
            backgroundColor: AppDesign.success,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        } else if (status == 'failed') {
          Get.snackbar(
            'Paiement échoué',
            "Le paiement n'a pas abouti.",
            backgroundColor: AppDesign.danger,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      } catch (_) {}
    }
  }

  // ─────────────────────────── Support ───────────────────────────
  /// Démarre une conversation avec le compte support ASSO et ouvre le chat avec
  /// un message pré-rempli (nom du produit + quantité).
  Future<void> _contactSupport() async {
    // Fonctionnalité réservée aux utilisateurs connectés (messagerie).
    if (!AuthGuard.checkAuthWithAlert(context, featureName: 'la messagerie')) {
      return;
    }

    setState(() => _contactingSupport = true);
    try {
      // 1) Identifiant du compte support (cache app sinon /v1/app/support).
      final appConfig = Get.isRegistered<AppConfigController>()
          ? Get.find<AppConfigController>()
          : Get.put(AppConfigController(), permanent: true);
      final supportUserId = await appConfig.ensureSupportUserId();

      if (supportUserId == null) {
        Get.snackbar(
          'Support indisponible',
          "Le service d'assistance n'est pas disponible pour le moment. Réessayez plus tard.",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // 2) Créer ou récupérer la conversation (sans productId : modèle wholesale).
      final response = await ConversationService.startConversation(
        userId: supportUserId,
      );
      if (!response.success || response.data == null) {
        Get.snackbar(
          'Erreur',
          'Impossible de démarrer la conversation avec le support.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final conversationData = response.data!['conversation'];
      final conversationId = conversationData?['id'];
      if (conversationId == null) {
        Get.snackbar(
          'Erreur',
          'Conversation indisponible.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final supportName = appConfig.supportName;

      // 3) Ouvrir le chat avec un message pré-rempli (nom produit + quantité).
      // La fiche reste dessous : au retour du chat, on retrouve le produit et
      // la quantité saisie au lieu de devoir tout reprendre.
      Get.toNamed(
        '/chatdetail',
        arguments: {
          'id': conversationId.toString(),
          'name': supportName,
          'avatar': StringUtils.getInitials(supportName),
          'isOnline': false,
          'default_message':
              '${widget.product.name} - quantité: $_quantity${_variantNote() == null ? '' : ' (${_variantNote()})'}',
          'is_support': true,
        },
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _contactingSupport = false);
    }
  }
}
