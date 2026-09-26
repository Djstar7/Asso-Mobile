import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:asso/app/core/utils/address_search.dart';
import 'package:asso/app/core/utils/location_label.dart';

Map<String, dynamic> _photon(Map<String, dynamic> properties) => {
  'type': 'Feature',
  'properties': properties,
  'geometry': {
    'type': 'Point',
    'coordinates': [9.7393663, 4.094354],
  },
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(json.encode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  tearDown(() => AddressSearch.newClient = http.Client.new);

  group('AddressSearch.fromPhoton', () {
    test('un quartier devient la zone de l’adresse', () {
      final result = AddressSearch.fromPhoton(
        _photon({
          'osm_key': 'place',
          'osm_value': 'suburb',
          'name': 'Bonamoussadi',
          'city': 'Douala V',
          'state': 'Région du Littoral',
          'country': 'Cameroun',
          'countrycode': 'CM',
        }),
      )!;

      expect(result['lat'], 4.094354);
      expect(result['lon'], 9.7393663);
      expect(
        result['display_name'],
        'Bonamoussadi, Douala V, Région du Littoral, Cameroun',
      );
      final label = LocationLabel.fromNominatim(
        result,
        latitude: 4.09,
        longitude: 9.73,
      );
      expect(label.address, 'Bonamoussadi, Douala V, Cameroun');
      expect(label.city, 'Douala V');
      expect(label.country, 'Cameroun');
    });

    test('une adresse garde son numéro, sa rue et son quartier', () {
      final result = AddressSearch.fromPhoton(
        _photon({
          'osm_key': 'place',
          'osm_value': 'house',
          'housenumber': '12',
          'street': 'Rue Joss',
          'district': 'Bonanjo',
          'city': 'Douala I',
          'country': 'Cameroun',
        }),
      )!;

      expect(
        result['display_name'],
        '12 Rue Joss, Bonanjo, Douala I, Cameroun',
      );
      expect((result['address'] as Map)['road'], 'Rue Joss');
      expect((result['address'] as Map)['suburb'], 'Bonanjo');
    });

    test('une rue ne répète pas son nom', () {
      final result = AddressSearch.fromPhoton(
        _photon({
          'osm_key': 'highway',
          'osm_value': 'residential',
          'name': 'Boulevard de la Liberté',
          'district': 'Akwa',
          'city': 'Douala I',
          'country': 'Cameroun',
        }),
      )!;

      expect(
        result['display_name'],
        'Boulevard de la Liberté, Akwa, Douala I, Cameroun',
      );
      expect((result['address'] as Map)['road'], 'Boulevard de la Liberté');
    });

    test('un commerce garde son nom devant sa rue', () {
      final result = AddressSearch.fromPhoton(
        _photon({
          'osm_key': 'shop',
          'osm_value': 'bakery',
          'name': 'Boulangerie Saker',
          'street': 'Boulevard de la Liberté',
          'district': 'Akwa',
          'city': 'Douala I',
          'country': 'Cameroun',
        }),
      )!;

      expect(
        result['display_name'],
        'Boulangerie Saker, Boulevard de la Liberté, Akwa, Douala I, Cameroun',
      );
    });

    test('une ville sans champ « city » est prise comme ville', () {
      final result = AddressSearch.fromPhoton(
        _photon({
          'osm_key': 'place',
          'osm_value': 'city',
          'name': 'Abidjan',
          'country': 'Côte d’Ivoire',
          'countrycode': 'CI',
        }),
      )!;

      expect(result['display_name'], 'Abidjan, Côte d’Ivoire');
      expect((result['address'] as Map)['city'], 'Abidjan');
      expect((result['address'] as Map)['country_code'], 'ci');
    });

    test('un résultat sans coordonnées est écarté', () {
      expect(
        AddressSearch.fromPhoton({
          'properties': {'name': 'Akwa'},
        }),
        isNull,
      );
    });
  });

  group('AddressSearch.search', () {
    test('interroge Photon près de la carte, sans filtre de pays', () async {
      late Uri asked;
      AddressSearch.newClient = () => MockClient((request) async {
        asked = request.url;
        return _json({
          'features': [
            _photon({
              'osm_key': 'place',
              'osm_value': 'suburb',
              'name': 'Bonamoussadi',
              'city': 'Douala V',
              'country': 'Cameroun',
            }),
          ],
        });
      });

      final results = await AddressSearch.search(
        'Bonamou',
        nearLatitude: 4.05,
        nearLongitude: 9.77,
      );

      expect(asked.host, 'photon.komoot.io');
      expect(asked.queryParameters['q'], 'Bonamou');
      expect(asked.queryParameters['lat'], '4.05');
      expect(asked.queryParameters['lon'], '9.77');
      expect(asked.queryParameters.containsKey('countrycodes'), isFalse);
      expect(results.single['display_name'], startsWith('Bonamoussadi'));
    });

    test('bascule sur Nominatim quand Photon ne répond pas', () async {
      final hosts = <String>[];
      AddressSearch.newClient = () => MockClient((request) async {
        hosts.add(request.url.host);
        if (request.url.host == 'photon.komoot.io') {
          return http.Response('Service Unavailable', 503);
        }
        return _json([
          {
            'display_name': 'Akwa, Douala I, Cameroun',
            'lat': '4.0525440',
            'lon': '9.6963304',
            'address': {'suburb': 'Akwa', 'city': 'Douala I'},
          },
        ]);
      });

      final results = await AddressSearch.search('Akwa');

      expect(hosts, ['photon.komoot.io', 'nominatim.openstreetmap.org']);
      expect(results.single['lat'], 4.052544);
      expect(results.single['lon'], 9.6963304);
    });

    test('signale l’échec quand aucun service ne répond', () async {
      AddressSearch.newClient = () =>
          MockClient((request) async => http.Response('Access denied', 403));

      expect(
        AddressSearch.search('Akwa'),
        throwsA(isA<AddressSearchException>()),
      );
    });
  });

  group('AddressSearch.reverse', () {
    test('se replie sur Photon quand Nominatim refuse', () async {
      AddressSearch.newClient = () => MockClient((request) async {
        if (request.url.host == 'nominatim.openstreetmap.org') {
          return http.Response('Access denied', 403);
        }
        return _json({
          'features': [
            _photon({
              'osm_key': 'place',
              'osm_value': 'suburb',
              'name': 'Bonamoussadi',
              'city': 'Douala V',
              'country': 'Cameroun',
            }),
          ],
        });
      });

      final result = await AddressSearch.reverse(4.09, 9.73);

      expect(result?['display_name'], 'Bonamoussadi, Douala V, Cameroun');
    });

    test('rend null quand aucun service ne répond', () async {
      AddressSearch.newClient = () =>
          MockClient((request) async => throw http.ClientException('offline'));

      expect(await AddressSearch.reverse(4.09, 9.73), isNull);
    });
  });
}
