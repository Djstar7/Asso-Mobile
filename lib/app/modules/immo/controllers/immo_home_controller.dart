import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/auth_guard.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';

/// Tri de la liste, dans l'ordre du menu « Trier par ».
const List<String> kImmoSorts = [
  'recent',
  'price_asc',
  'price_desc',
  'featured',
];

/// Page d'entrée de la rubrique : onglets Maisons à louer / Terrains à
/// vendre, recherche, filtres, tri et liste paginée.
class ImmoHomeController extends GetxController {
  ImmoHomeController({RealEstateType initialType = RealEstateType.rent})
    : type = initialType.obs;

  final Rx<RealEstateType> type;
  final RxString sort = 'recent'.obs;
  final Rxn<RealEstateType> houseTransaction = Rxn<RealEstateType>();

  /// Filtres actifs, aux noms des paramètres de l'API.
  final RxMap<String, dynamic> filters = <String, dynamic>{}.obs;

  final RxList<RealEstateListing> items = <RealEstateListing>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasError = false.obs;
  final RxInt total = 0.obs;

  final Rxn<RealEstateCriteria> criteria = Rxn<RealEstateCriteria>();
  final RxList<String> cities = <String>[].obs;

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  int _page = 1;
  bool _hasMore = false;
  int _requestId = 0;
  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    if (type.value == RealEstateType.sale) {
      houseTransaction.value = RealEstateType.sale;
    }
    scrollController.addListener(_onScroll);
    load();
    _loadSideData();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    scrollController.dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> _loadSideData() async {
    final loadedCities = await RealEstateService.cities();
    if (isClosed) return;
    cities.assignAll(loadedCities);

    if (AuthGuard.isAuthenticated) {
      final saved = await RealEstateService.criteria();
      if (!isClosed) criteria.value = saved;
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.pixels > position.maxScrollExtent - 600) loadMore();
  }

  Map<String, dynamic> _query(int page) {
    final q = <String, dynamic>{
      'type': type.value == RealEstateType.land
          ? 'land'
          : houseTransaction.value?.api ?? 'house',
      if (type.value == RealEstateType.land) 'price_basis': 'per_m2',
      'sort': sort.value,
      'page': page,
      'per_page': 15,
    };
    final text = searchController.text.trim();
    if (text.isNotEmpty) q['q'] = text;
    filters.forEach((key, value) {
      if (value == null || value == false || value == '') return;
      q[key] = value is bool ? 1 : value;
    });

    return q;
  }

  Future<void> load() async {
    final requestId = ++_requestId;
    isLoading.value = true;
    isLoadingMore.value = false;
    hasError.value = false;

    final page = await RealEstateService.listings(_query(1));
    if (isClosed || requestId != _requestId) return;

    isLoading.value = false;
    if (page == null) {
      hasError.value = true;
      items.clear();
      total.value = 0;
      return;
    }
    _page = 1;
    _hasMore = page.hasMore;
    total.value = page.total;
    items.assignAll(page.items);
  }

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value || !_hasMore) return;
    final requestId = _requestId;
    isLoadingMore.value = true;

    final page = await RealEstateService.listings(_query(_page + 1));
    if (isClosed || requestId != _requestId) return;

    isLoadingMore.value = false;
    if (page == null) return;
    _page = page.currentPage;
    _hasMore = page.hasMore;
    items.addAll(page.items);
  }

  void switchType(RealEstateType value) {
    if (type.value == value) return;
    type.value = value;
    // Les filtres d'une maison n'ont pas de sens pour un terrain, et
    // inversement : on repart d'une liste propre.
    filters.clear();
    sort.value = 'recent';
    if (scrollController.hasClients) scrollController.jumpTo(0);
    load();
  }

  void setHouseTransaction(RealEstateType? value) {
    if (houseTransaction.value == value) return;
    houseTransaction.value = value;
    filters.clear();
    load();
  }

  void onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), load);
  }

  void setSort(String value) {
    if (sort.value == value) return;
    sort.value = value;
    load();
  }

  void applyFilters(Map<String, dynamic> values) {
    for (final entry in values.entries) {
      if (entry.value == null || entry.value == false || entry.value == '') {
        filters.remove(entry.key);
      } else {
        filters[entry.key] = entry.value;
      }
    }
    load();
  }

  void clearFilters() {
    filters.clear();
    searchController.clear();
    load();
  }

  bool hasAny(List<String> keys) => keys.any(filters.containsKey);

  /// Critères enregistrés : on les applique tout de suite à la liste.
  Future<bool> saveCriteria(RealEstateCriteria value) async {
    value.type = type.value;
    criteria.value = value;
    applyFilters({
      'city': value.city,
      'price_min': value.budgetMin,
      'price_max': value.budgetMax,
      'available_by': value.moveInDate?.toIso8601String().substring(0, 10),
      'lease_months': value.leaseMonths,
    });
    if (!AuthGuard.isAuthenticated) return true;

    return RealEstateService.saveCriteria(value);
  }

  Future<void> toggleFavorite(RealEstateListing listing) async {
    final next = !listing.isFavorite;
    listing.isFavorite = next;
    items.refresh();

    final ok = await RealEstateService.setFavorite(listing.id, next);
    if (!ok && !isClosed) {
      listing.isFavorite = !next;
      items.refresh();
    }
  }

  /// Mise à jour d'une carte après un passage sur la fiche (favori…).
  void syncFavorite(int listingId, bool isFavorite) {
    final match = items.firstWhereOrNull((l) => l.id == listingId);
    if (match == null || match.isFavorite == isFavorite) return;
    match.isFavorite = isFavorite;
    items.refresh();
  }
}
