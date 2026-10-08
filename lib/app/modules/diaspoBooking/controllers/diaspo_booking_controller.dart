import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/models/diaspo_booking.dart';
import '../../../data/models/payment_method_option.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../wallet/views/payment_webview.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../payment/widgets/mobile_money_waiting.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../../data/services/stripe_native_service.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../routes/app_pages.dart';
import '../../diaspoList/controllers/diaspo_list_controller.dart';

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
  // Le prix au kilo reçu du serveur est déjà le prix PUBLIC (commission ASSO incluse,
  // taux réglé dans l'admin) : total = kg × prix, sans ligne de commission.
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
      Get.snackbar(
        'diaspo_booking.error'.tr,
        'diaspo_booking.offer_not_found'.tr,
      );
      // Pas `Get.back()` : il refermerait seulement ce snackbar. Après
      // l'image en cours : on est ici pendant la construction de la page.
      WidgetsBinding.instance.addPostFrameCallback((_) => AppNavigation.pop());
    }
  }

  void _calculatePrices() {
    totalPrice.value = double.parse((kgBooked.value * pricePerKg).toStringAsFixed(2));
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
      Get.snackbar(
        'diaspo_booking.error'.tr,
        'diaspo_booking.min_kg'.trParams({'kg': minKg.toStringAsFixed(1)}),
      );
      return;
    }

    if (kgBooked.value > remainingKg) {
      Get.snackbar(
        'diaspo_booking.error'.tr,
        'diaspo_booking.only_kg_available'.trParams({
          'kg': remainingKg.toStringAsFixed(1),
        }),
      );
      return;
    }

    // 1) Choix du moyen de paiement (tous affichés, grisés si trop faible,
    //    jamais masqués selon le pays, sans solde wallet).
    final method = await PaymentMethodSelector.show(
      amount: totalPrice.value,
      currency: currency,
      amountLabel: 'diaspo_booking.total_to_pay'.tr,
    );
    if (method == null) return; // annulé

    // 2) Sous-parcours selon le rail choisi.
    if (method.code == 'kpay') {
      // Mobile Money : sélecteur pays → opérateur → numéro.
      final selection = await KpayDirectPaymentSheet.show(
        amount: totalPrice.value,
        amountLabel: 'diaspo_booking.total_to_pay'.tr,
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
      Get.snackbar('diaspo_booking.unavailable'.tr,
          'diaspo_booking.card_mobile_only'.tr);
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
        _showError(Exception('diaspo_booking.card_data_unavailable'.tr));
        return;
      }

      final ok = await StripeNativeService().payWithCard(
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );
      if (!ok) {
        Get.snackbar('diaspo_booking.payment_cancelled_title'.tr,
            'diaspo_booking.payment_cancelled_message'.tr,
            backgroundColor: AppDesign.accent, colorText: Colors.white,
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
      // validé sur le téléphone. Le succès (+ code) n'est affiché qu'au statut « payé ».
      final outcome = await MobileMoneyWaiting.run(
        amount: totalPrice.value,
        // Montant dans la devise de l'offre (pas forcément le FCFA).
        formatAmount: (amount) => '${amount.toStringAsFixed(0)} $currency',
        provider: provider,
        phone: phone,
        check: () => _diaspoService.bookingPaymentState(booking.id),
        failureNote: 'diaspo_booking.payment_failed_released'.tr,
      );
      switch (outcome.status) {
        case 'paid':
          _showSuccessDialog(booking);
        case 'failed':
          break; // motif déjà expliqué
        default:
          Get.snackbar(
            'diaspo_booking.payment_pending_title'.tr,
            'diaspo_booking.payment_pending_ussd'.tr,
            backgroundColor: AppDesign.accent, colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          _pollBookingPayment(booking);
      }
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
        _showError(Exception('diaspo_booking.payment_link_unavailable'.tr));
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
      'diaspo_booking.error'.tr,
      e.toString().replaceAll('Exception: ', ''),
      backgroundColor: AppDesign.danger,
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
        Get.snackbar('diaspo_booking.payment_failed_title'.tr,
            'diaspo_booking.payment_failed_message'.tr,
            backgroundColor: AppDesign.danger, colorText: Colors.white,
            duration: const Duration(seconds: 5));
        return;
      }
    }
    // Délai dépassé sans confirmation : on reste prudent, pas de « confirmée ».
    Get.snackbar('diaspo_booking.payment_pending_title'.tr,
        'diaspo_booking.payment_pending_timeout'.tr,
        backgroundColor: AppDesign.accent, colorText: Colors.white,
        duration: const Duration(seconds: 5));
  }

  /// Referme la confirmation et revient à la liste des offres.
  ///
  /// La confirmation arrive par un suivi de plusieurs minutes : l'utilisateur
  /// a pu quitter la réservation entre-temps. Trois `Get.back()` fermaient
  /// alors des pages sans rapport ; ici on redescend jusqu'à la liste si
  /// elle est dans la pile (sans jamais vider celle-ci), sinon on l'ouvre.
  void _returnToOffers() {
    final navigator = Get.key.currentState;
    if (navigator == null) return;
    var reachedList = false;
    navigator.popUntil((route) {
      if (route.settings.name == Routes.DIASPO) {
        reachedList = true;
        return true;
      }
      return route.isFirst;
    });
    if (!reachedList) {
      Get.toNamed(Routes.DIASPO);
    } else if (Get.isRegistered<DiaspoListController>()) {
      Get.find<DiaspoListController>().refresh();
    }
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
                color: AppDesign.success,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'diaspo_booking.success.title'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'diaspo_booking.success.message'.trParams({
                  'kg': booking.kgBooked.toStringAsFixed(1),
                }),
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
                    Text(
                      'diaspo_booking.success.code_label'.tr,
                      style: const TextStyle(
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
                    Text(
                      'diaspo_booking.success.code_hint'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                  onPressed: _returnToOffers,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('diaspo_booking.success.finish'.tr),
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
  /// Le total est calculé à partir de `pricePerKg`
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
