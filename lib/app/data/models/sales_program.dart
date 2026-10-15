import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Programme commercial ASSO vu par l'utilisateur connecté : modalités,
/// commission et, s'il est déjà inscrit, son code.
class SalesProgram {
  final String terms;
  final double commissionRate;
  final bool isAgent;
  final bool isActive;
  final String? code;

  const SalesProgram({
    required this.terms,
    required this.commissionRate,
    this.isAgent = false,
    this.isActive = false,
    this.code,
  });

  factory SalesProgram.fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString().trim();
    return SalesProgram(
      terms: json['terms']?.toString() ?? '',
      commissionRate: parseRate(json['commission_rate']),
      isAgent: json['is_agent'] == true,
      isActive: json['is_active'] == true,
      code: code == null || code.isEmpty ? null : code,
    );
  }

  /// Le serveur envoie le taux en nombre, parfois en texte (« 10.00 »).
  static double parseRate(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('${raw ?? ''}'.replaceAll(',', '.')) ?? 0;
  }

  /// « 10 » pour un taux entier, « 7,5 » en français et « 7.5 » en anglais
  /// sinon : jamais de « 10.0 ».
  static String formatRate(double rate, {String? locale}) {
    final lang = locale ?? Get.locale?.languageCode ?? 'fr';
    return NumberFormat('0.##', lang).format(rate);
  }
}
