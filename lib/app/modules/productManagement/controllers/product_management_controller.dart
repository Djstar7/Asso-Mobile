import 'package:asso/app/core/utils/app_feedback.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/vendor_product_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/session_scope.dart';
import '../../../data/providers/offline_store.dart';
import '../../../data/services/connectivity_service.dart';

class ProductManagementController extends GetxController {
  // Observable variables
  final isShowingSnapshot = false.obs;
  final lastSyncedAt = Rxn<DateTime>();
  Worker? _connectivityWorker;

  final products = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final currentPage = 1.obs;
  final hasMore = true.obs;
  final totalProducts = 0.obs;

  /// Chargement d'une page supplémentaire : distinct de [isLoading] pour que
  /// la liste déjà affichée ne soit pas remplacée par un écran de chargement.
  final isLoadingMore = false.obs;

  /// Dernière requête ayant échoué, pour proposer un bouton « Réessayer »
  /// plutôt qu'une simple snackbar vite disparue.
  final errorMessage = RxnString();

  // Recherche & filtre
  final searchQuery = ''.obs;
  final statusFilter = RxnString();
  final searchController = TextEditingController();
  Timer? _searchDebounce;

  /// Les filtres actifs distinguent « aucun produit » de « aucun résultat ».
  bool get hasActiveFilters =>
      searchQuery.value.trim().isNotEmpty || statusFilter.value != null;

  // Pagination
  final int perPage = 20;

  /// Jeton de requête : une réponse lente arrivant après un nouveau filtre
  /// serait sinon appliquée par-dessus les résultats les plus récents.
  int _requestId = 0;

  @override
  void onInit() {
    super.onInit();
    print('');
    print('========================================');
    print('🛍️ PRODUCT MANAGEMENT CONTROLLER: Init');
    print('========================================');

    // Vérifier si on doit rafraîchir (retour depuis add/edit product)
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['refresh'] == true) {
      print('🔄 Refresh requested from arguments - will refresh products');
    }

