import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/import_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/models/wholesale_models.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/values/constants.dart';
import 'wholesale_order_sheet.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/masonry_grid.dart';
import '../../../core/widgets/app_ui.dart';

/// Catalogue de gros, présenté comme un mur d'images.
///
/// L'écran s'ouvre sur les produits de tous les pays d'origine mélangés :
/// c'est le catalogue qui accueille, pas un formulaire. La recherche et le
/// filtre par pays restent accessibles en haut, dans une barre qui s'efface
/// dès qu'on descend dans la grille.
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

/// Nom de pays tenant dans une pastille étroite.
///
/// Le backend préfixe certains libellés de la marque (« ASSO Turquie ») :
/// utile dans un back-office, encombrant dans une rangée où chaque pastille
/// n'a qu'un quart de l'écran.
@visibleForTesting
String shortImportCountryName(String name) {
  final trimmed = name.trim();
  const prefix = 'ASSO ';
  return trimmed.toUpperCase().startsWith(prefix) &&
          trimmed.length > prefix.length
      ? trimmed.substring(prefix.length).trim()
      : trimmed;
}

/// Un produit et le pays dont il provient.
///
/// La grille mêlant plusieurs origines, chaque tuile doit savoir d'où elle
/// vient : pour afficher son drapeau, et surtout pour ouvrir la commande avec
/// les bonnes options d'expédition — elles diffèrent d'un pays à l'autre.
class _CatalogEntry {
  const _CatalogEntry({
    required this.product,
    required this.country,
    required this.shipping,
  });

  final WholesaleProduct product;
  final _ImportCountry country;
  final List<ShippingOption> shipping;
}

