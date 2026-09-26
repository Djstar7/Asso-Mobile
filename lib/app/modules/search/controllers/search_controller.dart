import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/models/wholesale_models.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/import_service.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/currency_service.dart';

/// Les deux familles de résultats de la recherche.
///
/// L'application vend deux choses très différentes — des articles et du
/// transport de bagage — et les mélanger dans une même liste obligerait
/// l'utilisateur à trier lui-même.
enum SearchScope { products, passcolis }

/// Un article de gros proposé dans le mur de recherche.
///
/// Il garde ce qu'il faut pour ouvrir sa fiche : les options d'expédition et
/// le drapeau dépendent du pays d'origine, pas du produit.
class SearchWholesaleEntry {
  const SearchWholesaleEntry({
    required this.product,
    required this.countryFlag,
    required this.shippingOptions,
  });

  final WholesaleProduct product;
  final String countryFlag;
  final List<ShippingOption> shippingOptions;
}

/// Une tuile du mur de recherche.
sealed class SearchFeedItem {
  const SearchFeedItem();
}

/// Produit du catalogue local, tel que renvoyé par `/products`.
class LocalFeedItem extends SearchFeedItem {
  const LocalFeedItem(this.product);
  final Map<String, dynamic> product;
}

/// Article de gros (Import), souvent accompagné d'une vidéo.
class WholesaleFeedItem extends SearchFeedItem {
  const WholesaleFeedItem(this.entry);
  final SearchWholesaleEntry entry;
}

/// Intercale les articles de gros dans les produits locaux.
///
/// Un article de gros suit chaque groupe de [every] produits locaux, pour
/// que les vidéos apparaissent dès le premier écran sans noyer le catalogue
/// local. Le reste n'est ajouté qu'une fois le catalogue local épuisé
/// ([localComplete]) : avant, il reste des pages à charger entre eux.
///
/// Le résultat ne dépend que de l'ordre des listes : ajouter une page de
/// produits locaux prolonge le mur sans déplacer les tuiles déjà posées.
List<SearchFeedItem> mixSearchFeed(
  List<Map<String, dynamic>> local,
  List<SearchWholesaleEntry> wholesale, {
  required bool localComplete,
  int every = 3,
}) {
  final feed = <SearchFeedItem>[];
  var next = 0;

  for (var i = 0; i < local.length; i++) {
    feed.add(LocalFeedItem(local[i]));
    if ((i + 1) % every == 0 && next < wholesale.length) {
      feed.add(WholesaleFeedItem(wholesale[next++]));
    }
  }

  if (localComplete) {
    while (next < wholesale.length) {
      feed.add(WholesaleFeedItem(wholesale[next++]));
    }
  }

  return feed;
}

/// Ordonne les articles de gros de plusieurs pays.
///
/// Les vidéos passent devant dans chaque pays : ce sont elles qui font vivre
/// le mur. Puis un pays après l'autre, pour que le mur ne commence pas par
/// vingt articles chinois avant le premier turc.
List<SearchWholesaleEntry> interleaveWholesale(
  List<List<SearchWholesaleEntry>> perCountry,
) {
  final ordered = [
    for (final list in perCountry)
      [
        ...list.where((e) => e.product.video != null),
        ...list.where((e) => e.product.video == null),
      ],
  ];

  final longest = ordered.fold<int>(
    0,
    (max, l) => l.length > max ? l.length : max,
  );
  return [
    for (var row = 0; row < longest; row++)
      for (final list in ordered)
        if (row < list.length) list[row],
  ];
}

/// État d'un mur de résultats : le catalogue complet, ou une recherche.
///
/// Les deux murs sont gardés séparément : effacer la recherche retrouve le
/// catalogue tel qu'on l'avait laissé, sans le recharger, et la pagination
/// de l'un ne décale plus celle de l'autre.
class SearchWall {
  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  final RxList<SearchWholesaleEntry> wholesale = <SearchWholesaleEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxBool loadFailed = false.obs;

  /// Nombre total de produits locaux annoncé par le serveur.
  final RxInt total = 0.obs;

  /// Requête à laquelle correspondent les résultats affichés.
  final RxString query = ''.obs;

  /// Requête en cours de chargement.
  String loadingQuery = '';

  /// Version des filtres avec laquelle le mur a été chargé.
  int filtersVersion = -1;

