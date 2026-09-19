import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/import_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/models/wholesale_models.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/values/constants.dart';
import 'wholesale_order_sheet.dart';

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
  final List<Color> gradient;
  const _ImportCountry(this.code, this.name, this.flag, this.gradient);
}

class _ImportViewState extends State<ImportView> {
  // Palette de dégradés attribuée par index : un pays ajouté en base reçoit
  // automatiquement un dégradé, sans modification de code.
  static const _gradients = <List<Color>>[
    [Color(0xFFDE2910), Color(0xFFFF6B4A)],
    [Color(0xFFE30A17), Color(0xFFFF5C68)],
    [Color(0xFF0B6B3A), Color(0xFF2FB56E)],
    [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
    [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    [Color(0xFFB45309), Color(0xFFF59E0B)],
  ];

  static List<_ImportCountry> _mapCountries(List<Map<String, String>> raw) {
    return [
      for (var i = 0; i < raw.length; i++)
        _ImportCountry(
          raw[i]['code'] ?? '',
          raw[i]['name'] ?? '',
          (raw[i]['flag'] ?? '').isNotEmpty ? raw[i]['flag']! : '🏳️',
          _gradients[i % _gradients.length],
        ),
    ];
  }

  // Initialisé avec le fallback pour que le 1er rendu fonctionne, puis rechargé depuis l'API.
  List<_ImportCountry> _countries = _mapCountries(ProductService.importCountriesFallback);

  String _selected = 'CN';
  bool _loading = true;
  List<WholesaleProduct> _products = [];
  List<ShippingOption> _shipping = [];

  // Recherche dans les produits importés : pays sélectionné + nombre de résultats par pays.
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  Map<String, int> _counts = {};
  int _loadRequest = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final query = value.trim();
      if (query == _query) return;
      setState(() => _query = query);
      _load();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_query.isEmpty) return;
    setState(() {
      _query = '';
      _counts = {};
    });
    _load();
  }

