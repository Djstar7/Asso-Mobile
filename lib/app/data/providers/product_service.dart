import '../../core/values/constants.dart';
import 'api_provider.dart';

class ProductService {
  /// Get products with pagination and filters
  static Future<ApiResponse> getProducts({
    int page = 1,
    int perPage = 20,
    String? search,
    int? categoryId,
    int? subcategoryId,
    String? type,
    String? originCountry,
    double? minPrice,
    double? maxPrice,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category_id'] = categoryId;
    if (subcategoryId != null) params['subcategory_id'] = subcategoryId;
    if (type != null) params['type'] = type;
    if (originCountry != null) params['origin_country'] = originCountry;
    if (minPrice != null) params['min_price'] = minPrice;
    if (maxPrice != null) params['max_price'] = maxPrice;

    return await ApiProvider.get(AppConstants.productsUrl, queryParams: params);
  }

  /// Get single product details
  static Future<ApiResponse> getProduct(int id) async {
    return await ApiProvider.get('${AppConstants.productsUrl}/$id');
  }

  /// Liste des pays d'origine des produits importés (Chine/Turquie/Dubaï…),
  /// gérée côté backend. Retourne une liste de {code, name, flag}.
  /// Fallback local si l'API échoue, pour ne jamais casser l'UI.
  static const List<Map<String, String>> importCountriesFallback = [
    {'code': 'CN', 'name': 'Chine', 'flag': '🇨🇳'},
    {'code': 'TR', 'name': 'Turquie', 'flag': '🇹🇷'},
    {'code': 'AE', 'name': 'Dubaï', 'flag': '🇦🇪'},
  ];

  static Future<List<Map<String, String>>> getImportCountries() async {
    try {
      final res = await ApiProvider.get(AppConstants.importCountriesUrl);
      final list = res.data?['countries'];
      if (res.success && list is List && list.isNotEmpty) {
        return list
            .whereType<Map>()
            .map((c) => {
                  'code': (c['code'] ?? '').toString(),
                  'name': (c['name'] ?? '').toString(),
                  'flag': (c['flag'] ?? '').toString(),
                })
            .where((c) => c['code']!.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // ignore : on retombe sur le fallback
    }
    return importCountriesFallback;
  }

  /// Toggle favorite
  static Future<ApiResponse> toggleFavorite(int productId) async {
    return await ApiProvider.post('${AppConstants.productsUrl}/$productId/favorite');
  }

  /// Get user favorites
  static Future<ApiResponse> getFavorites({int page = 1, int perPage = 20}) async {
    return await ApiProvider.get(AppConstants.favoritesUrl, queryParams: {
      'page': page,
      'per_page': perPage,
    });
  }

  /// Get categories
  static Future<ApiResponse> getCategories() async {
    return await ApiProvider.get(AppConstants.categoriesUrl);
  }

  /// Get banners
  static Future<ApiResponse> getBanners() async {
    return await ApiProvider.get(AppConstants.bannersUrl);
  }

  /// Get nearby products (limited)
  static Future<ApiResponse> getNearbyProducts({int limit = 6}) async {
    return await ApiProvider.get('${AppConstants.productsUrl}/nearby', queryParams: {
      'limit': limit,
    });
  }

  /// Get recent products (limited)
  static Future<ApiResponse> getRecentProducts({int limit = 6}) async {
    return await ApiProvider.get('${AppConstants.productsUrl}/recent', queryParams: {
      'limit': limit,
    });
  }

  /// Analyze product image using Gemini AI
  static Future<ApiResponse> analyzeProductImage(String imagePath) async {
    return await ApiProvider.multipart(
      '${AppConstants.productsUrl}/analyze',
      files: {
        'image': imagePath,
      },
    );
  }

  /// Get available categories with subcategories
  static Future<ApiResponse> getCategoriesForAnalysis() async {
    return await ApiProvider.get('${AppConstants.productsUrl}/categories');
  }

  /// Health check for Gemini service
  static Future<ApiResponse> checkGeminiHealth() async {
    return await ApiProvider.get('${AppConstants.productsUrl}/analyze/health');
  }
}
