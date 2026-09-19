import '../providers/api_provider.dart';
import '../../core/values/constants.dart';

class DeliveryService {
  /// Get pending delivery requests
  static Future<ApiResponse> getPendingRequests() async {
    return await ApiProvider.get(AppConstants.deliveryPendingUrl);
  }

  /// Get active (in-progress) deliveries
  static Future<ApiResponse> getActiveDeliveries() async {
    return await ApiProvider.get(AppConstants.deliveryActiveUrl);
  }

  /// Accept a delivery request (start the delivery)
  static Future<ApiResponse> acceptDelivery(int orderId) async {
    return await ApiProvider.post('/v1/delivery/$orderId/accept', body: {});
  }

  /// Complete a delivery with confirmation code
  static Future<ApiResponse> completeDelivery(int orderId, {required String confirmationCode}) async {
    return await ApiProvider.post('/v1/delivery/$orderId/complete', body: {
      'confirmation_code': confirmationCode,
    });
  }

  /// Get delivery partners with calculated pricing for a product
  /// Le prix dépend du poids réel : poids unitaire × [quantity].
  static Future<ApiResponse> getDeliveryPartnersWithPricing({
    required int productId,
    int quantity = 1,
    double? latitude,
    double? longitude,
    String? city,
    String? country,
    String? quarter,
  }) async {
    final params = <String, dynamic>{
      'product_id': productId,
      'quantity': quantity < 1 ? 1 : quantity,
    };
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (country != null && country.isNotEmpty) params['country'] = country;
    // Quartier (grille zone à zone, ex. SOLEX Douala).
    if (quarter != null && quarter.isNotEmpty) params['quarter'] = quarter;

    return await ApiProvider.get('/v1/delivery/partners', queryParams: params);
  }

  /// Check if delivery is available at a location
  static Future<ApiResponse> checkDeliveryAvailability({
    required double latitude,
    required double longitude,
  }) async {
    return await ApiProvider.post(
      '/v1/delivery/check-availability',
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }
}
