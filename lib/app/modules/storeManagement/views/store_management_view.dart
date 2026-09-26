import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/store_management_controller.dart';
import '../models/store_models.dart';
import 'edit_store_view.dart';

/// Écran « Ma boutique ».
///
/// Parti pris visuel, aligné sur [AppDesign] : l'accent orange ne sert qu'aux
/// actions, jamais à décorer une surface. Les couleurs vives restantes sont
/// strictement sémantiques (seuil de stockage, entrée/sortie d'inventaire,
/// champ manquant). La hiérarchie est portée par la typographie et les titres
/// de section, pas par des cartes teintées.
class StoreManagementView extends GetView<StoreManagementController> {
  const StoreManagementView({super.key});

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
        leading: const AppBackButton(),
        centerTitle: false,
        title: Text(
          'Ma boutique',
          style: context.h5.copyWith(
            fontWeight: FontWeight.w700,
            color: ds.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ds.textSecondary, size: 20),
            tooltip: 'Actualiser',
            onPressed: controller.loadData,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.storeInfo.value == null) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppDesign.accent),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadData,
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
                    MediaQuery.of(context).viewPadding.bottom + AppDesign.space8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LocationRequestNotification(),
                      _BannerCarousel(),
                      _StoreEditorCard(),
                      SizedBox(height: AppDesign.space8),
                      _StorageCard(),
                      SizedBox(height: AppDesign.space8),
                      _CertificationCard(),
                      SizedBox(height: AppDesign.space8),
                      _AudienceStatsCard(),
                      SizedBox(height: AppDesign.space8),
                      _InventoryCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================================
// COMMUN
// ============================================================================

/// Titre de section. Volontairement discret : le titre de l'écran reste le
/// seul élément typographique dominant.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return Padding(
      padding: EdgeInsets.only(bottom: AppDesign.space3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.subtitle1.copyWith(
                fontWeight: FontWeight.w700,
                color: ds.textPrimary,
              ),
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppDesign.accent,
                padding: EdgeInsets.symmetric(horizontal: AppDesign.space2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                action!,
                style: context.body2.copyWith(
                  color: AppDesign.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte neutre : la surface de base de tout l'écran.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDesign.space5),
      decoration: BoxDecoration(
        color: ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        border: Border.all(color: ds.border),
      ),
      child: child,
    );
  }
}

/// Bouton d'action principal, pleine largeur.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: AppDesign.accent,
      foregroundColor: AppDesign.neutral0,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
    );
    // La couleur est forcée dans le TextStyle : le thème global écrase
    // autrement le foregroundColor et le libellé passe en noir sur l'orange.
    final text = Text(
      label,
      style: context.button.copyWith(
        color: AppDesign.neutral0,
        fontWeight: FontWeight.w600,
      ),
    );

    return SizedBox(
      width: double.infinity,
      height: context.buttonHeight,
      child: ElevatedButton(onPressed: onPressed, style: style, child: text),
    );
  }
}

/// Bouton secondaire, en contour neutre.
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final style = OutlinedButton.styleFrom(
      foregroundColor: ds.textPrimary,
      side: BorderSide(color: ds.borderStrong),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
    );
    final text = Text(
      label,
      style: context.button.copyWith(
        color: ds.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );

    return SizedBox(
      width: double.infinity,
      height: context.buttonHeight,
      child: OutlinedButton(onPressed: onPressed, style: style, child: text),
    );
  }
}

