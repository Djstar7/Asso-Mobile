import 'package:get/get.dart';

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
    bool includeWallet = false,
  }) async {
    final res = await ApiProvider.get('/v1/payments/methods', queryParams: {
      'amount': amount,
      'currency': currency,
      // Ajoute l'option « Wallet ASSO » (solde) en tête pour les parcours qui l'acceptent.
      if (includeWallet) 'include_wallet': 1,
    });

    if (res.success && res.data != null && res.data!['data'] != null) {
      final list = (res.data!['data']['methods'] as List?) ?? [];
      return list
          .map((e) => PaymentMethodOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  static Set<String>? _mobileMoneyProviders;
  static DateTime? _mobileMoneyProvidersAt;

  /// Opérateurs Mobile Money acceptés par le prestataire ACTIF côté backend
  /// (KPay : tout son catalogue ; ElgioPay : MTN et Orange Cameroun).
  ///
  /// Mis en cache quelques minutes. null si inconnu (réseau) : l'appelant garde
  /// alors le catalogue complet, le backend refusant de toute façon un opérateur
  /// non servi.
  static Future<Set<String>?> fetchMobileMoneyProviders() async {
    final at = _mobileMoneyProvidersAt;
    if (_mobileMoneyProviders != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 5)) {
      return _mobileMoneyProviders;
    }
    try {
      final methods = await fetchMethods(amount: 0, currency: 'XAF');
      final kpay = methods.firstWhereOrNull((m) => m.code == 'kpay');
      if (kpay == null || kpay.providers.isEmpty) return null;
      _mobileMoneyProviders = kpay.providers.toSet();
      _mobileMoneyProvidersAt = DateTime.now();
      return _mobileMoneyProviders;
    } catch (_) {
      return null;
    }
  }
}
