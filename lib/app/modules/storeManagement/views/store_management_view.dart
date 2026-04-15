import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/store_management_controller.dart';
import '../models/store_models.dart';
import 'edit_store_view.dart';

class StoreManagementView extends GetView<StoreManagementController> {
  const StoreManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: context.primaryTextColor,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Ma Boutique',
          style: context.h5.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: context.primaryTextColor,
            ),
            onPressed: controller.loadData,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.storeInfo.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.loadData,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carousel de bannières
                _BannerCarousel(),

                SizedBox(height: context.sectionSpacing),

                // Location request notification
                _LocationRequestNotification(),

                // Carte de stockage
                _StorageCard(),

                SizedBox(height: context.elementSpacing),

                // Certification
                _CertificationCard(),

                SizedBox(height: context.elementSpacing),

                // Statistiques d'audience
                _AudienceStatsCard(),

                SizedBox(height: context.elementSpacing),

                // Inventaire
                _InventoryCard(),

                SizedBox(height: context.elementSpacing),

                // Édition de la boutique
                _StoreEditorCard(),

                SizedBox(height: context.sectionSpacing),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Carousel de bannières promotionnelles
class _BannerCarousel extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.banners.isEmpty) return const SizedBox.shrink();

      return Column(
        children: [
          SizedBox(
            height: 140,
            child: PageView.builder(
              itemCount: controller.banners.length,
              onPageChanged: (index) {
                controller.currentBannerIndex.value = index;
              },
              itemBuilder: (context, index) {
                final banner = controller.banners[index];
                return _BannerItem(banner: banner);
              },
            ),
          ),
          const SizedBox(height: 12),
          // Indicateurs de page
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              controller.banners.length,
              (index) => Obx(() => Container(
                width: controller.currentBannerIndex.value == index ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: controller.currentBannerIndex.value == index
                      ? AppThemeSystem.primaryColor
                      : AppThemeSystem.grey300,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ),
        ],
      );
    });
  }
}

/// Item de bannière
class _BannerItem extends StatelessWidget {
  final PromotionalBanner banner;

  const _BannerItem({required this.banner});

