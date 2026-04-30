class CurrencyModel {
  final int id;
  final String code;
  final String name;
  final String symbol;
  final List<String> countries;
  final bool isActive;

  CurrencyModel({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
    required this.countries,
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
      'is_active': isActive,
    };
  }

  CurrencyModel copyWith({
    int? id,
    String? code,
    String? name,
    String? symbol,
    List<String>? countries,
    bool? isActive,
  }) {
    return CurrencyModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      countries: countries ?? this.countries,
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
