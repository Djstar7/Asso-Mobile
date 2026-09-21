import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/package_subscription_controller.dart';
import '../widgets/sales_code_field.dart';

class PackageSubscriptionView extends GetView<PackageSubscriptionController> {
  const PackageSubscriptionView({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Scaffold(
      backgroundColor: ds.canvas,
      appBar: AppBar(
        backgroundColor: ds.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: ds.textPrimary,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        centerTitle: false,
        title: Text(
          'Forfaits de stockage',
          style: context.h5.copyWith(
            fontWeight: FontWeight.w700,
            color: ds.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Obx(() {
          if (controller.isLoading.value && controller.packages.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(AppDesign.accent),
                strokeWidth: 2.5,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refreshPackages,
            color: AppDesign.accent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: ds.maxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      ds.gutter,
                      AppDesign.space2,
                      ds.gutter,
                      MediaQuery.of(context).padding.bottom + AppDesign.space8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (controller.hasPackage.value) ...[
                          _buildCurrentPackageSection(context),
                          SizedBox(height: AppDesign.space8),
                        ],

                        Text(
                          'Choisissez un forfait',
                          style: context.subtitle1.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ds.textPrimary,
                          ),
                        ),
                        SizedBox(height: AppDesign.space1),
                        Text(
                          "L'espace de stockage sert aux photos et vidéos de vos produits.",
                          style: context.body2.copyWith(color: ds.textSecondary),
                        ),
                        SizedBox(height: AppDesign.space4),

                        if (controller.packages.isEmpty)
                          _buildEmptyState(context)
                        else
                          _buildPackagesList(context),

                        SizedBox(height: AppDesign.space8),

                        // Code commercial (P6) : secondaire, donc placé après
                        // le choix du forfait plutôt qu'avant.
                        SalesCodeField(input: controller.salesCode),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Bandeau du forfait en cours.
  ///
  /// Le vert n'est plus une décoration de carte : il ne reste que sur la pastille
  /// d'état « Actif », qui est une information sémantique. La jauge de stockage
  /// ne vire au rouge que lorsqu'elle porte réellement une alerte.
  Widget _buildCurrentPackageSection(BuildContext context) {
    final ds = context.ds;
    final vendorPackage = controller.currentVendorPackage.value;
    if (vendorPackage == null) return const SizedBox.shrink();

    final storageTotalMb = (vendorPackage['storage_total_mb'] ?? 0).toDouble();
    final storageUsedMb = (vendorPackage['storage_used_mb'] ?? 0).toDouble();
    final storagePercentageUsed =
        (vendorPackage['storage_percentage_used'] ?? 0).toDouble();
    final daysRemaining = vendorPackage['days_remaining'] ?? 0;
    final packageData = vendorPackage['package'];

    final gaugeColor = storagePercentageUsed > 90
        ? AppDesign.danger
        : storagePercentageUsed > 75
            ? AppDesign.warning
            : AppDesign.accent;

    return Container(
      padding: EdgeInsets.all(AppDesign.space5),
      decoration: BoxDecoration(
        color: ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        border: Border.all(color: ds.border),
        boxShadow: ds.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forfait en cours',
                      style: context.caption.copyWith(color: ds.textTertiary),
                    ),
                    SizedBox(height: AppDesign.space1),
                    Text(
                      packageData?['name'] ?? 'Forfait actuel',
                      style: context.h6.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ds.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppDesign.space2),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDesign.space2,
                  vertical: AppDesign.space1,
                ),
                decoration: BoxDecoration(
                  color: AppDesign.successSubtle,
                  borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                ),
                child: Text(
                  'Actif',
                  style: context.caption.copyWith(
                    color: AppDesign.successText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppDesign.space5),

          // Jauge de stockage.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Stockage',
                  style: context.body2.copyWith(color: ds.textSecondary),
                ),
              ),
              Text(
                '${storageUsedMb.toStringAsFixed(1)} Mo',
                style: context.body2.copyWith(
                  color: ds.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' / ${storageTotalMb.toStringAsFixed(0)} Mo',
                style: context.body2.copyWith(color: ds.textTertiary),
              ),
            ],
          ),
          SizedBox(height: AppDesign.space2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            child: LinearProgressIndicator(
              value: (storagePercentageUsed / 100).clamp(0.0, 1.0),
              backgroundColor: ds.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
              minHeight: 6,
            ),
          ),

          if (daysRemaining <= 7) ...[
            SizedBox(height: AppDesign.space4),
            Container(
              padding: EdgeInsets.all(AppDesign.space3),
              decoration: BoxDecoration(
                color: AppDesign.warningSubtle,
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: AppDesign.warningText,
                  ),
                  SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Text(
                      daysRemaining <= 0
                          ? 'Votre forfait a expiré.'
                          : 'Expire dans $daysRemaining jour${daysRemaining > 1 ? "s" : ""}.',
                      style: context.body2.copyWith(
                        color: AppDesign.warningText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// État vide : sobre, sans grande icône décorative.
  Widget _buildEmptyState(BuildContext context) {
    final ds = context.ds;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppDesign.space5,
        vertical: AppDesign.space10,
      ),
      decoration: BoxDecoration(
        color: ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        border: Border.all(color: ds.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 28, color: ds.textTertiary),
          SizedBox(height: AppDesign.space3),
          Text(
            'Aucun forfait disponible pour le moment.',
            textAlign: TextAlign.center,
            style: context.body2.copyWith(color: ds.textSecondary),
          ),
          SizedBox(height: AppDesign.space4),
          TextButton(
            onPressed: controller.refreshPackages,
            style: TextButton.styleFrom(foregroundColor: AppDesign.accent),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesList(BuildContext context) {
    return Column(
      children: List.generate(
        controller.packages.length,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index < controller.packages.length - 1 ? AppDesign.space3 : 0,
          ),
          child: _buildModernPackageCard(context, controller.packages[index]),
        ),
      ),
    );
  }

  /// Carte d'un forfait.
  ///
  /// Hiérarchie portée par la typographie et l'espacement, pas par la couleur :
  /// l'accent orange ne marque que la sélection, conformément au principe
  /// « une seule couleur d'accent » d'[AppDesign].
  Widget _buildModernPackageCard(BuildContext context, Map<String, dynamic> package) {
    final ds = context.ds;
    final isPopular = package['is_popular'] ?? false;
    final benefits = package['benefits'] as List?;
    final name = package['name'] ?? '';
    final price = (package['price'] ?? 0).toDouble();
    final storage = package['formatted_storage_size'] ?? '';
    final duration = package['formatted_duration'] ?? '';

    return Obx(() {
      final isSelected = controller.selectedPackage.value?['id'] == package['id'];

      return Semantics(
        button: true,
        selected: isSelected,
        label: '$name, ${controller.formatCurrency(price)} $duration, $storage',
        child: GestureDetector(
          onTap: () => controller.selectPackage(package),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(AppDesign.space5),
            decoration: BoxDecoration(
              color: ds.surface,
              borderRadius: BorderRadius.circular(AppDesign.radiusLg),
              border: Border.all(
                color: isSelected ? AppDesign.accent : ds.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? ds.shadowMd : ds.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête : sélection, nom, badge éventuel.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SelectionDot(isSelected: isSelected),
                    SizedBox(width: AppDesign.space3),
                    Expanded(
                      child: Text(
                        name,
                        style: context.h6.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ds.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (isPopular) ...[
                      SizedBox(width: AppDesign.space2),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppDesign.space2,
                          vertical: AppDesign.space1,
                        ),
                        decoration: BoxDecoration(
                          color: AppDesign.accentSubtle,
                          borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                        ),
                        child: Text(
                          'Recommandé',
                          style: context.caption.copyWith(
                            color: AppDesign.accentText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: AppDesign.space4),

                // Prix : l'information la plus lourde de la carte.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        controller.formatCurrency(price),
                        style: context.h3.copyWith(
                          color: ds.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                    SizedBox(width: AppDesign.space2),
                    Text(
                      duration,
                      style: context.body2.copyWith(color: ds.textSecondary),
                    ),
                  ],
                ),

                SizedBox(height: AppDesign.space2),

                // Stockage : ligne de texte simple, sans pastille colorée.
                Row(
                  children: [
                    Icon(Icons.storage_outlined, size: 16, color: ds.icon),
                    SizedBox(width: AppDesign.space2),
                    Expanded(
                      child: Text(
                        '$storage de stockage',
                        style: context.body2.copyWith(color: ds.textSecondary),
                      ),
                    ),
                  ],
                ),

                if (benefits != null && benefits.isNotEmpty) ...[
                  SizedBox(height: AppDesign.space4),
                  Divider(height: 1, color: ds.border),
                  SizedBox(height: AppDesign.space4),
                  ...List.generate(
                    benefits.length > 4 ? 4 : benefits.length,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == (benefits.length > 4 ? 4 : benefits.length) - 1
                            ? 0
                            : AppDesign.space3,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: ds.textTertiary,
                            ),
                          ),
                          SizedBox(width: AppDesign.space2),
                          Expanded(
                            child: Text(
                              benefits[index].toString(),
                              style: context.body2.copyWith(color: ds.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // L'action n'apparaît que sur la carte choisie : une seule
                // cible d'action à l'écran au lieu d'une par carte.
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: isSelected
                      ? Column(
                          children: [
                            SizedBox(height: AppDesign.space5),
                            SizedBox(
                              width: double.infinity,
                              height: context.buttonHeight,
                              child: ElevatedButton(
                                onPressed: controller.isSubscribing.value
                                    ? null
                                    : () => controller.subscribeToSelectedPackage(package),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppDesign.accent,
                                  foregroundColor: AppDesign.neutral0,
                                  disabledBackgroundColor: ds.surfaceMuted,
                                  disabledForegroundColor: ds.textTertiary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDesign.radiusMd),
                                  ),
                                ),
                                child: Text(
                                  'Choisir ce plan',
                                  style: context.button.copyWith(
                                    color: controller.isSubscribing.value
                                        ? context.ds.textTertiary
                                        : AppDesign.neutral0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Indicateur de sélection : cercle neutre au repos, plein en accent une fois
/// choisi. Dessiné ici plutôt qu'avec un `Radio` pour rester aligné sur les
/// rayons et couleurs du design system.
class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppDesign.accent : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppDesign.accent : ds.borderStrong,
          width: isSelected ? 0 : 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 14, color: AppDesign.neutral0)
          : null,
    );
  }
}
