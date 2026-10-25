import 'package:asso/app/core/utils/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/stripe_connect_service.dart';
import '../../../core/utils/app_design.dart';

/// Onboarding Stripe Connect côté vendeur : saisie de l'IBAN + suivi du statut
/// de validation (null → pending → approved / rejected).
class StripeConnectController extends GetxController {
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final isUnlinking = false.obs;

  /// Statut non chargé (réseau, session expirée, serveur). Sans cela, un échec
  /// silencieux affichait le formulaire vierge : le vendeur croyait son IBAN perdu.
  final loadError = RxnString();

  // Statut renvoyé par le serveur.
  final status = RxnString(); // null | pending | approved | rejected
  final rejectionReason = RxnString();
  final ibanLast4 = RxnString();
  final bankCountry = RxnString();
  final holderName = RxnString();
  final hasAccount = false.obs;

  // État de vérification chez le partenaire bancaire (bloc `stripe` du statut) :
  // un compte peut être validé par ASSO tout en restant bloqué côté partenaire.
  final partnerReady = true.obs;
  final partnerVerification = RxnString();
  final partnerRequirements = <String>[].obs;

  // Formulaire.
  final formKey = GlobalKey<FormState>();
  final countryController = TextEditingController(text: 'FR');
  final ibanController = TextEditingController();
  final holderController = TextEditingController();

  // Identité exigée par le partenaire bancaire (non conservée par l'application).
  final phoneController = TextEditingController();
  final addressLine1Controller = TextEditingController();
  final addressCityController = TextEditingController();
  final addressPostalController = TextEditingController();
  final birthDate = Rxn<DateTime>();

  /// Erreurs renvoyées par le serveur (saisie refusée ou refus de la banque),
  /// affichées sous le champ concerné. Clé = nom du champ de l'API.
  final fieldErrors = <String, String>{}.obs;

  /// Message général affiché au-dessus du bouton après un envoi refusé.
  final formError = RxnString();

  /// Après un premier envoi, chaque champ se revérifie pendant la saisie.
  final submitAttempted = false.obs;

  /// L'utilisateur corrige un champ : son erreur serveur disparaît.
  void clearFieldError(String field) {
    fieldErrors.remove(field);
    formError.value = null;
    if (submitAttempted.value) formKey.currentState?.validate();
  }

  bool get isApproved => status.value == 'approved';
  bool get isPending => status.value == 'pending';
  bool get isRejected => status.value == 'rejected';

  /// Un compte validé est verrouillé (on ne change pas l'IBAN librement).
  bool get canEdit => !isApproved;