/// Filtre pays en vigueur. `null` = tous les pays.
const String _allCountries = '';

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
  List<_ImportCountry> _countries = _mapCountries(
    ProductService.importCountriesFallback,
  );

  /// Code pays filtré, ou [_allCountries] pour le mur complet.
  String _selected = _allCountries;
  bool _loading = true;

  /// Produits de tous les pays, dans l'ordre d'affichage.
  List<_CatalogEntry> _entries = [];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _query = '';
  Map<String, int> _counts = {};
  int _loadRequest = 0;

  /// La barre de recherche se replie quand on descend dans la grille.
  bool _chromeVisible = true;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Masque le chrome vers le bas, le rappelle vers le haut.
  ///
  /// Le seuil évite qu'un micro-mouvement du doigt ne fasse clignoter la
  /// barre ; près du sommet elle reste toujours visible.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final delta = offset - _lastOffset;

    if (offset <= 8) {
      if (!_chromeVisible) setState(() => _chromeVisible = true);
      _lastOffset = offset;
      return;
    }

    if (delta > 12 && _chromeVisible) {
      setState(() => _chromeVisible = false);
      _lastOffset = offset;
    } else if (delta < -12 && !_chromeVisible) {
      setState(() => _chromeVisible = true);
      _lastOffset = offset;
    }
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

  /// Charge la liste des pays depuis le backend, puis les produits.
  Future<void> _init() async {
    final loaded = await ProductService.getImportCountries();
    if (mounted && loaded.isNotEmpty) {
      setState(() => _countries = _mapCountries(loaded));
    }
    await _load();
  }

  /// Charge le catalogue.
  ///
  /// Sans filtre pays, les catalogues sont demandés en parallèle puis
  /// entrelacés — un pays après l'autre — pour que le mur ne commence pas par
  /// vingt articles chinois avant le premier turc.
  Future<void> _load() async {
    final request = ++_loadRequest;
    setState(() => _loading = true);

    final targets = _selected == _allCountries
        ? _countries
        : _countries.where((c) => c.code == _selected).toList();

    List<_CatalogEntry> entries = [];
    Map<String, int> counts = {};

    try {
      final catalogs = await Future.wait([
        for (final country in targets)
          ImportService.getCatalog(country.code, query: _query),
      ]);

      // Une liste par pays, puis tour de table jusqu'à épuisement.
      final perCountry = <List<_CatalogEntry>>[];
      for (var i = 0; i < targets.length; i++) {
        final catalog = catalogs[i];
        if (catalog == null) continue;
        final country = targets[i];
        perCountry.add([
          for (final product in catalog.products)
            _CatalogEntry(
              product: product,
              country: country,
              shipping: catalog.shippingOptions,
            ),
        ]);
      }

      final longest = perCountry.fold<int>(
        0,
        (max, list) => list.length > max ? list.length : max,
      );
      for (var row = 0; row < longest; row++) {
        for (final list in perCountry) {
          if (row < list.length) entries.add(list[row]);
        }
      }

      if (_query.isNotEmpty) {
        counts = await ImportService.searchCounts(_query);
      }
    } catch (_) {}

    if (!mounted || request != _loadRequest) return;
    setState(() {
      _entries = entries;
      _counts = counts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.ds.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildChrome(),
            Expanded(
              child: RefreshIndicator(
                color: AppDesign.accent,
                onRefresh: _load,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_loading)
                      _buildSkeletonGrid()
                    else if (_entries.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmpty(),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          AppDesign.space3,
                          AppDesign.space3,
                          AppDesign.space3,
                          AppDesign.space6,
                        ),
                        sliver: SliverMasonryGrid(
                          itemCount: _entries.length,
                          crossAxisSpacing: AppDesign.space2,
                          mainAxisSpacing: AppDesign.space2,
                          itemBuilder: (_, i) => _buildTile(_entries[i]),
                        ),
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

  // ─────────────────────────── Chrome repliable ───────────────────────────

  /// Recherche et filtres pays, repliés dès qu'on descend dans la grille.
  Widget _buildChrome() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _chromeVisible
          ? Container(
              color: context.ds.canvas,
              padding: EdgeInsets.fromLTRB(
                AppDesign.space3,
                AppDesign.space2,
                AppDesign.space3,
                AppDesign.space2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchField(),
                  SizedBox(height: AppDesign.space2),
                  _buildCountryFilters(),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        onSubmitted: (v) {
          _searchDebounce?.cancel();
          setState(() => _query = v.trim());
          _load();
        },
        textInputAction: TextInputAction.search,
        style: context.textStyle(
          FontSizeType.body2,
          color: context.ds.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher dans le catalogue',
          hintStyle: context.textStyle(
            FontSizeType.body2,
            color: context.ds.textTertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: context.ds.textTertiary,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: context.ds.textTertiary,
                  onPressed: _clearSearch,
                ),
          filled: true,
          fillColor: context.ds.surface,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          // Pilule pleine : la barre se lit comme un champ de recherche et non
          // comme un formulaire à remplir.
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            borderSide: BorderSide(color: context.ds.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            borderSide: BorderSide(color: context.ds.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            borderSide: const BorderSide(color: AppDesign.accent, width: 1.4),
          ),
        ),
      ),
    );
  }

  /// Pastilles de filtrage : « Tous » d'abord, puis chaque pays.
  /// Filtres pays occupant toute la largeur, comme un segmenté.
  ///
  /// Les origines sont peu nombreuses et ne changent pas : les étaler plutôt
  /// que les faire défiler montre d'emblée tout le choix, et chaque cible
  /// devient plus large donc plus facile à viser.
  Widget _buildCountryFilters() {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: _filterChip(
              label: 'Tous',
              selected: _selected == _allCountries,
              onTap: () => _selectCountry(_allCountries),
            ),
          ),
          for (final c in _countries) ...[
            SizedBox(width: AppDesign.space2),
            Expanded(
              child: _filterChip(
                label: shortImportCountryName(c.name),
                flag: c.flag,
                // En recherche, le nombre de résultats par pays aide à choisir.
                count: _query.isEmpty ? null : (_counts[c.code] ?? 0),
                selected: c.code == _selected,
                onTap: () => _selectCountry(c.code),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? flag,
    int? count,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: AppDesign.space2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppDesign.accentSubtle : context.ds.surface,
          borderRadius: BorderRadius.circular(AppDesign.radiusPill),
          border: Border.all(
            color: selected ? AppDesign.accentBorder : context.ds.border,
          ),
        ),
        // La pastille occupe une part fixe de la rangée : le libellé doit
        // pouvoir se rétracter plutôt que déborder sur un téléphone étroit.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag != null) ...[
              Text(flag, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppDesign.accentText
                      : context.ds.textSecondary,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: context.textStyle(
                  FontSizeType.overline,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppDesign.accentText
                      : context.ds.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Tuile ───────────────────────────

  /// Tuile du mur : l'image d'abord, le texte réduit à l'essentiel.
  ///
  /// La hauteur suit les proportions réelles de la photo — c'est ce décalage
  /// entre colonnes qui donne son rythme à la page, là où une grille carrée
  /// uniformise tout.
  Widget _buildTile(_CatalogEntry entry) {
    final p = entry.product;
    final tier = p.entryTier;

    void open() => WholesaleOrderSheet.show(
      product: p,
      shippingOptions: entry.shipping,
      countryFlag: entry.country.flag,
    );

    // Format propre à l'article, stable d'une ouverture à l'autre.
    final aspectRatio = masonryAspectRatioFor(p.id);

    return Material(
      color: context.ds.surface,
      borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: aspectRatio,
                  child: SizedBox(
                    width: double.infinity,
                    // `cover` : la photo remplit le format imposé, quitte à
                    // être rognée — mieux vaut cela que des bandes vides.
                    child: _buildProductImage(p.image, fit: BoxFit.cover),
                  ),
                ),
                // Drapeau d'origine : dans un mur qui mêle les pays, c'est
                // l'information qui situe l'article d'un coup d'œil.
                Positioned(
                  left: AppDesign.space2,
                  top: AppDesign.space2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppDesign.neutral900.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                    ),
                    child: Text(
                      entry.country.flag,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDesign.space2,
                AppDesign.space2,
                AppDesign.space2,
                AppDesign.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.caption,
                      fontWeight: FontWeight.w600,
                      color: context.ds.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: AppDesign.space1),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tier == null
                              ? '—'
                              : CurrencyService.formatAmountInCurrency(
                                  tier.unitPrice,
                                  tier.currency,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyle(
                            FontSizeType.body2,
                            fontWeight: FontWeight.w700,
                            color: context.ds.textPrimary,
                          ),
                        ),
                      ),
                      if (tier != null)
                        Text(
                          '×${tier.minQuantity}',
                          style: context.textStyle(
                            FontSizeType.overline,
                            fontWeight: FontWeight.w600,
                            color: context.ds.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Chargement ───────────────────────────

  Widget _buildSkeletonGrid() {
    // Les mêmes formats que la grille réelle, pris sur des identifiants
    // fictifs : le squelette annonce exactement le décalage qui va le
    // remplacer, sinon la page « saute » au chargement.
    final ratios = [for (var i = 0; i < 8; i++) masonryAspectRatioFor(i)];

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AppDesign.space3,
        AppDesign.space3,
        AppDesign.space3,
        AppDesign.space6,
      ),
      sliver: SliverMasonryGrid(
        itemCount: ratios.length,
        crossAxisSpacing: AppDesign.space2,
        mainAxisSpacing: AppDesign.space2,
        itemBuilder: (_, i) => _skeletonTile(ratios[i]),
      ),
    );
  }

  Widget _skeletonTile(double imageAspectRatio) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.ds.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDesign.space1),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Le squelette vit dans une colonne de hauteur libre : sa taille vient
        // de son contenu, il ne peut pas s'étirer dans une case imposée.
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: imageAspectRatio,
            child: ColoredBox(color: context.ds.surfaceMuted),
          ),
          Padding(
            padding: EdgeInsets.all(AppDesign.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(double.infinity, 10),
                SizedBox(height: AppDesign.space2),
                bar(70, 10),
                SizedBox(height: AppDesign.space2),
                bar(50, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── États vides ───────────────────────────

  Widget _buildEmpty() {
    if (_query.isNotEmpty) return _buildNoResult();

    final scope = _selected == _allCountries
        ? 'le catalogue'
        : _countries
              .firstWhere(
                (c) => c.code == _selected,
                orElse: () => _countries.first,
              )
              .name;

    return AppEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Catalogue vide',
      message:
          'Aucun article dans $scope pour le moment. De nouveaux produits importés arrivent régulièrement.',
      actionLabel: 'Actualiser',
      onAction: _load,
    );
  }

  /// Aucun résultat : proposer les pays qui en ont.
  Widget _buildNoResult() {
    final others = _countries
        .where((o) => o.code != _selected && (_counts[o.code] ?? 0) > 0)
        .toList();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.ds.gutter,
        vertical: AppDesign.space6,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: context.ds.textTertiary,
          ),
          SizedBox(height: AppDesign.space3),
          Text(
            'Aucun résultat pour « $_query »',
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.subtitle1,
              fontWeight: FontWeight.w700,
              color: context.ds.textPrimary,
            ),
          ),
          SizedBox(height: AppDesign.space2),
          Text(
            others.isEmpty
                ? 'Essayez un autre mot, ou un nom plus court.'
                : 'Disponible ailleurs :',
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.body2,
              color: context.ds.textSecondary,
              height: 1.4,
            ),
          ),
          if (others.isNotEmpty) ...[
            SizedBox(height: AppDesign.space3),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppDesign.space2,
              runSpacing: AppDesign.space2,
              children: [
                for (final o in others)
                  // Hors de la rangée, la pastille n'hérite d'aucune hauteur :
                  // on la lui donne pour qu'elle garde la même allure.
                  SizedBox(
                    height: 34,
                    child: _filterChip(
                      label:
                          '${shortImportCountryName(o.name)} · ${_counts[o.code]}',
                      flag: o.flag,
                      selected: false,
                      onTap: () => _selectCountry(o.code),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── Images ───────────────────────────

  Widget _imgPlaceholder() => ColoredBox(
    color: context.ds.surfaceMuted,
    child: Center(
      child: Icon(
        Icons.image_outlined,
        color: context.ds.textTertiary,
        size: 32,
      ),
    ),
  );

  Widget _buildProductImage(String? path, {BoxFit fit = BoxFit.contain}) {
    if (path == null || path.trim().isEmpty) return _imgPlaceholder();
    final value = path.trim();
    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: fit,
        errorBuilder: (_, _, _) => _imgPlaceholder(),
      );
    }

    return Image.network(
      _imageUrlForDevice(value),
      fit: fit,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : ColoredBox(color: context.ds.surfaceMuted),
      errorBuilder: (_, _, _) => _imgPlaceholder(),
    );
  }

  String _imageUrlForDevice(String value) {
    final apiUri = Uri.parse(AppConstants.baseUrl);
    final imageUri = Uri.tryParse(value);
    if (imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty) {
      final normalizedPath = imageUri.path.replaceFirst(
        '/storage/storage/',
        '/storage/',
      );
      if (imageUri.host == 'localhost' || imageUri.host == '127.0.0.1') {
        return imageUri
            .replace(host: apiUri.host, port: apiUri.port, path: normalizedPath)
            .toString();
      }
      return imageUri.replace(path: normalizedPath).toString();
    }

    final path = (value.startsWith('/') ? value : '/$value').replaceFirst(
      '/storage/storage/',
      '/storage/',
    );
    return Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.port,
      path: path.startsWith('/storage/') ? path : '/storage$path',
    ).toString();
  }
}