  Color _getColorFromType(BannerType type) {
    final colorCode = type.colorCode;
    return Color(int.parse(colorCode.replaceFirst('#', '0xFF')));
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorFromType(banner.type);

    return GestureDetector(
      onTap: banner.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.all(context.horizontalPadding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    banner.title,
                    style: context.h5.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      banner.description,
                      style: context.body2.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: context.borderRadius(BorderRadiusType.small),
                    ),
                    child: Text(
                      banner.actionLabel,
                      style: context.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte de gestion du stockage
class _StorageCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final storage = controller.storageStats.value;
      if (storage == null) return const SizedBox.shrink();

      return Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: AppThemeSystem.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Espace de stockage',
                  style: context.h6.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: context.elementSpacing),
            // Barre de progression
            ClipRRect(
              borderRadius: context.borderRadius(BorderRadiusType.small),
              child: LinearProgressIndicator(
                value: storage.usagePercentage / 100,
                minHeight: 12,
                backgroundColor: AppThemeSystem.grey200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  storage.isAlmostFull
                      ? AppThemeSystem.errorColor
                      : AppThemeSystem.primaryColor,
                ),
              ),
            ),
            SizedBox(height: context.elementSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${storage.usedSpaceGB.toStringAsFixed(1)} GB / ${storage.totalSpaceGB.toStringAsFixed(1)} GB',
                  style: context.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${storage.usagePercentage.toStringAsFixed(1)}%',
                  style: context.body2.copyWith(
                    color: storage.isAlmostFull
                        ? AppThemeSystem.errorColor
                        : AppThemeSystem.successColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.elementSpacing),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.inventory_2_outlined,
                    label: '${storage.totalProducts} produits',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.image_outlined,
                    label: '${storage.totalImages} images',
                  ),
                ),
              ],
            ),
            if (storage.isAlmostFull) ...[
              SizedBox(height: context.elementSpacing),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemeSystem.warningColor.withValues(alpha: 0.1),
                  borderRadius: context.borderRadius(BorderRadiusType.small),
                  border: Border.all(color: AppThemeSystem.warningColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppThemeSystem.warningColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Votre espace de stockage est presque plein',
                        style: context.caption.copyWith(
                          color: AppThemeSystem.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: context.elementSpacing),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.upgradeStorage,
                icon: const Icon(Icons.upgrade),
                label: const Text('Augmenter l\'espace'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Puce d'information
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemeSystem.grey100,
        borderRadius: context.borderRadius(BorderRadiusType.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.secondaryTextColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: context.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de certification
class _CertificationCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cert = controller.certification.value;
      if (cert == null) return const SizedBox.shrink();

      // Si certifié : afficher un badge élégant avec délai d'expiration
      if (cert.isCertified) {
        final daysRemaining = cert.daysUntilExpiry ?? 0;
        final isExpiringSoon = cert.isExpiringSoon;
        final isExpired = cert.isExpired;

        // Couleur basée sur le statut d'expiration
        final certColor = isExpired
            ? AppThemeSystem.errorColor
            : isExpiringSoon
                ? AppThemeSystem.warningColor
                : const Color(0xFF1DA1F2);

        return Container(
          padding: EdgeInsets.all(context.horizontalPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                certColor.withValues(alpha: 0.15),
                certColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            border: Border.all(
              color: certColor.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: certColor.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Badge avec animation shimmer subtile
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: certColor,
                      borderRadius: context.borderRadius(BorderRadiusType.small),
                      boxShadow: [
                        BoxShadow(
                          color: certColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Boutique Certifiée',
                              style: context.h6.copyWith(
                                fontWeight: FontWeight.bold,
                                color: certColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.stars,
                              color: certColor,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isExpired
                              ? 'Certification expirée'
                              : isExpiringSoon
                                  ? 'Expire bientôt - Renouvelez!'
                                  : 'Badge de confiance actif',
                          style: context.caption.copyWith(
                            color: context.secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Délai d'expiration
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.backgroundColor,
                  borderRadius: context.borderRadius(BorderRadiusType.small),
                  border: Border.all(
                    color: certColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpired
                          ? Icons.error_outline
                          : isExpiringSoon
                              ? Icons.warning_amber
                              : Icons.schedule,
                      color: certColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isExpired
                                ? 'Expirée'
                                : daysRemaining == 1
                                    ? 'Expire demain'
                                    : 'Expire dans',
                            style: context.caption.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                          if (!isExpired) ...[
                            const SizedBox(height: 2),
                            Text(
                              '$daysRemaining jour${daysRemaining > 1 ? 's' : ''}',
                              style: context.body1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: certColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isExpiringSoon || isExpired)
                      TextButton(
                        onPressed: controller.requestCertification,
                        style: TextButton.styleFrom(
                          foregroundColor: certColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: Text(
                          'Renouveler',
                          style: context.caption.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // Si non certifié : afficher comme une pub attractive
      return Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppThemeSystem.primaryColor.withValues(alpha: 0.1),
              AppThemeSystem.primaryColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                    borderRadius: context.borderRadius(BorderRadiusType.small),
                  ),
                  child: Icon(
                    Icons.verified_outlined,
                    color: AppThemeSystem.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Devenez une boutique certifiée',
                        style: context.h6.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gagnez la confiance de vos clients',
                        style: context.caption.copyWith(
                          color: context.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.elementSpacing),
            // Avantages
            _CertificationBenefit(
              icon: Icons.trending_up,
              text: '+300% de visibilité sur vos produits',
            ),
            const SizedBox(height: 8),
            _CertificationBenefit(
              icon: Icons.star,
              text: 'Badge bleu de confiance affiché',
            ),
            const SizedBox(height: 8),
            _CertificationBenefit(
              icon: Icons.security,
              text: 'Priorité dans les résultats de recherche',
            ),
            SizedBox(height: context.elementSpacing),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.requestCertification,
                icon: const Icon(Icons.verified),
                label: const Text('Demander la certification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Bénéfice de certification
class _CertificationBenefit extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CertificationBenefit({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppThemeSystem.primaryColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: context.caption.copyWith(
              color: context.primaryTextColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte des statistiques d'audience
class _AudienceStatsCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stats = controller.audienceStats.value;
      if (stats == null) return const SizedBox.shrink();

      return Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: AppThemeSystem.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Mes audiences',
                  style: context.h6.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: context.elementSpacing),
            // Statistiques générales
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: Icons.visibility_outlined,
                    label: 'Vues',
                    value: NumberFormat('#,###').format(stats.totalViews),
                    color: AppThemeSystem.infoColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    icon: Icons.touch_app_outlined,
                    label: 'Clics',
                    value: NumberFormat('#,###').format(stats.totalClicks),
                    color: AppThemeSystem.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Commandes',
                    value: stats.totalOrders.toString(),
                    color: AppThemeSystem.successColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    icon: Icons.percent,
                    label: 'Conversion',
                    value: '${stats.conversionRate.toStringAsFixed(1)}%',
                    color: AppThemeSystem.warningColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.elementSpacing),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: controller.boostProducts,
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Booster mes produits'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeSystem.primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Boîte de statistique
class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: context.borderRadius(BorderRadiusType.small),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: context.h5.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.caption.copyWith(
              color: context.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'inventaire
class _InventoryCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory,
                color: AppThemeSystem.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Inventaire',
                  style: context.h6.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: context.elementSpacing),
          // Filtres
          Obx(() => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Tous',
                isSelected: controller.selectedInventoryFilter.value == null,
                onTap: () => controller.selectedInventoryFilter.value = null,
              ),
              _FilterChip(
                label: 'Entrées',
                isSelected: controller.selectedInventoryFilter.value ==
                    InventoryType.entry,
                onTap: () => controller.selectedInventoryFilter.value =
                    InventoryType.entry,
              ),
              _FilterChip(
                label: 'Sorties',
                isSelected: controller.selectedInventoryFilter.value ==
                    InventoryType.exit,
                onTap: () => controller.selectedInventoryFilter.value =
                    InventoryType.exit,
              ),
            ],
          )),
          SizedBox(height: context.elementSpacing),
          // Liste des entrées (3 les plus récentes)
          Obx(() {
            final entries = controller.filteredInventory;
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucune entrée d\'inventaire',
                    style: context.body2.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                ...entries.take(3).map((entry) {
                  return _InventoryItem(entry: entry);
                }).toList(),
                if (entries.length > 3) ...[
                  SizedBox(height: context.elementSpacing),
                  OutlinedButton.icon(
                    onPressed: controller.viewAllInventory,
                    icon: Icon(Icons.visibility_outlined, size: 18),
                    label: Text('Voir tout (${entries.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeSystem.primaryColor,
                      side: BorderSide(color: AppThemeSystem.primaryColor),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Filtre chip
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeSystem.primaryColor
              : AppThemeSystem.grey100,
          borderRadius: context.borderRadius(BorderRadiusType.small),
          border: Border.all(
            color: isSelected
                ? AppThemeSystem.primaryColor
                : AppThemeSystem.grey300,
          ),
        ),
        child: Text(
          label,
          style: context.caption.copyWith(
            color: isSelected ? Colors.white : context.secondaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Item d'inventaire
class _InventoryItem extends GetView<StoreManagementController> {
  final InventoryEntry entry;

  const _InventoryItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isEntry = entry.type == InventoryType.entry;

    return InkWell(
      onTap: () => controller.viewInventoryDetails(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: context.borderRadius(BorderRadiusType.small),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isEntry
                    ? AppThemeSystem.successColor.withValues(alpha: 0.1)
                    : AppThemeSystem.errorColor.withValues(alpha: 0.1),
                borderRadius: context.borderRadius(BorderRadiusType.small),
              ),
              child: Icon(
                isEntry ? Icons.add : Icons.remove,
                color: isEntry
                    ? AppThemeSystem.successColor
                    : AppThemeSystem.errorColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.productName,
                    style: context.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd/MM/yyyy').format(entry.date),
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isEntry ? '+' : '-'}${entry.quantity}',
              style: context.body1.copyWith(
                color: isEntry
                    ? AppThemeSystem.successColor
                    : AppThemeSystem.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'édition de la boutique
class _StoreEditorCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final store = controller.storeInfo.value;
      if (store == null) return const SizedBox.shrink();

      return Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    borderRadius: context.borderRadius(BorderRadiusType.small),
                  ),
                  child: Icon(
                    Icons.storefront,
                    color: AppThemeSystem.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations de la boutique',
                        style: context.h6.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gérez les détails de votre boutique',
                        style: context.caption.copyWith(
                          color: context.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sectionSpacing),
            // Logo avec carte
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.backgroundColor,
                borderRadius: context.borderRadius(BorderRadiusType.small),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: controller.pickLogo,
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppThemeSystem.grey200,
                            borderRadius:
                                context.borderRadius(BorderRadiusType.small),
                            border: Border.all(
                              color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: controller.selectedLogo.value != null
                              ? ClipRRect(
                                  borderRadius:
                                      context.borderRadius(BorderRadiusType.small),
                                  child: Image.file(
                                    controller.selectedLogo.value!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : store.logoUrl != null && store.logoUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius:
                                          context.borderRadius(BorderRadiusType.small),
                                      child: Image.network(
                                        store.logoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.store,
                                            size: 40,
                                            color: AppThemeSystem.primaryColor,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.store,
                                      size: 40,
                                      color: AppThemeSystem.primaryColor,
                                    ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppThemeSystem.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.backgroundColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logo de la boutique',
                          style: context.body2.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tapez pour modifier',
                          style: context.caption.copyWith(
                            color: AppThemeSystem.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.elementSpacing),
            // Informations avec valeurs par défaut si vide
            _InfoRow(
              icon: Icons.store,
              label: 'Nom',
              value: store.name.isNotEmpty ? store.name : 'Non renseigné',
              isEmpty: store.name.isEmpty,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.location_city,
              label: 'Ville',
              value: store.city.isNotEmpty ? store.city : 'Non renseignée',
              isEmpty: store.city.isEmpty,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.home,
              label: 'Adresse',
              value: store.address.isNotEmpty ? store.address : 'Non renseignée',
              isEmpty: store.address.isEmpty,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.phone,
              label: 'Téléphone',
              value: store.phone.isNotEmpty ? store.phone : 'Non renseigné',
              isEmpty: store.phone.isEmpty,
            ),
            SizedBox(height: context.sectionSpacing),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.to(() => const EditStoreView());
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifier les informations'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Ligne d'information
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isEmpty;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: context.borderRadius(BorderRadiusType.small),
        border: Border.all(
          color: isEmpty
              ? AppThemeSystem.warningColor.withValues(alpha: 0.3)
              : context.borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isEmpty
                ? AppThemeSystem.warningColor
                : context.secondaryTextColor,
          ),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: context.body2.copyWith(
              color: context.secondaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: context.body2.copyWith(
                fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                color: isEmpty
                    ? AppThemeSystem.warningColor
                    : context.primaryTextColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Location Request Notification Card
class _LocationRequestNotification extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.hasLocationUpdatePending.value) {
        return const SizedBox.shrink();
      }

      // Get the most recent pending request
      final pendingRequests = controller.locationRequests
          .where((req) => req['status'] == 'pending')
          .toList();

      if (pendingRequests.isEmpty) {
        return const SizedBox.shrink();
      }

      final latestRequest = pendingRequests.first;

      return Container(
        margin: EdgeInsets.only(bottom: context.elementSpacing),
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          color: AppThemeSystem.warningColor.withValues(alpha: 0.1),
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(
            color: AppThemeSystem.warningColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.warningColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.pending_actions,
                    color: AppThemeSystem.warningColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demande de changement de localisation',
                        style: context.body1.copyWith(
                          color: AppThemeSystem.warningColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'En attente de validation',
                        style: context.caption.copyWith(
                          color: AppThemeSystem.warningColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: context.secondaryTextColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nouvelle position demandée',
                          style: context.caption.copyWith(
                            color: context.secondaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 24),
                      Expanded(
                        child: Text(
                          'Lat: ${_formatCoordinate(latestRequest['latitude'])}, '
                          'Lng: ${_formatCoordinate(latestRequest['longitude'])}',
                          style: context.caption.copyWith(
                            color: context.primaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (latestRequest['created_at'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: context.secondaryTextColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Soumis le ${_formatDate(latestRequest['created_at'])}',
                            style: context.caption.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Votre demande sera examinée par un administrateur. Vous serez notifié de la décision.',
              style: context.caption.copyWith(
                color: AppThemeSystem.warningColor,
              ),
            ),
          ],
        ),
      );
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy à HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCoordinate(dynamic value) {
    if (value == null) return '0.0';
    try {
      if (value is double) {
        return value.toStringAsFixed(6);
      } else if (value is int) {
        return value.toDouble().toStringAsFixed(6);
      } else if (value is String) {
        final parsed = double.tryParse(value);
        return parsed?.toStringAsFixed(6) ?? value;
      }
      return value.toString();
    } catch (e) {
      return value.toString();
    }
  }
}
