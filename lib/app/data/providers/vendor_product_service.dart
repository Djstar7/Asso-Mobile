import 'api_provider.dart';

class VendorProductService {
  /// Get vendor's products with pagination
  static Future<ApiResponse> getVendorProducts({
    int page = 1,
    int perPage = 20,
  }) async {
    print('');
    print('========================================');
    print('📦 VENDOR PRODUCT SERVICE: Get Products START');
    print('========================================');
    print('  └─ Page: $page');
    print('  └─ Per Page: $perPage');

    try {
      final queryParams = {
        'page': page,
        'per_page': perPage,
      };

      print('🌐 Calling API: GET /v1/vendor/products');

      final response = await ApiProvider.get(
        '/v1/vendor/products',
        queryParams: queryParams,
      );

      print('✅ VENDOR PRODUCT SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      if (response.data != null) {
        final meta = response.data!['meta'];
        if (meta != null) {
          print('  └─ Total Products: ${meta['total']}');
          print('  └─ Current Page: ${meta['current_page']}');
          print('  └─ Last Page: ${meta['last_page']}');
        }
      }
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 VENDOR PRODUCT SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Update a product
  static Future<ApiResponse> updateProduct(
    int productId,
    Map<String, dynamic> data,
  ) async {
    print('');
    print('========================================');
    print('✏️ VENDOR PRODUCT SERVICE: Update Product START');
    print('========================================');
    print('  └─ Product ID: $productId');
    print('  └─ Fields to update: ${data.keys.join(", ")}');

    try {
      print('🌐 Calling API: PUT /v1/vendor/products/$productId');

      final response = await ApiProvider.put(
        '/v1/vendor/products/$productId',
        body: data,
      );

      print('✅ VENDOR PRODUCT SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 VENDOR PRODUCT SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Delete a product
  static Future<ApiResponse> deleteProduct(int productId) async {
    print('');
    print('========================================');
    print('🗑️ VENDOR PRODUCT SERVICE: Delete Product START');
    print('========================================');
    print('  └─ Product ID: $productId');

    try {
      print('🌐 Calling API: DELETE /v1/vendor/products/$productId');

      final response = await ApiProvider.delete(
        '/v1/vendor/products/$productId',
      );

      print('✅ VENDOR PRODUCT SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      if (response.data != null && response.data!['storage_freed_mb'] != null) {
        print('  └─ Storage Freed: ${response.data!['storage_freed_mb']} MB');
      }
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 VENDOR PRODUCT SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Get inventory history for the vendor
  static Future<ApiResponse> getInventory({
    int page = 1,
    int perPage = 50,
    String? type, // 'entry', 'exit', 'adjustment'
    int? productId,
  }) async {
    print('');
    print('========================================');
    print('📊 VENDOR PRODUCT SERVICE: Get Inventory START');
    print('========================================');
    print('  └─ Page: $page');
    print('  └─ Per Page: $perPage');
    if (type != null) print('  └─ Type Filter: $type');
    if (productId != null) print('  └─ Product ID Filter: $productId');

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (type != null) queryParams['type'] = type;
      if (productId != null) queryParams['product_id'] = productId;

      print('🌐 Calling API: GET /v1/vendor/inventory');

      final response = await ApiProvider.get(
        '/v1/vendor/inventory',
        queryParams: queryParams,
      );

      print('✅ VENDOR PRODUCT SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      if (response.data != null && response.data!['meta'] != null) {
        final meta = response.data!['meta'];
        print('  └─ Total Entries: ${meta['total']}');
        print('  └─ Current Page: ${meta['current_page']}');
      }
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 VENDOR PRODUCT SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }
}
