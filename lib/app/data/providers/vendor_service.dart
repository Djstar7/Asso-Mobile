import 'dart:io';
import '../../core/values/constants.dart';
import 'api_provider.dart';

class VendorService {
  /// Apply to become vendor
  static Future<ApiResponse> applyVendor({
    required String shopName,
    String? shopDescription,
    String? shopAddress,
    double? shopLatitude,
    double? shopLongitude,
    List<String>? categories,
    String? firstName,
    String? lastName,
    String? gender,
    String? accountType,
    String? companyName,
    File? shopLogo,
    File? profileImage,
  }) async {
    print('');
    print('========================================');
    print('🔧 VENDOR SERVICE: Apply Vendor START');
    print('========================================');

    // Build fields map
    final Map<String, String> fields = {
      'shop_name': shopName,
    };

    print('📦 VENDOR SERVICE: Building fields...');
    if (shopDescription != null) fields['shop_description'] = shopDescription;
    if (shopAddress != null) fields['shop_address'] = shopAddress;
    if (shopLatitude != null) fields['shop_latitude'] = shopLatitude.toString();
    if (shopLongitude != null) fields['shop_longitude'] = shopLongitude.toString();

    // Add categories as array
    if (categories != null && categories.isNotEmpty) {
      print('  └─ Adding ${categories.length} categories');
      for (int i = 0; i < categories.length; i++) {
        fields['categories[$i]'] = categories[i];
      }
    }

    if (firstName != null) fields['first_name'] = firstName;
    if (lastName != null) fields['last_name'] = lastName;
    if (gender != null) fields['gender'] = gender;
    if (accountType != null) fields['account_type'] = accountType;
    if (companyName != null) fields['company_name'] = companyName;

    print('  └─ Total fields: ${fields.length}');

    // Build files map with file paths
    final Map<String, String> files = {};
    if (shopLogo != null) {
      files['shop_logo'] = shopLogo.path;
      print('  └─ Shop logo: ${shopLogo.path}');
    }
    if (profileImage != null) {
      files['avatar'] = profileImage.path;
      print('  └─ Avatar: ${profileImage.path}');
    }
    print('  └─ Total files: ${files.length}');

    print('🌐 VENDOR SERVICE: Calling API (multipart)...');
    print('  └─ Endpoint: ${AppConstants.vendorApplyUrl}');

    try {
      // Use multipart for file uploads
      final response = await ApiProvider.multipart(
        AppConstants.vendorApplyUrl,
        fields: fields,
        files: files.isNotEmpty ? files : null,
      );

      print('✅ VENDOR SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 VENDOR SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Get vendor dashboard
  static Future<ApiResponse> getVendorDashboard() async {
    return await ApiProvider.get(AppConstants.vendorDashboardUrl);
  }

  /// Apply to become delivery person
  static Future<ApiResponse> applyDelivery({
    String? vehicleType,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    return await ApiProvider.post(AppConstants.deliveryApplyUrl, body: {
      'vehicle_type': vehicleType,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Get delivery dashboard
  static Future<ApiResponse> getDeliveryDashboard() async {
    return await ApiProvider.get(AppConstants.deliveryDashboardUrl);
  }

  // ================================
  // VENDOR ORDER MANAGEMENT
  // ================================

  /// Get vendor's orders
  static Future<ApiResponse> getVendorOrders({String? status, int page = 1}) async {
    final params = <String, String>{'page': page.toString()};
    if (status != null) params['status'] = status;
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return await ApiProvider.get('${AppConstants.vendorOrdersUrl}?$query');
  }

  /// Validate (confirm) an order
  static Future<ApiResponse> validateOrder(int orderId) async {
    return await ApiProvider.post('${AppConstants.vendorOrdersUrl}/$orderId/validate', body: {});
  }

  /// Reject an order
  static Future<ApiResponse> rejectOrder(int orderId, {String? reason}) async {
    return await ApiProvider.post('${AppConstants.vendorOrdersUrl}/$orderId/reject', body: {
      if (reason != null) 'reason': reason,
    });
  }

  /// Assign delivery person to an order
  static Future<ApiResponse> assignDeliveryPerson(int orderId, int deliveryPersonId) async {
    return await ApiProvider.post('${AppConstants.vendorOrdersUrl}/$orderId/assign-delivery', body: {
      'delivery_person_id': deliveryPersonId,
    });
  }

  /// Get available delivery persons for a specific order's delivery company
  static Future<ApiResponse> getAvailableDeliveryPersons({int? orderId, int? companyId}) async {
    final params = <String, String>{};
    if (orderId != null) params['order_id'] = orderId.toString();
    if (companyId != null) params['company_id'] = companyId.toString();
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final url = query.isNotEmpty
        ? '${AppConstants.deliveryPersonsUrl}?$query'
        : AppConstants.deliveryPersonsUrl;
    return await ApiProvider.get(url);
  }

  /// Check if vendor has active orders
  static Future<ApiResponse> checkActiveOrders() async {
    print('');
    print('========================================');
    print('📦 VENDOR SERVICE: Check Active Orders');
    print('========================================');

    try {
      final response = await ApiProvider.get('${AppConstants.vendorOrdersUrl}/check-active');

      print('✅ VENDOR SERVICE: Response received');
      print('  └─ Success: ${response.success}');
      print('  └─ Has Active Orders: ${response.data?['has_active_orders']}');
      print('  └─ Count: ${response.data?['active_orders_count']}');
      print('========================================');

      return response;
    } catch (e) {
      print('💥 VENDOR SERVICE: Exception!');
      print('  └─ Error: $e');
      print('========================================');
      rethrow;
    }
  }
}
