import 'api_provider.dart';
import '../../core/values/constants.dart';

/// P6 — Codes commerciaux saisis à la souscription d'un forfait.
class SalesCodeService {
  /// Vérifie un code commercial.
  ///
  /// 200 : { success:true, data:{ code, agent_display_name } }
  /// 404 : { success:false, message } (code inconnu, désactivé ou le sien)
  static Future<ApiResponse> checkCode(String code) {
    return ApiProvider.get(
      '${AppConstants.salesCodeUrl}/${Uri.encodeComponent(code)}',
    );
  }
}
