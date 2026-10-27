import 'package:asso/app/modules/payment/widgets/payment_preparation.dart';
import 'package:asso/app/core/utils/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/format_cbm.dart';
import '../../../data/models/maritime.dart';
import '../../../data/models/payment_method_option.dart';
import '../../../data/providers/api_validation_exception.dart';
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

/// Envoi maritime : volume en CBM, colis, coordonnées, nature et valeur, puis paiement.
class MaritimeBookingController extends GetxController {
  final MaritimeService _service = Get.find<MaritimeService>();

  final departure = Rx<MaritimeDeparture?>(null);
  Map<String, dynamic>? freightInquiry;
  final isSubmitting = false.obs;
  final insuranceOptIn = false.obs;
  final cargoCategory = 'general'.obs;

  final kgController = TextEditingController(text: '10');
  final kg = 10.0.obs;

  final senderFirstName = TextEditingController();
  final senderLastName = TextEditingController();
  final senderPhone = TextEditingController();
  final emergencyPhone = TextEditingController();
  final recipientFirstName = TextEditingController();
  final recipientLastName = TextEditingController();
  final recipientPhone = TextEditingController();

  late final ParcelInsuranceForm insurance = ParcelInsuranceForm(
    currency: () => currency,
  );

  // ── Erreurs par champ ─────────────────────────────────────────────
  /// Clé = nom du champ API (identique à Laravel), valeur = message.
  final fieldErrors = <String, String>{}.obs;

  final scrollController = ScrollController();

  /// Ordre d'affichage des champs dans le formulaire.
  static const _fieldOrder = [
    'volume_cbm',
    'cargo_category',
    'kg_booked',
    'sender_first_name',
    'sender_last_name',
    'sender_phone',
    'emergency_phone',
    'recipient_first_name',
    'recipient_last_name',
    'recipient_phone',
    'parcel_nature_id',
    'declared_value',
  ];

  /// Une clé par champ pour Scrollable.ensureVisible.
  final Map<String, GlobalKey> fieldKeys = {
    for (final k in _fieldOrder) k: GlobalKey(),
  };

  static final _phoneRegex = RegExp(r'^\+?[0-9 ]{8,20}$');

  String? errorOf(String key) => fieldErrors[key];

  void clearError(String key) {
    if (fieldErrors.containsKey(key)) fieldErrors.remove(key);
  }

  void _setErrors(Map<String, String> errors) => fieldErrors.assignAll(errors);

