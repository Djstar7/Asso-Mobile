import 'dart:convert';

import 'package:http/http.dart' as http;
import '../services/locale_service.dart';

/// La recherche d'adresse n'a pas pu joindre de service (réseau, blocage).
class AddressSearchException implements Exception {
  const AddressSearchException();
}

/// Recherche d'adresses et géocodage inverse, communs à toutes les cartes.
///
/// La recherche passe par Photon (komoot, données OpenStreetMap) : il trouve
/// un lieu dès les premières lettres (« Bonamou » → Bonamoussadi) et tolère
/// les fautes. Nominatim, utilisé seul jusque-là, ne répond qu'aux mots
/// complets : la liste restait vide pendant la saisie et l'adresse semblait
/// refusée. Sa charte interdit d'ailleurs la recherche au fil de la frappe ;
/// il ne sert plus que de secours, et pour le géocodage inverse où il décrit
/// mieux le point touché.
///
/// Chaque résultat a la forme d'une réponse Nominatim (`display_name`, `lat`,
/// `lon` en double, `address`) : `LocationLabel.fromNominatim` et
/// `MapSearchResults` les lisent tels quels.
class AddressSearch {
  AddressSearch._();

  /// Client HTTP d'une requête ; remplacé dans les tests.
  static http.Client Function() newClient = http.Client.new;

  static const _timeout = Duration(seconds: 10);
  static Map<String, String> get _headers => {
    // Nominatim bloque les User-Agent génériques des bibliothèques HTTP.
    'User-Agent': 'AssoApp/1.0 (com.asso.asso)',
    'Accept-Language': LocaleService.currentLanguage,
  };

  /// Adresses correspondant à [query], les plus proches de
  /// ([nearLatitude], [nearLongitude]) en tête.
  ///
  /// Aucune restriction de pays : l'app sert aussi la Côte d'Ivoire, le
  /// Sénégal, le Gabon… La proximité suffit à remonter les lieux locaux.
  ///
  /// Lève [AddressSearchException] si aucun service n'a répondu.
  static Future<List<Map<String, dynamic>>> search(
    String query, {
    double? nearLatitude,
    double? nearLongitude,
    int limit = 5,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    try {
      final data = await _getJson(
        Uri.https('photon.komoot.io', '/api/', {
          'q': q,
          'limit': '$limit',
          'lang': LocaleService.currentLanguage,
          if (nearLatitude != null && nearLongitude != null) ...{
            'lat': '$nearLatitude',
            'lon': '$nearLongitude',
            // Rayon d'une région et poids fort de la proximité : « Bastos »
            // donne Yaoundé avant le Brésil depuis le Cameroun.
            'zoom': '10',
            'location_bias_scale': '0.1',
          },
        }),
      );
      return ((data as Map)['features'] as List)
          .whereType<Map>()
          .map(fromPhoton)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      // Photon indisponible : Nominatim prend le relais.
    }

    try {
      final data = await _getJson(
        Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': q,
          'format': 'json',
          'addressdetails': '1',
          'limit': '$limit',
          'accept-language': LocaleService.currentLanguage,
        }),
      );
      return (data as List)
          .whereType<Map>()
          .map(fromNominatim)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      throw const AddressSearchException();
    }
  }

  /// Adresse du point touché, ou null si aucun service n'a répondu.
  static Future<Map<String, dynamic>?> reverse(
    double latitude,
    double longitude,
  ) async {
    try {
      final data = await _getJson(
        Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'json',
          'lat': '$latitude',
          'lon': '$longitude',
          'zoom': '18',
          'addressdetails': '1',
          'accept-language': LocaleService.currentLanguage,
        }),
      );
      final result = fromNominatim(data as Map);
      if (result != null) return result;
    } catch (_) {}

    try {
      final data = await _getJson(
        Uri.https('photon.komoot.io', '/reverse', {
          'lat': '$latitude',
          'lon': '$longitude',
          'lang': LocaleService.currentLanguage,
          'limit': '1',
        }),
      );
      final features = (data as Map)['features'] as List;
      if (features.isNotEmpty && features.first is Map) {
        return fromPhoton(features.first as Map);
      }
    } catch (_) {}

    return null;
  }

  static Future<dynamic> _getJson(Uri url) async {
    final client = newClient();
    try {
      final response = await client
          .get(url, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', url);
      }
      return json.decode(utf8.decode(response.bodyBytes));
    } finally {
      client.close();
    }
  }

  static double? _toDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  /// Résultat Nominatim avec des coordonnées en double (il les envoie en
  /// texte) ; null s'il n'a pas de position.
  static Map<String, dynamic>? fromNominatim(Map item) {
    final lat = _toDouble(item['lat']);
    final lon = _toDouble(item['lon']);
    final name = item['display_name']?.toString().trim() ?? '';
    if (lat == null || lon == null || name.isEmpty) return null;
    return {
      'display_name': name,
      'lat': lat,
      'lon': lon,
      'address': Map<String, dynamic>.from(item['address'] as Map? ?? const {}),
    };
  }

  static const _settlements = {
    'city',
    'town',
    'village',
    'municipality',
    'hamlet',
  };

  /// Convertit un résultat Photon (GeoJSON) au format Nominatim ; null s'il
  /// n'a pas de position.
  static Map<String, dynamic>? fromPhoton(Map feature) {
    final props = Map<String, dynamic>.from(
      feature['properties'] as Map? ?? const {},
    );
    final coords = (feature['geometry'] as Map?)?['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = _toDouble(coords[0]);
    final lat = _toDouble(coords[1]);
    if (lat == null || lon == null) return null;

    String? pick(String key) {
      final value = props[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    final name = pick('name');
    final isPlace = props['osm_key'] == 'place';
    final isSettlement = isPlace && _settlements.contains(props['osm_value']);
    // Photon range une rue ou un quartier sous son seul nom : on le replace
    // dans le champ Nominatim correspondant.
    final road =
        pick('street') ?? (props['osm_key'] == 'highway' ? name : null);
    final area =
        pick('district') ??
        pick('locality') ??
        (isPlace && !isSettlement ? name : null);
    final city = pick('city') ?? (isSettlement ? name : null);
    final country = pick('country');
    final countryCode = pick('countrycode')?.toLowerCase();

    final street = road == null ? null : [?pick('housenumber'), road].join(' ');
    final parts = <String>{
      // Le nom d'une rue est déjà sa rue : il ne se répète pas.
      if (name != null && name != road) name,
      ?street,
      ?area,
      ?city,
      ?pick('state'),
      ?country,
    };
    if (parts.isEmpty) return null;

    return {
      'display_name': parts.join(', '),
      'lat': lat,
      'lon': lon,
      'address': {
        'road': ?road,
        'house_number': ?pick('housenumber'),
        'suburb': ?area,
        'city': ?city,
        'county': ?pick('county'),
        'state': ?pick('state'),
        'postcode': ?pick('postcode'),
        'country': ?country,
        'country_code': ?countryCode,
      },
    };
  }
}
