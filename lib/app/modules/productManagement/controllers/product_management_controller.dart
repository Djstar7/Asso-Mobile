import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/vendor_product_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_design.dart';

class ProductManagementController extends GetxController {
  // Observable variables
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
      if (requestId != _requestId) {
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

        print('✅ ${newProducts.length} produits — total ${totalProducts.value}');
      } else {
        final message = response.message.isNotEmpty
            ? response.message
            : 'Impossible de charger les produits';
        print('❌ Échec du chargement : $message');
        // L'erreur reste affichée dans la liste ; la snackbar ne sert qu'au
        // chargement d'une page supplémentaire, où la liste reste visible.
        if (loadMore) {
          Get.snackbar('Erreur', message, snackPosition: SnackPosition.BOTTOM);
        } else {
          errorMessage.value = message;
        }
      }
    } catch (e) {
      if (requestId != _requestId) return;
      print('💥 Exception loading products: $e');
      const message = 'Vérifiez votre connexion et réessayez.';
      if (loadMore) {
        Get.snackbar('Erreur', message, snackPosition: SnackPosition.BOTTOM);
      } else {
        errorMessage.value = message;
      }
    } finally {
      if (requestId == _requestId) {
        isLoading.value = false;
        isLoadingMore.value = false;
      }
    }
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

  /// Delete a product
  Future<void> deleteProduct(int productId, String productName) async {
    print('');
    print('🗑️ Deleting product...');
    print('  └─ Product ID: $productId');
    print('  └─ Product Name: $productName');

    // Show confirmation dialog
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "$productName" ?\n\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesign.danger,
            ),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
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
        String message = 'Produit supprimé avec succès';
        if (response.data?['storage_freed_mb'] != null) {
          final freedMb = response.data!['storage_freed_mb'];
          message += '\n${freedMb.toStringAsFixed(2)} MB libérés';
        }

        Get.snackbar(
          'Succès',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        print('❌ Failed to delete product: ${response.message}');
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty
              ? response.message
              : 'Impossible de supprimer le produit',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('💥 Exception deleting product: $e');
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  Future<void> toggleProductStatus(Map<String, dynamic> product) async {
    final currentStatus = product['status']?.toString() ?? 'inactive';
    final nextStatus = currentStatus == 'active' ? 'inactive' : 'active';
    final verb = nextStatus == 'active' ? 'réactiver' : 'désactiver';
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(
          nextStatus == 'active'
              ? 'Réactiver le produit'
              : 'Désactiver le produit',
        ),
        content: Text('Voulez-vous $verb « ${product['name']} » ?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Confirmer'),
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
      Get.snackbar(
        'Succès',
        response.message.isNotEmpty ? response.message : 'Statut mis à jour',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        'Erreur',
        response.message.isNotEmpty
            ? response.message
            : 'Impossible de modifier le statut',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Navigate to edit product
  void editProduct(Map<String, dynamic> product) {
    print('');
    print('✏️ Editing product: ${product['name']}');

    // Navigate to AddProduct in edit mode
    Get.toNamed(
      '/add-product',
      arguments: {'product': product, 'isEdit': true},
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
    Get.toNamed('/add-product')?.then((_) {
      // Refresh products after adding
      refreshProducts();
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    super.onClose();
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
