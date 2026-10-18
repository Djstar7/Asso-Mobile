import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../data/models/maritime.dart';
import '../../../data/models/payment_method_option.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/maritime_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/services/stripe_native_service.dart';
import '../../../routes/app_pages.dart';
import '../../diaspoBooking/widgets/parcel_insurance_form.dart';
import '../../payment/widgets/mobile_money_waiting.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../wallet/views/payment_webview.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import 'maritime_controller.dart';

/// Envoi maritime : kilos, colis, coordonnées, nature et valeur, puis paiement.
class MaritimeBookingController extends GetxController {
  final MaritimeService _service = Get.find<MaritimeService>();

  final departure = Rx<MaritimeDeparture?>(null);
  final isSubmitting = false.obs;

  final kgController = TextEditingController(text: '10');
  final kg = 10.0.obs;
  final parcelsController = TextEditingController(text: '1');

  final senderFirstName = TextEditingController();
  final senderLastName = TextEditingController();
  final senderPhone = TextEditingController();
  final emergencyPhone = TextEditingController();
  final recipientFirstName = TextEditingController();
  final recipientLastName = TextEditingController();
  final recipientPhone = TextEditingController();
  final recipientCountry = RxnString();

  late final ParcelInsuranceForm insurance =
      ParcelInsuranceForm(currency: () => currency);

  String get currency => departure.value?.currency ?? 'EUR';
  double get pricePerKg => departure.value?.pricePerKg ?? 0;
  double get remainingKg => departure.value?.remainingKg ?? 0;

