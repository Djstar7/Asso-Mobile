import 'package:get/get.dart';
import '../../../data/providers/product_service.dart';

class FavoritesController extends GetxController {
  final RxList<Map<String, dynamic>> favoriteProducts = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;

  int currentPage = 1;
  final int perPage = 20;

  @override
  void onInit() {
    super.onInit();
    loadFavorites();
  }

  /// Load favorite products
  Future<void> loadFavorites({bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      hasMore.value = true;
      favoriteProducts.clear();
    }

    if (!hasMore.value) return;

    if (currentPage == 1) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final response = await ProductService.getFavorites(
        page: currentPage,
        perPage: perPage,
      );

      if (response.success && response.data != null) {
        final products = response.data!['products'] as List? ?? [];
        final List<Map<String, dynamic>> productsList = products
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();

        if (refresh) {
          favoriteProducts.value = productsList;
        } else {
          favoriteProducts.addAll(productsList);
        }

        // Check pagination
        final pagination = response.data!['pagination'];
        if (pagination != null) {
          final currentPageNum = pagination['current_page'] ?? currentPage;
          final lastPageNum = pagination['last_page'] ?? currentPage;
          hasMore.value = currentPageNum < lastPageNum;

          if (hasMore.value) {
            currentPage++;
          }
        } else {
          hasMore.value = productsList.length >= perPage;
          if (hasMore.value) {
            currentPage++;
          }
        }
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de charger les favoris: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  /// Load more products (pagination)
  Future<void> loadMore() async {
    if (!isLoadingMore.value && hasMore.value) {
      await loadFavorites();
    }
  }

  /// Refresh favorites list
  Future<void> refreshFavorites() async {
    await loadFavorites(refresh: true);
  }

  /// Toggle favorite for a product
  Future<void> toggleFavorite(int productId) async {
    try {
      final response = await ProductService.toggleFavorite(productId);

      if (response.success) {
        final isFavorite = response.data?['is_favorite'] ?? false;

        if (!isFavorite) {
          // Remove from list if unfavorited
          favoriteProducts.removeWhere((p) => p['id'] == productId);
        }

        Get.snackbar(
          'Succès',
          response.data?['message'] ?? (isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris'),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de modifier le favori',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Navigate to product details
  void goToProductDetails(Map<String, dynamic> product) {
    Get.toNamed('/product', arguments: product);
  }
}
