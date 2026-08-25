import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/models/diaspo_booking.dart';
import '../../../data/models/payment_method_option.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../wallet/views/payment_webview.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../../data/services/stripe_native_service.dart';

class DiaspoBookingController extends GetxController {
  final DiaspoService _diaspoService = Get.find<DiaspoService>();

  final offer = Rx<DiaspoOffer?>(null);
  final isLoading = false.obs;
  final isSubmitting = false.obs;

  // Kg selection
  final kgController = TextEditingController();
  final kgBooked = 1.0.obs;
  final minKg = 1.0;

  // Price calculation
  final subtotal = 0.0.obs;
  final commissionPercent = 5.0.obs; // Default 5%
  final commissionAmount = 0.0.obs;
  final totalPrice = 0.0.obs;

  double get remainingKg => offer.value?.remainingKg ?? 0;
  double get pricePerKg => offer.value?.pricePerKg ?? 0;
  String get currency => offer.value?.currency ?? 'XAF';

  @override
  void onInit() {
    super.onInit();
    _loadOffer();

    // Initialize kg
    kgController.text = '1.0';
    kgBooked.value = 1.0;
    _calculatePrices();

    // Listen to kg changes
    kgController.addListener(() {
      final value = double.tryParse(kgController.text) ?? 0;
      if (value > 0 && value <= remainingKg) {
        kgBooked.value = value;
        _calculatePrices();
      }
    });
  }

  @override
  void onClose() {
    kgController.dispose();
    super.onClose();
  }

  void _loadOffer() {
    final args = Get.arguments;
    if (args != null && args['offer'] != null) {
      offer.value = args['offer'] as DiaspoOffer;
    } else {
      Get.snackbar('Erreur', 'Offre introuvable');
      Get.back();
    }
  }

  void _calculatePrices() {
    subtotal.value = kgBooked.value * pricePerKg;
    commissionAmount.value = subtotal.value * (commissionPercent.value / 100);
    totalPrice.value = subtotal.value + commissionAmount.value;
  }

  void incrementKg() {
    final newValue = kgBooked.value + 1.0;
    if (newValue <= remainingKg) {
      kgBooked.value = newValue;
      kgController.text = newValue.toStringAsFixed(1);
      _calculatePrices();
    }
  }

  void decrementKg() {
    final newValue = kgBooked.value - 1.0;
    if (newValue >= minKg) {
      kgBooked.value = newValue;
      kgController.text = newValue.toStringAsFixed(1);
      _calculatePrices();
    }
  }

  Future<void> submitBooking() async {
    if (offer.value == null) return;

    // Validation
    if (kgBooked.value < minKg) {
      Get.snackbar('Erreur', 'Le minimum est ${minKg.toStringAsFixed(1)} kg');
      return;
    }

    if (kgBooked.value > remainingKg) {
      Get.snackbar('Erreur', 'Seulement ${remainingKg.toStringAsFixed(1)} kg disponibles');
      return;
    }

    // 1) Choix du moyen de paiement (tous affichés, grisés si trop faible,
    //    jamais masqués selon le pays, sans solde wallet).
    final method = await PaymentMethodSelector.show(
      amount: totalPrice.value,
      currency: currency,
      amountLabel: 'Total à payer',
    );
    if (method == null) return; // annulé

    // 2) Sous-parcours selon le rail choisi.
    if (method.code == 'kpay') {
      // Mobile Money : sélecteur pays → opérateur → numéro.
      final selection = await KpayDirectPaymentSheet.show(
        amount: totalPrice.value,
        amountLabel: 'Total à payer',
      );
      if (selection == null) return; // annulé
      await _processKpayBooking(selection['provider']!, selection['phone']!);
    } else if (method.code == 'stripe') {
      // Carte : Payment Sheet Stripe native.
      await _processCardBooking();
    } else {
      // PayPal : redirection WebView.
      await _processRedirectBooking(method);
    }
  }

  /// Réservation payée par CARTE (Payment Sheet Stripe native).
  Future<void> _processCardBooking() async {
    if (!StripeNativeService.isSupported) {
      Get.snackbar('Indisponible',
          "Le paiement par carte est disponible sur l'application mobile.");
      return;
    }
    isSubmitting.value = true;
    try {
      final result = await _diaspoService.bookOffer(
        offerId: offer.value!.id,
        kgBooked: kgBooked.value,
        paymentMethod: 'stripe',
      );
      final booking = result['booking'] as DiaspoBooking;
      final payment = result['payment'] as Map<String, dynamic>;
      final clientSecret = payment['client_secret']?.toString();
      final publishableKey = payment['publishable_key']?.toString();

      isSubmitting.value = false;

      if (clientSecret == null || clientSecret.isEmpty ||
          publishableKey == null || publishableKey.isEmpty) {
        _showError(Exception('Données de paiement carte indisponibles. Réessayez.'));
        return;
      }

      final ok = await StripeNativeService().payWithCard(
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );
      if (!ok) {
        Get.snackbar('Paiement annulé', "Le paiement n'a pas été finalisé.",
            backgroundColor: Colors.orange, colorText: Colors.white,
            duration: const Duration(seconds: 4));
        return;
      }

      // La confirmation réelle se fait côté serveur (webhook), suivie par le polling.
      _pollBookingPayment(booking);
    } catch (e) {
      isSubmitting.value = false;
      _showError(e);
    }
  }

