import 'package:image_picker/image_picker.dart' show XFile;
import '../../core/values/constants.dart';
import 'api_provider.dart';

class ShopService {
  /// Get shop information for the authenticated vendor
  static Future<ApiResponse> getShop() async {
    print('');
    print('========================================');
    print('🏪 SHOP SERVICE: Get Shop START');
    print('========================================');
    print('🌐 SHOP SERVICE: Calling API...');
    print('  └─ Endpoint: ${AppConstants.vendorShopUrl}');

    try {
      final response = await ApiProvider.get(AppConstants.vendorShopUrl);

      print('✅ SHOP SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 SHOP SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Update shop information
  static Future<ApiResponse> updateShop({
    String? shopName,
    String? shopDescription,
    String? shopAddress,
    String? shopPhone,
    double? shopLatitude,
    double? shopLongitude,
    List<String>? categories,
    XFile? shopLogo,
  }) async {
    print('');
    print('========================================');
    print('🏪 SHOP SERVICE: Update Shop START');
    print('========================================');

    // Build fields map
    final Map<String, String> fields = {};

    print('📦 SHOP SERVICE: Building fields...');
    if (shopName != null) fields['shop_name'] = shopName;
    if (shopDescription != null) fields['shop_description'] = shopDescription;
    if (shopAddress != null) fields['shop_address'] = shopAddress;
    if (shopPhone != null) fields['shop_phone'] = shopPhone;
    if (shopLatitude != null) fields['shop_latitude'] = shopLatitude.toString();
    if (shopLongitude != null) {
      fields['shop_longitude'] = shopLongitude.toString();
    }

    // Add categories as array
    if (categories != null && categories.isNotEmpty) {
      print('  └─ Adding ${categories.length} categories');
      for (int i = 0; i < categories.length; i++) {
        fields['categories[$i]'] = categories[i];
      }
    }

    print('  └─ Total fields: ${fields.length}');

    // Build media files map (XFile) — compatible web ET mobile.
    final Map<String, XFile> mediaFiles = {};
    if (shopLogo != null) {
      mediaFiles['shop_logo'] = shopLogo;
      print('  └─ Shop logo: ${shopLogo.name}');
    }
    print('  └─ Total files: ${mediaFiles.length}');

    // Laravel doesn't parse multipart for PUT, so use POST with _method=PUT
    fields['_method'] = 'PUT';

    print('🌐 SHOP SERVICE: Calling API (multipart)...');
    print('  └─ Endpoint: ${AppConstants.vendorShopUrl}');
    print('  └─ Method: POST with _method=PUT (Laravel method spoofing)');

    try {
      // Use multipart for file uploads with POST (method spoofing for PUT)
      final response = await ApiProvider.multipart(
        AppConstants.vendorShopUrl,
        fields: fields,
        mediaFiles: mediaFiles.isNotEmpty ? mediaFiles : null,
        method: 'POST',  // Changed from PUT to POST
      );

      print('✅ SHOP SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 SHOP SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Get all shops for the authenticated vendor
  static Future<ApiResponse> getShops() async {
    print('');
    print('========================================');
    print('🏪 SHOP SERVICE: Get Shops START');
    print('========================================');
    print('🌐 SHOP SERVICE: Calling API...');
    print('  └─ Endpoint: ${AppConstants.vendorShopsUrl}');

    try {
      final response = await ApiProvider.get(AppConstants.vendorShopsUrl);

      print('✅ SHOP SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 SHOP SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Get public shop information by ID
  static Future<ApiResponse> getPublicShop(String shopId) async {
    print('');
    print('========================================');
    print('🏪 SHOP SERVICE: Get Public Shop START');
    print('========================================');
    print('🌐 SHOP SERVICE: Calling API...');
    print('  └─ Endpoint: ${AppConstants.publicShopUrl}/$shopId');

    try {
      final response =
          await ApiProvider.get('${AppConstants.publicShopUrl}/$shopId');

      print('✅ SHOP SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 SHOP SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Get location change requests for the authenticated vendor's shop
  static Future<ApiResponse> getLocationRequests() async {
    print('');
    print('========================================');
    print('📍 SHOP SERVICE: Get Location Requests START');
    print('========================================');
    print('🌐 SHOP SERVICE: Calling API...');
    print('  └─ Endpoint: ${AppConstants.vendorShopUrl}/location-requests');

    try {
      final response = await ApiProvider.get(
        '${AppConstants.vendorShopUrl}/location-requests',
      );

      print('✅ SHOP SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('  └─ Pending count: ${response.data?['pending_count']}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 SHOP SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }
}
