import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
      throw Exception('data.stripe.missing_params'.tr);
    }

    try {
      // Clé publique (peut changer selon l'environnement renvoyé par l'API).
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      // Préparation bornée : bloquée, elle laissait l'écran sans réaction et
      // sans message après le choix « Carte bancaire ».
      await Stripe.instance
          .initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: merchantDisplayName,
            ),
          )
          .timeout(_initTimeout);

      await Stripe.instance.presentPaymentSheet();
      return true; // Paiement confirmé côté client.
    } on TimeoutException {
      debugPrint('[StripeNativeService] initPaymentSheet sans réponse après ${_initTimeout.inSeconds} s');
      throw Exception('data.stripe.sheet_unavailable'.tr);
    } on StripeException catch (e) {
      // Annulation utilisateur : retour silencieux (false), pas une erreur.
      if (e.error.code == FailureCode.Canceled) {
        return false;
      }
      // Visible en logcat / console même en release : seule trace de la cause
      // quand la feuille ne s'ouvre pas (clés test/live mélangées, compte…).
      debugPrint('[StripeNativeService] ${e.error.code}: ${e.error.message}');
      throw Exception(
        e.error.localizedMessage ?? e.error.message ?? 'data.stripe.payment_failed'.tr,
      );
    } on PlatformException catch (e) {
      // Erreur native hors StripeException (SDK non initialisé, écran absent…).
      debugPrint('[StripeNativeService] ${e.code}: ${e.message}');
      throw Exception('data.stripe.sheet_unavailable'.tr);
    }
  }

  /// Délai maximal de préparation de la Payment Sheet (appel réseau Stripe).
  static const Duration _initTimeout = Duration(seconds: 25);
}
