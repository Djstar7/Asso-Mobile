import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/stripe_connect_service.dart';

/// Onboarding Stripe Connect côté vendeur : saisie de l'IBAN + suivi du statut
/// de validation (null → pending → approved / rejected).
class StripeConnectController extends GetxController {
  final isLoading = true.obs;
  final isSubmitting = false.obs;

  // Statut renvoyé par le serveur.
  final status = RxnString(); // null | pending | approved | rejected
  final rejectionReason = RxnString();
  final ibanLast4 = RxnString();
  final bankCountry = RxnString();
  final holderName = RxnString();
  final hasAccount = false.obs;

  // Formulaire.
  final formKey = GlobalKey<FormState>();
  final countryController = TextEditingController(text: 'FR');
  final ibanController = TextEditingController();
  final holderController = TextEditingController();

  bool get isApproved => status.value == 'approved';
  bool get isPending => status.value == 'pending';
  bool get isRejected => status.value == 'rejected';

  /// Un compte validé est verrouillé (on ne change pas l'IBAN librement).
  bool get canEdit => !isApproved;

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
    super.onClose();
  }

  Future<void> loadStatus() async {
    try {
      isLoading.value = true;
      final res = await StripeConnectService.getStatus();
      if (res.success && res.data != null) {
        _applyStatus(res.data!);
      }
    } catch (_) {
      // Silencieux : on laisse simplement le formulaire vierge.
    } finally {
      isLoading.value = false;
    }
  }

  void _applyStatus(Map<String, dynamic> data) {
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
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    try {
      isSubmitting.value = true;
      final res = await StripeConnectService.submit(
        country: countryController.text.trim().toUpperCase(),
        iban: ibanController.text.replaceAll(' ', '').toUpperCase(),
        accountHolderName: holderController.text.trim(),
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
          res.message.isNotEmpty
              ? res.message
              : "Impossible d'enregistrer vos informations.",
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
}
