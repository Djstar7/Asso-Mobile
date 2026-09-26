import 'address_search.dart';

/// Localisation lisible « Ville, Pays » (ex. « Douala, Cameroun »).
class LocationLabel {
  final String address;
  final String? city;
  final String? country;

  const LocationLabel({required this.address, this.city, this.country});

  /// « Ville, Pays », ou null si aucun des deux n'est connu.
  String? get label => format(city, country);

  static String? format(String? city, String? country) {
    final parts = [city, country]
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Lit une réponse Nominatim (`addressdetails=1`) : adresse courte + ville + pays.
  static LocationLabel fromNominatim(
    Map<String, dynamic> data, {
    required double latitude,
    required double longitude,
  }) {
    final details = Map<String, dynamic>.from(data['address'] ?? const {});
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = details[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final city = pick(['city', 'town', 'municipality', 'village', 'county']);
    final country = pick(['country']);
    final area = pick(['road', 'suburb', 'neighbourhood', 'quarter']);
    final parts = <String>{?area, ?city, ?country}.toList();

    return LocationLabel(
      address: parts.isNotEmpty
          ? parts.join(', ')
          : (data['display_name']?.toString() ??
                'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}'),
      city: city,
      country: country,
    );
  }

  /// Géocodage inverse ([AddressSearch.reverse]). Null si aucun service ne répond.
  static Future<LocationLabel?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final data = await AddressSearch.reverse(latitude, longitude);
    if (data == null) return null;
    return fromNominatim(data, latitude: latitude, longitude: longitude);
  }

  /// Libellé à afficher pour une boutique ou un produit renvoyé par l'API.
  /// Le serveur fournit `location_label` ; les anciennes réponses n'ont que l'adresse.
  static String? fromApi(Map<String, dynamic>? data) {
    if (data == null) return null;
    final label = data['location_label']?.toString().trim();
    if (label != null && label.isNotEmpty) return label;
    return format(data['city']?.toString(), data['country']?.toString());
  }
}
