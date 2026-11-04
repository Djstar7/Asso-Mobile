import 'package:get/get.dart';

import 'api_provider.dart';
import '../models/wholesale_models.dart';
import 'currency_service.dart';

/// API du module GROS (ASSO CHINA / DUBAÏ / TURQUIE).
class ImportService {
  /// Nombre d'articles par page du catalogue gros.
  static const int perPage = 20;

  /// Une page du catalogue gros d'un pays (produits à paliers + options
  /// d'expédition), du plus récent au plus ancien.
  static Future<WholesaleCatalog?> getCatalog(
    String countryCode, {
    String? query,
    int page = 1,
    int perPage = perPage,
  }) async {
    final targetCurrency = Get.isRegistered<CurrencyService>()
        ? CurrencyService.to.currencyCode
        : 'XAF';
    final res = await ApiProvider.get(
      '/v1/import/$countryCode/products',
      queryParams: {
        'currency': targetCurrency,
        'page': page,
        'per_page': perPage,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    if (res.success && res.data != null) {
      return WholesaleCatalog.fromJson(Map<String, dynamic>.from(res.data!));
    }
    return null;
  }

  /// Fiche d'un produit en gros et ses options d'expédition, pour l'ouvrir
  /// depuis son seul identifiant (annonce, lien partagé).
  static Future<ApiResponse> getProduct(int id) {
    final targetCurrency = Get.isRegistered<CurrencyService>()
        ? CurrencyService.to.currencyCode
        : 'XAF';
    return ApiProvider.get(
      '/v1/import/products/$id',
      queryParams: {'currency': targetCurrency},
    );
  }

  /// Crée une commande EN GROS : import jusqu'à Douala, puis livraison [delivery].
  /// [items] : [{ 'product_id': int, 'price_tier_id': int, 'quantity': int }, ...]
  /// Retourne l'ApiResponse (data contient order_id, approval_url, payment_reference).
  static Future<ApiResponse> createOrder({
    required List<Map<String, dynamic>> items,
    required int shippingOptionId,
    String paymentMode = 'kpay_direct',
    String? provider,
    String? phoneNumber,
    Map<String, dynamic> delivery = const {},
    String? notes,
  }) async {
    return await ApiProvider.post(
      '/v1/import/orders',
      body: {
        'items': items,
        'shipping_option_id': shippingOptionId,
        'payment_mode': paymentMode,
        if (provider != null) 'provider': provider,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        // Livraison SOLEX de Douala jusqu'au client (voir WholesaleDelivery.orderFields).
        ...delivery,
        if (notes != null) 'notes': notes,
      },
    );
  }

  /// Nombre de résultats d'une recherche pour chaque pays d'import ({'CN': 2, 'TR': 1}).
  static Future<Map<String, int>> searchCounts(String query) async {
    final res = await ApiProvider.get(
      '/v1/import/search',
      queryParams: {'q': query.trim()},
    );
    final counts = res.data?['counts'];
    if (!res.success || counts is! Map) return {};
    return counts.map(
      (k, v) => MapEntry(
        k.toString(),
        v is num ? v.toInt() : int.tryParse('$v') ?? 0,
      ),
    );
  }
}