  int page = 1;

  /// Incrémenté à chaque chargement : une réponse d'un chargement dépassé
  /// (saisie plus rapide que le réseau) est ignorée au lieu d'écraser la
  /// plus récente.
  int request = 0;

  void cancel() {
    request++;
    isLoading.value = false;
    isLoadingMore.value = false;
  }
}

class SearchController extends GetxController {
  // ================================
  // SERVICES ET STORAGE
  // ================================
  final _storage = GetStorage();
  final TextEditingController searchTextController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final TextEditingController minPriceController = TextEditingController();
  final TextEditingController maxPriceController = TextEditingController();

  static const int _pageSize = 20;
  static const double _priceCap = 1000000.0;

  // ================================
  // MURS DE PRODUITS
  // ================================
  final SearchWall _allWall = SearchWall();
  final SearchWall _searchWall = SearchWall();

  /// Mur affiché : la recherche dès qu'un texte est saisi.
  SearchWall get wall =>
      searchQuery.value.trim().isEmpty ? _allWall : _searchWall;

  RxList<Map<String, dynamic>> get allProducts => _allWall.products;
  RxList<Map<String, dynamic>> get searchResults => _searchWall.products;

  /// Produits locaux du mur affiché.
  RxList<Map<String, dynamic>> get displayedProducts => wall.products;

  RxBool get isLoading => wall.isLoading;
  RxBool get isLoadingMore => wall.isLoadingMore;
  RxBool get hasMore => wall.hasMore;

  /// Articles de gros par requête, pour qu'un retour sur une recherche
  /// récente (historique, onglet) ne relance pas les appels par pays.
  final Map<String, List<SearchWholesaleEntry>> _wholesaleCache = {};
  static const int _wholesaleCacheSize = 12;
  List<Map<String, String>>? _importCountries;

  // ================================
  // DONNÉES PASSCOLIS (offres Diaspo)
  // ================================
  final RxList<DiaspoOffer> passcolisOffers = <DiaspoOffer>[].obs;
  final RxBool isLoadingPasscolis = false.obs;
  final RxBool passcolisLoadFailed = false.obs;
  bool _passcolisLoaded = false;

  /// Onglet actif : produits ou passcolis.
  final Rx<SearchScope> scope = SearchScope.products.obs;

  // ================================
  // ÉTAT DE LA RECHERCHE
  // ================================
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxBool showFilters = false.obs;
  final RxBool hasFocus = false.obs;

  /// Onglets et catégories, repliés quand on descend dans le mur pour lui
  /// laisser l'écran ; le champ de recherche, lui, reste.
  final RxBool chromeVisible = true.obs;

  // ================================
  // FILTRES
  // ================================
  final RxInt selectedCategoryId = 0.obs;
  final RxString selectedCategory = ''.obs;
  final RxDouble minPrice = 0.0.obs;
  final RxDouble maxPrice = _priceCap.obs;
  final RxDouble currentMinPrice = 0.0.obs;
  final RxDouble currentMaxPrice = _priceCap.obs;
  final RxString selectedLocation = 'Toutes les villes'.obs;
  final RxString sortBy = 'created_at'.obs;
  final RxString sortOrder = 'desc'.obs;

  /// Incrémentée à chaque changement de filtre ou de tri : un mur chargé
  /// avec une version antérieure est à recharger avant d'être réaffiché.
  int _filtersVersion = 0;

  // ================================
  // TRI
  // ================================
  final Rx<SortOption> selectedSortOption = SortOption.relevance.obs;

  // ================================
  // CATÉGORIES DISPONIBLES
  // ================================
  final RxList<Map<String, dynamic>> apiCategories =
      <Map<String, dynamic>>[].obs;
  final RxList<String> categories = <String>['Tous'].obs;

  // ================================
  // VILLES DISPONIBLES
  // ================================
  final List<String> cities = [
    'Toutes les villes',
    'Douala',
    'Yaoundé',
    'Bafoussam',
    'Bamenda',
    'Garoua',
  ];

  // ================================
  // HISTORIQUE DE RECHERCHE
  // ================================
  final RxList<String> searchHistory = <String>[].obs;
  final int maxHistoryItems = 10;

  // ================================
  // SUGGESTIONS
  // ================================
  final RxList<String> suggestions = <String>[].obs;

