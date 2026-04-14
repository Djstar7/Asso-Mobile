import '../../core/values/constants.dart';
import 'api_provider.dart';

class OrderService {
  /// Get user orders
  static Future<ApiResponse> getOrders({
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (status != null) params['status'] = status;

    return await ApiProvider.get(AppConstants.ordersUrl, queryParams: params);
  }

  /// Get single order
  static Future<ApiResponse> getOrder(int id) async {
    return await ApiProvider.get('${AppConstants.ordersUrl}/$id');
  }

  /// Create order with escrow (wallet lock)
  static Future<ApiResponse> createOrder({
    required List<Map<String, dynamic>> items,
    int? deliveryCompanyId,
    int? deliveryZoneId,
    required String walletProvider,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? notes,
  }) async {
    return await ApiProvider.post(AppConstants.ordersUrl, body: {
      'items': items,
      'delivery_company_id': deliveryCompanyId,
      'delivery_zone_id': deliveryZoneId,
      'wallet_provider': walletProvider,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'notes': notes,
    });
  }

  /// Cancel order
  static Future<ApiResponse> cancelOrder(int id, {String? reason}) async {
    return await ApiProvider.post('${AppConstants.ordersUrl}/$id/cancel', body: {
      'reason': reason,
    });
  }

  /// Initiate payment
  static Future<ApiResponse> initiatePayment({
    required int orderId,
    required String paymentMethod,
    String? phoneNumber,
  }) async {
    return await ApiProvider.post(AppConstants.paymentInitiateUrl, body: {
      'order_id': orderId,
      'payment_method': paymentMethod,
      'phone_number': phoneNumber,
    });
  }

  /// Rate a delivered order
  static Future<ApiResponse> rateOrder(int orderId, {required int rating, String? comment}) async {
    return await ApiProvider.post('${AppConstants.ordersUrl}/$orderId/rate', body: {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  /// Check payment status
  static Future<ApiResponse> checkPaymentStatus(String reference) async {
    return await ApiProvider.get('${AppConstants.paymentStatusUrl}/$reference');
  }
}
