import '../../core/values/constants.dart';
import 'api_provider.dart';

/// Appels API pour l'onboarding Stripe Connect côté vendeur (compte de virement IBAN).
class StripeConnectService {
  /// Statut du compte de virement du vendeur connecté.
  /// GET /v1/stripe/connect/status
  static Future<ApiResponse> getStatus() async {
    return await ApiProvider.get(AppConstants.stripeConnectStatusUrl);
  }

  /// Soumet (ou met à jour) les informations bancaires du vendeur.
  /// POST /v1/stripe/connect/submit
  static Future<ApiResponse> submit({
    required String country,
    required String iban,
    required String accountHolderName,
    String? firstName,
    String? lastName,
  }) async {
    return await ApiProvider.post(AppConstants.stripeConnectSubmitUrl, body: {
      'country': country,
      'iban': iban,
      'account_holder_name': accountHolderName,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
    });
  }
}