  // ================================
  // NOMBRE DE FILTRES ACTIFS
  // ================================
  int get activeFiltersCount {
    int count = 0;
    if (selectedCategory.value.isNotEmpty && selectedCategory.value != 'Tous') {
      count++;
    }
    if (currentMinPrice.value > 0 || currentMaxPrice.value < _priceCap) count++;
    if (selectedLocation.value != 'Toutes les villes') count++;
    return count;
  }

  // ================================
  // BACKWARD COMPATIBILITY GETTERS
  // ================================
  /// Returns searchResults (for backward compatibility)
  RxList<Map<String, dynamic>> get filteredProducts => searchResults;

  // ================================
  // MUR MIXTE (local + gros)
  // ================================

  /// Les articles de gros n'ont ni catégorie du catalogue local, ni prix en
  /// FCFA comparable (paliers dans la devise du pays), ni date commune : dès
  /// qu'un filtre ou un tri porte sur l'un de ces critères, les intercaler
  /// fausserait le résultat promis. Ils ne rejoignent que le mur par défaut.
  bool get wholesaleApplies =>
      selectedCategoryId.value == 0 &&
      currentMinPrice.value <= 0 &&
      currentMaxPrice.value >= _priceCap &&
      sortBy.value == 'created_at' &&
      sortOrder.value == 'desc';

  /// Tuiles du mur affiché, dans l'ordre.
  List<SearchFeedItem> get feed {
    final current = wall;
    return mixSearchFeed(
      current.products,
      wholesaleApplies ? current.wholesale : const [],
      localComplete: !current.hasMore.value,
    );
  }

  /// Nombre de résultats du mur, pages non chargées comprises.
  int get resultCount {
    final current = wall;
    return current.total.value +
        (wholesaleApplies ? current.wholesale.length : 0);
  }

  /// Texte saisi dont les résultats ne sont pas encore arrivés (attente du
  /// debounce ou de la réponse). Tant que c'est le cas, un mur vide n'est
  /// pas un « aucun résultat ».
  bool get isSearchPending {
    final query = searchQuery.value.trim();
    return query.isNotEmpty && _searchWall.query.value != query;
  }

  // ================================
  // PASSCOLIS
  // ================================

  /// Offres correspondant au texte saisi.
  ///
  /// Le filtrage est local : le catalogue de trajets est court, et l'API ne
  /// sait filtrer que par ville ou pays pris séparément, alors que
  /// l'utilisateur tape indifféremment « Douala » ou « Cameroun ».
  List<DiaspoOffer> get filteredPasscolis {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return passcolisOffers;

    return passcolisOffers.where((offer) {
      return offer.departureCity.toLowerCase().contains(query) ||
          offer.departureCountry.toLowerCase().contains(query) ||
          offer.arrivalCity.toLowerCase().contains(query) ||
          offer.arrivalCountry.toLowerCase().contains(query);
    }).toList();
  }

  /// Bascule d'onglet. Les passcolis ne sont chargés qu'à la première
  /// ouverture de leur onglet : inutile d'appeler l'API pour quelqu'un qui
  /// ne cherche que des produits.
  void changeScope(SearchScope value) {
    if (scope.value == value) return;
    scope.value = value;
    chromeVisible.value = true;

    if (value == SearchScope.passcolis && !_passcolisLoaded) {
      loadPasscolisOffers();
    }
  }

  Future<void> loadPasscolisOffers({bool isRefresh = false}) async {
    if (isLoadingPasscolis.value) return;
    if (isRefresh) _passcolisLoaded = false;

    isLoadingPasscolis.value = true;
    passcolisLoadFailed.value = false;

    try {
      if (!Get.isRegistered<DiaspoService>()) {
        Get.put(DiaspoService());
      }

      final response = await Get.find<DiaspoService>().getOffers(perPage: 50);

      if (response['success'] == true) {
        final list = response['data']?['data'] as List? ?? [];
        passcolisOffers.value = list
            .map((json) => DiaspoOffer.fromJson(json))
            .toList();
        _passcolisLoaded = true;
      } else {
        passcolisLoadFailed.value = true;
      }
    } catch (e) {
      passcolisLoadFailed.value = true;
      debugPrint('Erreur chargement passcolis: $e');
    } finally {
      isLoadingPasscolis.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    minPriceController.text = minPrice.value > 0
        ? minPrice.value.toInt().toString()
        : '';
    maxPriceController.text = maxPrice.value > 0
        ? maxPrice.value.toInt().toString()
        : '';
    _loadSearchHistory();
    _loadCategories();
    _setupSearchListener();
    _setupFocusListener();

    // Check if category filter was passed in arguments
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      // Ouverture directe sur l'onglet Passcolis (« Voir tout » de l'accueil).
      if (args['tab'] == 'passcolis') {
        scope.value = SearchScope.passcolis;
        loadPasscolisOffers();
      }

      final categoryId = args['categoryId'] as int?;
      final categoryName = args['categoryName'] as String?;

      if (categoryId != null) {
        selectedCategoryId.value = categoryId;
        if (categoryName != null) {
          selectedCategory.value = categoryName;
        }
        _filtersVersion++;
      }
    }

    // Charger tous les produits par défaut
    loadAllProducts();
  }