    loadProducts();
    if (Get.isRegistered<ConnectivityService>()) {
      _connectivityWorker = ever(ConnectivityService.to.isOnline, (online) {
        if (online == true) refreshProducts();
      });
    }
  }

  @override
  void onReady() {
    super.onReady();

    // Si on revient de la page d'ajout/édition, rafraîchir les produits
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['refresh'] == true) {
      print('🔄 Refreshing products after add/edit...');
      refreshProducts();
    }
  }

  /// Load products with pagination
  Future<void> loadProducts({bool loadMore = false}) async {
    final session = SessionScope.current;
    if (ConnectivityService.isOffline) {
      _requestId++;
      _loadSavedProducts();
      return;
    }
    if (loadMore) {
      // Une page supplémentaire ne doit pas s'empiler sur un chargement en
      // cours, ni être demandée une fois la dernière page atteinte.
      if (isLoadingMore.value || isLoading.value || !hasMore.value) return;
      isLoadingMore.value = true;
    } else {
      if (isLoading.value) return;
      isLoading.value = true;
      errorMessage.value = null;
    }

    final requestId = ++_requestId;
    final page = loadMore ? currentPage.value + 1 : 1;

    print('');
    print('📦 Loading products (page $page, loadMore: $loadMore)');

    try {
      final response = await VendorProductService.getVendorProducts(
        page: page,
        perPage: perPage,
        search: searchQuery.value,
        status: statusFilter.value,
      );

      // Une réponse devancée par une recherche plus récente est ignorée.
      if (requestId != _requestId || !SessionScope.isCurrent(session)) {
        print('↩️ Réponse obsolète ignorée (page $page)');
        return;
      }

      if (response.success && response.data != null) {
        final productsData = response.data!['data'] as List?;
        final meta = response.data!['meta'] as Map<String, dynamic>?;

        final newProducts = (productsData ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

        if (loadMore) {
          products.addAll(newProducts);
        } else {
          products.value = newProducts;
        }
        errorMessage.value = null;
        isShowingSnapshot.value = response.data!['_offline'] == true;
        lastSyncedAt.value =
            DateTime.tryParse('${response.data!['_saved_at']}') ??
            DateTime.now();

        if (meta != null) {
          currentPage.value = meta['current_page'] as int? ?? page;
          final lastPage = meta['last_page'] as int? ?? currentPage.value;
          hasMore.value = currentPage.value < lastPage;
          totalProducts.value = meta['total'] as int? ?? products.length;
        } else {
          // Sans métadonnées, une page incomplète signale la fin de la liste.
          currentPage.value = page;
          hasMore.value = newProducts.length >= perPage;
          totalProducts.value = products.length;
        }

        print(
          '✅ ${newProducts.length} produits — total ${totalProducts.value}',
        );
      } else {
        final message = response.message.isNotEmpty
            ? response.message
            : 'product_management.controller.load_failed'.tr;
        // L'erreur reste affichée dans la liste ; la snackbar ne sert qu'au
        // chargement d'une page supplémentaire, où la liste reste visible.
        if (loadMore) {
          AppFeedback.show(
            'product_management.controller.error_title'.tr,
            message,
            snackPosition: SnackPosition.BOTTOM,
          );
        } else {
          errorMessage.value = message;
        }
      }
    } catch (e) {
      if (requestId != _requestId || !SessionScope.isCurrent(session)) return;
      print('💥 Exception loading products: $e');
      final message = 'product_management.controller.check_connection'.tr;
      if (loadMore) {
        AppFeedback.show(
          'product_management.controller.error_title'.tr,
          message,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        errorMessage.value = message;
      }
    } finally {
      if (requestId == _requestId && SessionScope.isCurrent(session)) {
        isLoading.value = false;
        isLoadingMore.value = false;
      }
    }
  }

  void _loadSavedProducts() {
    final snapshot = OfflineStore.readSnapshot('vendor_product_list');
    isShowingSnapshot.value = true;
    isLoading.value = false;
    isLoadingMore.value = false;
    hasMore.value = false;
    if (snapshot is! Map || snapshot['products'] is! List) {
      products.clear();
      totalProducts.value = 0;
      lastSyncedAt.value = null;
      errorMessage.value = 'core.offline.no_saved_data'.tr;
      return;
    }
    lastSyncedAt.value = DateTime.tryParse('${snapshot['saved_at']}');
    final search = searchQuery.value.trim().toLowerCase();
    products.value = (snapshot['products'] as List)
        .whereType<Map>()
        .map((product) => Map<String, dynamic>.from(product))
        .where(
          (product) =>
              (search.isEmpty ||
                  '${product['name'] ?? ''}'.toLowerCase().contains(search)) &&
              (statusFilter.value == null ||
                  product['status'] == statusFilter.value),
        )
        .toList();
    totalProducts.value = products.length;
    currentPage.value = 1;
    errorMessage.value = null;
  }

  // ================================
  // RECHERCHE & FILTRES
  // ================================

  /// Saisie dans le champ de recherche : on attend une pause de frappe pour
  /// ne pas lancer une requête à chaque caractère.
  void onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      if (trimmed == searchQuery.value) return;
      searchQuery.value = trimmed;
      _restartPagination();
    });
  }

  /// Vide la recherche et recharge immédiatement le catalogue complet.
  void clearSearch() {
    _searchDebounce?.cancel();
    if (searchController.text.isNotEmpty) searchController.clear();
    if (searchQuery.value.isEmpty) return;
    searchQuery.value = '';
    _restartPagination();
  }

  /// Filtre par statut ; [status] à null retire le filtre.
  void setStatusFilter(String? status) {
    if (statusFilter.value == status) return;
    statusFilter.value = status;
    _restartPagination();
  }

  /// Retire recherche et filtre en une seule requête.
  void clearFilters() {
    _searchDebounce?.cancel();
    if (!hasActiveFilters) return;
    searchController.clear();
    searchQuery.value = '';
    statusFilter.value = null;
    _restartPagination();
  }

  /// Tout changement de filtre repart de la première page.
  void _restartPagination() {
    currentPage.value = 1;
    hasMore.value = true;
    loadProducts();
  }

  bool get isReadOnly =>
      ConnectivityService.isOffline || isShowingSnapshot.value;

  bool _canEditOnline() {
    if (!isReadOnly) return true;
    AppFeedback.show(
      'core.offline.label'.tr,
      'core.offline.online_required'.tr,
    );
    return false;
  }

  /// Delete a product
  Future<void> deleteProduct(int productId, String productName) async {
    if (!_canEditOnline()) return;
    print('');
    print('🗑️ Deleting product...');
    print('  └─ Product ID: $productId');
    print('  └─ Product Name: $productName');

    // Show confirmation dialog
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('product_management.controller.delete_title'.tr),
        content: Text(
          'product_management.controller.delete_message'.trParams({
            'name': productName,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('product_management.controller.cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: AppDesign.danger),
            child: Text(
              'product_management.controller.delete'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      print('❌ Deletion cancelled by user');
      return;
    }

    // Pas de bascule de `isLoading` ici : elle remplacerait toute la liste
    // par un écran de chargement pour la suppression d'une seule fiche.
    try {
      final response = await VendorProductService.deleteProduct(productId);

      if (response.success) {
        print('✅ Product deleted successfully!');

        // Remove product from list
        products.removeWhere((p) => p['id'] == productId);
        totalProducts.value = totalProducts.value - 1;

        // Show success message with storage info
        String message = 'product_management.controller.delete_success'.tr;
        if (response.data?['storage_freed_mb'] != null) {
          final freedMb = response.data!['storage_freed_mb'];
          message +=
              '\n${'product_management.controller.storage_freed'.trParams({'mb': freedMb.toStringAsFixed(2)})}';
        }

        AppFeedback.show(
          'product_management.controller.success_title'.tr,
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        AppFeedback.show(
          'product_management.controller.error_title'.tr,
          response.message.isNotEmpty
              ? response.message
              : 'product_management.controller.delete_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('💥 Exception deleting product: $e');
      AppFeedback.show(
        'product_management.controller.error_title'.tr,
        'product_management.controller.error_with_detail'.trParams({
          'error': '$e',
        }),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  Future<void> toggleProductStatus(Map<String, dynamic> product) async {
    if (!_canEditOnline()) return;
    final currentStatus = product['status']?.toString() ?? 'inactive';
    final nextStatus = currentStatus == 'active' ? 'inactive' : 'active';
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(
          nextStatus == 'active'
              ? 'product_management.controller.reactivate_title'.tr
              : 'product_management.controller.deactivate_title'.tr,
        ),
        content: Text(
          (nextStatus == 'active'
                  ? 'product_management.controller.reactivate_message'
                  : 'product_management.controller.deactivate_message')
              .trParams({'name': '${product['name']}'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('product_management.controller.cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: Text('product_management.controller.confirm'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final response = await VendorProductService.updateProductStatus(
      product['id'] as int,
      nextStatus,
    );
    if (response.success) {
      product['status'] = nextStatus;
      // Sous un filtre de statut, la fiche qui change d'état quitte la liste.
      if (statusFilter.value != null && statusFilter.value != nextStatus) {
        products.removeWhere((p) => p['id'] == product['id']);
        if (totalProducts.value > 0) totalProducts.value -= 1;
      }
      products.refresh();
      AppFeedback.show(
        'product_management.controller.success_title'.tr,
        response.message.isNotEmpty
            ? response.message
            : 'product_management.controller.status_updated'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      AppFeedback.show(
        'product_management.controller.error_title'.tr,
        response.message.isNotEmpty
            ? response.message
            : 'product_management.controller.status_update_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Navigate to edit product
  void editProduct(Map<String, dynamic> product) {
    if (!_canEditOnline()) return;
    print('');
    print('✏️ Editing product: ${product['name']}');

    // Navigate to AddProduct in edit mode
    Get.toNamed(
      '/add-product',
      arguments: {
        'product': product,
        'isEdit': true,
        'fromProductManagement': true,
      },
    )?.then((_) {
      // Refresh products after edit
      refreshProducts();
    });
  }

  /// Refresh products (pull to refresh)
  Future<void> refreshProducts() async {
    print('');
    print('🔄 Refreshing products...');
    currentPage.value = 1;
    hasMore.value = true;
    await loadProducts();
  }

  /// Load more products (infinite scroll)
  void loadMoreProducts() => loadProducts(loadMore: true);

  /// Navigate to add product
  void navigateToAddProduct() {
    Get.toNamed(
      '/add-product',
      arguments: {'fromProductManagement': true},
    )?.then((_) {
      // Refresh products after adding
      refreshProducts();
    });
  }

  @override
  void onClose() {
    _connectivityWorker?.dispose();
    _searchDebounce?.cancel();
    searchController.dispose();
    super.onClose();
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format price with user's currency
  String formatPrice(double amountXaf, {bool showSymbol = true}) {
    return CurrencyService.formatFromPivot(amountXaf, showSymbol: showSymbol);
  }

  /// Get currency symbol
  String get currencySymbol {
    if (!Get.isRegistered<CurrencyService>()) {
      return 'FCFA';
    }
    return CurrencyService.to.currencySymbol;
  }
}
