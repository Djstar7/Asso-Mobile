import 'api_provider.dart';

/// Statistiques boutiques (P8).
///
/// - [track] : signale une interaction acheteur (consultation d'un produit,
///   prise de contact). La visite d'une boutique est comptée côté serveur à
///   l'ouverture de sa page publique. Appel « fire and forget » : un échec ne
///   doit jamais gêner l'acheteur.
/// - [getVendorStatistics] : tableau de bord du vendeur sur une période.
class StatisticsService {
  static const String trackUrl = '/v1/analytics/track';
  static const String vendorStatisticsUrl = '/v1/vendor/statistics';

  static const String productView = 'product_view';
  static const String contact = 'contact';

  static Future<void> track(
    String event, {
    int? productId,
    int? shopId,
  }) async {
    if (productId == null && shopId == null) return;
    try {
      await ApiProvider.post(trackUrl, body: {
        'event': event,
        if (productId != null) 'product_id': productId,
        if (shopId != null) 'shop_id': shopId,
      });
    } catch (_) {
      // Statistique perdue : sans incidence pour l'utilisateur.
    }
  }

  static void trackProductView(dynamic productId) {
    final id = int.tryParse(productId?.toString() ?? '');
    if (id != null) track(productView, productId: id);
  }

  static void trackContact({dynamic productId, dynamic shopId}) {
    track(
      contact,
      productId: int.tryParse(productId?.toString() ?? ''),
      shopId: int.tryParse(shopId?.toString() ?? ''),
    );
  }

  /// [period] : 7d | 30d | 90d | 365d | all
  static Future<ApiResponse> getVendorStatistics({String period = '30d'}) {
    return ApiProvider.get(vendorStatisticsUrl, queryParams: {'period': period});
  }
}