  @override
  void onClose() {
    searchTextController.dispose();
    searchFocusNode.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.onClose();
  }

  // ================================
  // CHARGEMENT DES DONNÉES
  // ================================

  /// Recharge le catalogue complet (mur affiché sans recherche).
  Future<void> loadAllProducts({bool isRefresh = false}) {
    if (isRefresh) _wholesaleCache.clear();
    return _reload(_allWall, '');
  }

  /// Tire pour rafraîchir le mur affiché.
  Future<void> refreshWall() {
    _wholesaleCache.clear();
    final query = searchQuery.value.trim();
    return _reload(query.isEmpty ? _allWall : _searchWall, query);
  }

  /// Charge la première page d'un mur : produits locaux et articles de gros
  /// en parallèle, affichés ensemble.
  ///
  /// Les poser en deux temps ferait sauter le mur : chaque article de gros
  /// arrivé après coup s'intercalerait entre des tuiles déjà visibles.
  Future<void> _reload(SearchWall target, String query) async {
    final request = ++target.request;
    final filtersVersion = _filtersVersion;
    target.isLoading.value = true;
    target.isLoadingMore.value = false;
    target.loadingQuery = query;

    final withWholesale = wholesaleApplies;

    try {
      final (page, wholesale) = await (
        _fetchLocalPage(page: 1, query: query),
        withWholesale
            ? _fetchWholesale(query)
            : Future.value(const <SearchWholesaleEntry>[]),
      ).wait;

      if (request != target.request) return;

      if (page == null) {
        // Échec sur une autre requête : ses anciens résultats ne répondent
        // pas à la nouvelle, mieux vaut un état d'erreur qu'un faux résultat.
        if (target.query.value != query) {
          target.products.clear();
          target.wholesale.clear();
          target.total.value = 0;
        } else if (target.products.isNotEmpty) {
          _showError('Impossible de rafraîchir les produits');
        }
        target.query.value = query;
        target.loadFailed.value = true;
        return;
      }

      target
        ..page = 1
        ..filtersVersion = filtersVersion;
      target.loadFailed.value = false;
      target.products.assignAll(page.products);
      target.wholesale.assignAll(wholesale);
      target.total.value = page.total;
      target.hasMore.value = page.hasMore;
      target.query.value = query;
    } finally {
      if (request == target.request) target.isLoading.value = false;
    }
  }

  /// Une page du catalogue local, ou null si l'appel a échoué.
  Future<({List<Map<String, dynamic>> products, bool hasMore, int total})?>
  _fetchLocalPage({required int page, required String query}) async {
    try {
      final response = await ProductService.getProducts(
        page: page,
        perPage: _pageSize,
        search: query.isEmpty ? null : query,
        categoryId: selectedCategoryId.value > 0
            ? selectedCategoryId.value
            : null,
        minPrice: currentMinPrice.value > 0 ? currentMinPrice.value : null,
        maxPrice: currentMaxPrice.value < _priceCap
            ? currentMaxPrice.value
            : null,
        sortBy: sortBy.value,
        sortOrder: sortOrder.value,
      );

      if (!response.success || response.data == null) return null;

      final products = response.data!['products'] as List? ?? [];
      final pagination =
          response.data!['pagination'] as Map<String, dynamic>? ?? {};

      return (
        products: products
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList(),
        hasMore: pagination['has_more'] == true,
        total: (pagination['total'] as num?)?.toInt() ?? products.length,
      );
    } catch (e) {
      debugPrint('[Search] chargement des produits impossible : $e');
      return null;
    }
  }

