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
  ///
  /// Les informations d'identité (naissance, téléphone, adresse) sont EXIGÉES par
  /// le partenaire bancaire : sans elles le compte est créé mais reste bloqué, et
  /// tout virement est refusé. Elles ne sont pas conservées par l'application.
  static Future<ApiResponse> submit({
    required String country,
    required String iban,
    required String accountHolderName,
    required String birthDate, // AAAA-MM-JJ
    required String phone,
    required String addressLine1,
    required String addressCity,
    required String addressPostalCode,
    String? addressLine2,
    String? addressState,
    String? firstName,
    String? lastName,
  }) async {
    return await ApiProvider.post(AppConstants.stripeConnectSubmitUrl, body: {
      'country': country,
      'iban': iban,
      'account_holder_name': accountHolderName,
      'birth_date': birthDate,
      'phone': phone,
      'address_line1': addressLine1,
      'address_city': addressCity,
      'address_postal_code': addressPostalCode,
      if (addressLine2 != null && addressLine2.isNotEmpty) 'address_line2': addressLine2,
      if (addressState != null && addressState.isNotEmpty) 'address_state': addressState,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
    });
  }
}
