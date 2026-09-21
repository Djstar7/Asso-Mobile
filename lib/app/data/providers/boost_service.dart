import 'api_provider.dart';

/// Asso Ads — sponsoring d'un article du vendeur.
///
/// L'achat passe par [PackageService] (rails wallet / kpay / stripe communs à
/// tous les forfaits) : ce service ne sert qu'à lister les offres et à suivre
/// les campagnes.
class BoostService {
  static const String boostPackagesUrl = '/v1/packages/boost';
  static const String boostsUrl = '/v1/vendor/boosts';

  /// Forfaits de sponsoring proposés (prix, durée, audience).
  static Future<ApiResponse> getPackages() {
    return ApiProvider.get(boostPackagesUrl);
  }

  /// Campagnes du vendeur, la plus récente d'abord.
  static Future<ApiResponse> getCampaigns({int limit = 20}) {
    return ApiProvider.get(boostsUrl, queryParams: {'limit': '$limit'});
  }

  /// Détail d'une campagne : portée délivrée, personnes touchées, interactions.
  static Future<ApiResponse> getCampaign(int boostId) {
    return ApiProvider.get('$boostsUrl/$boostId');
  }

  /// Le produit peut-il être sponsorisé ? Sert à griser le bouton.
  static Future<ApiResponse> getProductStatus(int productId) {
    return ApiProvider.get('/v1/vendor/products/$productId/boost-status');
  }

  /// Arrêt anticipé. La portée déjà délivrée reste due : pas de remboursement.
  static Future<ApiResponse> cancel(int boostId) {
    return ApiProvider.post('$boostsUrl/$boostId/cancel');
  }
}
