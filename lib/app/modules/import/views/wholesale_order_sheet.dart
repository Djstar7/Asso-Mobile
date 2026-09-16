import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/controllers/app_config_controller.dart';
import '../../../core/values/constants.dart';
import '../../../data/models/wholesale_models.dart';
import '../../../data/providers/import_service.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/conversation_service.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../wallet/views/payment_webview.dart';
import '../../../data/services/stripe_native_service.dart';
import '../../../data/providers/currency_service.dart';

/// Fiche produit GROS + tunnel de commande : palier (cota) → quantité → expédition
/// → moyen de paiement (sélecteur unifié). Réservé aux commandes en gros.
class WholesaleOrderSheet extends StatefulWidget {
  final WholesaleProduct product;
  final List<ShippingOption> shippingOptions;
  final String countryFlag;

  const WholesaleOrderSheet({
    super.key,
    required this.product,
    required this.shippingOptions,
    required this.countryFlag,
  });

  static Future<void> show({
    required WholesaleProduct product,
    required List<ShippingOption> shippingOptions,
    required String countryFlag,
  }) {
    return Get.bottomSheet(
      WholesaleOrderSheet(
        product: product,
        shippingOptions: shippingOptions,
        countryFlag: countryFlag,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<WholesaleOrderSheet> createState() => _WholesaleOrderSheetState();
}

class _WholesaleOrderSheetState extends State<WholesaleOrderSheet> {
  PriceTier? _tier;
  ShippingOption? _shipping;
  int _quantity = 0;
  bool _submitting = false;
  bool _contactingSupport = false;
  int _imageIndex = 0;
  Map<String, dynamic>? _selectedVariant;
  final PageController _galleryController = PageController();

  @override
  void initState() {
    super.initState();
    _tier = widget.product.entryTier;
    _quantity = _tier?.minQuantity ?? 1;
    if (widget.shippingOptions.isNotEmpty) {
      _shipping = widget.shippingOptions.first;
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  String _fmt(double valueInXaf) => Get.isRegistered<CurrencyService>()
      ? CurrencyService.to.formatPrice(valueInXaf)
      : '${valueInXaf.toStringAsFixed(0)} FCFA';

  String _fmtConverted(double amount, String currency) =>
      CurrencyService.formatAmountInCurrency(amount, currency);

  String? _variantNote() {
    final attributes = _selectedVariant?['attributes'];
    if (attributes is! Map) return null;
    return 'Variante choisie : ${attributes.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ')}';
  }

  double get _subtotal => (_tier?.unitPriceXaf ?? 0) * _quantity;

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

  double get _total => _subtotal + _shippingCost;

  bool get _needsWeight => _shipping?.rateType == 'per_kg';
  bool get _needsCbm => _shipping?.rateType == 'per_cbm';
  double get _shippingWeightKg =>
      (widget.product.unitWeightKg ?? 0) * _quantity;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: AppThemeSystem.getBackgroundColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppThemeSystem.getPrimaryTextColor(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppThemeSystem.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 16),
              _buildProductGallery(context, p),
              const SizedBox(height: 16),
              // En-tête produit
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.countryFlag,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'COMMANDE EN GROS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppThemeSystem.getPrimaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (p.description != null && p.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  p.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppThemeSystem.getSecondaryTextColor(context),
                  ),
                ),
              ],
              if (p.characteristics?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _label(context, 'Caractéristiques'),
                const SizedBox(height: 4),
                Text(
                  p.characteristics!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppThemeSystem.getSecondaryTextColor(context),
                  ),
                ),
              ],
              if (p.commercialInformation?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _label(context, 'Informations commerciales'),
                const SizedBox(height: 4),
                Text(
                  p.commercialInformation!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppThemeSystem.getSecondaryTextColor(context),
                  ),
                ),
              ],
              if (p.variants.isNotEmpty) ...[
                const SizedBox(height: 12),
                _label(context, 'Variantes disponibles'),
                const SizedBox(height: 6),
                Column(
                  children: p.variants
                      .map((variant) => _variantCard(context, variant))
                      .toList(),
                ),
              ],

              const SizedBox(height: 20),
              _label(context, 'Conditionnement (prix & quantité minimale)'),
              const SizedBox(height: 8),
              ...p.priceTiers.map(_tierTile),

              const SizedBox(height: 20),
              _label(context, 'Quantité'),
              const SizedBox(height: 8),
              _quantityRow(context),

              const SizedBox(height: 20),
              _label(context, 'Expédition internationale'),
              const SizedBox(height: 8),
              ...widget.shippingOptions.map(_shippingTile),
              if (_needsWeight || _needsCbm) ...[
                const SizedBox(height: 10),
                _shippingMeasureInfo(context),
              ],

              const SizedBox(height: 20),
              _summary(context),
              const SizedBox(height: 16),
              // Contacter le support ASSO à propos de cette commande en gros.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _contactingSupport ? null : _contactSupport,
                  icon: _contactingSupport
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppThemeSystem.primaryColor,
                          ),
                        )
                      : Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppThemeSystem.primaryColor,
                        ),
                  label: Text(
                    'Écrire un message',
                    style: TextStyle(
                      color: AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppThemeSystem.primaryColor,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _pay,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                        ),
                  label: const Text(
                    'Choisir un moyen de paiement',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _imgPh() => Container(
    width: 56,
    height: 56,
    color: const Color(0xFFF1F2F5),
    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFFB4BCC6)),
  );

  Widget _buildProductGallery(BuildContext context, WholesaleProduct product) {
    final images = <String>[
      ...product.images,
      if (product.images.isEmpty && product.image?.isNotEmpty == true)
        product.image!,
    ];
    if (images.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showImageGallery(context, images, _imageIndex),
          child: Stack(
            children: [
              SizedBox(
                height: 210,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: PageView.builder(
                    controller: _galleryController,
                    itemCount: images.length,
                    onPageChanged: (index) =>
                        setState(() => _imageIndex = index),
                    itemBuilder: (_, index) =>
                        _buildLargeProductImage(images[index]),
                  ),
                ),
              ),
              if (images.length > 1) ...[
                Positioned(
                  left: 8,
                  top: 82,
                  child: _galleryArrow(Icons.chevron_left, () {
                    final target = (_imageIndex - 1).clamp(
                      0,
                      images.length - 1,
                    );
                    _galleryController.animateToPage(
                      target,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }),
                ),
                Positioned(
                  right: 8,
                  top: 82,
                  child: _galleryArrow(Icons.chevron_right, () {
                    final target = (_imageIndex + 1).clamp(
                      0,
                      images.length - 1,
                    );
                    _galleryController.animateToPage(
                      target,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }),
                ),
              ],
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_in, color: Colors.white, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        '${_imageIndex + 1}/${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Text(
            'Balayez pour voir les autres photos · touchez pour agrandir',
            style: TextStyle(
              fontSize: 11,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _galleryArrow(IconData icon, VoidCallback onPressed) => Material(
    color: Colors.black.withValues(alpha: 0.58),
    shape: const CircleBorder(),
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 30),
      tooltip: icon == Icons.chevron_left
          ? 'Photo précédente'
          : 'Photo suivante',
    ),
  );

  Widget _buildLargeProductImage(String value) {
    final widget = _buildProductImage(value);
    if (widget is Image)
      return Image(
        image: widget.image,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _imgPh(),
      );
    return widget;
  }

  void _showImageGallery(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    final controller = PageController(initialPage: initialIndex);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              itemBuilder: (_, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: _buildLargeProductImage(images[index])),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                ),
              ),
            ),
            const Positioned(
              bottom: 26,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Text(
                  'Pincez pour zoomer · balayez pour changer de photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  Widget _buildProductImage(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('assets/')) {
      return Image.asset(
        trimmed,
        width: 56,
        height: 56,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _imgPh(),
      );
    }

    final apiUri = Uri.parse(AppConstants.baseUrl);
    final imageUri = Uri.tryParse(trimmed);
    final imageUrl =
        imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty
        ? ((imageUri.host == 'localhost' || imageUri.host == '127.0.0.1')
              ? imageUri
                    .replace(
                      host: apiUri.host,
                      port: apiUri.port,
                      path: imageUri.path.replaceFirst(
                        '/storage/storage/',
                        '/storage/',
                      ),
                    )
                    .toString()
              : imageUri
                    .replace(
                      path: imageUri.path.replaceFirst(
                        '/storage/storage/',
                        '/storage/',
                      ),
                    )
                    .toString())
        : Uri(
            scheme: apiUri.scheme,
            host: apiUri.host,
            port: apiUri.port,
            path: trimmed.startsWith('/storage/')
                ? trimmed.replaceFirst('/storage/storage/', '/storage/')
                : '/storage/${trimmed.replaceFirst(RegExp(r'^/'), '')}',
          ).toString();

    return Image.network(
      imageUrl,
      width: 56,
      height: 56,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _imgPh(),
    );
  }

  Widget _label(BuildContext c, String t) => Text(
    t,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppThemeSystem.getPrimaryTextColor(c),
    ),
  );

  Widget _tierTile(PriceTier t) {
    final selected = _tier?.id == t.id;
    return GestureDetector(
      onTap: () => setState(() {
        _tier = t;
        if (_quantity < t.minQuantity) _quantity = t.minQuantity;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppThemeSystem.primaryColor
                : AppThemeSystem.getBorderColor(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? AppThemeSystem.primaryColor
                  : AppThemeSystem.getSecondaryTextColor(context),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppThemeSystem.getPrimaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Minimum ${t.minQuantity}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _fmtConverted(t.unitPrice, t.currency),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppThemeSystem.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityRow(BuildContext context) {
    final min = _tier?.minQuantity ?? 1;
    return Row(
      children: [
        _qtyBtn(Icons.remove, _quantity > min, () {
          if (_quantity > min) setState(() => _quantity--);
        }),
        Expanded(
          child: Center(
            child: Text(
              '$_quantity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.getPrimaryTextColor(context),
              ),
            ),
          ),
        ),
        _qtyBtn(Icons.add, true, () => setState(() => _quantity++)),
      ],
    );
  }

  Widget _qtyBtn(IconData i, bool enabled, VoidCallback onTap) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: enabled
            ? AppThemeSystem.primaryColor
            : AppThemeSystem.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        i,
        color: enabled ? Colors.white : AppThemeSystem.primaryColor,
      ),
    ),
  );

  Widget _shippingTile(ShippingOption s) {
    final selected = _shipping?.id == s.id;
    return GestureDetector(
      onTap: () => setState(() {
        _shipping = s;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppThemeSystem.primaryColor
                : AppThemeSystem.getBorderColor(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _shipIcon(s.mode),
              color: selected
                  ? AppThemeSystem.primaryColor
                  : AppThemeSystem.getSecondaryTextColor(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.modeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppThemeSystem.getPrimaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtConverted(s.rateAmount, s.currency)}${s.rateType == 'per_kg'
                        ? ' / kg'
                        : s.rateType == 'per_cbm'
                        ? ' / CBM'
                        : ''}${s.expeditionNote != null ? ' · ${s.expeditionNote}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppThemeSystem.getSecondaryTextColor(context),
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
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppThemeSystem.primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          _needsWeight ? Icons.scale_rounded : Icons.view_in_ar_rounded,
          color: AppThemeSystem.primaryColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _needsWeight && _shippingWeightKg > 0
                ? 'Poids calculé par ASSO : ${_shippingWeightKg.toStringAsFixed(2)} kg'
                : 'Le poids/volume d\'expédition est renseigné par ASSO.',
            style: TextStyle(
              color: AppThemeSystem.getPrimaryTextColor(context),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _summary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _sumRow(
            context,
            'Produit (${_quantity} × ${_tier?.label ?? ''})',
            _fmt(_subtotal),
          ),
          const SizedBox(height: 6),
          _sumRow(
            context,
            'Expédition (${_shipping?.modeLabel ?? '—'})',
            _fmt(_shippingCost),
          ),
          const Divider(height: 18),
          _sumRow(context, 'Total', _fmt(_total), bold: true),
        ],
      ),
    );
  }

  Widget _sumRow(BuildContext c, String l, String v, {bool bold = false}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              l,
              style: TextStyle(
                color: AppThemeSystem.getSecondaryTextColor(c),
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            v,
            style: TextStyle(
              color: bold
                  ? AppThemeSystem.primaryColor
                  : AppThemeSystem.getPrimaryTextColor(c),
              fontWeight: FontWeight.bold,
              fontSize: bold ? 16 : 13,
            ),
          ),
        ],
      );

  Widget _variantCard(BuildContext context, Map<String, dynamic> variant) {
    final attributes = Map<String, dynamic>.from(
      variant['attributes'] as Map? ?? const {},
    );
    String? colorName;
    for (final entry in attributes.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('couleur') || key.contains('color')) {
        colorName = entry.value.toString();
        break;
      }
    }
    final swatchColor = _variantColor(colorName);
    final stock = (variant['stock'] as num?)?.toInt() ?? 0;
    final selected = _selectedVariant?['id'] == variant['id'];

    return GestureDetector(
      onTap: stock > 0
          ? () => setState(() => _selectedVariant = variant)
          : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppThemeSystem.primaryColor.withValues(alpha: 0.08)
              : AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppThemeSystem.primaryColor
                : AppThemeSystem.getBorderColor(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (colorName != null) ...[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: swatchColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: swatchColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: attributes.entries
                        .map(
                          (entry) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeSystem.primaryColor.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              entry.value.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 15,
                        color: stock > 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$stock disponible${stock > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: stock > 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppThemeSystem.primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  Color _variantColor(String? name) {
    final value = (name ?? '').toLowerCase().trim();
    const colors = <String, Color>{
      'rouge': Color(0xFFE53935),
      'red': Color(0xFFE53935),
      'bleu': Color(0xFF1E88E5),
      'blue': Color(0xFF1E88E5),
      'vert': Color(0xFF43A047),
      'green': Color(0xFF43A047),
      'noir': Color(0xFF212121),
      'black': Color(0xFF212121),
      'blanc': Color(0xFFFAFAFA),
      'white': Color(0xFFFAFAFA),
      'jaune': Color(0xFFFDD835),
      'yellow': Color(0xFFFDD835),
      'orange': Color(0xFFFB8C00),
      'rose': Color(0xFFEC407A),
      'pink': Color(0xFFEC407A),
      'violet': Color(0xFF8E24AA),
      'purple': Color(0xFF8E24AA),
      'marron': Color(0xFF795548),
      'brown': Color(0xFF795548),
      'gris': Color(0xFF757575),
      'grey': Color(0xFF757575),
      'gray': Color(0xFF757575),
      'beige': Color(0xFFD7CCC8),
    };
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return colors.entries
        .firstWhere(
          (entry) => value.contains(entry.key),
          orElse: () => const MapEntry('', Color(0xFFBDBDBD)),
        )
        .value;
  }

  // ─────────────────────────── Paiement ───────────────────────────
  Future<void> _pay() async {
    // En mode invité, ne pas ouvrir un sélecteur vide ("aucun moyen disponible") :
    // exiger la connexion d'abord.
    if (!AuthGuard.checkAuthWithAlert(context, featureName: 'le paiement')) {
      return;
    }
    final tier = _tier, shipping = _shipping;
    if (tier == null || shipping == null) {
      Get.snackbar(
        'Erreur',
        'Choisissez un conditionnement et une expédition.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_quantity < tier.minQuantity) {
      Get.snackbar(
        'Quantité minimale',
        'Minimum ${tier.minQuantity} pour ${tier.label}.',
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

    final currency = Get.isRegistered<CurrencyService>()
        ? CurrencyService.to
        : null;
    final displayAmount = currency?.convertFromXOF(_total) ?? _total;
    final displayCurrency = currency?.currencyCode ?? 'XAF';
    final method = await PaymentMethodSelector.show(
      amount: displayAmount,
      currency: displayCurrency,
      amountLabel: 'Total à payer',
    );
    if (method == null) return;

    final items = [
      {
        'product_id': widget.product.id,
        'price_tier_id': tier.id,
        'quantity': _quantity,
      },
    ];
    final weight = _needsWeight ? _shippingWeightKg : null;
    final cbm = null;

    if (method.code == 'kpay') {
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
    } else if (method.code == 'paypal') {
      await _create('paypal_direct', items, shipping.id, weight, cbm);
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
      Get.back(); // fermer le sheet

      if (mode == 'kpay_direct') {
        _pollOrder(orderId);
        Get.snackbar(
          'Commande créée',
          'Validez le paiement sur votre téléphone (USSD).',
          backgroundColor: Colors.green,
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
        backgroundColor: Colors.green,
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

      Get.back(); // fermer le sheet
      _pollOrder(orderId);
      Get.snackbar(
        'Paiement en cours',
        'La confirmation est automatique. Vous serez notifié.',
        backgroundColor: Colors.green,
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
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        } else if (status == 'failed') {
          Get.snackbar(
            'Paiement échouéPaiement confirm',
            "Le paiement n'a pas abouti.",
            backgroundColor: Colors.red,
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
      Get.back(); // fermer le sheet de commande
      Get.toNamed(
        '/chatdetail',
        arguments: {
          'id': conversationId.toString(),
          'name': supportName,
          'avatar': StringUtils.getInitials(supportName),
          'isOnline': false,
          'default_message': '${widget.product.name} - quantité: $_quantity',
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