  /// À lire dans un Obx.
  double get freight => double.parse((kg.value * pricePerKg).toStringAsFixed(2));
  double get grandTotal =>
      double.parse((freight + insurance.insuranceAmount.value).toStringAsFixed(2));

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['departure'] is MaritimeDeparture) {
      departure.value = args['departure'] as MaritimeDeparture;
      recipientCountry.value = departure.value!.destinationHub?.country;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => AppNavigation.pop());
      return;
    }

    final user = StorageService.getUser();
    if (user != null) {
      senderFirstName.text = user.firstName;
      senderLastName.text = user.lastName;
      senderPhone.text = user.phone;
    }

    if (remainingKg < kg.value) {
      kg.value = remainingKg;
      kgController.text = remainingKg.toStringAsFixed(1);
    }
    kgController.addListener(() {
      final value = double.tryParse(kgController.text.replaceAll(',', '.')) ?? 0;
      if (value > 0 && value <= remainingKg) kg.value = value;
    });
    insurance.load();
  }

  @override
  void onClose() {
    for (final c in [
      kgController, parcelsController, senderFirstName, senderLastName, senderPhone,
      emergencyPhone, recipientFirstName, recipientLastName, recipientPhone,
    ]) {
      c.dispose();
    }
    insurance.dispose();
    super.onClose();
  }

  String formatAmount(double amount) => CurrencyService.formatFromCurrency(amount, currency);
  String get currencySymbol => CurrencyService.getSymbolForCode(currency);

  String formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String? _validate() {
    final requiredFields = [
      senderFirstName, senderLastName, senderPhone, emergencyPhone,
      recipientFirstName, recipientLastName, recipientPhone,
    ];
    if (requiredFields.any((c) => c.text.trim().isEmpty) || recipientCountry.value == null) {
      return 'maritime.form.fill_all'.tr;
    }
    if (kg.value < 0.5 || kg.value > remainingKg) {
      return 'maritime.form.kg_range'.trParams({'max': remainingKg.toStringAsFixed(1)});
    }
    if (!insurance.isComplete) return 'parcel_insurance.required'.tr;
    return null;
  }

  Map<String, dynamic> _payload(String method, {String? provider, String? phone}) => {
        'kg_booked': kg.value,
        'parcels_count': int.tryParse(parcelsController.text) ?? 1,
        'sender_first_name': senderFirstName.text.trim(),
        'sender_last_name': senderLastName.text.trim(),
        'sender_phone': senderPhone.text.trim(),
        'emergency_phone': emergencyPhone.text.trim(),
        'recipient_first_name': recipientFirstName.text.trim(),
        'recipient_last_name': recipientLastName.text.trim(),
        'recipient_country': recipientCountry.value,
        'recipient_phone': recipientPhone.text.trim(),
        'parcel_nature_id': insurance.selectedNature.value!.id,
        'declared_value': insurance.declaredValue.value,
        'declared_value_currency': insurance.valueCurrency,
        'payment_method': method,
        if (provider != null) 'provider': provider,
        if (phone != null) 'phone_number': phone,
      };

  Future<void> submit() async {
    final error = _validate();
    if (error != null) {
      Get.snackbar('maritime.error'.tr, error, backgroundColor: AppDesign.danger, colorText: Colors.white);
      return;
    }
    if (insurance.isQuoting.value) return;

    final method = await PaymentMethodSelector.show(
      amount: grandTotal,
      currency: currency,
      amountLabel: 'maritime.form.total_to_pay'.tr,
    );
    if (method == null) return;

    if (method.code == 'kpay') {
      final selection = await KpayDirectPaymentSheet.show(
        amount: grandTotal,
        currency: currency,
        amountLabel: 'maritime.form.total_to_pay'.tr,
      );
      if (selection == null) return;
      await _payKpay(selection['provider']!, selection['phone']!);
    } else if (method.code == 'stripe') {
      await _payCard();
    } else {
      await _payRedirect(method);
    }
  }

  Future<MaritimeBooking?> _create(String method, {String? provider, String? phone}) async {
    isSubmitting.value = true;
    try {
      final result = await _service.book(
        departureId: departure.value!.id,
        data: _payload(method, provider: provider, phone: phone),
      );
      _lastPayment = result.payment;
      return result.booking;
    } catch (e) {
      Get.snackbar('maritime.error'.tr, e.toString().replaceAll('Exception: ', ''),
          backgroundColor: AppDesign.danger, colorText: Colors.white, duration: const Duration(seconds: 5));
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Map<String, dynamic> _lastPayment = {};

  Future<void> _payKpay(String provider, String phone) async {
    final booking = await _create('kpay', provider: provider, phone: phone);
    if (booking == null) return;
    final outcome = await MobileMoneyWaiting.run(
      amount: grandTotal,
      formatAmount: formatAmount,
      provider: provider,
      phone: phone,
      check: () => _service.paymentState(booking.id),
      failureNote: 'maritime.form.payment_failed_released'.tr,
    );
    if (outcome.status == 'paid') {
      _showSuccess(booking);
    } else if (outcome.status != 'failed') {
      _poll(booking);
    }
  }

  Future<void> _payCard() async {
    if (!StripeNativeService.isSupported) {
      Get.snackbar('diaspo_booking.unavailable'.tr, 'diaspo_booking.card_mobile_only'.tr);
      return;
    }
    final booking = await _create('stripe');
    if (booking == null) return;
    final secret = _lastPayment['client_secret']?.toString();
    final key = _lastPayment['publishable_key']?.toString();
    if (secret == null || key == null || secret.isEmpty || key.isEmpty) {
      Get.snackbar('maritime.error'.tr, 'diaspo_booking.card_data_unavailable'.tr);
      return;
    }
    final ok = await StripeNativeService().payWithCard(publishableKey: key, clientSecret: secret);
    if (!ok) {
      Get.snackbar('diaspo_booking.payment_cancelled_title'.tr, 'diaspo_booking.payment_cancelled_message'.tr,
          backgroundColor: AppDesign.accent, colorText: Colors.white);
      return;
    }
    _poll(booking);
  }

  Future<void> _payRedirect(PaymentMethodOption method) async {
    final booking = await _create(method.code);
    if (booking == null) return;
    final url = _lastPayment['approval_url']?.toString();
    if (url == null || url.isEmpty) {
      Get.snackbar('maritime.error'.tr, 'diaspo_booking.payment_link_unavailable'.tr);
      return;
    }
    await Get.to(() => PaymentWebView(paymentUrl: url, paymentMethod: method.code, paymentId: booking.id));
    _poll(booking);
  }

  /// Suit le paiement (5 s) ; le succès n'est affiché qu'au statut « payé ».
  Future<void> _poll(MaritimeBooking booking) async {
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 5));
      final state = await _service.paymentState(booking.id);
      if (state.status == 'paid') {
        _showSuccess(booking);
        return;
      }
      if (state.status == 'failed') {
        Get.snackbar('diaspo_booking.payment_failed_title'.tr, 'maritime.form.payment_failed_released'.tr,
            backgroundColor: AppDesign.danger, colorText: Colors.white);
        return;
      }
    }
    Get.snackbar('diaspo_booking.payment_pending_title'.tr, 'diaspo_booking.payment_pending_timeout'.tr,
        backgroundColor: AppDesign.accent, colorText: Colors.white);
  }

  void _showSuccess(MaritimeBooking booking) {
    final hub = departure.value?.originHub;
    Get.dialog(
      AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppDesign.success, size: 56),
        title: Text('maritime.success.title'.tr),
        content: Text(
          'maritime.success.message'.trParams({
            'hub': hub?.fullAddress ?? '',
            'date': booking.dropoffDeadline != null ? formatDate(booking.dropoffDeadline!) : '',
            'code': booking.confirmationCode,
          }),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Get.back();
              _returnToShipments();
            },
            child: Text('maritime.success.see_shipments'.tr),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _returnToShipments() {
    final navigator = Get.key.currentState;
    if (navigator == null) return;
    var reached = false;
    navigator.popUntil((route) {
      if (route.settings.name == Routes.DIASPO) {
        reached = true;
        return true;
      }
      return route.isFirst;
    });
    if (!reached) {
      Get.toNamed(Routes.DIASPO);
    } else if (Get.isRegistered<MaritimeController>()) {
      Get.find<MaritimeController>().changeTab(1);
    }
  }
}
