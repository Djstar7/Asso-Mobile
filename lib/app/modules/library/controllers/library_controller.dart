import 'package:get/get.dart';

import '../../../core/utils/app_feedback.dart';
import '../../../data/providers/product_service.dart';

/// Rubrique Bibliothèque : livres seuls (`/products?library=1`), classés par
/// rayon et genre, filtrables par langue et format, et recherchables par
/// titre, auteur ou ISBN.
class LibraryController extends GetxController {
  static const languages = ['fr', 'en'];
  static const formats = ['paperback', 'hardcover', 'ebook', 'audio'];
  static const _perPage = 20;

  final shelves = <Map<String, dynamic>>[].obs;
  final books = <Map<String, dynamic>>[].obs;

  final selectedShelfId = RxnInt();
  final selectedGenreId = RxnInt();
  final language = RxnString();
  final format = RxnString();
  final search = ''.obs;

  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final loadError = RxnString();

  int _page = 1;

  /// Seule la dernière requête lancée remplit la liste : changer de rayon
  /// pendant un chargement ne doit pas afficher les livres de l'ancien.
  int _request = 0;

  @override
  void onInit() {
    super.onInit();
    debounce(search, (_) => reload(), time: const Duration(milliseconds: 400));
    loadShelves();
    reload();
  }

  Map<String, dynamic>? get selectedShelf =>
      shelves.firstWhereOrNull((s) => s['id'] == selectedShelfId.value);

  List<Map<String, dynamic>> get genres {
    final list = selectedShelf?['subcategories'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((g) => Map<String, dynamic>.from(g))
        .where((g) => (g['products_count'] ?? 0) != 0)
        .toList();
  }

  int get activeFilterCount =>
      (language.value != null ? 1 : 0) + (format.value != null ? 1 : 0);

  bool get hasAnyFilter =>
      activeFilterCount > 0 ||
      selectedShelfId.value != null ||
      search.value.trim().isNotEmpty;

  /// Nom du rayon ou du genre dans la langue de l'application.
  static String localizedName(Map<String, dynamic> category) {
    final english = category['name_en']?.toString().trim() ?? '';
    if ((Get.locale?.languageCode ?? 'fr') == 'en' && english.isNotEmpty) {
      return english;
    }
    return category['name']?.toString() ?? '';
  }

  Future<void> loadShelves() async {
    try {
      final response = await ProductService.getCategories(library: true);
      final list = response.data?['categories'];
      if (response.success && list is List) {
        shelves.assignAll(
          list.whereType<Map>().map((c) => Map<String, dynamic>.from(c)),
        );
      }
    } catch (_) {
      // Les rayons ne sont qu'un filtre : la liste des livres reste utilisable.
    }
  }

  void selectShelf(int? id) {
    if (selectedShelfId.value == id) return;
    selectedShelfId.value = id;
    selectedGenreId.value = null;
    reload();
  }

  void selectGenre(int? id) {
    if (selectedGenreId.value == id) return;
    selectedGenreId.value = id;
    reload();
  }

  void applyFilters({String? language, String? format}) {
    this.language.value = language;
    this.format.value = format;
    reload();
  }

  void clearAll() {
    selectedShelfId.value = null;
    selectedGenreId.value = null;
    language.value = null;
    format.value = null;
    if (search.value.isEmpty) {
      reload();
    } else {
      search.value = ''; // le debounce relance la recherche
    }
  }

  Future<void> reload() async {
    _page = 1;
    hasMore.value = true;
    await _fetch(reset: true);
  }

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) return;
    await _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    final request = ++_request;
    reset ? isLoading.value = true : isLoadingMore.value = true;
    if (reset) loadError.value = null;

    try {
      final response = await ProductService.getProducts(
        page: _page,
        perPage: _perPage,
        library: true,
        search: search.value.trim(),
        categoryId: selectedShelfId.value,
        subcategoryId: selectedGenreId.value,
        language: language.value,
        format: format.value,
      );
      if (request != _request) return;

      if (!response.success) {
        if (reset) {
          books.clear();
          loadError.value = response.message.isNotEmpty
              ? response.message
              : 'library.load_failed'.tr;
        }
        return;
      }

      final items = (response.data?['products'] as List? ?? const [])
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          // Une annonce sponsorisée hors Bibliothèque n'a rien à faire ici.
          .where((p) => p['book'] != null || p['is_sponsored'] != true)
          .toList();
      reset ? books.assignAll(items) : books.addAll(items);

      final pagination = response.data?['pagination'];
      hasMore.value = pagination is Map
          ? pagination['has_more'] == true
          : items.length >= _perPage;
      if (hasMore.value) _page++;
    } catch (e) {
      if (request != _request) return;
      if (reset) {
        books.clear();
        loadError.value = AppFeedback.errorMessage(e);
      }
    } finally {
      if (request == _request) {
        isLoading.value = false;
        isLoadingMore.value = false;
      }
    }
  }
}
