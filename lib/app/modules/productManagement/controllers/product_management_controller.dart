import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/vendor_product_service.dart';

class ProductManagementController extends GetxController {
  // Observable variables
  final products = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final currentPage = 1.obs;
  final hasMore = true.obs;
  final totalProducts = 0.obs;

  // Pagination
  final int perPage = 20;

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
    if (isLoading.value) {
      print('⚠️ Already loading, skipping...');
      return;
    }

    if (loadMore && !hasMore.value) {
      print('ℹ️ No more products to load');
      return;
    }

    print('');
    print('📦 Loading products...');
    print('  └─ Load More: $loadMore');
    print('  └─ Current Page: ${currentPage.value}');

    isLoading.value = true;

    try {
      final page = loadMore ? currentPage.value + 1 : 1;
      final response = await VendorProductService.getVendorProducts(
        page: page,
        perPage: perPage,
      );

      if (response.success && response.data != null) {
        final productsData = response.data!['data'] as List?;
        final meta = response.data!['meta'] as Map<String, dynamic>?;

        if (productsData != null) {
          final newProducts = productsData
              .map((e) => e as Map<String, dynamic>)
              .toList();

          if (loadMore) {
            products.addAll(newProducts);
          } else {
            products.value = newProducts;
          }

          print('✅ Loaded ${newProducts.length} products');
        }

        // Update pagination info
        if (meta != null) {
          currentPage.value = meta['current_page'] ?? 1;
          final lastPage = meta['last_page'] ?? 1;
          hasMore.value = currentPage.value < lastPage;
          totalProducts.value = meta['total'] ?? 0;

          print('  └─ Total: ${totalProducts.value}');
          print('  └─ Current Page: ${currentPage.value}/$lastPage');
          print('  └─ Has More: ${hasMore.value}');
        }
      } else {
        print('❌ Failed to load products: ${response.message}');
        Get.snackbar(
          'Erreur',
          response.message ?? 'Impossible de charger les produits',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print('💥 Exception loading products: $e');
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
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
              backgroundColor: const Color(0xFFF44336),
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

    isLoading.value = true;

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
          backgroundColor: const Color(0xFF4CAF50),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        print('❌ Failed to delete product: ${response.message}');
        Get.snackbar(
          'Erreur',
          response.message ?? 'Impossible de supprimer le produit',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFF44336),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('💥 Exception deleting product: $e');
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFF44336),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
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
  void loadMoreProducts() {
    if (!isLoading.value && hasMore.value) {
      loadProducts(loadMore: true);
    }
  }

  /// Navigate to add product
  void navigateToAddProduct() {
    Get.toNamed('/add-product')?.then((_) {
      // Refresh products after adding
      refreshProducts();
    });
  }
}
