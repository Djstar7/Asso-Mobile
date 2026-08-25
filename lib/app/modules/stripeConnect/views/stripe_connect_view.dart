import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/stripe_connect_controller.dart';

/// Écran vendeur : saisir son IBAN pour être payé par virement, et suivre le
/// statut de validation par ASSO.
class StripeConnectView extends GetView<StripeConnectController> {
  const StripeConnectView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compte de virement'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.loadStatus,
          child: ListView(
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
              // Informations réclamées par le partenaire : on redonne le formulaire
              // plutôt que de laisser le vendeur devant une page d'attente sans issue.
              else if (controller.needsMoreInfo) ...[
                _moreInfoBanner(context),
                const SizedBox(height: 16),
                _form(context),
              ] else if (controller.isPending)
                _pendingCard(context)
              else
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
          const Expanded(
            child: Text(
              "Enregistrez votre IBAN pour recevoir vos paiements par virement bancaire. "
              "Vos informations sont vérifiées par notre équipe avant activation.",
              style: TextStyle(fontSize: 13.5, height: 1.35),
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
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_late_outlined, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informations complémentaires demandées',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.partnerVerification.value ??
                      "Notre partenaire bancaire a besoin de précisions avant d'autoriser "
                          'vos virements.',
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Renvoyez le formulaire ci-dessous en vérifiant chaque champ.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.3),
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
            color: Colors.orange.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.orange),
        ),
        const SizedBox(height: 16),
        const Text(
          'État du compte indisponible',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "Si vous avez déjà enregistré un IBAN, il est toujours là : "
            "cet écran n'a pas pu le récupérer.",
            style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.loadStatus,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    );
  }

  Widget _statusBanner(BuildContext context) {
    final (Color color, IconData icon, String label, String detail) = switch (controller.status.value) {
      'approved' => (
          Colors.green,
          Icons.verified,
          'Compte validé',
          'Vous pouvez être payé par virement sur cet IBAN.'
        ),
      'rejected' => (
          Colors.red,
          Icons.cancel,
          'Compte rejeté',
          controller.rejectionReason.value ?? 'Veuillez corriger vos informations et renvoyer.'
        ),
      _ => (
          Colors.orange,
          Icons.hourglass_top,
          'En attente de validation',
          'Votre IBAN est en cours de vérification (24-48h).'
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
                    'IBAN : •••• ${controller.ibanLast4.value}'
                    '${controller.bankCountry.value != null ? '  (${controller.bankCountry.value})' : ''}',
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
    const orange = Colors.orange;
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
        const Text(
          'Vérification en cours',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "Votre IBAN a bien été enregistré. Notre équipe le vérifie avant "
            "d'activer les virements sur votre compte (généralement sous 24-48h).",
            style: TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87),
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
                const Text('Informations enregistrées',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _readonlyRow('Titulaire', (holder ?? '').isNotEmpty ? holder! : '—'),
                _readonlyRow('IBAN', last4 != null ? '•••• •••• $last4' : '••••'),
                _readonlyRow('Pays', country ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Icon(Icons.info_outline, size: 18, color: Colors.black45),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Vous ne pouvez pas modifier votre IBAN pendant la vérification. "
                "Tirez vers le bas pour actualiser le statut.",
                style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
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
    const green = Color(0xFF16A34A);
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
        const Text(
          'Compte de virement validé',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "Vos paiements peuvent désormais être virés sur ce compte bancaire. "
            "Le montant est converti depuis votre portefeuille au moment du retrait.",
            style: TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87),
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
                const Text('Informations enregistrées',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _readonlyRow('Titulaire', (holder ?? '').isNotEmpty ? holder! : '—'),
                _readonlyRow('IBAN', last4 != null ? '•••• •••• $last4' : '••••'),
                _readonlyRow('Pays', country ?? '—'),
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
            label: const Text('Retour au portefeuille'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Icon(Icons.lock_outline, size: 18, color: Colors.black45),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Pour modifier un IBAN déjà validé, contactez le support.",
                style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
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
          "Vérification bancaire en cours.";
      final missing = controller.partnerRequirements;

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: Colors.orange),
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
                      'Les virements resteront indisponibles tant que ce point '
                      "n'est pas réglé.",
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade900, height: 1.3),
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
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Corrigez vos informations puis renvoyez.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          TextFormField(
            controller: controller.holderController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom du titulaire du compte',
              hintText: 'Ex. : Jean Dupont',
              border: OutlineInputBorder(),
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
            decoration: const InputDecoration(
              labelText: 'Pays du compte (code à 2 lettres)',
              hintText: 'FR',
              border: OutlineInputBorder(),
            ),
            validator: controller.validateCountry,
          ),
          const SizedBox(height: 22),
          const Text(
            "Vos informations d'identité",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            "Exigées par notre partenaire bancaire pour autoriser les virements. "
            "Elles ne sont pas conservées par l'application.",
            style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 14),
          // La date n'est pas saisie au clavier : sélecteur borné à 18 ans.
          Obx(() => InkWell(
                onTap: () => controller.pickBirthDate(context),
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date de naissance',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    errorText: controller.birthDate.value == null &&
                            controller.isSubmitting.value
                        ? 'Date de naissance requise'
                        : null,
                  ),
                  child: Text(
                    controller.birthDateLabel.isEmpty
                        ? 'JJ/MM/AAAA'
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
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              hintText: '+33 6 12 34 56 78',
              border: OutlineInputBorder(),
            ),
            validator: controller.validatePhone,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller.addressLine1Controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Adresse',
              hintText: '12 rue de la Paix',
              border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: 'Ville',
                    border: OutlineInputBorder(),
                  ),
                  validator: controller.validateCity,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller.addressPostalController,
                  decoration: const InputDecoration(
                    labelText: 'Code postal',
                    border: OutlineInputBorder(),
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
                      : Text(controller.isRejected || controller.needsMoreInfo
                          ? 'Renvoyer mes informations'
                          : 'Enregistrer mon IBAN'),
                )),
          ),
        ],
      ),
    );
  }
}
