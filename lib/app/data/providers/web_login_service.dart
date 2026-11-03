import '../../core/values/constants.dart';
import 'api_provider.dart';

/// Connexion par QR à l'espace vendeur web.
class WebLoginService {
  const WebLoginService._();

  static const String _base = AppConstants.webLoginUrl;

  // Côté site : session de connexion affichée en QR.

  static Future<ApiResponse> createSession() =>
      ApiProvider.post('$_base/sessions');

  /// Le secret part dans le corps : une adresse finirait dans les journaux.
  static Future<ApiResponse> pollSession(String id, String secret) =>
      ApiProvider.post('$_base/sessions/$id/poll', body: {'secret': secret});

  // Côté application : le vendeur scanne et confirme.

  static Future<ApiResponse> availability() =>
      ApiProvider.get('$_base/availability');

  static Future<ApiResponse> scan(String code) =>
      ApiProvider.post('$_base/scan', body: {'code': code});

  static Future<ApiResponse> approve(String code) =>
      ApiProvider.post('$_base/approve', body: {'code': code});

  static Future<ApiResponse> reject(String code) =>
      ApiProvider.post('$_base/reject', body: {'code': code});

  static Future<ApiResponse> devices() => ApiProvider.get('$_base/devices');

  static Future<ApiResponse> revokeDevice(int id) =>
      ApiProvider.delete('$_base/devices/$id');
}
