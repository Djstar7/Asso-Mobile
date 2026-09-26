import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../core/values/constants.dart';

class AppConfigService {
  static final http.Client _client = http.Client();

  /// Lit un objet JSON, en tolérant la liste vide.
  ///
  /// Le backend (PHP) sérialise un groupe sans paramètre en `[]` et non en
  /// `{}` : `"system": []`. Le `as Map` qui suivait levait, et aucun
  /// paramètre n'était jamais chargé — l'application gardait ses valeurs par
  /// défaut.
  static Map<String, dynamic> asObject(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  /// Délai maximal du chargement au démarrage.
  ///
  /// `main` attend ces paramètres avant d'afficher la première image : sans
  /// borne, une connexion qui ne répond pas laissait l'application figée sur
  /// l'écran de lancement. Passé ce délai, les valeurs par défaut s'appliquent.
  static const Duration startupTimeout = Duration(seconds: 8);

  /// Récupérer tous les settings publics (general + system)
  static Future<Map<String, dynamic>> getAllSettings() async {
    try {
      final url = '${AppConstants.baseUrl}/settings';
      developer.log('GET $url', name: 'AppConfigService');

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(startupTimeout);

      developer.log(
        'Response status: ${response.statusCode}',
        name: 'AppConfigService',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Chaque groupe (general, system) peut arriver en `[]`.
          final groups = asObject(data['data']);
          return {
            for (final entry in groups.entries)
              entry.key: asObject(entry.value),
          };
        }
      }

      throw Exception('Failed to load settings');
    } catch (e) {
      developer.log('Error loading settings: $e', name: 'AppConfigService', error: e);
      rethrow;
    }
  }

  /// Récupérer les settings d'un groupe spécifique (general ou system)
  static Future<Map<String, dynamic>> getSettingsByGroup(String group) async {
    try {
      final url = '${AppConstants.baseUrl}/settings/group/$group';
      developer.log('GET $url', name: 'AppConfigService');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return asObject(data['data']);
        }
      }

      throw Exception('Failed to load settings for group: $group');
    } catch (e) {
      developer.log('Error loading settings for group $group: $e', name: 'AppConfigService', error: e);
      rethrow;
    }
  }

  /// Récupérer un setting spécifique par sa clé
  static Future<dynamic> getSetting(String key) async {
    try {
      final url = '${AppConstants.baseUrl}/settings/$key';
      developer.log('GET $url', name: 'AppConfigService');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['value'];
        }
      }

      throw Exception('Failed to load setting: $key');
    } catch (e) {
      developer.log('Error loading setting $key: $e', name: 'AppConfigService', error: e);
      rethrow;
    }
  }
}