  /// Articles de gros de tous les pays d'import pour [query].
  ///
  /// Les pays sont interrogés en parallèle ; un pays qui ne répond pas ne
  /// prive pas le mur des autres. Jamais d'exception : sans articles de
  /// gros, le mur reste celui du catalogue local.
  Future<List<SearchWholesaleEntry>> _fetchWholesale(String query) async {
    final key = query.toLowerCase();
    final cached = _wholesaleCache[key];
    if (cached != null) return cached;

    try {
      final countries = _importCountries ??=
          await ProductService.getImportCountries();

      final catalogs = await Future.wait([
        for (final country in countries)
          ImportService.getCatalog(
            country['code']!,
            query: query,
          ).catchError((_) => null),
      ]);

      final perCountry = <List<SearchWholesaleEntry>>[];
      for (var i = 0; i < countries.length; i++) {
        final catalog = catalogs[i];
        if (catalog == null) continue;
        final flag = catalog.countryFlag.isNotEmpty
            ? catalog.countryFlag
            : (countries[i]['flag'] ?? '');
        perCountry.add([
          for (final product in catalog.products)
            SearchWholesaleEntry(
              product: product,
              countryFlag: flag,
              shippingOptions: catalog.shippingOptions,
            ),
        ]);
      }

      final entries = interleaveWholesale(perCountry);

      // Un échec de tous les pays n'est pas un « aucun article » : on ne le
      // retient pas, le prochain passage réessaiera.
      if (perCountry.isNotEmpty) {
        if (_wholesaleCache.length >= _wholesaleCacheSize) {
          _wholesaleCache.remove(_wholesaleCache.keys.first);
        }
        _wholesaleCache[key] = entries;
      }
      return entries;
    } catch (e) {
      debugPrint('[Search] articles de gros indisponibles : $e');
      return const [];
    }
  }

  /// Charge les catégories depuis l'API
  Future<void> _loadCategories() async {
    try {
      final response = await ProductService.getCategories();
      if (response.success && response.data != null) {
        final cats = response.data!['categories'] as List? ?? [];
        apiCategories.value = cats
            .map((c) => Map<String, dynamic>.from(c))
            .toList();

        // Build category names list
        categories.clear();
        categories.add('Tous');
        for (var cat in apiCategories) {
          categories.add(cat['name'] ?? '');
        }
      }
    } catch (e) {
      // Use fallback categories
      categories.value = [
        'Tous',
        'Vêtements',
        'Électronique',
        'Accessoires',
        'Maison',
        'Sport',
        'Beauté',
        'Livres',
        'Autres',
      ];
    }
  }

  // ================================
  // RECHERCHE
  // ================================

  /// Configure l'écoute des changements de texte
  void _setupSearchListener() {
    // Debounce pour éviter une requête par lettre tapée.
    debounce(searchQuery, (_) {
      if (searchQuery.value.trim().isNotEmpty) {
        _search();
      } else {
        // Texte effacé au clavier : une réponse encore en route ne doit plus
        // rien afficher, et le catalogue peut avoir changé de filtres entre-temps.
        _searchWall.cancel();
        _refreshAllWallIfStale();
      }
    }, time: const Duration(milliseconds: 350));
  }

  /// Configure l'écoute des changements de focus
  void _setupFocusListener() {
    searchFocusNode.addListener(() {
      hasFocus.value = searchFocusNode.hasFocus;
    });
  }

  /// Effectue la recherche (appelé depuis l'historique ou suggestions)
  void performSearch(String query) {
    searchQuery.value = query;
    searchTextController.text = query;
    isSearching.value = query.isNotEmpty;

    // Ajouter à l'historique et lancer immédiatement (sans debounce)
    if (query.trim().isNotEmpty) {
      _addToSearchHistory(query.trim());
      _search();
    }

    // Masquer le focus du champ de recherche
    searchFocusNode.unfocus();
  }

  /// Lance la recherche du texte saisi, sauf si ses résultats sont déjà là
  /// ou en route — la validation au clavier suit souvent de près le debounce.
  void _search() {
    final query = searchQuery.value.trim();
    if (query.isEmpty) return;

    final target = _searchWall;
    final upToDate = target.filtersVersion == _filtersVersion;
    if (target.isLoading.value && target.loadingQuery == query) return;
    if (!target.isLoading.value &&
        !target.loadFailed.value &&
        upToDate &&
        target.query.value == query) {
      return;
    }

    chromeVisible.value = true;
    _reload(target, query);
  }

