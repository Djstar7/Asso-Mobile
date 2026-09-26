import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../routes/app_pages.dart';
import '../controllers/boost_controller.dart';
import '../widgets/boost_campaign_card.dart';
import '../widgets/boost_package_card.dart';
import '../widgets/boost_product_picker.dart';

/// Asso Ads — écran vendeur : lancer un sponsoring, suivre ses campagnes.
class BoostView extends GetView<BoostController> {
  const BoostView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.canvas(context),
      appBar: AppBar(
        backgroundColor: AppDesign.surface(context),
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Asso Ads',
          style: TextStyle(
            color: AppDesign.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: AppDesign.icon(context)),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppDesign.gutter(context),
              16,
              AppDesign.gutter(context),
              32,
            ),
            children: [
              if (controller.hasLoadError.value) _errorBanner(context),
              if (!controller.adsEnabled.value) _suspendedBanner(context),
              _intro(context),
              const SizedBox(height: 24),
              _section(context, 'Quel article mettre en avant ?'),
              const SizedBox(height: 12),
              const BoostProductPicker(),
              const SizedBox(height: 24),
              _section(context, 'Combien de personnes toucher ?'),
              const SizedBox(height: 12),
              ..._packages(context),
              const SizedBox(height: 24),
              _buyButton(context),
              if (controller.campaigns.isNotEmpty) ...[
                const SizedBox(height: 32),
                _section(context, 'Mes campagnes'),
                const SizedBox(height: 12),
                ...controller.campaigns.map(
                  (campaign) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BoostCampaignCard(
                      campaign: campaign,
                      onTap: () => Get.toNamed(
                        Routes.BOOST_DETAIL,
                        arguments: {'boost_id': campaign.id},
                      ),
                      onCancel: campaign.isRunning
                          ? () => controller.cancelCampaign(campaign)
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  /// Chargement en échec : on le dit, plutôt que de laisser croire au vendeur
  /// qu'il n'a ni article ni formule disponible.
  Widget _errorBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesign.dangerSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesign.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_off_rounded, color: AppDesign.dangerText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chargement incomplet',
                  style: TextStyle(
                    color: AppDesign.dangerText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vérifiez votre connexion, puis tirez vers le bas pour réessayer.',
                  style: TextStyle(
                    color: AppDesign.dangerText.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: controller.loadAll,
            style: TextButton.styleFrom(foregroundColor: AppDesign.dangerText),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _suspendedBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesign.warningSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesign.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pause_circle_outline, color: AppDesign.warningText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Le sponsoring est momentanément suspendu. Vos campagnes en cours '
              'reprendront automatiquement, sans consommer de vues entre-temps.',
              style: TextStyle(color: AppDesign.warningText, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesign.accentSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesign.accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, color: AppDesign.accentText, size: 22),
              const SizedBox(width: 8),
              Text(
                'Faites voir votre article',
                style: TextStyle(
                  color: AppDesign.accentText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Votre article apparaît dans le fil d'accueil et les résultats de "
            "recherche, signalé « Sponsorisé ». Vous payez un nombre de vues "
            "garanti : la campagne s'arrête quand il est atteint.",
            style: TextStyle(
              color: AppDesign.accentText.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppDesign.textPrimary(context),
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  List<Widget> _packages(BuildContext context) {
    if (controller.packages.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppDesign.surfaceMuted(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Aucune formule disponible pour le moment.',
            style: TextStyle(color: AppDesign.textSecondary(context), fontSize: 14),
          ),
        ),
      ];
    }

    return controller.packages
        .map(
          (package) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Obx(
              () => BoostPackageCard(
                package: package,
                selected: controller.selectedPackage.value?.id == package.id,
                onTap: () => controller.selectPackage(package),
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _buyButton(BuildContext context) {
    return Obx(() {
      final product = controller.selectedProduct.value;
      final package = controller.selectedPackage.value;
      final busy = controller.isSubscribing.value;
      final ready = product != null && package != null && !busy;

      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: ready ? controller.buy : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppDesign.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  package == null
                      ? 'Choisir une formule'
                      : 'Sponsoriser pour ${package.formattedPrice}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      );
    });
  }
}
