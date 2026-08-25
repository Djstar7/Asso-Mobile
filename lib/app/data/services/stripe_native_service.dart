import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';

/// Service réutilisable pour le paiement carte NATIF via la Payment Sheet Stripe.
///
/// Contrat commun (les 5 flux) :
///  1. l'API crée l'objet (commande / réservation / abonnement / recharge) en mode
///     "stripe_direct" / payment_method:"stripe" et renvoie
///     `client_secret` + `payment_intent_id` + `publishable_key` ;
///  2. on présente la Payment Sheet native avec [payWithCard] ;
///  3. l'appelant POLL l'endpoint payment-status jusqu'à un état terminal
///     (paid/completed/failed). Le webhook confirme aussi côté serveur.
class StripeNativeService {
  StripeNativeService._();
  static final StripeNativeService instance = StripeNativeService._();
  factory StripeNativeService() => instance;

  /// La Payment Sheet native n'est disponible que sur Android/iOS.
  static bool get isSupported => GetPlatform.isAndroid || GetPlatform.isIOS;

  /// Présente la Payment Sheet Stripe pour régler un PaymentIntent.
  ///
  /// Renvoie `true` si le paiement a réussi, `false` si l'utilisateur a annulé.
  /// Lève une [Exception] en cas d'échec réel (à catcher par l'appelant).
  Future<bool> payWithCard({
    required String publishableKey,
    required String clientSecret,
    String merchantDisplayName = 'ASSO',
  }) async {
    if (publishableKey.isEmpty || clientSecret.isEmpty) {
      throw Exception('Paramètres de paiement carte manquants.');
    }

    try {
      // Clé publique (peut changer selon l'environnement renvoyé par l'API).
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true; // Paiement confirmé côté client.
    } on StripeException catch (e) {
      // Annulation utilisateur : retour silencieux (false), pas une erreur.
      if (e.error.code == FailureCode.Canceled) {
        return false;
      }
      throw Exception(
        e.error.localizedMessage ?? e.error.message ?? 'Paiement carte échoué.',
      );
    }
  }
}
