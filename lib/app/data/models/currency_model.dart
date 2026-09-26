/// Un pays tel que le backend le décrit : nom, code ISO et drapeau.
///
/// L'API expose `countries_detailed` en plus de `countries`. Le drapeau y est
/// déjà calculé côté serveur, ce qui évite de dépendre d'une table de noms
/// locale : les noms renvoyés sont en anglais et ne correspondent pas aux
/// clés françaises de `CountryCatalog`.
class CountryInfo {
  const CountryInfo({
    required this.name,
    required this.isoCode,
    required this.flag,
  });

  final String name;
  final String isoCode;
  final String flag;

  factory CountryInfo.fromJson(Map<String, dynamic> json) {
    return CountryInfo(
      name: (json['name'] ?? '').toString(),
      isoCode: (json['code'] ?? '').toString(),
      flag: (json['flag'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': isoCode,
        'flag': flag,
      };
}

class CurrencyModel {
  final int id;
  final String code;
  final String name;
  final String symbol;
  final List<String> countries;

  /// Pays avec code ISO et drapeau, quand le backend les fournit.
  /// Vide sur les réponses anciennes : l'appelant retombe alors sur
  /// [countries] et le catalogue local.
  final List<CountryInfo> countriesDetailed;
  final bool isActive;

  CurrencyModel({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
    required this.countries,
    this.countriesDetailed = const [],
    this.isActive = true,
  });

  factory CurrencyModel.fromJson(Map<String, dynamic> json) {
    return CurrencyModel(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
      countries: json['countries'] != null
          ? List<String>.from(json['countries'])
          : [],
      countriesDetailed: json['countries_detailed'] is List
          ? (json['countries_detailed'] as List)
              .whereType<Map>()
              .map((e) => CountryInfo.fromJson(Map<String, dynamic>.from(e)))
              .where((c) => c.name.isNotEmpty)
              .toList()
          : const [],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'symbol': symbol,
      'countries': countries,
      'countries_detailed': [
        for (final c in countriesDetailed) c.toJson(),
      ],
      'is_active': isActive,
    };
  }

  CurrencyModel copyWith({
    int? id,
    String? code,
    String? name,
    String? symbol,
    List<String>? countries,
    List<CountryInfo>? countriesDetailed,
    bool? isActive,
  }) {
    return CurrencyModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      countries: countries ?? this.countries,
      countriesDetailed: countriesDetailed ?? this.countriesDetailed,
      isActive: isActive ?? this.isActive,
    );
  }
}

class ExchangeRateModel {
  final int id;
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final DateTime effectiveDate;
  final bool isActive;

  ExchangeRateModel({
    required this.id,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.effectiveDate,
    this.isActive = true,
  });

  factory ExchangeRateModel.fromJson(Map<String, dynamic> json) {
    return ExchangeRateModel(
      id: json['id'] ?? 0,
      fromCurrency: json['from_currency'] ?? '',
      toCurrency: json['to_currency'] ?? '',
      rate: double.tryParse(json['rate'].toString()) ?? 1.0,
      effectiveDate: json['effective_date'] != null
          ? DateTime.parse(json['effective_date'])
          : DateTime.now(),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_currency': fromCurrency,
      'to_currency': toCurrency,
      'rate': rate,
      'effective_date': effectiveDate.toIso8601String(),
      'is_active': isActive,
    };
  }

  double convert(double amount) {
    return amount * rate;
  }
}