  /// Efface la recherche
  void clearSearch() {
    searchQuery.value = '';
    searchTextController.clear();
    isSearching.value = false;
    suggestions.clear();

    // Le mur de recherche repart de zéro : une nouvelle saisie ne doit pas
    // montrer, le temps de charger, les résultats d'une recherche sans rapport.
    _searchWall
      ..cancel()
      ..filtersVersion = -1;
    _searchWall.products.clear();
    _searchWall.wholesale.clear();
    _searchWall.total.value = 0;
    _searchWall.query.value = '';
    _searchWall.loadFailed.value = false;

    chromeVisible.value = true;
    _refreshAllWallIfStale();
  }

  /// Le catalogue a été chargé avec d'anciens filtres : on le recharge avant
  /// de le réafficher.
  void _refreshAllWallIfStale() {
    if (_allWall.filtersVersion != _filtersVersion &&
        !_allWall.isLoading.value) {
      _reload(_allWall, '');
    }
  }

  /// Réessaie après un échec de chargement.
  void retry() {
    final query = searchQuery.value.trim();
    _reload(query.isEmpty ? _allWall : _searchWall, query);
  }

  // ================================
  // FILTRES ET PAGINATION
  // ================================

  /// Charge la page suivante du mur affiché.
  Future<void> loadMore() async {
    final target = wall;
    if (!target.hasMore.value ||
        target.isLoading.value ||
        target.isLoadingMore.value ||
        target.loadFailed.value) {
      return;
    }
    // Nouvelle saisie en attente : la page suivante serait celle de
    // l'ancienne requête.
    if (target.query.value != searchQuery.value.trim()) return;

    final request = target.request;
    target.isLoadingMore.value = true;

    try {
      final page = await _fetchLocalPage(
        page: target.page + 1,
        query: target.query.value,
      );
      if (request != target.request || page == null) return;

      // Un produit publié entre deux pages décale la pagination : le dernier
      // de la page précédente revient en tête de la suivante. Les annonces,
      // elles, peuvent légitimement reprendre un produit déjà listé.
      final seen = {
        for (final p in target.products)
          if (p['is_sponsored'] != true) p['id'],
      };
      target.page++;
      target.products.addAll(
        page.products.where(
          (p) => p['is_sponsored'] == true || !seen.contains(p['id']),
        ),
      );
      target.hasMore.value = page.hasMore;
    } finally {
      if (request == target.request) target.isLoadingMore.value = false;
    }
  }

  /// Un filtre ou le tri a changé : on recharge le mur affiché, l'autre le
  /// sera quand on y reviendra.
  void _onFiltersChanged() {
    _filtersVersion++;
    final query = searchQuery.value.trim();
    _reload(query.isEmpty ? _allWall : _searchWall, query);
  }

  /// Change la catégorie
  void selectCategory(String category) {
    selectedCategory.value = category;

    // Update category ID based on selected category name
    if (category == 'Tous' || category.isEmpty) {
      selectedCategoryId.value = 0;
    } else {
      final cat = apiCategories.firstWhereOrNull((c) => c['name'] == category);
      selectedCategoryId.value = cat?['id'] ?? 0;
    }

    _onFiltersChanged();
  }

  /// Fixe et applique une plage de prix.
  void setPriceRange(double min, double max) {
    minPrice.value = min;
    maxPrice.value = max;
    applyPriceFilters();
  }

  /// Applique les filtres de prix
  void applyPriceFilters() {
    currentMinPrice.value = minPrice.value;
    currentMaxPrice.value = maxPrice.value;
    _onFiltersChanged();
  }

  /// Change la localisation
  void selectLocation(String location) {
    selectedLocation.value = location;
    _onFiltersChanged();
  }

  /// Change l'option de tri
  void selectSortOption(SortOption option) {
    selectedSortOption.value = option;
    _updateSortParams(option);
    _onFiltersChanged();
  }

