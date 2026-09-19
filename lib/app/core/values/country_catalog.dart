/// Correspondance entre les noms de pays renvoyés par l'API (en français)
/// et leur code ISO 3166-1 alpha-2.
///
/// Sert à afficher un drapeau dans la liste de choix du pays. Le drapeau est
/// rendu en emoji plutôt qu'en image : aucun asset à embarquer, aucun appel
/// réseau, et le rendu suit la police système.
///
/// La table doit rester alignée sur `WorldCurrencySeeder` côté backend. Un
/// pays absent d'ici n'est pas une erreur : [flagFor] renvoie alors une chaîne
/// vide et la liste retombe sur la pastille portant le symbole monétaire.
library;

class CountryCatalog {
  const CountryCatalog._();

  /// Nom de pays (tel que renvoyé par l'API) -> code ISO 3166-1 alpha-2.
  static const Map<String, String> isoCodes = {
    'Afghanistan': 'AF',
    'Afrique du Sud': 'ZA',
    'Albanie': 'AL',
    'Algérie': 'DZ',
    'Allemagne': 'DE',
    'Andorre': 'AD',
    'Angola': 'AO',
    'Antigua-et-Barbuda': 'AG',
    'Arabie saoudite': 'SA',
    'Argentine': 'AR',
    'Arménie': 'AM',
    'Australie': 'AU',
    'Autriche': 'AT',
    'Azerbaïdjan': 'AZ',
    'Bahamas': 'BS',
    'Bahreïn': 'BH',
    'Bangladesh': 'BD',
    'Barbade': 'BB',
    'Belgique': 'BE',
    'Belize': 'BZ',
    'Bhoutan': 'BT',
    'Birmanie': 'MM',
    'Biélorussie': 'BY',
    'Bolivie': 'BO',
    'Bosnie-Herzégovine': 'BA',
    'Botswana': 'BW',
    'Brunei': 'BN',
    'Brésil': 'BR',
    'Bulgarie': 'BG',
    'Burkina Faso': 'BF',
    'Burundi': 'BI',
    'Bénin': 'BJ',
    'Cambodge': 'KH',
    'Cameroun': 'CM',
    'Canada': 'CA',
    'Cap-Vert': 'CV',
    'Centrafrique': 'CF',
    'Chili': 'CL',
    'Chine': 'CN',
    'Chypre': 'CY',
    'Colombie': 'CO',
    'Comores': 'KM',
    'Congo': 'CG',
    'Corée du Nord': 'KP',
    'Corée du Sud': 'KR',
    'Costa Rica': 'CR',
    'Croatie': 'HR',
    'Cuba': 'CU',
    "Côte d'Ivoire": 'CI',
    'Danemark': 'DK',
    'Djibouti': 'DJ',
    'Dominique': 'DM',
    'Espagne': 'ES',
    'Estonie': 'EE',
    'Eswatini': 'SZ',
    'Fidji': 'FJ',
    'Finlande': 'FI',
    'France': 'FR',
    'Gabon': 'GA',
    'Gambie': 'GM',
    'Ghana': 'GH',
    'Grenade': 'GD',
    'Grèce': 'GR',
    'Guatemala': 'GT',
    'Guinée': 'GN',
    'Guinée équatoriale': 'GQ',
    'Guinée-Bissau': 'GW',
    'Guyana': 'GY',
    'Géorgie': 'GE',
    'Haïti': 'HT',
    'Honduras': 'HN',
    'Hong Kong': 'HK',
    'Hongrie': 'HU',
    'Inde': 'IN',
    'Indonésie': 'ID',
    'Irak': 'IQ',
    'Iran': 'IR',
    'Irlande': 'IE',
    'Islande': 'IS',
    'Israël': 'IL',
    'Italie': 'IT',
    'Jamaïque': 'JM',
    'Japon': 'JP',
    'Jordanie': 'JO',
    'Kazakhstan': 'KZ',
    'Kenya': 'KE',
    'Kirghizistan': 'KG',
    'Kiribati': 'KI',
    'Koweït': 'KW',
    'Laos': 'LA',
    'Lesotho': 'LS',
    'Lettonie': 'LV',
    'Liban': 'LB',
    'Liberia': 'LR',
    'Libye': 'LY',
    'Liechtenstein': 'LI',
    'Lituanie': 'LT',
    'Luxembourg': 'LU',
    'Macao': 'MO',
    'Macédoine du Nord': 'MK',
    'Madagascar': 'MG',
    'Malaisie': 'MY',
    'Malawi': 'MW',
    'Maldives': 'MV',
    'Mali': 'ML',
    'Malte': 'MT',
    'Maroc': 'MA',
    'Maurice': 'MU',
    'Mauritanie': 'MR',
    'Mexique': 'MX',
    'Moldavie': 'MD',
    'Monaco': 'MC',
    'Mongolie': 'MN',
    'Monténégro': 'ME',
    'Mozambique': 'MZ',
    'Namibie': 'NA',
    'Nauru': 'NR',
    'Nicaragua': 'NI',
    'Niger': 'NE',
    'Nigeria': 'NG',
    'Norvège': 'NO',
    'Nouvelle-Calédonie': 'NC',
    'Nouvelle-Zélande': 'NZ',
    'Népal': 'NP',
    'Oman': 'OM',
    'Ouganda': 'UG',
    'Ouzbékistan': 'UZ',
    'Pakistan': 'PK',
    'Palestine': 'PS',
    'Panama': 'PA',
    'Papouasie-Nouvelle-Guinée': 'PG',
    'Paraguay': 'PY',
    'Pays-Bas': 'NL',
    'Philippines': 'PH',
    'Pologne': 'PL',
    'Polynésie française': 'PF',
    'Porto Rico': 'PR',
    'Portugal': 'PT',
    'Pérou': 'PE',
    'Qatar': 'QA',
    'Roumanie': 'RO',
    'Royaume-Uni': 'GB',
    'Russie': 'RU',
    'Rwanda': 'RW',
    'République dominicaine': 'DO',
    'République démocratique du Congo': 'CD',
    'Saint-Christophe-et-Niévès': 'KN',
    'Saint-Marin': 'SM',
    'Saint-Vincent-et-les-Grenadines': 'VC',
    'Sainte-Lucie': 'LC',
    'Salvador': 'SV',
    'Samoa': 'WS',
    'Sao Tomé-et-Principe': 'ST',
    'Serbie': 'RS',
    'Seychelles': 'SC',
    'Sierra Leone': 'SL',
    'Singapour': 'SG',
    'Slovaquie': 'SK',
    'Slovénie': 'SI',
    'Somalie': 'SO',
    'Soudan': 'SD',
    'Soudan du Sud': 'SS',
    'Sri Lanka': 'LK',
    'Suisse': 'CH',
    'Suriname': 'SR',
    'Suède': 'SE',
    'Syrie': 'SY',
    'Sénégal': 'SN',
    'Tadjikistan': 'TJ',
    'Tanzanie': 'TZ',
    'Taïwan': 'TW',
    'Tchad': 'TD',
    'Tchéquie': 'CZ',
    'Thaïlande': 'TH',
    'Timor oriental': 'TL',
    'Togo': 'TG',
    'Tonga': 'TO',
    'Trinité-et-Tobago': 'TT',
    'Tunisie': 'TN',
    'Turkménistan': 'TM',
    'Turquie': 'TR',
    'Tuvalu': 'TV',
    'Ukraine': 'UA',
    'Uruguay': 'UY',
    'Vanuatu': 'VU',
    'Vatican': 'VA',
    'Venezuela': 'VE',
    'Viêt Nam': 'VN',
    'Wallis-et-Futuna': 'WF',
    'Yémen': 'YE',
    'Zambie': 'ZM',
    'Zimbabwe': 'ZW',
    'Égypte': 'EG',
    'Émirats arabes unis': 'AE',
    'Équateur': 'EC',
    'Érythrée': 'ER',
    'États-Unis': 'US',
    'Éthiopie': 'ET',
    'Îles Salomon': 'SB',
  };

