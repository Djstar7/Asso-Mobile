import 'package:flutter/material.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/import_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/models/wholesale_models.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/values/constants.dart';
import 'wholesale_order_sheet.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/app_ui.dart';

/// Section « Produits importés » : pays d'origine gérés côté backend
/// (Chine 🇨🇳, Turquie 🇹🇷, Dubaï 🇦🇪, Inde 🇮🇳…).
/// Filtre les produits par pays d'origine (origin_country).
class ImportView extends StatefulWidget {
  const ImportView({super.key});

  @override
  State<ImportView> createState() => _ImportViewState();
}

class _ImportCountry {
  final String code; // ISO2 : CN, TR, AE
  final String name;
  final String flag;
  const _ImportCountry(this.code, this.name, this.flag);
}

class _ImportViewState extends State<ImportView> {
  static List<_ImportCountry> _mapCountries(List<Map<String, String>> raw) {
    return [
      for (var i = 0; i < raw.length; i++)
        _ImportCountry(
          raw[i]['code'] ?? '',
          raw[i]['name'] ?? '',
          (raw[i]['flag'] ?? '').isNotEmpty ? raw[i]['flag']! : '🏳️',
        ),
    ];
  }

  // Initialisé avec le fallback pour que le 1er rendu fonctionne, puis rechargé depuis l'API.
  List<_ImportCountry> _countries = _mapCountries(ProductService.importCountriesFallback);

  String _selected = 'CN';
  bool _loading = true;
  List<WholesaleProduct> _products = [];
  List<ShippingOption> _shipping = [];

  @override
  void initState() {
    super.initState();
    _selected = _countries.isNotEmpty ? _countries.first.code : 'CN';
    _init();
  }