  /// Met à jour les paramètres de tri selon l'option sélectionnée
  void _updateSortParams(SortOption option) {
    switch (option) {
      case SortOption.relevance:
        // `/products` ne calcule pas de score : lui demander un tri sur une
        // colonne « relevance » inexistante faisait échouer la requête. La
        // pertinence y est l'ordre par défaut, du plus récent au plus ancien.
        sortBy.value = 'created_at';
        sortOrder.value = 'desc';
        break;
      case SortOption.priceAsc:
        sortBy.value = 'price';
        sortOrder.value = 'asc';
        break;
      case SortOption.priceDesc:
        sortBy.value = 'price';
        sortOrder.value = 'desc';
        break;
      case SortOption.dateDesc:
        sortBy.value = 'created_at';
        sortOrder.value = 'desc';
        break;
      case SortOption.dateAsc:
        sortBy.value = 'created_at';
        sortOrder.value = 'asc';
        break;
    }
  }

  /// Réinitialise tous les filtres
  void resetFilters() {
    selectedCategory.value = '';
    selectedCategoryId.value = 0;
    minPrice.value = 0.0;
    maxPrice.value = _priceCap;
    currentMinPrice.value = 0.0;
    currentMaxPrice.value = _priceCap;
    minPriceController.clear();
    maxPriceController.clear();
    selectedLocation.value = 'Toutes les villes';
    selectedSortOption.value = SortOption.relevance;
    sortBy.value = 'created_at';
    sortOrder.value = 'desc';
    _onFiltersChanged();
  }

  /// Toggle affichage des filtres
  void toggleFilters() {
    showFilters.value = !showFilters.value;
  }

  // ================================
  // HISTORIQUE
  // ================================

  /// Charge l'historique de recherche
  void _loadSearchHistory() {
    final history = _storage.read<List>('search_history');
    if (history != null) {
      searchHistory.value = history.cast<String>();
    }
  }

  /// Ajoute une recherche à l'historique
  void _addToSearchHistory(String query) {
    // Retirer si déjà présent
    searchHistory.remove(query);

    // Ajouter en première position
    searchHistory.insert(0, query);

    // Limiter la taille
    if (searchHistory.length > maxHistoryItems) {
      searchHistory.removeRange(maxHistoryItems, searchHistory.length);
    }

    // Sauvegarder
    _storage.write('search_history', searchHistory);
  }

  /// Supprime un élément de l'historique
  void removeFromHistory(String query) {
    searchHistory.remove(query);
    _storage.write('search_history', searchHistory);
  }

  /// Efface tout l'historique
  void clearHistory() {
    searchHistory.clear();
    _storage.remove('search_history');
  }

  // ================================
  // ACTIONS SUR LES PRODUITS
  // ================================

  /// Navigue vers les détails du produit.
  ///
  /// Asso Ads : une ouverture venue d'une carte sponsorisée porte `from_ad`,
  /// sans quoi le clic ne serait jamais compté et le vendeur verrait un
  /// retour sous-évalué sur une campagne qu'il a payée.
  void onProductTap(Map<String, dynamic> product) {
    Get.toNamed(
      '/product',
      arguments: product['is_sponsored'] == true
          ? {...product, 'from_ad': true}
          : product,
    );
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format price with user's currency
  String formatPrice(double priceInXOF, {bool showSymbol = true}) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: showSymbol);
  }

  /// Get currency symbol
  String get currencySymbol {
    if (!Get.isRegistered<CurrencyService>()) {
      return 'FCFA';
    }
    return CurrencyService.to.currencySymbol;
  }
}

// ================================
// ENUMS
// ================================

enum SortOption { relevance, priceAsc, priceDesc, dateDesc, dateAsc }

extension SortOptionExtension on SortOption {
  String get label {
    switch (this) {
      case SortOption.relevance:
        return 'Pertinence';
      case SortOption.priceAsc:
        return 'Prix croissant';
      case SortOption.priceDesc:
        return 'Prix décroissant';
      case SortOption.dateDesc:
        return 'Plus récents';
      case SortOption.dateAsc:
        return 'Plus anciens';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.relevance:
        return Icons.star_outline;
      case SortOption.priceAsc:
        return Icons.arrow_upward;
      case SortOption.priceDesc:
        return Icons.arrow_downward;
      case SortOption.dateDesc:
        return Icons.access_time;
      case SortOption.dateAsc:
        return Icons.history;
    }
  }
}

void _showError(String message) {
  Get.snackbar(
    'Erreur',
    message,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
  );
}
