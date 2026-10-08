import 'package:asso/app/core/values/kpay_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ElgioPay : seuls le Cameroun et ses deux opérateurs restent', () {
    final countries = KPayCatalog.restrictedTo({'MTN_MOMO_CMR', 'ORANGE_CMR'});

    expect(countries.map((c) => c.iso3), ['CMR']);
    expect(
      countries.single.operators.map((o) => o.providerCode),
      ['MTN_MOMO_CMR', 'ORANGE_CMR'],
    );
  });

  test('Opérateur isolé : le pays ne garde que lui', () {
    final countries = KPayCatalog.restrictedTo({'ORANGE_CMR'});

    expect(countries.single.operators.map((o) => o.name), ['Orange Money']);
  });

  test('Opérateur camerounais déduit du préfixe du numéro', () {
    String? detect(String n) => KPayCatalog.detectProviderCode('CMR', n);

    expect(detect('658895572'), 'ORANGE_CMR');
    expect(detect('699000000'), 'ORANGE_CMR');
    expect(detect('670000001'), 'MTN_MOMO_CMR');
    expect(detect('651234567'), 'MTN_MOMO_CMR');
    expect(detect('662000000'), isNull); // préfixe inconnu : choix laissé
    expect(detect('65'), isNull);
    expect(KPayCatalog.detectProviderCode('SEN', '771234567'), isNull);
  });

  test('Sans restriction connue : tout le catalogue KPay', () {
    expect(KPayCatalog.restrictedTo(null), KPayCatalog.countries);
    expect(KPayCatalog.restrictedTo({}), KPayCatalog.countries);
  });
}
