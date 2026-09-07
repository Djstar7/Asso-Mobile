import 'package:get/get.dart';

import 'api_provider.dart';
import '../models/wholesale_models.dart';
import 'currency_service.dart';

/// API du module GROS (ASSO CHINA / DUBAÏ / TURQUIE).
class ImportService {
  /// Catalogue gros d'un pays (produits à paliers + options d'expédition).
  static Future<WholesaleCatalog?> getCatalog(String countryCode) async {
    final targetCurrency = Get.isRegistered<CurrencyService>()
        ? CurrencyService.to.currencyCode
        : 'XAF';
    final res = await ApiProvider.get(
      '/v1/import/$countryCode/products',
      queryParams: {'currency': targetCurrency},
    );
    if (res.success && res.data != null) {
      return WholesaleCatalog.fromJson(Map<String, dynamic>.from(res.data!));
    }
    return null;
  }

  /// Crée une commande EN GROS.
  /// [items] : [{ 'product_id': int, 'price_tier_id': int, 'quantity': int }, ...]
  /// Retourne l'ApiResponse (data contient order_id, approval_url, payment_reference).
  static Future<ApiResponse> createOrder({
    required List<Map<String, dynamic>> items,
    required int shippingOptionId,
    double? shippingWeightKg,
    double? shippingCbm,
    String paymentMode = 'kpay_direct',
    String? provider,
    String? phoneNumber,
    String? deliveryAddress,
    String? notes,
  }) async {
    return await ApiProvider.post('/v1/import/orders', body: {
      'items': items,
      'shipping_option_id': shippingOptionId,
      if (shippingWeightKg != null) 'shipping_weight_kg': shippingWeightKg,
      if (shippingCbm != null) 'shipping_cbm': shippingCbm,
      'payment_mode': paymentMode,
      if (provider != null) 'provider': provider,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (notes != null) 'notes': notes,
    });
  }
}
