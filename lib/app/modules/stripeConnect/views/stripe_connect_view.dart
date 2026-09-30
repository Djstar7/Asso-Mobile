import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/stripe_connect_controller.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';

/// Écran vendeur : saisir son IBAN pour être payé par virement, et suivre le
/// statut de validation par ASSO.
class StripeConnectView extends GetView<StripeConnectController> {
  const StripeConnectView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('stripe_connect.view.title'.tr),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.loadStatus,
          child: ListView(
            // Formulaire IBAN : faire défiler referme le clavier qui cachait
            // le bouton d'enregistrement.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              _intro(context),
              const SizedBox(height: 16),
              // La bannière n'est utile qu'au-dessus du formulaire (cas rejeté).
              // Les états « validé » et « en attente » ont leur propre carte plein écran.
              if (controller.isRejected) ...[
                _statusBanner(context),
                const SizedBox(height: 16),
              ],
              // Statut inconnu : ne PAS afficher le formulaire, qui laisserait
              // croire qu'aucun IBAN n'est enregistré.
              if (controller.loadError.value != null && controller.status.value == null)
                _loadErrorCard(context)
              else if (controller.isApproved)
                _approvedCard(context)
              else if (controller.isPending) ...[
                // Dossier en cours d'examen : plus aucune saisie possible. Si le
                // partenaire réclame des précisions, le bandeau l'annonce et la
                // correction passe par le support (qui rouvre le formulaire).
                if (controller.needsMoreInfo) ...[
                  _moreInfoBanner(context),
                  const SizedBox(height: 16),
                ],
                _pendingCard(context),
              ] else
                _form(context),
            ],
          ),
        );
      }),
    );
  }

  Widget _intro(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'stripe_connect.view.intro'.tr,
              style: const TextStyle(fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Bandeau « informations complémentaires demandées », au-dessus du formulaire.
  Widget _moreInfoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesign.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesign.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_late_outlined, color: AppDesign.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'stripe_connect.view.more_info_title'.tr,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppDesign.accent),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.partnerVerification.value ??
                      'stripe_connect.view.more_info_default'.tr,
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(
                  'stripe_connect.view.more_info_contact'.tr,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// État indisponible : on l'annonce et on propose de réessayer.
  Widget _loadErrorCard(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppDesign.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_off_rounded, size: 40, color: AppDesign.accent),
        ),
        const SizedBox(height: 16),
        Text(
          'stripe_connect.view.status_unavailable'.tr,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            controller.loadError.value ?? '',
            style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'stripe_connect.view.status_unavailable_hint'.tr,
            style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.loadStatus,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('stripe_connect.view.retry'.tr),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    );
  }

  Widget _statusBanner(BuildContext context) {
    final (Color color, IconData icon, String label, String detail) = switch (controller.status.value) {
      'approved' => (
          AppDesign.success,
          Icons.verified,
          'stripe_connect.view.banner_approved_title'.tr,
          'stripe_connect.view.banner_approved_detail'.tr
        ),
      'rejected' => (
          AppDesign.danger,
          Icons.cancel,
          'stripe_connect.view.banner_rejected_title'.tr,
          controller.rejectionReason.value ?? 'stripe_connect.view.banner_rejected_detail'.tr
        ),
      _ => (
          AppDesign.accent,
          Icons.hourglass_top,
          'stripe_connect.view.banner_pending_title'.tr,
          'stripe_connect.view.banner_pending_detail'.tr
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(fontSize: 13, height: 1.3)),
                if (controller.ibanLast4.value != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'stripe_connect.view.iban_masked'.trParams({'last4': '${controller.ibanLast4.value}'}) +
                        (controller.bankCountry.value != null ? '  (${controller.bankCountry.value})' : ''),
                    style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Page d'attente affichée quand un IBAN a été soumis et est en cours de
  /// vérification : plus de formulaire, seulement le rappel des informations
  /// (IBAN masqué + titulaire) et le statut.
  Widget _pendingCard(BuildContext context) {
    const orange = AppDesign.accent;
    final holder = controller.holderName.value;
    final last4 = controller.ibanLast4.value;
    final country = controller.bankCountry.value;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: orange.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hourglass_top, size: 44, color: orange),
        ),
        const SizedBox(height: 16),
        Text(
          'stripe_connect.view.pending_title'.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'stripe_connect.view.pending_message'.tr,
            style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        _partnerStateNotice(),
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('stripe_connect.view.saved_info'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _readonlyRow('stripe_connect.view.holder'.tr, (holder ?? '').isNotEmpty ? holder! : '—'),
                _readonlyRow('IBAN', last4 != null ? '•••• •••• $last4' : '••••'),
                _readonlyRow('stripe_connect.view.country'.tr, country ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Colors.black45),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'stripe_connect.view.pending_locked'.tr,
                style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Compte validé : plus aucun formulaire, une page de confirmation.
  ///
  /// Le vendeur n'a plus rien à saisir — lui reproposer les champs laisse croire
  /// que sa demande n'a pas abouti.
  Widget _approvedCard(BuildContext context) {
    const green = AppDesign.success;
    final holder = controller.holderName.value;
    final last4 = controller.ibanLast4.value;
    final country = controller.bankCountry.value;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_rounded, size: 44, color: green),
        ),
        const SizedBox(height: 16),
        Text(
          'stripe_connect.view.approved_title'.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'stripe_connect.view.approved_message'.tr,
            style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('stripe_connect.view.saved_info'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _readonlyRow('stripe_connect.view.holder'.tr, (holder ?? '').isNotEmpty ? holder! : '—'),
                _readonlyRow('IBAN', last4 != null ? '•••• •••• $last4' : '••••'),
                _readonlyRow('stripe_connect.view.country'.tr, country ?? '—'),
                _partnerStateNotice(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: Text('stripe_connect.view.back_to_wallet'.tr),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 18, color: Colors.black45),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'stripe_connect.view.approved_locked'.tr,
                style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Avertissement quand le partenaire bancaire n'a pas (encore) activé le compte.
  ///
  /// Un compte peut être validé par ASSO et pourtant refusé par le partenaire
  /// (vérification en cours, pièce manquante) : le vendeur doit le savoir avant de
  /// demander un virement qui serait rejeté.
  Widget _partnerStateNotice() {
    return Obx(() {
      if (controller.partnerReady.value) return const SizedBox.shrink();

      final message = controller.partnerVerification.value ??
          'stripe_connect.view.partner_verification_default'.tr;
      final missing = controller.partnerRequirements;

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppDesign.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppDesign.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppDesign.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message,
                      style: const TextStyle(fontSize: 12.5, height: 1.35)),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'stripe_connect.view.partner_blocking'.tr,
                      style: TextStyle(
                          fontSize: 12, color: AppDesign.accent, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _readonlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.isRejected)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'stripe_connect.view.fix_and_resend'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          TextFormField(
            controller: controller.holderController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'stripe_connect.view.holder_label'.tr,
              hintText: 'stripe_connect.view.holder_hint'.tr,
              border: const OutlineInputBorder(),
            ),
            validator: controller.validateHolder,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller.ibanController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'IBAN',
              hintText: 'FR76 3000 6000 0112 3456 7890 189',
              border: OutlineInputBorder(),
            ),
            validator: controller.validateIban,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller.countryController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 2,
            decoration: InputDecoration(
              labelText: 'stripe_connect.view.country_label'.tr,
              hintText: 'FR',
              border: const OutlineInputBorder(),
            ),
            validator: controller.validateCountry,
          ),
          const SizedBox(height: 22),
          Text(
            'stripe_connect.view.identity_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'stripe_connect.view.identity_subtitle'.tr,
            style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 14),
          // La date n'est pas saisie au clavier : sélecteur borné à 18 ans.
          Obx(() => InkWell(
                onTap: () => controller.pickBirthDate(context),
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'stripe_connect.birth_date'.tr,
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    errorText: controller.birthDate.value == null &&
                            controller.isSubmitting.value
                        ? 'stripe_connect.birth_date_required_title'.tr
                        : null,
                  ),
                  child: Text(
                    controller.birthDateLabel.isEmpty
                        ? 'stripe_connect.view.date_placeholder'.tr
                        : controller.birthDateLabel,
                    style: TextStyle(
                      color: controller.birthDateLabel.isEmpty
                          ? Colors.black45
                          : Colors.black87,
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller.phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'stripe_connect.view.phone_label'.tr,
              hintText: '+33 6 12 34 56 78',
              border: const OutlineInputBorder(),
            ),
            validator: controller.validatePhone,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller.addressLine1Controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'stripe_connect.view.address_label'.tr,
              hintText: 'stripe_connect.view.address_hint'.tr,
              border: const OutlineInputBorder(),
            ),
            validator: controller.validateAddressLine,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: controller.addressCityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'stripe_connect.view.city_label'.tr,
                    border: const OutlineInputBorder(),
                  ),
                  validator: controller.validateCity,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller.addressPostalController,
                  decoration: InputDecoration(
                    labelText: 'stripe_connect.view.postal_label'.tr,
                    border: const OutlineInputBorder(),
                  ),
                  validator: controller.validatePostalCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  onPressed: controller.isSubmitting.value ? null : controller.submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: controller.isSubmitting.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(controller.isRejected ? 'stripe_connect.view.resend_iban'.tr : 'stripe_connect.view.save_iban'.tr),
                )),
          ),
        ],
      ),
    );
  }
}
