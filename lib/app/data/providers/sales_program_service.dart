import 'api_provider.dart';
import '../../core/values/constants.dart';

/// Programme « Devenir un commercial ASSO ».
class SalesProgramService {
  /// Modalités du programme et statut commercial de l'utilisateur connecté.
  ///
  /// 200 : { success:true, data:{ terms, commission_rate, is_agent, is_active, code } }
  static Future<ApiResponse> getProgram() {
    return ApiProvider.get(AppConstants.salesProgramUrl);
  }

  /// Inscrit l'utilisateur comme commercial (idempotent : renvoie le même code).
  ///
  /// 200 : { success:true, data:{ code, commission_rate } }
  /// 403 : { success:false, code:'sales_agent_inactive', message }
  static Future<ApiResponse> enroll() {
    return ApiProvider.post(
      AppConstants.salesProgramEnrollUrl,
      body: {'accepted': true},
    );
  }
}
