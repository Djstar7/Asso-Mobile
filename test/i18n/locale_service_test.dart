import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/core/services/locale_service.dart';

void main() {
  String lang(String iso, {String device = 'en'}) =>
      LocaleService.languageForCountry(iso, deviceLanguage: device);

  test('pays francophones → français', () {
    for (final iso in ['BJ', 'SN', 'CI', 'GA', 'FR', 'cd']) {
      expect(lang(iso), 'fr', reason: iso);
    }
  });

  test('pays anglophones et autres → anglais', () {
    for (final iso in ['NG', 'GH', 'GB', 'US', 'CN', 'TR', 'DE', '']) {
      expect(lang(iso, device: 'fr'), 'en', reason: iso);
    }
  });

  test('Cameroun et Canada suivent la langue du téléphone', () {
    expect(lang('CM', device: 'fr'), 'fr');
    expect(lang('CM', device: 'en'), 'en');
    expect(lang('CA', device: 'fr'), 'fr');
    expect(lang('CA', device: 'es'), 'en');
  });
}
