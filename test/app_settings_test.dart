import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/data/providers/app_config_service.dart';

void main() {
  group('Lecture des paramètres publics', () {
    test('un groupe vide envoyé en liste par le backend devient un objet vide', () {
      // Réponse réelle de GET /api/settings : PHP sérialise le groupe vide
      // en `[]`.
      final body = <String, dynamic>{
        'general': {'support_user_id': 70},
        'system': <dynamic>[],
      };

      final general = AppConfigService.asObject(body['general']);
      final system = AppConfigService.asObject(body['system']);

      expect(general['support_user_id'], 70);
      expect(system, isEmpty);
      expect(system.containsKey('min_deposit_amount'), isFalse);
    });

    test('un groupe renseigné est lu tel quel', () {
      final system = AppConfigService.asObject({
        'min_deposit_amount': '500',
        'currency': 'XOF',
      });

      expect(system['min_deposit_amount'], '500');
      expect(system['currency'], 'XOF');
    });

    test('une valeur absente ou inattendue donne un objet vide', () {
      expect(AppConfigService.asObject(null), isEmpty);
      expect(AppConfigService.asObject('oops'), isEmpty);
    });
  });
}