  /// Le partenaire bancaire réclame des informations complémentaires.
  ///
  /// Sans ce cas, un compte « en vérification » bloqué chez Stripe était une
  /// impasse : le vendeur n'avait plus de formulaire, et l'admin ne pouvait pas
  /// valider un compte que Stripe refuse. On lui rend la main pour renvoyer son
  /// dossier immédiatement.
  bool get needsMoreInfo =>
      isPending && !partnerReady.value && partnerRequirements.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    loadStatus();
  }

  @override
  void onClose() {
    countryController.dispose();
    ibanController.dispose();
    holderController.dispose();
    phoneController.dispose();
    addressLine1Controller.dispose();
    addressCityController.dispose();
    addressPostalController.dispose();
    super.onClose();
  }

  /// Date de naissance formatée pour l'API (AAAA-MM-JJ).
  String get birthDateIso {
    final d = birthDate.value;
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Date de naissance affichée dans le formulaire (JJ/MM/AAAA).
  String get birthDateLabel {
    final d = birthDate.value;
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Sélecteur de date borné à la majorité (18 ans), refusée par le partenaire.
  Future<void> pickBirthDate(BuildContext context) async {
    final now = DateTime.now();
    final majority = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate.value ?? DateTime(now.year - 30, 1, 1),
      // 1900 : une borne à 100 ans rendait inaccessibles les dates de vérification
      // utilisées en environnement de test (01/01/1901).
      firstDate: DateTime(1900),
      lastDate: majority,
      helpText: 'stripe_connect.birth_date'.tr,
    );

    if (picked != null) {
      birthDate.value = picked;
      clearFieldError('birth_date');
    }
  }

  Future<void> loadStatus() async {
    try {
      isLoading.value = true;
      loadError.value = null;
      final res = await StripeConnectService.getStatus();
      if (res.success && res.data != null) {
        _applyStatus(res.data!);
      } else {
        loadError.value = res.message.isNotEmpty
            ? res.message
            : 'stripe_connect.errors.status_load_failed'.tr;
      }
    } catch (_) {
      loadError.value = 'stripe_connect.errors.server_unreachable'.tr;
    } finally {
      isLoading.value = false;
    }
  }

  /// Applique le statut renvoyé par le serveur.
  ///
  /// ⚠️ `ApiResponse.data` porte le corps COMPLET (`{success, message, data}`) et
  /// non le sous-objet `data` : sans ce déballage, `status` restait null et l'écran
  /// réaffichait le formulaire alors que l'IBAN était bien enregistré.
  void _applyStatus(Map<String, dynamic> body) {
    final raw = body['data'];
    final data = raw is Map<String, dynamic> ? raw : body;

    status.value = data['status'] as String?;
    rejectionReason.value = data['rejection_reason'] as String?;
    ibanLast4.value = data['iban_last4'] as String?;
    bankCountry.value = data['bank_country'] as String?;
    holderName.value = data['account_holder_name'] as String?;
    hasAccount.value = data['has_account'] == true;

    if ((holderName.value ?? '').isNotEmpty && holderController.text.isEmpty) {
      holderController.text = holderName.value!;
    }
    if ((bankCountry.value ?? '').isNotEmpty) {
      countryController.text = bankCountry.value!;
    }

    // Bloc optionnel : absent si le partenaire n'est pas configuré côté serveur.
    final partner = data['stripe'];
    if (partner is Map) {
      partnerReady.value = partner['ready'] == true;
      partnerVerification.value = partner['verification']?.toString();
      partnerRequirements.value = (partner['requirements_due'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
    }
  }

  /// Désynchronise l'IBAN après confirmation : plus de virement vers ce
  /// compte, le formulaire est rouvert pour en enregistrer un autre.
  Future<void> unlink() async {
    if (isUnlinking.value) return;
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('stripe_connect.unlink.title'.tr),
      content: Text('stripe_connect.unlink.confirm'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('common.cancel'.tr)),
        TextButton(
          onPressed: () => Get.back(result: true),
          style: TextButton.styleFrom(foregroundColor: AppDesign.danger),
          child: Text('stripe_connect.unlink.action'.tr),
        ),
      ],
    ));
    if (ok != true) return;

    isUnlinking.value = true;
    try {
      final res = await StripeConnectService.unlink();
      if (res.success && res.data != null) _applyStatus(res.data!);
      AppFeedback.show(
        res.success ? 'stripe_connect.unlink.done_title'.tr : 'stripe_connect.error'.tr,
        res.message.isNotEmpty ? res.message : 'stripe_connect.errors.generic_retry'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: res.success ? AppDesign.success : AppDesign.danger,
        colorText: Colors.white,
      );
    } catch (_) {
      AppFeedback.show(
        'stripe_connect.error'.tr,
        'stripe_connect.errors.generic_retry'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    } finally {
      isUnlinking.value = false;
    }
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;
    submitAttempted.value = true;
    fieldErrors.clear();
    formError.value = null;
    final fieldsValid = formKey.currentState?.validate() ?? false;
    if (!fieldsValid || birthDate.value == null) return;

    isSubmitting.value = true;
    try {
      final res = await StripeConnectService.submit(
        country: countryController.text.trim().toUpperCase(),
        iban: ibanController.text.replaceAll(' ', '').toUpperCase(),
        accountHolderName: holderController.text.trim(),
        birthDate: birthDateIso,
        phone: phoneController.text.trim(),
        addressLine1: addressLine1Controller.text.trim(),
        addressCity: addressCityController.text.trim(),
        addressPostalCode: addressPostalController.text.trim(),
      );

      if (res.success) {
        if (res.data != null) _applyStatus(res.data!);
        AppFeedback.show(
          'stripe_connect.submitted_title'.tr,
          'stripe_connect.submitted_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
        );
      } else {
        _applyServerErrors(res.data?['errors']);
        if (fieldErrors.isEmpty) {
          formError.value = _friendlyError(
            res.message,
            statusCode: res.statusCode,
          );
        }
      }
    } catch (_) {
      formError.value = 'stripe_connect.errors.generic_retry'.tr;
    } finally {
      // Do not retain the bank identifier in the form after sending it to the API.
      ibanController.clear();
      isSubmitting.value = false;
    }
  }

  /// Erreurs par champ de la réponse (`errors: {champ: [message]}`) : affichées
  /// sous chaque champ, le formulaire est revalidé pour les montrer.
  void _applyServerErrors(dynamic errors) {
    if (errors is! Map) return;
    errors.forEach((field, messages) {
      final message = messages is List && messages.isNotEmpty ? '${messages.first}' : '$messages';
      if (message.trim().isNotEmpty) fieldErrors['$field'] = message;
    });
    formKey.currentState?.validate();
  }

  /// Nettoie un message d'erreur venant du serveur : si du texte technique brut
  /// (erreur Stripe, hôte réseau, code errno…) fuit encore, on le remplace par un
  /// message clair. Filet de sécurité pour les backends pas encore à jour.
  String _friendlyError(String message, {int? statusCode}) {
    final raw = message.trim();
    if (statusCode == 503 || statusCode == 0) {
      return 'stripe_connect.errors.service_unavailable'.tr;
    }
    if (raw.isEmpty) return 'stripe_connect.errors.save_failed'.tr;

    final low = raw.toLowerCase();
    const technicalMarkers = [
      'stripe.com',
      'could not connect',
      'could not resolve host',
      'network error',
      'errno',
      'http',
      'connection',
      'timeout',
      'ssl',
      'curl',
      'exception',
    ];
    final looksTechnical = technicalMarkers.any(low.contains);

    if (looksTechnical) {
      if (low.contains('resolve host') ||
          low.contains('could not connect') ||
          low.contains('network') ||
          low.contains('timeout') ||
          low.contains('connection')) {
        return 'stripe_connect.errors.service_unavailable'.tr;
      }
      if (low.contains('iban') || low.contains('bank') || low.contains('account_number')) {
        return 'stripe_connect.errors.iban_seems_invalid'.tr;
      }
      return 'stripe_connect.errors.save_error_later'.tr;
    }

    // Backend messages are localized and curated; unexpected messages remain hidden.
    if (raw == 'payments.stripe_connect.already_validated'.tr ||
        raw == 'stripe_connect.errors.account_already_validated'.tr) {
      return 'stripe_connect.errors.account_already_validated'.tr;
    }
    if (raw == 'payments.stripe_connect.error_country_unsupported'.tr) {
      return 'stripe_connect.validation.country_unsupported'.tr;
    }
    if (statusCode == 422) return raw;

    return 'stripe_connect.errors.save_failed'.tr;
  }

  // ---- Validateurs ----
  // Vérifications locales : un message précis par champ, puis l'erreur du
  // serveur pour ce champ s'il en a renvoyé une.

  String? validateCountry(String? v) {
    final country = (v ?? '').trim().toUpperCase();
    if (country.isEmpty) return 'stripe_connect.validation.country_required'.tr;
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country)) return 'stripe_connect.validation.country_code'.tr;
    final iban = ibanController.text.replaceAll(' ', '').toUpperCase();
    if (iban.length >= 2 && RegExp(r'^[A-Z]{2}').hasMatch(iban) && iban.substring(0, 2) != country) {
      return 'stripe_connect.validation.country_mismatch'.trParams({'iban': iban.substring(0, 2)});
    }
    return fieldErrors['country'];
  }

  String? validateIban(String? v) {
    final iban = (v ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (iban.isEmpty) return 'stripe_connect.validation.iban_required'.tr;
    if (!RegExp(r'^[A-Z]{2}').hasMatch(iban)) return 'stripe_connect.validation.iban_country'.tr;
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}').hasMatch(iban)) return 'stripe_connect.validation.iban_key'.tr;
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(iban)) return 'stripe_connect.validation.iban_characters'.tr;
    if (iban.length < 15) return 'stripe_connect.validation.iban_too_short'.tr;
    if (iban.length > 34) return 'stripe_connect.validation.iban_too_long'.tr;
    if (!_ibanChecksumOk(iban)) return 'stripe_connect.validation.iban_checksum'.tr;
    return fieldErrors['iban'];
  }

  /// Clé de contrôle de l'IBAN (modulo 97) : repère une faute de frappe.
  bool _ibanChecksumOk(String iban) {
    final rearranged = iban.substring(4) + iban.substring(0, 4);
    var remainder = 0;
    for (final unit in rearranged.codeUnits) {
      final digits = unit >= 65 ? '${unit - 55}' : String.fromCharCode(unit);
      for (final d in digits.codeUnits) {
        remainder = (remainder * 10 + (d - 48)) % 97;
      }
    }
    return remainder == 1;
  }

  String? validateHolder(String? v) {
    final holder = (v ?? '').trim();
    if (holder.isEmpty) return 'stripe_connect.validation.holder_required'.tr;
    if (holder.length > 255) return 'stripe_connect.validation.holder_too_long'.tr;
    return fieldErrors['account_holder_name'];
  }

  /// Date de naissance : obligatoire, choisie au calendrier.
  String? get birthDateError {
    if (birthDate.value == null && submitAttempted.value) {
      return 'stripe_connect.birth_date_required_message'.tr;
    }
    return fieldErrors['birth_date'];
  }

  String? validatePhone(String? v) {
    final phone = (v ?? '').trim();
    if (phone.isEmpty) return 'stripe_connect.validation.phone_required'.tr;
    if (!RegExp(r'^\+[1-9][0-9\s().-]*$').hasMatch(phone)) {
      return 'stripe_connect.validation.phone_international'.tr;
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return 'stripe_connect.validation.phone_incomplete'.tr;
    if (digits.length > 15) return 'stripe_connect.validation.phone_too_long'.tr;
    return fieldErrors['phone'];
  }

  String? validateAddressLine(String? v) {
    final address = (v ?? '').trim();
    if (address.isEmpty) return 'stripe_connect.validation.address_required'.tr;
    if (address.length > 255) return 'stripe_connect.validation.address_too_long'.tr;
    return fieldErrors['address_line1'];
  }

  String? validateCity(String? v) {
    if (v == null || v.trim().isEmpty) return 'stripe_connect.validation.city_required'.tr;
    if (v.trim().length > 120) return 'stripe_connect.validation.city_too_long'.tr;
    return fieldErrors['address_city'];
  }

  String? validatePostalCode(String? v) {
    final postal = (v ?? '').trim();
    if (postal.isEmpty) return 'stripe_connect.validation.postal_required'.tr;
    if (postal.length > 20) return 'stripe_connect.validation.postal_too_long'.tr;
    return fieldErrors['address_postal_code'];
  }
}