  /// Réservation payée par Mobile Money (KPay direct).
  Future<void> _processKpayBooking(String provider, String phone) async {
    isSubmitting.value = true;
    try {
      final result = await _diaspoService.bookOffer(
        offerId: offer.value!.id,
        kgBooked: kgBooked.value,
        paymentMethod: 'kpay',
        provider: provider,
        phoneNumber: phone,
      );
      final booking = result['booking'] as DiaspoBooking;

      isSubmitting.value = false;
      // La réservation n'est PAS encore confirmée : le paiement Mobile Money doit être
      // validé sur le téléphone. On informe, puis on n'affiche le succès (+ code) qu'au
      // statut « payé » (voir _pollBookingPayment).
      Get.snackbar(
        'Paiement en attente',
        'Validez le paiement sur votre téléphone (USSD). La réservation sera confirmée ensuite.',
        backgroundColor: Colors.orange, colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      _pollBookingPayment(booking);
    } catch (e) {
      isSubmitting.value = false;
      _showError(e);
    }
  }

  /// Réservation payée par redirection (PayPal, carte Stripe) via WebView.
  Future<void> _processRedirectBooking(PaymentMethodOption method) async {
    isSubmitting.value = true;
    try {
      final result = await _diaspoService.bookOffer(
        offerId: offer.value!.id,
        kgBooked: kgBooked.value,
        paymentMethod: method.code,
      );
      final booking = result['booking'] as DiaspoBooking;
      final payment = result['payment'] as Map<String, dynamic>;
      final approvalUrl = payment['approval_url']?.toString();

      isSubmitting.value = false;

      if (approvalUrl == null || approvalUrl.isEmpty) {
        _showError(Exception('Lien de paiement indisponible. Réessayez.'));
        return;
      }

      // Ouvre la page de paiement hébergée ; la confirmation réelle se fait
      // côté serveur (webhook), suivie par le polling. Le succès (+ code) n'est
      // affiché qu'une fois le statut « payé » confirmé (voir _pollBookingPayment).
      await Get.to(() => PaymentWebView(
            paymentUrl: approvalUrl,
            paymentMethod: method.code,
            paymentId: booking.id,
          ));

      _pollBookingPayment(booking);
    } catch (e) {
      isSubmitting.value = false;
      _showError(e);
    }
  }

  void _showError(Object e) {
    Get.snackbar(
      'Erreur',
      e.toString().replaceAll('Exception: ', ''),
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  /// Suit le paiement d'une réservation (polling 5 s). Le succès (dialog + code de
  /// confirmation) n'est affiché QU'AU statut « payé » — jamais à la simple création.
  void _pollBookingPayment(DiaspoBooking booking) async {
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 5));
      final status = await _diaspoService.bookingPaymentStatus(booking.id);
      if (status == 'paid') {
        _showSuccessDialog(booking); // réservation réellement confirmée → on révèle le code
        return;
      } else if (status == 'failed') {
        Get.snackbar('Paiement échoué', 'Le paiement de la réservation n\'a pas abouti.',
            backgroundColor: Colors.red, colorText: Colors.white,
            duration: const Duration(seconds: 5));
        return;
      }
    }
    // Délai dépassé sans confirmation : on reste prudent, pas de « confirmée ».
    Get.snackbar('Paiement en attente',
        "La confirmation n'est pas encore arrivée. Vérifiez dans « Mes Achats ».",
        backgroundColor: Colors.orange, colorText: Colors.white,
        duration: const Duration(seconds: 5));
  }

  void _showSuccessDialog(DiaspoBooking booking) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Réservation confirmée!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Votre réservation de ${booking.kgBooked.toStringAsFixed(1)} kg a été confirmée.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Code de confirmation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.confirmationCode,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Donnez ce code au vendeur pour confirmer la réception',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back(); // Close dialog
                    Get.back(); // Close booking screen
                    Get.back(); // Close detail screen
                    // Go back to list and refresh
                    Get.toNamed('/diaspo');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Terminer'),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format price with user's currency
  String formatPrice(double priceInXOF, {bool showSymbol = true}) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: showSymbol);
  }

  /// Symbole de la devise réelle de l'offre (pas celle de l'utilisateur).
  String get currencySymbol => CurrencyService.getSymbolForCode(currency);

  /// Formate un montant DÉJÀ exprimé dans la devise de l'offre, SANS reconversion.
  /// Les sous-total/commission/total sont calculés à partir de `pricePerKg`
  /// (devise de l'offre), il ne faut donc pas les reconvertir vers la devise user.
  String formatOfferAmount(double amount) {
    final hasDecimals = amount != amount.roundToDouble();
    final raw = hasDecimals
        ? amount.toStringAsFixed(2)
        : amount.toStringAsFixed(0);
    final parts = raw.split('.');
    parts[0] = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
    return '${parts.join('.')} $currencySymbol';
  }
}
