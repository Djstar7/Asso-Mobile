import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/stripe_connect_service.dart';

/// Onboarding Stripe Connect côté vendeur : saisie de l'IBAN + suivi du statut
/// de validation (null → pending → approved / rejected).
class StripeConnectController extends GetxController {
  final isLoading = true.obs;
  final isSubmitting = false.obs;

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
      firstDate: DateTime(now.year - 100),
      lastDate: majority,
      helpText: 'Date de naissance',
    );

    if (picked != null) birthDate.value = picked;
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
            : "Impossible de récupérer l'état de votre compte de virement.";
      }
    } catch (_) {
      loadError.value = "Connexion au serveur impossible. Vérifiez votre réseau puis réessayez.";
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

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    if (birthDate.value == null) {
      Get.snackbar(
        'Date de naissance requise',
        'Notre partenaire bancaire exige votre date de naissance pour activer les virements.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isSubmitting.value = true;
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
        ibanController.clear();
        Get.snackbar(
          'Informations envoyées',
          res.message.isNotEmpty
              ? res.message
              : 'Votre compte de virement sera vérifié sous 24-48h.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Erreur',
          _friendlyError(res.message),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (_) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue. Réessayez.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Nettoie un message d'erreur venant du serveur : si du texte technique brut
  /// (erreur Stripe, hôte réseau, code errno…) fuit encore, on le remplace par un
  /// message clair. Filet de sécurité pour les backends pas encore à jour.
  String _friendlyError(String message) {
    final raw = message.trim();
    if (raw.isEmpty) return "Impossible d'enregistrer vos informations bancaires. Réessayez.";

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
        return "Le service de virement bancaire est momentanément indisponible. "
            "Vérifiez votre connexion et réessayez dans quelques instants.";
      }
      if (low.contains('iban') || low.contains('bank') || low.contains('account_number')) {
        return "L'IBAN saisi semble invalide. Vérifiez-le puis réessayez.";
      }
      return "Une erreur est survenue lors de l'enregistrement. Veuillez réessayer plus tard.";
    }

    // Message déjà propre (renvoyé par le backend à jour) : on l'affiche tel quel.
    return raw;
  }

  // ---- Validateurs ----
  String? validateCountry(String? v) {
    if (v == null || v.trim().length != 2) return 'Code pays à 2 lettres (ex. FR)';
    return null;
  }

  String? validateIban(String? v) {
    final iban = (v ?? '').replaceAll(' ', '').toUpperCase();
    if (iban.isEmpty) return 'IBAN requis';
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$').hasMatch(iban)) {
      return 'IBAN invalide';
    }
    return null;
  }

  String? validateHolder(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nom du titulaire requis';
    return null;
  }

  String? validatePhone(String? v) {
    final phone = (v ?? '').trim();
    if (phone.isEmpty) return 'Téléphone requis';
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 8) return 'Numéro incomplet';
    return null;
  }

  String? validateAddressLine(String? v) {
    if (v == null || v.trim().length < 4) return 'Adresse requise';
    return null;
  }

  String? validateCity(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ville requise';
    return null;
  }

  String? validatePostalCode(String? v) {
    if (v == null || v.trim().isEmpty) return 'Code postal requis';
    return null;
  }
}