  /// Charge la liste des pays depuis le backend, puis les produits du pays sélectionné.
  Future<void> _init() async {
    final loaded = await ProductService.getImportCountries();
    if (mounted && loaded.isNotEmpty) {
      setState(() {
        _countries = _mapCountries(loaded);
        if (!_countries.any((c) => c.code == _selected)) {
          _selected = _countries.first.code;
        }
      });
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Catalogue GROS du pays : produits à paliers (cota) + options d'expédition.
      final catalog = await ImportService.getCatalog(_selected);
      _products = catalog?.products ?? [];
      _shipping = catalog?.shippingOptions ?? [];
    } catch (_) {
      _products = [];
      _shipping = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  _ImportCountry get _current =>
      _countries.firstWhere((c) => c.code == _selected, orElse: () => _countries.first);

  @override
  Widget build(BuildContext context) {
    final country = _current;
    return Container(
      color: context.ds.canvas,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppDesign.accent,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(country)),
              SliverToBoxAdapter(child: _buildCountrySelector()),
              SliverToBoxAdapter(child: _buildSectionLabel(country)),
              if (_loading)
                _buildSkeletonGrid()
              else if (_products.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildEmpty(country))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: ProductCard.gridDelegate(context),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildProductCard(_products[i], country),
                      childCount: _products.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Hero header ───────────────────────────
  Widget _buildHeader(_ImportCountry c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        border: Border.all(color: context.ds.border),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Motif décoratif discret

          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.ds.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Text(c.flag, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flight_takeoff_rounded,
                            color: context.ds.textTertiary, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('PRODUITS IMPORTÉS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context
                                  .textStyle(FontSizeType.overline,
                                      fontWeight: FontWeight.w700,
                                      color: context.ds.textTertiary)
                                  .copyWith(letterSpacing: 1.1)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Made in ${c.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(FontSizeType.h5,
                            fontWeight: FontWeight.w700,
                            color: context.ds.textPrimary)),
                    const SizedBox(height: 8),
                    _headerCountChip(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCountChip() {
    final label = _loading
        ? 'Chargement…'
        : '${_products.length} produit${_products.length > 1 ? 's' : ''} disponible${_products.length > 1 ? 's' : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.ds.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              color: context.ds.textSecondary, size: 13),
          const SizedBox(width: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(FontSizeType.overline,
                  fontWeight: FontWeight.w600,
                  color: context.ds.textSecondary)),
        ],
      ),
    );
  }

  // ─────────────────────────── Sélecteur de pays ───────────────────────────
  Widget _buildCountrySelector() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        itemCount: _countries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = _countries[i];
          final selected = c.code == _selected;
          return GestureDetector(
            onTap: () {
              if (c.code != _selected) {
                setState(() => _selected = c.code);
                _load();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppDesign.accentSubtle : context.ds.surface,
                borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                border: Border.all(
                  color: selected ? AppDesign.accentBorder : context.ds.border,
                ),
              ),
              child: Row(
                children: [
                  Text(c.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.caption,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? AppDesign.accentText
                            : context.ds.textSecondary,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(_ImportCountry c) {
    if (_loading || _products.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        children: [
          Text('Sélection ${c.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesign.neutral900)),
          const Spacer(),
          Text('${_products.length} article${_products.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12.5, color: AppDesign.neutral500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─────────────────────────── Skeleton de chargement ───────────────────────────
  Widget _buildSkeletonGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.66,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, __) => _skeletonCard(),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesign.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppDesign.neutral100,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: double.infinity, color: AppDesign.neutral100),
                const SizedBox(height: 8),
                Container(height: 12, width: 90, color: AppDesign.neutral100),
                const SizedBox(height: 12),
                Container(height: 14, width: 70, color: AppDesign.neutral100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── État vide ───────────────────────────
  Widget _buildEmpty(_ImportCountry c) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDesign.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Le drapeau tient lieu d'illustration, sur une pastille neutre :
          // la teinte du pays ne colore plus tout l'écran.
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.ds.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Text(c.flag, style: const TextStyle(fontSize: 34)),
          ),
          SizedBox(height: AppDesign.space4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
            child: Column(
              children: [
                Text(
                  'Aucun produit ${c.name} pour le moment',
                  textAlign: TextAlign.center,
                  style: context.textStyle(
                    FontSizeType.subtitle1,
                    fontWeight: FontWeight.w600,
                    color: context.ds.textPrimary,
                  ),
                ),
                SizedBox(height: AppDesign.space2),
                Text(
                  'De nouveaux articles importés de ${c.name} arrivent régulièrement.',
                  textAlign: TextAlign.center,
                  style: context.textStyle(
                    FontSizeType.body2,
                    color: context.ds.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppDesign.space5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: 'Actualiser',
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.secondary,
                expand: false,
                onPressed: _load,
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildProductCard(WholesaleProduct p, _ImportCountry c) {
    final entry = p.entryTier;
    final image = p.image;

    // Même carte que sur l'accueil et la recherche : un produit doit avoir
    // partout la même apparence. Les deux spécificités du gros — quantité
    // minimale et ajout direct au panier — s'y greffent.
    return Stack(
      fit: StackFit.expand,
      children: [
        ProductCard(
          name: p.name,
          price: entry == null
              ? '—'
              : 'Dès ${CurrencyService.formatAmountInCurrency(entry.unitPrice, entry.currency)}',
          location: entry == null ? null : 'Minimum ${entry.minQuantity} pièces',
          badgeLabel: 'GROS',
          badgeTone: AppBadgeTone.accent,
          imageBuilder: image == null || image.isEmpty
              ? null
              : (context) => _buildProductImage(image),
          onTap: () => WholesaleOrderSheet.show(
            product: p,
            shippingOptions: _shipping,
            countryFlag: c.flag,
          ),
        ),
        // Ajout direct, posé sur l'angle du visuel.
        Positioned(
          right: AppDesign.space1,
          top: AppDesign.space1,
          child: Material(
            color: AppDesign.accent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            child: InkWell(
              onTap: () => WholesaleOrderSheet.show(
                product: p,
                shippingOptions: _shipping,
                countryFlag: c.flag,
              ),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.add_rounded, color: Colors.white, size: 19),
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _imgPlaceholder() => Container(
        color: AppDesign.neutral100,
        child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 40),
      );

  Widget _buildProductImage(String? path) {
    if (path == null || path.trim().isEmpty) return _imgPlaceholder();
    final value = path.trim();
    if (value.startsWith('assets/')) {
      return Image.asset(value, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _imgPlaceholder());
    }

    return Image.network(
      _imageUrlForDevice(value),
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: AppDesign.neutral100),
      errorBuilder: (_, __, ___) => _imgPlaceholder(),
    );
  }

  String _imageUrlForDevice(String value) {
    final apiUri = Uri.parse(AppConstants.baseUrl);
    final imageUri = Uri.tryParse(value);
    if (imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty) {
      final normalizedPath = imageUri.path.replaceFirst('/storage/storage/', '/storage/');
      if (imageUri.host == 'localhost' || imageUri.host == '127.0.0.1') {
        return imageUri
            .replace(host: apiUri.host, port: apiUri.port, path: normalizedPath)
            .toString();
      }
      return imageUri.replace(path: normalizedPath).toString();
    }

    final path = (value.startsWith('/') ? value : '/$value')
        .replaceFirst('/storage/storage/', '/storage/');
    return Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.port,
      path: path.startsWith('/storage/') ? path : '/storage$path',
    ).toString();
  }
}