  void _scrollToFirstError() {
    for (final key in _fieldOrder) {
      if (fieldErrors.containsKey(key)) {
        final ctx = fieldKeys[key]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            alignment: 0.2,
          );
        }
        break;
      }
    }
  }

  /// Efface l'erreur d'un champ dès que l'utilisateur le corrige.
  void _bindErrorClearing() {
    final map = <String, TextEditingController>{
      'kg_booked': kgController,
      'volume_cbm': kgController,
      'sender_first_name': senderFirstName,
      'sender_last_name': senderLastName,
      'sender_phone': senderPhone,
      'emergency_phone': emergencyPhone,
      'recipient_first_name': recipientFirstName,
      'recipient_last_name': recipientLastName,
      'recipient_phone': recipientPhone,
    };
    map.forEach((key, c) => c.addListener(() => clearError(key)));
    _declarationWorkers.addAll([
      ever(insurance.selectedNature, (_) {
        clearError('parcel_nature_id');
        if (!insurance.isComplete) insuranceOptIn.value = false;
      }),
      ever(insurance.declaredValue, (_) {
        clearError('declared_value');
        if (!insurance.isComplete) insuranceOptIn.value = false;
      }),
    ]);
  }

  final List<Worker> _declarationWorkers = [];

  String get currency => departure.value?.currency ?? 'EUR';
  double get pricePerKg => freightInquiry != null
      ? (freightInquiry!['freight_amount'] as num).toDouble() /
            (freightInquiry!['kg'] as num).toDouble()
      : departure.value?.pricePerKg ?? 0;
  double get remainingKg => departure.value?.remainingKg ?? 0;
  bool get isSea => departure.value?.isSea ?? true;
  String get quantityField => isSea ? 'volume_cbm' : 'kg_booked';
  double get conversion => isSea ? (departure.value?.kgPerCbm ?? 1000) : 1;
  double get quantity => kg.value / conversion;
  double get remainingQuantity => remainingKg / conversion;
  double get unitPrice => freightInquiry != null && quantity > 0
      ? (freightInquiry!['freight_amount'] as num).toDouble() / quantity
      : selectedCargoOption?.pricePerUnit ??
            (isSea ? (departure.value?.publicCbmRate ?? 0) : pricePerKg);
  MaritimeCargoOption? get selectedCargoOption => departure.value?.cargoOptions
      .firstWhereOrNull((option) => option.category == cargoCategory.value);

  void selectCargoCategory(String? category) {
    if (category == null || freightInquiry != null || isSubmitting.value) {
      return;
    }
    if (!(departure.value?.cargoOptions.any(
          (option) => option.category == category,
        ) ??
        false)) {
      return;
    }
    cargoCategory.value = category;
    clearError('cargo_category');
  }

  String get unit => isSea ? 'CBM' : 'kg';

  /// À lire dans un Obx.
  double get freight => freightInquiry != null
      ? (freightInquiry!['freight_amount'] as num).toDouble()
      : double.parse((quantity * unitPrice).toStringAsFixed(2));
  double get grandTotal => double.parse(
    (freight + (insuranceOptIn.value ? insurance.insuranceAmount.value : 0))
        .toStringAsFixed(2),
  );

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['departure'] is MaritimeDeparture) {
      departure.value = args['departure'] as MaritimeDeparture;
      cargoCategory.value = departure.value!.cargoCategory;
      if (args['freight_inquiry'] is Map) {
        freightInquiry = Map<String, dynamic>.from(args['freight_inquiry']);
        kg.value = (freightInquiry!['kg'] as num).toDouble();
        kgController.text = kg.value.toString();
      }
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

    if (freightInquiry == null && remainingKg < kg.value) {
      kg.value = remainingKg;
      kgController.text = remainingKg.toStringAsFixed(1);
    }
    if (freightInquiry == null && isSea) {
      kg.value = remainingKg < conversion ? remainingKg : conversion;
    }
    kgController.text = isSea
        ? formatCbm(quantity)
        : quantity.toStringAsFixed(1);
    kgController.addListener(() {
      final value =
          double.tryParse(kgController.text.replaceAll(',', '.')) ?? 0;
      if (freightInquiry == null) {
        kg.value = value.isFinite && value > 0 ? value * conversion : 0;
      }
    });

    _bindErrorClearing();
    insurance.load();
  }

  @override
  void onClose() {
    for (final c in [
      kgController,
      senderFirstName,
      senderLastName,
      senderPhone,
      emergencyPhone,
      recipientFirstName,
      recipientLastName,
      recipientPhone,
    ]) {
      c.dispose();
    }
    scrollController.dispose();
    for (final worker in _declarationWorkers) {
      worker.dispose();
    }
    insurance.dispose();
    super.onClose();
  }

  String formatAmount(double amount) =>
      CurrencyService.formatFromCurrency(amount, currency);
  String get currencySymbol => CurrencyService.getSymbolForCode(currency);

  String formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  /// Retourne true si tout est valide ; remplit [fieldErrors] sinon.
  /// Retourne true si tout est valide ; remplit [fieldErrors] sinon.
  bool _validate() {
    final errors = <String, String>{};

    String t(TextEditingController c) => c.text.trim();

    // Poids
    final rawKg = double.tryParse(kgController.text.replaceAll(',', '.'));
    if (rawKg == null || !rawKg.isFinite || t(kgController).isEmpty) {
      errors[quantityField] =
          (isSea
                  ? 'maritime.validation.volume_required'
                  : 'maritime.validation.kg_required')
              .tr;
    } else if (rawKg < (isSea ? 0.001 : 0.5)) {
      errors[quantityField] =
          (isSea
                  ? 'maritime.validation.volume_min'
                  : 'maritime.validation.kg_min')
              .tr;
    } else if (rawKg > remainingQuantity) {
      errors[quantityField] =
          (isSea
                  ? 'maritime.validation.volume_max'
                  : 'maritime.validation.kg_max')
              .trParams({
                'max': isSea
                    ? formatCbm(remainingQuantity)
                    : remainingQuantity.toStringAsFixed(1),
              });
    }

    // Expéditeur
    if (t(senderFirstName).isEmpty) {
      errors['sender_first_name'] =
          'maritime.validation.first_name_required'.tr;
    }
    if (t(senderLastName).isEmpty) {
      errors['sender_last_name'] = 'maritime.validation.last_name_required'.tr;
    }

    /// [requiredKey] = clé du message « obligatoire » propre au champ.
    String? phoneError(TextEditingController c, String requiredKey) {
      if (t(c).isEmpty) return requiredKey.tr;
      if (!_phoneRegex.hasMatch(t(c))) {
        return 'maritime.validation.phone_invalid'.tr;
      }
      return null;
    }

    final sp = phoneError(
      senderPhone,
      'maritime.validation.sender_phone_required',
    );
    if (sp != null) errors['sender_phone'] = sp;

    final ep = phoneError(
      emergencyPhone,
      'maritime.validation.emergency_phone_required',
    );
    if (ep != null) {
      errors['emergency_phone'] = ep;
    } else if (t(emergencyPhone) == t(senderPhone)) {
      errors['emergency_phone'] = 'maritime.validation.emergency_phone_same'.tr;
    }

    // Destinataire
    if (t(recipientFirstName).isEmpty) {
      errors['recipient_first_name'] =
          'maritime.validation.recipient_first_name_required'.tr;
    }
    if (t(recipientLastName).isEmpty) {
      errors['recipient_last_name'] =
          'maritime.validation.recipient_last_name_required'.tr;
    }

    final rp = phoneError(
      recipientPhone,
      'maritime.validation.recipient_phone_required',
    );
    if (rp != null) errors['recipient_phone'] = rp;

    // Assurance / nature / valeur
    if (insurance.selectedNature.value == null) {
      errors['parcel_nature_id'] = 'maritime.validation.nature_required'.tr;
    }
    if (!insurance.hasValidValue) {
      errors['declared_value'] = 'maritime.validation.value_required'.tr;
    }

    _setErrors(errors);
    return errors.isEmpty;
  }

  Map<String, dynamic> bookingPayload(
    String method, {
    String? provider,
    String? phone,
  }) => {
    if (freightInquiry != null) 'freight_inquiry_id': freightInquiry!['id'],
    quantityField: quantity,
    'cargo_category': cargoCategory.value,
    'expected_unit_price': unitPrice,
    'parcels_count': 1,
    'sender_first_name': senderFirstName.text.trim(),
    'sender_last_name': senderLastName.text.trim(),
    'sender_phone': senderPhone.text.trim(),
    'emergency_phone': emergencyPhone.text.trim(),
    'recipient_first_name': recipientFirstName.text.trim(),
    'recipient_last_name': recipientLastName.text.trim(),
    // Le pays est celui du hub de destination choisi, pas une donnée
    // à demander une seconde fois au destinataire.
    if (departure.value?.destinationHub?.country case final country?)
      'recipient_country': country,
    'recipient_phone': recipientPhone.text.trim(),
    'parcel_nature_id': insurance.selectedNature.value!.id,
    'declared_value': insurance.declaredValue.value,
    'declared_value_currency': insurance.valueCurrency,
    'insurance_opt_in': insuranceOptIn.value,
    'payment_method': method,
    if (provider != null) 'provider': provider,
    if (phone != null) 'phone_number': phone,
  };

  Future<void> submit() async {
    if (!_validate()) {
      _scrollToFirstError();
      AppFeedback.show(
        'maritime.error'.tr,
        'maritime.validation.fix_fields'.tr,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return;
    }
    if (insuranceOptIn.value && insurance.isQuoting.value) return;
    if (insuranceOptIn.value && !insurance.quoteAvailable.value) {
      AppFeedback.show(
        'maritime.error'.tr,
        'maritime.form.insurance_quote_unavailable'.tr,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return;
    }

    final method = await PaymentMethodSelector.show(
      amount: grandTotal,
      currency: currency,
      amountLabel: 'maritime.form.total_to_pay'.tr,
      includeWallet: true, // payer avec le solde Wallet ASSO
    );
    if (method == null) return;

    if (method.isWallet) {
      // Débité et confirmé immédiatement par le serveur.
      final booking = await _create('wallet');
      if (booking != null) _showSuccess(booking);
    } else if (method.code == 'kpay') {
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

  Future<MaritimeBooking?> _create(
    String method, {
    String? provider,
    String? phone,
  }) async {
    isSubmitting.value = true;
    try {
      final result = await PaymentPreparation.run(
        method: method,
        action: () => _service.book(
          departureId: departure.value!.id,
          data: bookingPayload(method, provider: provider, phone: phone),
        ),
      );
      _lastPayment = result.payment;
      return result.booking;
    } on ApiValidationException catch (e) {
      if (e.fieldErrors.isNotEmpty) {
        _setErrors(e.fieldErrors);
        _scrollToFirstError();
        AppFeedback.show(
          'maritime.error'.tr,
          'maritime.validation.fix_fields'.tr,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      } else {
        AppFeedback.show(
          'maritime.error'.tr,
          e.message,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
      return null;
    } catch (e) {
      AppFeedback.show(
        'maritime.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
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
      AppFeedback.show(
        'diaspo_booking.unavailable'.tr,
        'diaspo_booking.card_mobile_only'.tr,
      );
      return;
    }
    final booking = await _create('stripe');
    if (booking == null) return;
    final secret = _lastPayment['client_secret']?.toString();
    final key = _lastPayment['publishable_key']?.toString();
    if (secret == null || key == null || secret.isEmpty || key.isEmpty) {
      AppFeedback.show(
        'maritime.error'.tr,
        'diaspo_booking.card_data_unavailable'.tr,
      );
      return;
    }
    final ok = await StripeNativeService().payWithCard(
      publishableKey: key,
      clientSecret: secret,
    );
    if (!ok) {
      AppFeedback.show(
        'diaspo_booking.payment_cancelled_title'.tr,
        'diaspo_booking.payment_cancelled_message'.tr,
        backgroundColor: AppDesign.accent,
        colorText: Colors.white,
      );
      return;
    }
    _poll(booking);
  }

  Future<void> _payRedirect(PaymentMethodOption method) async {
    final booking = await _create(method.code);
    if (booking == null) return;
    final url = _lastPayment['approval_url']?.toString();
    if (url == null || url.isEmpty) {
      AppFeedback.show(
        'maritime.error'.tr,
        'diaspo_booking.payment_link_unavailable'.tr,
      );
      return;
    }
    await Get.to(
      () => PaymentWebView(
        paymentUrl: url,
        paymentMethod: method.code,
        paymentId: booking.id,
      ),
    );
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
        AppFeedback.show(
          'diaspo_booking.payment_failed_title'.tr,
          'maritime.form.payment_failed_released'.tr,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
        return;
      }
    }
    AppFeedback.show(
      'diaspo_booking.payment_pending_title'.tr,
      'diaspo_booking.payment_pending_timeout'.tr,
      backgroundColor: AppDesign.accent,
      colorText: Colors.white,
    );
  }

  void _showSuccess(MaritimeBooking booking) {
    final hub = departure.value?.originHub;
    Get.dialog(
      AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: AppDesign.success,
          size: 56,
        ),
        title: Text('maritime.success.title'.tr),
        content: Text(
          'maritime.success.message'.trParams({
            'hub': hub?.fullAddress ?? '',
            'date': booking.dropoffDeadline != null
                ? formatDate(booking.dropoffDeadline!)
                : '',
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