  void _selectCountry(String code) {
    if (code == _selected) return;
    setState(() => _selected = code);
    _load();
  }

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
    final request = ++_loadRequest;
    setState(() => _loading = true);
    List<WholesaleProduct> products = [];
    List<ShippingOption> shipping = [];
    Map<String, int> counts = {};
    try {
      // Catalogue GROS du pays : produits à paliers (cota) + options d'expédition,
      // filtré par la recherche ; en parallèle, le nombre de résultats de chaque pays.
      final results = await Future.wait([
        ImportService.getCatalog(_selected, query: _query),
        if (_query.isNotEmpty) ImportService.searchCounts(_query),
      ]);
      final catalog = results[0] as WholesaleCatalog?;
      products = catalog?.products ?? [];
      shipping = catalog?.shippingOptions ?? [];
      if (results.length > 1) counts = results[1] as Map<String, int>;
    } catch (_) {}
    if (!mounted || request != _loadRequest) return;
    setState(() {
      _products = products;
      _shipping = shipping;
      _counts = counts;
      _loading = false;
    });
  }

  _ImportCountry get _current =>
      _countries.firstWhere((c) => c.code == _selected, orElse: () => _countries.first);

  @override
  Widget build(BuildContext context) {
    final country = _current;
    return Container(
      color: const Color(0xFFF7F8FA),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: country.gradient.first,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(country)),
              SliverToBoxAdapter(child: _buildSearchField(country)),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.66,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
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
        gradient: LinearGradient(
          colors: c.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: c.gradient.first.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Motif décoratif discret
          Positioned(
            right: -18,
            top: -22,
            child: Icon(Icons.public_rounded, size: 120, color: Colors.white.withValues(alpha: 0.10)),
          ),
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
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
                        const Icon(Icons.flight_takeoff_rounded, color: Colors.white70, size: 15),
                        const SizedBox(width: 6),
                        Text('PRODUITS IMPORTÉS',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Made in ${c.name}',
                        style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
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
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─────────────────────────── Recherche ───────────────────────────
  Widget _buildSearchField(_ImportCountry c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        onSubmitted: (v) {
          _searchDebounce?.cancel();
          setState(() => _query = v.trim());
          _load();
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher en Chine, Turquie, Dubaï…',
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8A97A3)),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: _clearSearch),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE6E9EE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE6E9EE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.gradient.first, width: 1.5),
          ),
        ),
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
            onTap: () => _selectCountry(c.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: selected ? Colors.transparent : const Color(0xFFE6E9EE),
                ),
                boxShadow: selected
                    ? [BoxShadow(color: c.gradient.first.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Row(
                children: [
                  Text(c.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(c.name,
                      style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF33404A),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14)),
                  // Recherche en cours : nombre de résultats dans ce pays.
                  if (_query.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: 0.25) : c.gradient.first.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_counts[c.code] ?? 0}',
                          style: TextStyle(
                              color: selected ? Colors.white : c.gradient.first,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ],
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
          Text(_query.isEmpty ? 'Sélection ${c.name}' : 'Résultats en ${c.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B2530))),
          const Spacer(),
          Text('${_products.length} article${_products.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A97A3), fontWeight: FontWeight.w600)),
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
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEFF1F4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: double.infinity, color: const Color(0xFFEFF1F4)),
                const SizedBox(height: 8),
                Container(height: 12, width: 90, color: const Color(0xFFEFF1F4)),
                const SizedBox(height: 12),
                Container(height: 14, width: 70, color: const Color(0xFFEFF1F4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── État vide ───────────────────────────
  Widget _buildEmpty(_ImportCountry c) {
    if (_query.isNotEmpty) return _buildNoResult(c);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.gradient.first.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Text(c.flag, style: const TextStyle(fontSize: 46)),
          ),
          const SizedBox(height: 18),
          Text('Aucun produit ${c.name} pour l\'instant',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2A3540))),
          const SizedBox(height: 6),
          Text('Reviens bientôt : de nouveaux articles importés de ${c.name} arrivent régulièrement.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.4)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.gradient.first,
              side: BorderSide(color: c.gradient.first.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            label: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  /// Aucun résultat dans ce pays : proposer les pays qui en ont.
  Widget _buildNoResult(_ImportCountry c) {
    final others = _countries.where((o) => o.code != c.code && (_counts[o.code] ?? 0) > 0).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: c.gradient.first.withValues(alpha: 0.6)),
          const SizedBox(height: 14),
          Text('Aucun résultat pour « $_query » en ${c.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2A3540))),
          const SizedBox(height: 6),
          Text(
            others.isEmpty ? 'Essayez un autre mot, ou un nom plus court.' : 'Disponible ailleurs :',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.4),
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in others)
                  ActionChip(
                    avatar: Text(o.flag),
                    label: Text('${o.name} · ${_counts[o.code]}'),
                    onPressed: () => _selectCountry(o.code),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextButton(onPressed: _clearSearch, child: const Text('Effacer la recherche')),
        ],
      ),
    );
  }

  // ─────────────────────────── Carte produit ───────────────────────────
  Widget _buildProductCard(WholesaleProduct p, _ImportCountry c) {
    final name = p.name;
    final entry = p.entryTier;
    final image = p.image;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => WholesaleOrderSheet.show(product: p, shippingOptions: _shipping, countryFlag: c.flag),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDEFF3)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildProductImage(image),
                    ),
                    // Badge drapeau pays (origine)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.flag, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(c.code,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF33404A))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.25, color: Color(0xFF23303B))),
                    const SizedBox(height: 6),
                    // Prix d'entrée (« à partir de ») + quantité minimale (cota)
                    Text(
                      entry != null
                          ? 'À partir de ${CurrencyService.formatAmountInCurrency(entry.unitPrice, entry.currency)}'
                          : 'Sur devis',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppThemeSystem.primaryColor, fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              entry != null ? 'GROS · min ${entry.minQuantity}' : 'GROS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700, fontSize: 10.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppThemeSystem.primaryColor,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 19),
                        ),
                      ],
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

  Widget _imgPlaceholder() => Container(
        color: const Color(0xFFF1F2F5),
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
          progress == null ? child : Container(color: const Color(0xFFF1F2F5)),
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
