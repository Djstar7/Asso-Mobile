/// Catalogue KPay : pays couverts, indicatifs, drapeaux et opérateurs.
///
/// Le `providerCode` est la valeur EXACTE à envoyer au backend (champ `provider`)
/// pour l'init dépôt/retrait KPay ; le pays et la devise en sont déduits côté KPay.
/// Source : documentation d'intégration KPay.
library;

class KPayOperator {
  final String name; // libellé affiché (ex. "MTN MoMo")
  final String providerCode; // code KPay (ex. "MTN_MOMO_CMR")

  const KPayOperator(this.name, this.providerCode);
}

class KPayCountry {
  final String iso3; // ex. "CMR"
  final String iso2; // ex. "CM" (pour le drapeau emoji)
  final String name; // nom français
  final String dialCode; // indicatif sans "+" (ex. "237")
  final String currency; // devise principale
  final List<KPayOperator> operators;

  const KPayCountry({
    required this.iso3,
    required this.iso2,
    required this.name,
    required this.dialCode,
    required this.currency,
    required this.operators,
  });

  /// Drapeau emoji dérivé de l'ISO2 (regional indicator symbols).
  String get flag {
    if (iso2.length != 2) return '🏳️';
    final base = 0x1F1E6;
    final a = iso2.codeUnitAt(0) - 0x41;
    final b = iso2.codeUnitAt(1) - 0x41;
    return String.fromCharCode(base + a) + String.fromCharCode(base + b);
  }

  /// "🇨🇲 +237"
  String get flagWithDial => '$flag +$dialCode';
}

class KPayCatalog {
  const KPayCatalog._();

  /// Les 12 pays couverts par KPay (opérateurs Wave SEN/CIV temporairement exclus).
  static const List<KPayCountry> countries = [
    KPayCountry(iso3: 'BEN', iso2: 'BJ', name: 'Bénin', dialCode: '229', currency: 'XOF', operators: [
      KPayOperator('MTN MoMo', 'MTN_MOMO_BEN'),
      KPayOperator('Moov', 'MOOV_BEN'),
    ]),
    KPayCountry(iso3: 'CMR', iso2: 'CM', name: 'Cameroun', dialCode: '237', currency: 'XAF', operators: [
      KPayOperator('MTN MoMo', 'MTN_MOMO_CMR'),
      KPayOperator('Orange Money', 'ORANGE_CMR'),
    ]),
    KPayCountry(iso3: 'CIV', iso2: 'CI', name: "Côte d'Ivoire", dialCode: '225', currency: 'XOF', operators: [
      KPayOperator('MTN MoMo', 'MTN_MOMO_CIV'),
      KPayOperator('Orange Money', 'ORANGE_CIV'),
    ]),
    KPayCountry(iso3: 'COD', iso2: 'CD', name: 'RD Congo', dialCode: '243', currency: 'CDF', operators: [
      KPayOperator('Vodacom M-Pesa', 'VODACOM_MPESA_COD'),
      KPayOperator('Airtel Money', 'AIRTEL_COD'),
      KPayOperator('Orange Money', 'ORANGE_COD'),
    ]),
    KPayCountry(iso3: 'GAB', iso2: 'GA', name: 'Gabon', dialCode: '241', currency: 'XAF', operators: [
      KPayOperator('Airtel Money', 'AIRTEL_GAB'),
    ]),
    KPayCountry(iso3: 'KEN', iso2: 'KE', name: 'Kenya', dialCode: '254', currency: 'KES', operators: [
      KPayOperator('M-Pesa', 'MPESA_KEN'),
    ]),
    KPayCountry(iso3: 'COG', iso2: 'CG', name: 'Congo', dialCode: '242', currency: 'XAF', operators: [
      KPayOperator('Airtel Money', 'AIRTEL_COG'),
      KPayOperator('MTN MoMo', 'MTN_MOMO_COG'),
    ]),
    KPayCountry(iso3: 'RWA', iso2: 'RW', name: 'Rwanda', dialCode: '250', currency: 'RWF', operators: [
      KPayOperator('Airtel Money', 'AIRTEL_RWA'),
      KPayOperator('MTN MoMo', 'MTN_MOMO_RWA'),
    ]),
    KPayCountry(iso3: 'SEN', iso2: 'SN', name: 'Sénégal', dialCode: '221', currency: 'XOF', operators: [
      KPayOperator('Free Money', 'FREE_SEN'),
      KPayOperator('Orange Money', 'ORANGE_SEN'),
    ]),
    KPayCountry(iso3: 'SLE', iso2: 'SL', name: 'Sierra Leone', dialCode: '232', currency: 'SLE', operators: [
      KPayOperator('Orange Money', 'ORANGE_SLE'),
    ]),
    KPayCountry(iso3: 'UGA', iso2: 'UG', name: 'Ouganda', dialCode: '256', currency: 'UGX', operators: [
      KPayOperator('Airtel Money', 'AIRTEL_OAPI_UGA'),
      KPayOperator('MTN MoMo', 'MTN_MOMO_UGA'),
    ]),
    KPayCountry(iso3: 'ZMB', iso2: 'ZM', name: 'Zambie', dialCode: '260', currency: 'ZMW', operators: [
      KPayOperator('Airtel Money', 'AIRTEL_OAPI_ZMB'),
      KPayOperator('MTN MoMo', 'MTN_MOMO_ZMB'),
      KPayOperator('Zamtel', 'ZAMTEL_ZMB'),
    ]),
  ];

  /// Pays par défaut (Cameroun).
  static KPayCountry get defaultCountry =>
      countries.firstWhere((c) => c.iso3 == 'CMR', orElse: () => countries.first);

  static KPayCountry? byIso3(String iso3) {
    for (final c in countries) {
      if (c.iso3 == iso3) return c;
    }
    return null;
  }
}
