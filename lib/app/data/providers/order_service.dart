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

  /// Create order.
  /// paymentMode: 'wallet' (escrow depuis solde) ou 'kpay_direct' (PayIn KPay).
  /// En mode kpay_direct, fournir [kpayProvider] (code opérateur) et [kpayPhone].
  static Future<ApiResponse> createOrder({
    required List<Map<String, dynamic>> items,
    int? deliveryCompanyId,
    int? deliveryZoneId,
    String walletProvider = 'kpay',
    String paymentMode = 'wallet',
    String? kpayProvider,
    String? kpayPhone,
    String? deliveryAddress,
    String? deliveryAddressDetails,
    String? customerPhone,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? notes,
  }) async {
    return await ApiProvider.post(AppConstants.ordersUrl, body: {
      'items': items,
      'delivery_company_id': deliveryCompanyId,
      'delivery_zone_id': deliveryZoneId,
      'payment_mode': paymentMode,
      'wallet_provider': walletProvider,
      if (kpayProvider != null) 'provider': kpayProvider,
      if (kpayPhone != null) 'phone_number': kpayPhone,
      'delivery_address': deliveryAddress,
      'delivery_address_details': deliveryAddressDetails,
      'customer_phone': customerPhone,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'notes': notes,
    });
  }

  /// Statut de paiement d'une commande (mode kpay_direct) — re-vérifie chez KPay.
  static Future<ApiResponse> orderPaymentStatus(int orderId) async {
    return await ApiProvider.get('${AppConstants.ordersUrl}/$orderId/payment-status');
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
