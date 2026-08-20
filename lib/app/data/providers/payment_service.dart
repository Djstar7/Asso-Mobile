import '../models/payment_method_option.dart';
import 'api_provider.dart';

/// Service des moyens de paiement entrants (encaissement).
///
/// Point d'entrée mobile unique et RÉUTILISABLE pour tout flux de paiement
/// (réservation Diaspo, achat produit, packages…). Renvoie la liste des moyens
/// pour un montant/devise donnés, telle que calculée par le backend
/// (disponibilité, minimum, montant converti).
class PaymentService {
  /// Récupère les moyens de paiement pour [amount] exprimé en [currency].
  static Future<List<PaymentMethodOption>> fetchMethods({
    required double amount,
    required String currency,
  }) async {
    final res = await ApiProvider.get('/v1/payments/methods', queryParams: {
      'amount': amount,
      'currency': currency,
    });

    if (res.success && res.data != null && res.data!['data'] != null) {
      final list = (res.data!['data']['methods'] as List?) ?? [];
      return list
          .map((e) => PaymentMethodOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }
}