/// Bandeau d'information sémantique (alerte, attente, erreur).
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    required this.background,
    required this.foreground,
    this.title,
  });

  final IconData icon;
  final String message;
  final String? title;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: foreground),
          ),
          SizedBox(width: AppDesign.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: context.body2.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: context.body2.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BANNIÈRES
// ============================================================================

/// Carrousel de bannières promotionnelles.
///
/// Les cartes sont neutres et se distinguent par leur pictogramme : quatre
/// aplats saturés (orange, bleu, vert, violet) faisaient de l'en-tête un
/// nuancier et écrasaient le reste de l'écran.
class _BannerCarousel extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.banners.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: EdgeInsets.only(bottom: AppDesign.space8),
        child: Column(
          children: [
            SizedBox(
              height: 128,
              child: PageView.builder(
                itemCount: controller.banners.length,
                controller: PageController(viewportFraction: 0.94),
                onPageChanged: (index) =>
                    controller.currentBannerIndex.value = index,
                itemBuilder: (context, index) =>
                    _BannerItem(banner: controller.banners[index]),
              ),
            ),
            if (controller.banners.length > 1) ...[
              SizedBox(height: AppDesign.space3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  controller.banners.length,
                  (index) => Obx(() {
                    final isActive =
                        controller.currentBannerIndex.value == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: isActive ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppDesign.accent
                            : context.ds.borderStrong,
                        borderRadius:
                            BorderRadius.circular(AppDesign.radiusPill),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _BannerItem extends StatelessWidget {
  const _BannerItem({required this.banner});

  final PromotionalBanner banner;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDesign.space1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: banner.onTap,
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
          child: Container(
            padding: EdgeInsets.all(AppDesign.space4),
            decoration: BoxDecoration(
              color: ds.surface,
              borderRadius: BorderRadius.circular(AppDesign.radiusLg),
              border: Border.all(color: ds.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ds.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                  ),
                  child: Icon(banner.type.icon, size: 20, color: ds.textSecondary),
                ),
                SizedBox(width: AppDesign.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        banner.title,
                        style: context.body1.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ds.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          banner.description,
                          style: context.caption.copyWith(color: ds.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: AppDesign.space2),
                      Text(
                        banner.actionLabel,
                        style: context.caption.copyWith(
                          color: AppDesign.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: ds.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STOCKAGE
// ============================================================================

class _StorageCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ds = context.ds;
      final storage = controller.storageStats.value;
      if (storage == null) return const SizedBox.shrink();

      final percent = storage.usagePercentage;
      // La jauge n'est vive que lorsqu'elle alerte réellement.
      final gaugeColor = percent > 90
          ? AppDesign.danger
          : percent > 75
              ? AppDesign.warning
              : AppDesign.accent;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('Stockage'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sans forfait actif il n'y a aucun quota : afficher une jauge
                // à 0 sur 0 n'aurait aucun sens, on explique l'état.
                if (!storage.hasQuota) ...[
                  Text(
                    'Aucun espace alloué',
                    style: context.subtitle1.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ds.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Souscrivez à un forfait pour publier les photos et vidéos '
                    'de vos produits.',
                    style: context.body2.copyWith(color: ds.textSecondary),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          'Espace utilisé',
                          style: context.body2.copyWith(color: ds.textSecondary),
                        ),
                      ),
                      Text(
                        '${storage.usedSpaceGB.toStringAsFixed(1)} Go',
                        style: context.body2.copyWith(
                          color: ds.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' / ${storage.totalSpaceGB.toStringAsFixed(1)} Go',
                        style: context.body2.copyWith(color: ds.textTertiary),
                      ),
                    ],
                  ),
                  SizedBox(height: AppDesign.space2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                    child: LinearProgressIndicator(
                      value: (percent / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: ds.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                    ),
                  ),
                  SizedBox(height: AppDesign.space2),
                  Text(
                    '${percent.toStringAsFixed(0)} % utilisé · '
                    '${storage.totalProducts} produits · ${storage.totalImages} images',
                    style: context.caption.copyWith(color: ds.textTertiary),
                  ),
                ],

                if (storage.isAlmostFull) ...[
                  SizedBox(height: AppDesign.space4),
                  _Notice(
                    icon: Icons.warning_amber_rounded,
                    message: 'Votre espace de stockage est presque plein.',
                    background: AppDesign.warningSubtle,
                    foreground: AppDesign.warningText,
                  ),
                ],

                SizedBox(height: AppDesign.space4),
                _PrimaryButton(
                  label: storage.hasQuota
                      ? "Augmenter l'espace"
                      : 'Voir les forfaits',
                  onPressed: controller.upgradeStorage,
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

// ============================================================================
// CERTIFICATION
// ============================================================================

class _CertificationCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cert = controller.certification.value;
      if (cert == null) return const SizedBox.shrink();

      return cert.isCertified
          ? _buildCertified(context, cert)
          : _buildOffer(context);
    });
  }

  /// Boutique certifiée : l'état se lit à une pastille, pas à une carte teintée
  /// bordée et ombrée en couleur.
  Widget _buildCertified(BuildContext context, dynamic cert) {
    final ds = context.ds;
    final daysRemaining = cert.daysUntilExpiry ?? 0;
    final isExpiringSoon = cert.isExpiringSoon;
    final isExpired = cert.isExpired;

    final Color badgeBackground;
    final Color badgeForeground;
    final String badgeLabel;
    if (isExpired) {
      badgeBackground = AppDesign.dangerSubtle;
      badgeForeground = AppDesign.dangerText;
      badgeLabel = 'Expirée';
    } else if (isExpiringSoon) {
      badgeBackground = AppDesign.warningSubtle;
      badgeForeground = AppDesign.warningText;
      badgeLabel = 'Expire bientôt';
    } else {
      badgeBackground = AppDesign.successSubtle;
      badgeForeground = AppDesign.successText;
      badgeLabel = 'Active';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Certification'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_outlined, size: 20, color: AppDesign.info),
                  SizedBox(width: AppDesign.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Boutique certifiée',
                          style: context.subtitle1.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ds.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Badge de confiance affiché sur votre vitrine',
                          style: context.caption.copyWith(color: ds.textSecondary),
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
                      color: badgeBackground,
                      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                    ),
                    child: Text(
                      badgeLabel,
                      style: context.caption.copyWith(
                        color: badgeForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppDesign.space4),
              Divider(height: 1, color: ds.border),
              SizedBox(height: AppDesign.space4),

              Row(
                children: [
                  Icon(Icons.event_outlined, size: 16, color: ds.textTertiary),
                  SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Text(
                      isExpired
                          ? 'Certification expirée'
                          : daysRemaining == 1
                              ? 'Expire demain'
                              : 'Expire dans $daysRemaining jours',
                      style: context.body2.copyWith(color: ds.textSecondary),
                    ),
                  ),
                ],
              ),

              if (isExpiringSoon || isExpired) ...[
                SizedBox(height: AppDesign.space4),
                _PrimaryButton(
                  label: 'Renouveler la certification',
                  onPressed: controller.requestCertification,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Boutique non certifiée : proposition sobre, l'accent reste sur le bouton.
  Widget _buildOffer(BuildContext context) {
    final ds = context.ds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Certification'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Devenez une boutique certifiée',
                style: context.subtitle1.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ds.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Gagnez la confiance de vos clients.',
                style: context.body2.copyWith(color: ds.textSecondary),
              ),
              SizedBox(height: AppDesign.space4),
              const _CertificationBenefit(text: 'Visibilité accrue sur vos produits'),
              SizedBox(height: AppDesign.space3),
              const _CertificationBenefit(text: 'Badge de confiance sur votre vitrine'),
              SizedBox(height: AppDesign.space3),
              const _CertificationBenefit(
                  text: 'Priorité dans les résultats de recherche'),
              SizedBox(height: AppDesign.space5),
              _PrimaryButton(
                label: 'Demander la certification',
                onPressed: controller.requestCertification,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CertificationBenefit extends StatelessWidget {
  const _CertificationBenefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.check_rounded, size: 16, color: ds.textTertiary),
        ),
        SizedBox(width: AppDesign.space2),
        Expanded(
          child: Text(
            text,
            style: context.body2.copyWith(color: ds.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// AUDIENCE
// ============================================================================

class _AudienceStatsCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stats = controller.audienceStats.value;
      if (stats == null) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            'Audience',
            action: 'Voir le détail',
            onAction: controller.openStatistics,
          ),
          _Card(
            child: Column(
              children: [
                // Une seule teinte pour les quatre chiffres : l'ancienne version
                // attribuait bleu, orange, vert et jaune à des mesures de même
                // nature, ce qui suggérait une hiérarchie qui n'existe pas.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Visites',
                          value: NumberFormat('#,###').format(stats.totalViews),
                        ),
                      ),
                      _StatDivider(),
                      Expanded(
                        child: _StatBox(
                          label: 'Produits vus',
                          value: NumberFormat('#,###').format(stats.totalClicks),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppDesign.space4),
                  child: Divider(height: 1, color: context.ds.border),
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Commandes',
                          value: stats.totalOrders.toString(),
                        ),
                      ),
                      _StatDivider(),
                      Expanded(
                        child: _StatBox(
                          label: 'Conversion',
                          value: '${stats.conversionRate.toStringAsFixed(1)} %',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppDesign.space5),
                _SecondaryButton(
                  label: 'Booster mes produits',
                  onPressed: controller.boostProducts,
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDesign.space4),
        child: VerticalDivider(width: 1, color: context.ds.border),
      );
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: context.h4.copyWith(
              color: ds.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        SizedBox(height: AppDesign.space1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.caption.copyWith(color: ds.textSecondary),
        ),
      ],
    );
  }
}

// ============================================================================
// INVENTAIRE
// ============================================================================

class _InventoryCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() {
          final entries = controller.filteredInventory;
          return _SectionHeader(
            'Inventaire',
            action: entries.length > 3 ? 'Voir tout (${entries.length})' : null,
            onAction: entries.length > 3 ? controller.viewAllInventory : null,
          );
        }),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Wrap(
                    spacing: AppDesign.space2,
                    runSpacing: AppDesign.space2,
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        isSelected:
                            controller.selectedInventoryFilter.value == null,
                        onTap: () =>
                            controller.selectedInventoryFilter.value = null,
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
              SizedBox(height: AppDesign.space4),
              Obx(() {
                final entries = controller.filteredInventory;
                if (entries.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: AppDesign.space6),
                    child: Center(
                      child: Text(
                        "Aucun mouvement d'inventaire.",
                        style: context.body2
                            .copyWith(color: context.ds.textSecondary),
                      ),
                    ),
                  );
                }

                final visible = entries.take(3).toList();
                return Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: context.ds.border),
                      _InventoryItem(entry: visible[i]),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: AppDesign.space3,
            vertical: AppDesign.space2,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppDesign.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            border: Border.all(
              color: isSelected ? AppDesign.accent : ds.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: context.caption.copyWith(
              color: isSelected ? AppDesign.accentText : ds.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryItem extends GetView<StoreManagementController> {
  const _InventoryItem({required this.entry});

  final InventoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final isEntry = entry.type == InventoryType.entry;
    // Le sens du mouvement est une information, pas une décoration : il tient
    // dans le signe et une teinte sourde sur la quantité.
    final color = isEntry ? AppDesign.successText : AppDesign.dangerText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.viewInventoryDetails(entry),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppDesign.space3),
          child: Row(
            children: [
              Icon(
                isEntry
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 16,
                color: ds.textTertiary,
              ),
              SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.productName,
                      style: context.body2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ds.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMM yyyy', 'fr_FR').format(entry.date),
                      style: context.caption.copyWith(color: ds.textTertiary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppDesign.space2),
              Text(
                '${isEntry ? '+' : '−'}${entry.quantity}',
                style: context.body1.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// INFORMATIONS DE LA BOUTIQUE
// ============================================================================

class _StoreEditorCard extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ds = context.ds;
      final store = controller.storeInfo.value;
      if (store == null) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            'Informations',
            action: 'Modifier',
            onAction: () => Get.to(() => const EditStoreView()),
          ),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StoreLogo(store: store),
                    SizedBox(width: AppDesign.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.name.isNotEmpty ? store.name : 'Sans nom',
                            style: context.subtitle1.copyWith(
                              fontWeight: FontWeight.w700,
                              color: ds.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Touchez le logo pour le remplacer',
                            style: context.caption.copyWith(color: ds.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppDesign.space4),
                Divider(height: 1, color: ds.border),
                SizedBox(height: AppDesign.space2),

                _InfoRow(
                  label: 'Localisation',
                  value: store.city,
                  placeholder: 'Non renseignée',
                ),
                _InfoRow(
                  label: 'Adresse',
                  value: store.address,
                  placeholder: 'Non renseignée',
                ),
                _InfoRow(
                  label: 'Téléphone',
                  value: store.phone,
                  placeholder: 'Non renseigné',
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _StoreLogo extends GetView<StoreManagementController> {
  const _StoreLogo({required this.store});

  final dynamic store;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final radius = BorderRadius.circular(AppDesign.radiusMd);

    return GestureDetector(
      onTap: controller.changeLogo,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ds.surfaceMuted,
              borderRadius: radius,
              border: Border.all(color: ds.border),
            ),
            child: Obx(() {
              if (controller.isUploadingLogo.value) {
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppDesign.accent,
                      ),
                    ),
                  ),
                );
              }
              if (store.logoUrl != null && store.logoUrl!.isNotEmpty) {
                return ClipRRect(
                  borderRadius: radius,
                  child: Image.network(
                    store.logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.storefront_outlined,
                      size: 26,
                      color: ds.textTertiary,
                    ),
                  ),
                );
              }
              return Icon(Icons.storefront_outlined,
                  size: 26, color: ds.textTertiary);
            }),
          ),
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppDesign.accent,
                shape: BoxShape.circle,
                border: Border.all(color: ds.surface, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: AppDesign.neutral0, size: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne d'information. Un champ vide est signalé par son libellé en italique,
/// sans encadrer toute la ligne d'une bordure d'alerte.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.placeholder,
  });

  final String label;
  final String value;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final isEmpty = value.isEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDesign.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: context.body2.copyWith(color: ds.textSecondary),
            ),
          ),
          SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(
              isEmpty ? placeholder : value,
              textAlign: TextAlign.right,
              style: context.body2.copyWith(
                color: isEmpty ? ds.textTertiary : ds.textPrimary,
                fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
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

// ============================================================================
// DEMANDE DE LOCALISATION
// ============================================================================

class _LocationRequestNotification extends GetView<StoreManagementController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.hasLocationUpdatePending.value) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: EdgeInsets.only(bottom: AppDesign.space6),
        child: _Notice(
          icon: Icons.schedule_outlined,
          title: 'Changement de localisation en attente',
          message:
              'Votre demande sera examinée par un administrateur. Vous serez notifié de la décision.',
          background: AppDesign.warningSubtle,
          foreground: AppDesign.warningText,
        ),
      );
    });
  }
}