  /// Noms alternatifs tolérés, pour rester compatible avec d'anciennes
  /// valeurs stockées côté application ou avec un backend non migré.
  static const Map<String, String> _aliases = {
    'Cote d\'Ivoire': 'CI',
    'Ivory Coast': 'CI',
    'RDC': 'CD',
    'Congo-Kinshasa': 'CD',
    'Congo-Brazzaville': 'CG',
    'Vietnam': 'VN',
    'Viet Nam': 'VN',
    'Myanmar': 'MM',
    'Etats-Unis': 'US',
    'USA': 'US',
    'Emirats arabes unis': 'AE',
    'Republique dominicaine': 'DO',
    'Bielorussie': 'BY',
    'Cap Vert': 'CV',
    'Sao Tome-et-Principe': 'ST',
  };

  /// Code ISO 3166-1 alpha-2 d'un pays, ou `null` s'il est inconnu.
  static String? isoCodeFor(String country) {
    final name = country.trim();
    if (name.isEmpty) return null;

    final direct = isoCodes[name] ?? _aliases[name];
    if (direct != null) return direct;

    // Dernier recours : comparaison insensible à la casse.
    final lower = name.toLowerCase();
    for (final entry in isoCodes.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    for (final entry in _aliases.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  /// Drapeau en emoji pour un pays, ou une chaîne vide si le pays est inconnu.
  ///
  /// Un drapeau emoji est la paire de « symboles indicatifs régionaux »
  /// correspondant aux deux lettres du code ISO : 'FR' -> 🇫🇷.
  static String flagFor(String country) {
    final iso = isoCodeFor(country);
    if (iso == null || iso.length != 2) return '';
    return flagForIsoCode(iso);
  }

  /// Drapeau en emoji à partir d'un code ISO alpha-2 déjà connu.
  static String flagForIsoCode(String isoCode) {
    final code = isoCode.trim().toUpperCase();
    if (code.length != 2) return '';

    const regionalIndicatorA = 0x1F1E6;
    const letterA = 0x41;

    final buffer = StringBuffer();
    for (final unit in code.codeUnits) {
      if (unit < letterA || unit > letterA + 25) return '';
      buffer.writeCharCode(regionalIndicatorA + (unit - letterA));
    }
    return buffer.toString();
  }
}
