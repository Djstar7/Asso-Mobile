import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/delivery_details_widgets.dart';
import '../../../core/widgets/deposit_widgets.dart';
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
import '../../payment/widgets/mobile_money_waiting.dart';
import '../../payment/widgets/wallet_payment_confirm_dialog.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../wallet/views/payment_webview.dart';
import '../../../data/services/stripe_native_service.dart';
import '../../../data/providers/currency_service.dart';
import '../widgets/wholesale_delivery.dart';

/// Fiche produit GROS + tunnel de commande. La page ne montre que le
/// produit : galerie, prix, options et descriptions. « Commander » ouvre une
/// feuille, comme sur la fiche détail, où l'acheteur règle dans l'ordre :
/// combinaison → prix selon la quantité (paliers) → expédition jusqu'à Douala
/// → adresse, précision, contact et partenaire de livraison (SOLEX) →
/// récapitulatif, puis le moyen de paiement (sélecteur unifié). Le client paie
/// les deux trajets à la commande.
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

  /// Prévient la feuille de commande d'un changement fait sur la page :
  /// ouverte par-dessus, elle ne se redessine pas avec `setState`.
  final ValueNotifier<int> _orderRevision = ValueNotifier(0);

  /// `setState` qui redessine aussi la feuille de commande.
  void _update(VoidCallback change) {
    setState(change);
    _orderRevision.value++;
  }

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
    _orderRevision.dispose();
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

  /// Minimum de commande : le seuil du premier palier.
  int get _minQuantity => _tiers.firstOrNull?.minQuantity ?? 1;

  /// Le minimum porte sur le total du produit si les options se cumulent,
  /// sinon chaque option doit l'atteindre seule. Même règle que le serveur.
  bool get _belowMinimum => _mixVariants
      ? _quantity < _minQuantity
      : _lines.any((line) => line.$2 < _minQuantity);

  bool get _quantityTooLow => _lines.isEmpty || _belowMinimum;

  /// Rappel du minimum non atteint.
  String get _minimumMessage => !_hasVariants
      ? 'import.wholesale.hint.minimum'.trParams({'minimum': '$_minQuantity'})
      : _mixVariants
      ? 'import.wholesale.hint.minimum_total'.trParams({
          'quantity': '$_quantity',
          'minimum': '$_minQuantity',
        })
      : 'import.wholesale.hint.minimum_per_option'.trParams({
          'minimum': '$_minQuantity',
        });

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

  bool get _hasDeposit => widget.product.hasDeposit;

  /// Acompte (même calcul que le serveur) : part de chaque ligne au prix du
  /// palier + expédition jusqu'à Douala + course SOLEX, plafonné au total.
  double get _deposit {
    final rate = widget.product.depositRate;
    final lines = _lines.fold<double>(
      0,
      (sum, line) =>
          sum +
          DepositProduct.depositFor(
            (_tierFor(line.$2)?.unitPriceXaf ?? 0) * line.$2,
            rate,
          ),
    );
    final deposit = lines + _shippingCost + _delivery.buyerPrice;
    return deposit < _total ? deposit : _total;
  }

  /// Montant payé à la commande : l'acompte, ou le total.
  double get _amountDue => _hasDeposit ? _deposit : _total;

  String get _amountDueLabel => _hasDeposit
      ? 'core.deposit.deposit_now'.tr
      : 'import.wholesale.amount_to_pay'.tr;

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
      _update(() => _singleQuantity = tier.minQuantity);
      _quantityChanged();
      return;
    }
    final id = _focusedVariantId ?? _lines.lastOrNull?.$1;
    if (id == null) {
      // Un palier s'applique à une combinaison : il en faut une d'abord.
      Get.snackbar(
        'import.wholesale.choose_title'.tr,
        'import.wholesale.choose_message'.tr,
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
        'import.wholesale.quantities_exceeded_title'.tr,
        'import.wholesale.quantities_exceeded_message'.trParams({
          'count': '${_quantity - current}',
          'tier': tier.label,
        }),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    _update(() => _variantQuantities = {..._variantQuantities, id: next});
    _quantityChanged();
  }

  /// Première étape qui bloque la commande ; null quand tout est prêt.
  String? get _missingStep {
    if (_lines.isEmpty) {
      return _hasVariants
          ? 'import.wholesale.choose_message'.tr
          : 'import.wholesale.hint.enter_quantity'.tr;
    }
    if (_belowMinimum) return _minimumMessage;
    if (_tier == null || _shipping == null) {
      return 'import.wholesale.choose_tier_and_shipping'.tr;
    }
    if (_needsWeight && _shippingWeightKg <= 0) {
      return 'import.wholesale.weight_unavailable_message'.tr;
    }
    if (_needsCbm) return 'import.wholesale.volume_unavailable_message'.tr;
    return _delivery.missingStep;
  }

  /// Feuille de commande, comme celle de la fiche détail : la page ne montre
  /// que le produit, tout se règle ici dans l'ordre — combinaison, prix selon
  /// la quantité, expédition, adresse et contact, partenaire. Le
  /// récapitulatif s'ouvre ensuite par-dessus ([_openSummarySheet]) ; elle
  /// rend `true` quand l'acheteur l'a confirmé.
  Future<bool?> _openOrderSheet() {
    return AppSheet.show<bool>(
      ListenableBuilder(
        listenable: Listenable.merge([_delivery, _orderRevision]),
        builder: (context, _) {
          final missing = _missingStep;
          return AppSheet(
            title: 'import.wholesale.order_sheet.title'.tr,
            subtitle: widget.product.name,
            // Les étapes sont des cartes : elles se détachent mieux sur le
            // fond d'écran que sur une surface blanche.
            color: context.ds.canvas,
            // Épinglé au-dessus du clavier, avec l'étape qui le bloque.
            footer: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (missing != null)
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
                            missing,
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
                AppButton(
                  label: 'import.wholesale.order_sheet.review'.trParams({
                    'total': _fmt(_amountDue),
                  }),
                  icon: Icons.receipt_long_rounded,
                  size: AppButtonSize.large,
                  onPressed: missing == null
                      ? () async {
                          AppNavigation.dismissKeyboard();
                          // Récapitulatif par-dessus la feuille : « Modifier »
                          // y ramène, « Confirmer et payer » passe au paiement.
                          final confirmed = await _openSummarySheet();
                          if (confirmed == true) AppNavigation.pop(true);
                        }
                      : null,
                ),
              ],
            ),
            child: _orderSheetContent(context),
          );
        },
      ),
    );
  }

  Widget _orderSheetContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Combinaison, avec les paliers glissés entre les options et la
        // saisie : l'acheteur voit le prix avant de taper sa quantité.
        if (_hasVariants)
          _section(
            context,
            title: 'import.wholesale.order_sheet.combination_title'.tr,
            subtitle: 'import.wholesale.order_sheet.combination_subtitle'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En gros, le stock saisi sur une variante n'a pas de sens :
                // toutes les options restent commandables.
                VariantComboPicker(
                  catalog: _variantCatalog,
                  quantities: _variantQuantities,
                  limitToStock: false,
                  priceOf: (variant) {
                    final id = VariantQuantityList.idOf(variant);
                    final tier = _tierFor(_variantQuantities[id] ?? 0);
                    return tier == null
                        ? ''
                        : 'import.wholesale.price_per_unit'.trParams({
                            'price': _fmtConverted(
                              tier.unitPrice,
                              tier.currency,
                            ),
                          });
                  },
                  beforeQuantity: _tiers.isEmpty ? null : _sheetTiers(context),
                  onFocusChanged: (id) => _focusedVariantId = id,
                  onChanged: (next) {
                    _update(() => _variantQuantities = next);
                    _quantityChanged();
                  },
                ),
                if (_tiers.isNotEmpty) _buildQuantityHint(context),
              ],
            ),
          )
        else ...[
          // 1. Sans options : prix selon la quantité, puis la quantité.
          // Toucher un palier y amène la quantité.
          if (_tiers.isNotEmpty) ...[
            _section(
              context,
              title: 'import.wholesale.tiers_title'.tr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [..._tiers.map(_tierTile)],
              ),
            ),
            const SizedBox(height: AppDesign.space3),
          ],
          _section(
            context,
            title: 'import.wholesale.quantity_title'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuantityStepper(
                  value: _singleQuantity,
                  // Pas de min à 50 ici : la saisie au clavier repasserait au
                  // minimum dès le premier chiffre. Le rappel s'affiche en rouge.
                  min: 1,
                  hasError: _quantityTooLow,
                  onChanged: (value) {
                    _update(() => _singleQuantity = value);
                    _quantityChanged();
                  },
                ),
                if (_tiers.isNotEmpty) _buildQuantityHint(context),
              ],
            ),
          ),
        ],
        // 3. Expédition jusqu'à l'entrepôt ASSO.
        if (widget.shippingOptions.isNotEmpty) ...[
          const SizedBox(height: AppDesign.space3),
          _section(
            context,
            title: 'import.wholesale.shipping_title'.trParams({
              'city': _hubCity,
            }),
            subtitle: 'import.wholesale.shipping_subtitle'.trParams({
              'city': _hubCity,
            }),
            child: Column(
              children: [
                ...widget.shippingOptions.map(_shippingTile),
                if (_needsWeight || _needsCbm) _shippingMeasureInfo(context),
              ],
            ),
          ),
        ],
        // 4. Adresse, précision, contact et partenaire de livraison.
        const SizedBox(height: AppDesign.space3),
        _section(
          context,
          title: 'import.wholesale.delivery_title'.trParams({'city': _hubCity}),
          subtitle: 'import.wholesale.delivery_subtitle'.tr,
          child: WholesaleDeliverySection(
            delivery: _delivery,
            formatPrice: _fmt,
          ),
        ),
      ],
    );
  }

  /// Paliers dans la feuille de commande, entre les options et la saisie :
  /// titre, règle de calcul et paliers à toucher.
  Widget _sheetTiers(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'import.wholesale.tiers_title'.tr,
          style: context.textStyle(
            FontSizeType.subtitle1,
            fontWeight: FontWeight.w700,
            color: context.ds.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _mixVariants
              ? 'import.wholesale.tiers_mixed_subtitle'.tr
              : 'import.wholesale.tiers_per_option_subtitle'.tr,
          style: context.textStyle(
            FontSizeType.caption,
            color: context.ds.textSecondary,
          ),
        ),
        const SizedBox(height: AppDesign.space2),
        ..._tiers.map(_tierTile),
      ],
    );
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                          // Couleurs et tailles sont seulement montrées : la
                          // combinaison, les paliers et la livraison se
                          // règlent dans la feuille « Commander ».
                          if (_hasVariants) ...[
                            const SizedBox(height: AppDesign.space3),
                            _section(
                              context,
                              title: 'import.wholesale.options_title'.tr,
                              subtitle: 'import.wholesale.options_subtitle'.tr,
                              child: VariantOptionsPreview(
                                catalog: _variantCatalog,
                                dimOutOfStock: false,
                              ),
                            ),
                          ],
                          ..._buildDetailSections(context, p),
                          const SizedBox(height: AppDesign.space4),
                          // Contacter le support ASSO à propos de cette
                          // commande en gros.
                          AppButton(
                            label: _contactingSupport
                                ? 'import.wholesale.opening'.tr
                                : 'import.wholesale.ask_support'.tr,
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
                                    ? 'import.wholesale.one_photo'.tr
                                    : 'import.wholesale.photos_count'.trParams({
                                        'count': '${_images.length}',
                                      }),
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
              AppBadge(
                label: 'import.wholesale.badge'.tr,
                tone: AppBadgeTone.accent,
                icon: Icons.inventory_2_outlined,
              ),
              if (p.freeDelivery) const FreeDeliveryBadge(),
              if (p.hasDeposit)
                AppBadge(
                  label: 'core.deposit.on_order'.tr,
                  tone: AppBadgeTone.warning,
                  icon: Icons.schedule_rounded,
                ),
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
                    text: 'import.wholesale.from_prefix'.tr,
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
                    text: 'import.wholesale.per_unit_suffix'.tr,
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
                'import.wholesale.degressive_price'.tr,
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
      ('import.wholesale.details.description'.tr, p.description),
      ('import.wholesale.details.characteristics'.tr, p.characteristics),
      (
        'import.wholesale.details.commercial_information'.tr,
        p.commercialInformation,
      ),
      ('product.specs.delivery_delay'.tr, p.deliveryDelay?.label),
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
                        // Le premier seuil est le minimum de commande.
                        t.id == _tiers.first.id && _tiers.length > 1
                            ? (t.minQuantity <= 1
                                  ? 'import.wholesale.tier_up_to'.trParams({
                                      'count': '${_tiers[1].minQuantity - 1}',
                                    })
                                  : 'import.wholesale.tier_range'.trParams({
                                      'min': '${t.minQuantity}',
                                      'count': '${_tiers[1].minQuantity - 1}',
                                    }))
                            : t.minQuantity <= 1
                            ? 'import.wholesale.tier_any_quantity'.tr
                            : 'import.wholesale.tier_from'.trParams({
                                'count': '${t.minQuantity}',
                              }),
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
    if (_lines.isEmpty) {
      text = _hasVariants
          ? 'import.wholesale.hint.choose_option'.tr
          : 'import.wholesale.hint.enter_quantity'.tr;
    } else if (_belowMinimum) {
      text = _minimumMessage;
    } else if (!_mixVariants) {
      text = 'import.wholesale.hint.total_per_option'.trParams({
        'quantity': '$_quantity',
      });
    } else {
      final tier = _tier;
      final price = tier == null
          ? ''
          : 'import.wholesale.hint.at_price'.trParams({
              'price': _fmtConverted(tier.unitPrice, tier.currency),
            });
      // Palier suivant : combien il manque pour le prix plus bas.
      final next = _tiers.where((t) => t.minQuantity > _quantity).firstOrNull;
      final nudge = next == null
          ? ''
          : 'import.wholesale.hint.nudge'.trParams({
              'count': '${next.minQuantity - _quantity}',
              'price': _fmtConverted(next.unitPrice, next.currency),
            });
      text = 'import.wholesale.hint.total'.trParams({
        'quantity': '$_quantity',
        'price': price,
        'nudge': nudge,
      });
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
      if (s.leadTimeDays != null)
        'import.wholesale.lead_time_days'.trParams({
          'days': '${s.leadTimeDays}',
        }),
      if (s.expeditionNote != null && s.expeditionNote!.isNotEmpty)
        s.expeditionNote!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space2),
      child: Material(
        color: selected ? AppDesign.accentSubtle : context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        child: InkWell(
          onTap: () => _update(() => _shipping = s),
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
                ? 'import.wholesale.weight_computed'.trParams({
                    'weight': _shippingWeightKg.toStringAsFixed(2),
                  })
                : 'import.wholesale.weight_set_by_asso'.tr,
            style: context.textStyle(
              FontSizeType.caption,
              color: AppDesign.infoText,
            ),
          ),
        ),
      ],
    ),
  );

  /// Récapitulatif complet, comme celui de la fiche détail : article et
  /// options, expédition, livraison, montant. Rend `true` sur « Confirmer et
  /// payer », `false` sur « Modifier ».
  Future<bool?> _openSummarySheet() {
    final delivery = _delivery.selected;
    final details = _delivery.detailsController.text.trim();
    final image = _images.isNotEmpty
        ? _images.first
        : (widget.product.image ?? '');
    return AppSheet.show<bool>(
      Builder(
        builder: (context) => AppSheet(
          title: 'import.wholesale.recap.title'.tr,
          subtitle: widget.product.name,
          color: context.ds.canvas,
          // La flèche ramène à la feuille de commande, restée ouverte dessous.
          onBack: () => AppNavigation.pop(false),
          showClose: false,
          footer: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'import.wholesale.recap.edit'.tr,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.large,
                  onPressed: () => AppNavigation.pop(false),
                ),
              ),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'import.wholesale.recap.confirm_and_pay'.tr,
                  icon: Icons.lock_rounded,
                  size: AppButtonSize.large,
                  onPressed: () => AppNavigation.pop(true),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(
                context,
                title: 'import.wholesale.recap.item'.tr,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusSm,
                          ),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: image.isEmpty
                                ? _imagePlaceholder()
                                : _image(image, BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: AppDesign.space3),
                        Expanded(
                          child: Text(
                            widget.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.body1,
                              fontWeight: FontWeight.w600,
                              color: context.ds.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDesign.space2),
                    // Une ligne par option : « Rouge · L — 30 × 1 000 FCFA ».
                    for (final (label, quantity) in _recapLines)
                      Padding(
                        padding: const EdgeInsets.only(top: AppDesign.space2),
                        child: _sumRow(
                          context,
                          label,
                          '$quantity × ${_fmt(_tierFor(quantity)?.unitPriceXaf ?? 0)}',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppDesign.space3),
              _section(
                context,
                title: 'import.wholesale.recap.delivery'.tr,
                child: Column(
                  children: [
                    _sumRow(
                      context,
                      'import.wholesale.recap.shipping'.trParams({
                        'city': _hubCity,
                      }),
                      _shipping?.modeLabel ?? '—',
                    ),
                    const SizedBox(height: AppDesign.space2),
                    _sumRow(
                      context,
                      'import.wholesale.recap.address'.tr,
                      _delivery.address,
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: AppDesign.space2),
                      _sumRow(
                        context,
                        'import.wholesale.recap.address_details'.tr,
                        details,
                      ),
                    ],
                    const SizedBox(height: AppDesign.space2),
                    _sumRow(
                      context,
                      'import.wholesale.recap.contact_phone'.tr,
                      _delivery.phoneController.text.trim(),
                    ),
                    if (delivery != null) ...[
                      const SizedBox(height: AppDesign.space2),
                      _sumRow(
                        context,
                        'import.wholesale.recap.courier'.tr,
                        delivery.vehicleLabel != null
                            ? '${delivery.companyName} · ${delivery.vehicleLabel}'
                            : delivery.companyName,
                      ),
                      const SizedBox(height: AppDesign.space2),
                      _sumRow(
                        context,
                        'import.wholesale.recap.mode'.tr,
                        delivery.deliveryOptionLabel,
                      ),
                      if (delivery.leadTime != null) ...[
                        const SizedBox(height: AppDesign.space2),
                        _sumRow(
                          context,
                          'import.wholesale.recap.lead_time'.tr,
                          delivery.leadTime!,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppDesign.space3),
              _section(
                context,
                title: 'import.wholesale.recap.amount'.tr,
                child: _summary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lignes du récapitulatif : (libellé de l'option, quantité).
  List<(String, int)> get _recapLines => _hasVariants
      ? [
          for (final (variant, quantity) in _variantLines)
            (VariantCatalog.attributesOf(variant).values.join(' · '), quantity),
        ]
      : [
          if (_singleQuantity > 0)
            ('import.wholesale.recap.quantity'.tr, _singleQuantity),
        ];

  Widget _summary(BuildContext context) {
    return Column(
      children: [
        _sumRow(
          context,
          _mixVariants
              ? 'import.wholesale.summary.product_tier'.trParams({
                  'quantity': '$_quantity',
                  'tier': _tier?.label ?? '',
                })
              : 'import.wholesale.summary.product_units'.trParams({
                  'quantity': '$_quantity',
                }),
          _fmt(_subtotal),
        ),
        const SizedBox(height: AppDesign.space2),
        _sumRow(
          context,
          'import.wholesale.summary.shipping'.trParams({
            'city': _hubCity,
            'mode': _shipping?.modeLabel ?? '—',
          }),
          _fmt(_shippingCost),
        ),
        const SizedBox(height: AppDesign.space2),
        _sumRow(
          context,
          _delivery.selected == null
              ? 'import.wholesale.delivery_title'.trParams({'city': _hubCity})
              : 'import.wholesale.summary.delivery_company'.trParams({
                  'company': _delivery.selected!.companyName,
                }),
          _delivery.selected == null ? '—' : _fmt(_delivery.price),
          struck: _delivery.isFree,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppDesign.space3),
          child: AppDivider(),
        ),
        _sumRow(
          context,
          _hasDeposit
              ? 'core.deposit.total_price'.tr
              : 'import.wholesale.total'.tr,
          _fmt(_total),
          bold: !_hasDeposit,
        ),
        if (_hasDeposit) ...[
          const SizedBox(height: AppDesign.space2),
          _sumRow(
            context,
            'core.deposit.balance_later'.tr,
            _fmt(_total - _deposit),
          ),
          const SizedBox(height: AppDesign.space2),
          _sumRow(
            context,
            'core.deposit.deposit_now'.tr,
            _fmt(_deposit),
            bold: true,
          ),
          const SizedBox(height: AppDesign.space3),
          DeliveryNotice('core.deposit.verification_notice'.tr),
        ],
      ],
    );
  }

  Widget _sumRow(
    BuildContext c,
    String l,
    String v, {
    bool bold = false,
    bool struck = false,
  }) => Row(
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

  /// Barre d'action : « Commander » ouvre la feuille où tout se règle. Le
  /// prix est déjà dans l'en-tête ; le total n'existe qu'une fois la
  /// quantité choisie, il s'affiche dans la feuille.
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
          child: AppButton(
            label: 'import.wholesale.order_button'.tr,
            icon: Icons.shopping_cart_checkout_rounded,
            size: AppButtonSize.large,
            isLoading: _submitting,
            onPressed: _pay,
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
    if (!AuthGuard.checkAuthWithAlert(
      context,
      featureName: 'import.wholesale.feature_payment'.tr,
    )) {
      return;
    }
    final confirmed = await _openOrderSheet();
    if (confirmed != true || !mounted) return;
    // La feuille ne laisse passer qu'une commande complète, récapitulatif
    // confirmé ; garde au cas où
    // un devis aurait changé entre-temps.
    final missing = _missingStep, shipping = _shipping;
    if (missing != null || shipping == null) {
      Get.snackbar(
        'import.wholesale.error'.tr,
        missing ?? 'import.wholesale.choose_tier_and_shipping'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final currency = Get.isRegistered<CurrencyService>()
        ? CurrencyService.to
        : null;
    final displayAmount = currency?.convertFromXOF(_amountDue) ?? _amountDue;
    final displayCurrency = currency?.currencyCode ?? 'XAF';
    final method = await PaymentMethodSelector.show(
      amount: displayAmount,
      currency: displayCurrency,
      amountLabel: _amountDueLabel,
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
        itemLabel: 'import.wholesale.wallet_item_label'.trParams({
          'name': widget.product.name,
        }),
        amount: _amountDue,
        balance: method.balance ?? 0,
      );
      if (!confirmed) return;
      await _create('wallet', items, shipping.id, weight, cbm);
    } else if (method.code == 'kpay') {
      final sel = await KpayDirectPaymentSheet.show(
        amount: _amountDue,
        amountLabel: _amountDueLabel,
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
        'import.wholesale.unavailable'.tr,
        'import.wholesale.method_unavailable'.tr,
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
          'import.wholesale.error'.tr,
          res.message.isNotEmpty
              ? res.message
              : 'import.wholesale.order_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final orderId = res.data?['order_id'] as int?;
      final approvalUrl = res.data?['approval_url']?.toString();

      if (mode == 'kpay_direct') {
        // Rien n'est annoncé avant la réponse de l'opérateur ; en cas de
        // refus, la fiche reste ouverte pour corriger l'opérateur ou le numéro.
        if (mounted) setState(() => _submitting = false);
        final outcome = await MobileMoneyWaiting.run(
          amount: _amountDue,
          provider: provider!,
          phone: phone!,
          formatAmount: _fmt,
          check: () => _orderPaymentState(orderId),
          failureNote: 'product.payment.failed_order_cancelled'.tr,
        );
        if (outcome.status == 'failed') return;
        AppNavigation.pop(); // fermer la fiche
        if (outcome.status == 'paid') {
          Get.snackbar(
            'import.wholesale.payment_confirmed_title'.tr,
            'import.wholesale.payment_confirmed_message'.tr,
            backgroundColor: AppDesign.success,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
            snackPosition: SnackPosition.BOTTOM,
          );
        } else {
          _pollOrder(orderId);
          Get.snackbar(
            'import.wholesale.created_title'.tr,
            'import.wholesale.created_kpay_message'.tr,
            backgroundColor: AppDesign.accent,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return;
      }

      // `AppNavigation.pop` : `Get.back()` fermerait d'abord un snackbar
      // encore affiché et laisserait la fiche ouverte.
      AppNavigation.pop(); // fermer la fiche : la commande est passée

      if (mode == 'wallet') {
        Get.snackbar(
          'import.wholesale.paid_title'.tr,
          'import.wholesale.paid_wallet_message'.tr,
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
          'import.wholesale.error'.tr,
          'import.wholesale.payment_link_unavailable'.tr,
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
        'import.wholesale.payment_pending_title'.tr,
        'import.wholesale.payment_pending_message'.tr,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'import.wholesale.error'.tr,
        'import.wholesale.generic_error'.tr,
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
        'import.wholesale.unavailable'.tr,
        'import.wholesale.card_mobile_only'.tr,
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
          'import.wholesale.error'.tr,
          res.message.isNotEmpty
              ? res.message
              : 'import.wholesale.order_failed'.tr,
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
          'import.wholesale.error'.tr,
          'import.wholesale.card_data_unavailable'.tr,
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
          'import.wholesale.payment_cancelled_title'.tr,
          'import.wholesale.payment_cancelled_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // `AppNavigation.pop` : `Get.back()` fermerait d'abord un snackbar
      // encore affiché et laisserait la fiche ouverte.
      AppNavigation.pop(); // fermer la fiche : la commande est passée
      _pollOrder(orderId);
      Get.snackbar(
        'import.wholesale.payment_pending_title'.tr,
        'import.wholesale.payment_pending_message'.tr,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'import.wholesale.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// État du paiement de la commande relu sur le serveur (une lecture).
  Future<MobileMoneyStatus> _orderPaymentState(int? orderId) async {
    if (orderId == null) return (status: 'pending', failure: null);
    final data = (await OrderService.orderPaymentStatus(orderId)).data?['data'];
    final status = data?['payment_status']?.toString();
    return (
      status: status == 'paid' || status == 'failed' ? status! : 'pending',
      failure: data?['payment_failure']?.toString(),
    );
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
            'import.wholesale.payment_confirmed_title'.tr,
            'import.wholesale.payment_confirmed_message'.tr,
            backgroundColor: AppDesign.success,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        } else if (status == 'failed') {
          Get.snackbar(
            'import.wholesale.payment_failed_title'.tr,
            switch (res.data?['data']?['payment_failure']?.toString()) {
              final String failure => MobileMoneyWaiting.failureMessage(failure),
              _ => 'import.wholesale.payment_failed_message'.tr,
            },
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
    if (!AuthGuard.checkAuthWithAlert(
      context,
      featureName: 'import.wholesale.feature_messaging'.tr,
    )) {
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
          'import.wholesale.support_unavailable_title'.tr,
          'import.wholesale.support_unavailable_message'.tr,
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
          'import.wholesale.error'.tr,
          'import.wholesale.support_start_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final conversationData = response.data!['conversation'];
      final conversationId = conversationData?['id'];
      if (conversationId == null) {
        Get.snackbar(
          'import.wholesale.error'.tr,
          'import.wholesale.conversation_unavailable'.tr,
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
        'import.wholesale.error'.tr,
        'import.wholesale.error_with_details'.trParams({'error': '$e'}),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _contactingSupport = false);
    }
  }
}
