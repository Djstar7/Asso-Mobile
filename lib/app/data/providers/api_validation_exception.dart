// data/providers/api_validation_exception.dart
class ApiValidationException implements Exception {
  final String message;
  final Map<String, String> fieldErrors;
  ApiValidationException(this.message, this.fieldErrors);

  /// Construit depuis le corps JSON Laravel : {message, errors:{champ:[msg,...]}}
  factory ApiValidationException.fromJson(Map<String, dynamic> json) {
    final raw = json['errors'];
    final map = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List && v.isNotEmpty) map[k.toString()] = v.first.toString();
        if (v is String) map[k.toString()] = v;
      });
    }
    return ApiValidationException(json['message']?.toString() ?? 'Données invalides.', map);
  }

  @override
  String toString() => message;
}