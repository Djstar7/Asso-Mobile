import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/media_helper.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/vendor_dashboard_controller.dart';
import '../../orderManagement/views/order_management_view.dart';
import '../../orderManagement/bindings/order_management_binding.dart';
import '../../storeManagement/views/store_management_view.dart';
import '../../storeManagement/bindings/store_management_binding.dart';
import '../../wallet/views/wallet_view.dart';
import '../../wallet/bindings/wallet_binding.dart';
import '../../../core/widgets/currency_switcher.dart';
import '../../../core/widgets/offline_badge.dart';
import '../../../data/models/pending_product.dart';
import '../../../data/services/offline_product_sync_service.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../routes/app_pages.dart';
import 'vendor_dashboard_shimmer.dart';

/// Tableau de bord vendeur.
///
/// Parti pris visuel, aligné sur [AppDesign] : l'accent orange ne sert qu'aux
/// actions, jamais à décorer une surface. Les couleurs vives restantes sont
/// strictement sémantiques (état de vérification, seuil de stockage, urgence).
/// La hiérarchie est portée par la typographie et l'espacement.
class VendorDashboardView extends GetView<VendorDashboardController> {
  const VendorDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: ds.canvas,
        appBar: AppBar(
          backgroundColor: ds.canvas,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          // Sans écran derrière, le retour ramène à l'accueil.
          leading: const AppBackButton(),
          centerTitle: false,
          title: Text(
            'vendor_dashboard.title'.tr,
            style: context.h5.copyWith(
              fontWeight: FontWeight.w700,
              color: ds.textPrimary,
            ),
          ),
          actions: [
            const OfflineBadge(),
            // Pilote l'affichage de tout l'espace vendeur : ventes,
            // statistiques, prix. Sert aussi de devise par défaut à la
            // création d'un produit.
            const CurrencySwitcher(),
            SizedBox(width: ds.gutter),
          ],
        ),
        body: SafeArea(
          bottom: true,
          child: Obx(() {
            if (controller.isLoading.value) {
              return const VendorDashboardShimmer();
            }

            return RefreshIndicator(
              onRefresh: () => controller.refreshData(),
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
                          _buildShopHeader(context),
                          _buildOfflineSection(context),
                          SizedBox(height: AppDesign.space6),
                          _buildStatsSection(context),
                          SizedBox(height: AppDesign.space8),
                          _buildPackageSection(context),
                          SizedBox(height: AppDesign.space8),
                          _buildQuickActions(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ==========================================================================
  // EN-TÊTE BOUTIQUE
  // ==========================================================================

  Widget _buildShopHeader(BuildContext context) {
    final ds = context.ds;
    final logoSize = context.deviceType == DeviceType.mobile ? 56.0 : 72.0;

    return Container(
      padding: EdgeInsets.all(AppDesign.space4),
      decoration: BoxDecoration(
        color: ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        border: Border.all(color: ds.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildShopLogo(context, logoSize),
          SizedBox(width: AppDesign.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Obx(() => Text(
                            controller.shopName.value,
                            style: context.h6.copyWith(
                              fontWeight: FontWeight.w700,
                              color: ds.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )),
                    ),
                    // Certification : un pictogramme suffit, sans halo coloré.
                    Obx(() => controller.isCertified.value
                        ? Padding(
                            padding: EdgeInsets.only(left: AppDesign.space1),
                            child: Icon(Icons.verified_rounded,
                                color: AppDesign.info, size: 16),
                          )
                        : const SizedBox.shrink()),
                  ],
                ),
                Obx(() {
                  if (controller.shopLocation.value.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: AppDesign.space1),
                    child: Row(
                      children: [
                        Icon(Icons.place_outlined, size: 13, color: ds.textTertiary),
                        SizedBox(width: AppDesign.space1),
                        Flexible(
                          child: Text(
                            controller.shopLocation.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.caption.copyWith(color: ds.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: AppDesign.space2),
                Obx(() => _buildVerificationBadge(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopLogo(BuildContext context, double size) {
    final ds = context.ds;
    final radius = BorderRadius.circular(AppDesign.radiusMd);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ds.surfaceMuted,
        borderRadius: radius,
        border: Border.all(color: ds.border),
      ),
      child: Obx(() {
        if (controller.shopLogoUrl.value != null &&
            controller.shopLogoUrl.value!.isNotEmpty) {
          return ClipRRect(
            borderRadius: radius,
            child: Image.network(
              controller.shopLogoUrl.value!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.storefront_outlined, color: ds.textTertiary, size: size * 0.4),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ds.textTertiary,
                    ),
                  ),
                );
              },
            ),
          );
        }
        if (controller.shopLogo.value != null) {
          return ClipRRect(
            borderRadius: radius,
            child: MediaHelper.buildImagePreview(
              controller.shopLogo.value!,
              fit: BoxFit.cover,
            ),
          );
        }
        return Icon(Icons.storefront_outlined,
            color: ds.textTertiary, size: size * 0.4);
      }),
    );
  }

  /// Pastille d'état de vérification.
  ///
  /// Variantes `*Subtle` / `*Text` plutôt qu'un aplat saturé : l'information
  /// reste lisible sans dominer l'écran.
  Widget _buildVerificationBadge(BuildContext context) {
    final Color background;
    final Color foreground;
    final IconData badgeIcon;
    final String statusText;

    switch (controller.verificationStatus.value) {
      case 'approved':
      case 'verified':
      case 'active':
        background = AppDesign.successSubtle;
        foreground = AppDesign.successText;
        badgeIcon = Icons.check_circle_outline_rounded;
        statusText = 'vendor_dashboard.verification.verified'.tr;
        break;
      case 'rejected':
        background = AppDesign.dangerSubtle;
        foreground = AppDesign.dangerText;
        badgeIcon = Icons.cancel_outlined;
        statusText = 'vendor_dashboard.verification.rejected'.tr;
        break;
      case 'pending':
      case 'inactive':
      default:
        background = AppDesign.warningSubtle;
        foreground = AppDesign.warningText;
        badgeIcon = Icons.schedule_outlined;
        statusText = 'vendor_dashboard.verification.pending'.tr;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesign.space2,
        vertical: AppDesign.space1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: foreground),
          SizedBox(width: AppDesign.space1),
          Flexible(
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.caption.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STATISTIQUES
  // ==========================================================================

  /// Les chiffres sont hiérarchisés : le chiffre d'affaires et les commandes
  /// occupent une carte pleine largeur, le reste passe en grille secondaire.
  /// L'ancienne grille de six cartes identiques ne disait pas où regarder.
  Widget _buildStatsSection(BuildContext context) {
    final formatter = NumberFormat('#,###');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'vendor_dashboard.stats.activity'.tr,
          action: 'vendor_dashboard.stats.see_details'.tr,
          onAction: controller.navigateToStatistics,
        ),
        SizedBox(height: AppDesign.space3),

        // Chiffre d'affaires : la donnée maîtresse de l'écran.
        Obx(() => _buildPrimaryStat(
              context,
              label: 'vendor_dashboard.stats.sales_collected'.tr,
              value: controller.formatPrice(controller.totalSales.value),
              caption: (controller.totalOrders.value > 1
                      ? 'vendor_dashboard.stats.orders_total_plural'
                      : 'vendor_dashboard.stats.orders_total_singular')
                  .trParams({'count': '${controller.totalOrders.value}'}),
              onTap: controller.onlineOnly(
                () => Get.to(() => const WalletView(), binding: WalletBinding()),
              ),
            )),

        SizedBox(height: AppDesign.space3),

        // Indicateurs secondaires.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Obx(() => _buildStatCard(
                      context,
                      icon: Icons.storefront_outlined,
                      label: 'vendor_dashboard.stats.shop_visits'.tr,
                      value: formatter.format(controller.totalVisits.value),
                      caption: 'vendor_dashboard.stats.last_7_days'.trParams({'count': formatter.format(controller.visitsLast7Days.value)}),
                      onTap: controller.navigateToStatistics,
                    )),
              ),
              SizedBox(width: AppDesign.space3),
              Expanded(
                child: Obx(() => _buildStatCard(
                      context,
                      icon: Icons.visibility_outlined,
                      label: 'vendor_dashboard.stats.product_views'.tr,
                      value: formatter.format(controller.totalProductViews.value),
                      onTap: controller.navigateToStatistics,
                    )),
              ),
            ],
          ),
        ),
        SizedBox(height: AppDesign.space3),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Obx(() => _buildStatCard(
                      context,
                      icon: Icons.inventory_2_outlined,
                      label: 'vendor_dashboard.stats.products_online'.tr,
                      value: '${controller.totalProducts.value}',
                      onTap: controller.navigateToProductManagement,
                    )),
              ),
              SizedBox(width: AppDesign.space3),
              Expanded(
                child: Obx(() => _buildStatCard(
                      context,
                      icon: Icons.star_outline_rounded,
                      label: 'vendor_dashboard.stats.average_rating'.tr,
                      value: controller.rating.value > 0
                          ? controller.rating.value.toStringAsFixed(1)
                          : '—',
                    )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Carte de statistique principale, pleine largeur.
  Widget _buildPrimaryStat(
    BuildContext context, {
    required String label,
    required String value,
    required String caption,
    VoidCallback? onTap,
  }) {
    final ds = context.ds;

    return _Tappable(
      onTap: onTap,
      borderRadius: AppDesign.radiusLg,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppDesign.space5),
        decoration: BoxDecoration(
          color: ds.surface,
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
          border: Border.all(color: ds.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.body2.copyWith(color: ds.textSecondary),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, size: 18, color: ds.textTertiary),
              ],
            ),
            SizedBox(height: AppDesign.space2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: context.h2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ds.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
            SizedBox(height: AppDesign.space1),
            Text(
              caption,
              style: context.caption.copyWith(color: ds.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  /// Carte de statistique secondaire.
  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? caption,
    VoidCallback? onTap,
  }) {
    final ds = context.ds;

    return _Tappable(
      onTap: onTap,
      borderRadius: AppDesign.radiusLg,
      child: Container(
        padding: EdgeInsets.all(AppDesign.space4),
        decoration: BoxDecoration(
          color: ds.surface,
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
          border: Border.all(color: ds.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: ds.textTertiary),
            SizedBox(height: AppDesign.space3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: context.h4.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ds.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
            SizedBox(height: AppDesign.space1),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.caption.copyWith(color: ds.textSecondary),
            ),
            if (caption != null) ...[
              SizedBox(height: 2),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.caption.copyWith(color: ds.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // FORFAIT
  // ==========================================================================

  Widget _buildPackageSection(BuildContext context) {
    return Obx(() {
      if (!controller.hasPackage.value) {
        return _buildNoPackageCard(context);
      }
      return _buildActivePackageCard(context);
    });
  }

  Widget _buildNoPackageCard(BuildContext context) {
    final ds = context.ds;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDesign.space5),
      decoration: BoxDecoration(
        color: ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        border: Border.all(color: ds.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppDesign.warningText),
              SizedBox(width: AppDesign.space2),
              Expanded(
                child: Text(
                  'vendor_dashboard.package.none_title'.tr,
                  style: context.subtitle1.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ds.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDesign.space2),
          Text(
            'vendor_dashboard.package.none_message'.tr,
            style: context.body2.copyWith(color: ds.textSecondary),
          ),
          SizedBox(height: AppDesign.space4),
          SizedBox(
            width: double.infinity,
            height: context.buttonHeight,
            child: ElevatedButton(
              onPressed: controller.onlineOnly(() => Get.toNamed('/package-subscription')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesign.accent,
                foregroundColor: AppDesign.neutral0,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesign.radiusMd),
                ),
              ),
              child: Text(
                'vendor_dashboard.package.see_plans'.tr,
                style: context.button.copyWith(
                  color: AppDesign.neutral0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePackageCard(BuildContext context) {
    final ds = context.ds;
    final packageData = controller.packageInfo.value;
    final packageName = packageData?['package']?['name'] ?? 'vendor_dashboard.package.default_name'.tr;
    final packagePriceRaw =
        double.tryParse(packageData?['package']?['price']?.toString() ?? '0') ?? 0.0;
    final packagePrice = packagePriceRaw > 0
        ? controller.formatPrice(packagePriceRaw)
        : (packageData?['package']?['formatted_price'] ?? '');
    final expiresAt = controller.packageExpiresAt.value;
    final percentUsed = controller.storagePercentageUsed.value;
    final daysRemaining = controller.daysRemaining.value;

    // Le seuil colore la jauge : elle n'est vive que lorsqu'elle alerte.
    final gaugeColor = percentUsed > 90
        ? AppDesign.danger
        : percentUsed > 75
            ? AppDesign.warning
            : AppDesign.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'vendor_dashboard.package.my_plan'.tr,
          action: 'vendor_dashboard.package.change'.tr,
          onAction: controller.onlineOnly(() => Get.toNamed('/package-subscription')),
        ),
        SizedBox(height: AppDesign.space3),
        Container(
          padding: EdgeInsets.all(AppDesign.space5),
          decoration: BoxDecoration(
            color: ds.surface,
            borderRadius: BorderRadius.circular(AppDesign.radiusLg),
            border: Border.all(color: ds.border),
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
                          packageName,
                          style: context.subtitle1.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ds.textPrimary,
                          ),
                        ),
                        if (packagePrice.toString().isNotEmpty) ...[
                          SizedBox(height: 2),
                          Text(
                            packagePrice,
                            style: context.body2.copyWith(color: ds.textSecondary),
                          ),
                        ],
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
                      'vendor_dashboard.package.active'.tr,
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
                      'vendor_dashboard.package.storage'.tr,
                      style: context.body2.copyWith(color: ds.textSecondary),
                    ),
                  ),
                  Text(
                    'vendor_dashboard.package.storage_used'.trParams({'used': controller.storageUsedMb.value.toStringAsFixed(1)}),
                    style: context.body2.copyWith(
                      color: ds.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'vendor_dashboard.package.storage_total'.trParams({'total': controller.storageTotalMb.value.toStringAsFixed(0)}),
                    style: context.body2.copyWith(color: ds.textTertiary),
                  ),
                ],
              ),
              SizedBox(height: AppDesign.space2),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                child: LinearProgressIndicator(
                  value: (percentUsed / 100).clamp(0.0, 1.0),
                  backgroundColor: ds.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                  minHeight: 6,
                ),
              ),
              SizedBox(height: AppDesign.space2),
              Text(
                'vendor_dashboard.package.storage_usage'.trParams({
                  'percent': percentUsed.toStringAsFixed(0),
                  'remaining': controller.storageRemainingMb.value.toStringAsFixed(1),
                }),
                style: context.caption.copyWith(color: ds.textTertiary),
              ),

              SizedBox(height: AppDesign.space4),
              Divider(height: 1, color: ds.border),
              SizedBox(height: AppDesign.space4),

              // Échéance.
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 16, color: ds.textTertiary),
                  SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Text(
                      expiresAt != null
                          ? 'vendor_dashboard.package.valid_until'.trParams({'date': DateFormat('d MMMM yyyy').format(DateTime.parse(expiresAt))})
                          : 'vendor_dashboard.package.unknown_expiry'.tr,
                      style: context.body2.copyWith(color: ds.textSecondary),
                    ),
                  ),
                ],
              ),

              // L'alerte d'expiration n'apparaît que lorsqu'elle est utile.
              if (daysRemaining <= 7) ...[
                SizedBox(height: AppDesign.space3),
                Container(
                  padding: EdgeInsets.all(AppDesign.space3),
                  decoration: BoxDecoration(
                    color: daysRemaining <= 3
                        ? AppDesign.dangerSubtle
                        : AppDesign.warningSubtle,
                    borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: daysRemaining <= 3
                            ? AppDesign.dangerText
                            : AppDesign.warningText,
                      ),
                      SizedBox(width: AppDesign.space2),
                      Expanded(
                        child: Text(
                          daysRemaining <= 0
                              ? 'vendor_dashboard.package.expired'.tr
                              : (daysRemaining > 1
                                      ? 'vendor_dashboard.package.expires_in_days'
                                      : 'vendor_dashboard.package.expires_in_day')
                                  .trParams({'days': '$daysRemaining'}),
                          style: context.body2.copyWith(
                            color: daysRemaining <= 3
                                ? AppDesign.dangerText
                                : AppDesign.warningText,
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
        ),
      ],
    );
  }

  // ==========================================================================
  // ACTIONS RAPIDES
  // ==========================================================================

  /// Les raccourcis sont regroupés dans une seule carte à lignes séparées
  /// plutôt qu'en cinq blocs bordés : moins de bordures, un bloc plus calme.
  Widget _buildQuickActions(BuildContext context) {
    final ds = context.ds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'vendor_dashboard.actions.management'.tr),
        SizedBox(height: AppDesign.space3),
        Container(
          decoration: BoxDecoration(
            color: ds.surface,
            borderRadius: BorderRadius.circular(AppDesign.radiusLg),
            border: Border.all(color: ds.border),
          ),
          child: Column(
            children: [
              Obx(() {
                // Hors ligne, la liste des produits est inaccessible : seul
                // l'ajout reste ouvert.
                if (controller.totalProducts.value == 0 ||
                    !controller.isOnline.value) {
                  return _buildActionRow(
                    context,
                    icon: Icons.add_box_outlined,
                    title: 'vendor_dashboard.actions.add_product'.tr,
                    subtitle: !controller.isOnline.value
                        ? 'vendor_dashboard.actions.add_product_offline'.tr
                        : 'vendor_dashboard.actions.add_first_product'.tr,
                    onTap: controller.navigateToAddProduct,
                    isFirst: true,
                  );
                }
                return _buildActionRow(
                  context,
                  icon: Icons.inventory_2_outlined,
                  title: 'vendor_dashboard.actions.my_products'.tr,
                  subtitle: 'vendor_dashboard.actions.my_products_subtitle'.tr,
                  badge: controller.totalProducts.value,
                  onTap: controller.navigateToProductManagement,
                  isFirst: true,
                );
              }),
              _buildRowDivider(context),
              // Asso Ads : mettre un article en avant dans le fil et la
              // recherche. Quand une campagne tourne, la ligne rend compte de
              // la portée déjà délivrée — le vendeur a payé, il doit voir où
              // en est son achat sans avoir à ouvrir l'écran.
              Obx(() {
                final running = controller.runningBoosts.value;
                final served = controller.boostImpressionsServed.value;
                final quota = controller.boostImpressionsQuota.value;

                return _buildActionRow(
                  context,
                  icon: Icons.campaign_outlined,
                  title: running > 0
                      ? 'vendor_dashboard.actions.boost_running'.tr
                      : 'vendor_dashboard.actions.boost_item'.tr,
                  subtitle: running > 0
                      ? 'vendor_dashboard.actions.boost_reach'.trParams({
                          'served': _compact(served),
                          'quota': _compact(quota),
                        })
                      : 'vendor_dashboard.actions.boost_subtitle'.tr,
                  badge: running > 0 ? running : null,
                  onTap: controller.onlineOnly(() async {
                    await Get.toNamed(Routes.BOOST);
                    await controller.refreshData();
                  }),
                );
              }),
              _buildRowDivider(context),
              Obx(() => _buildActionRow(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: 'vendor_dashboard.actions.orders'.tr,
                    subtitle: controller.pendingOrders.value > 0
                        ? 'vendor_dashboard.actions.orders_pending'.trParams({'count': '${controller.pendingOrders.value}'})
                        : 'vendor_dashboard.actions.orders_subtitle'.tr,
                    badge: controller.pendingOrders.value,
                    isUrgent: true,
                    onTap: controller.onlineOnly(() async {
                      await Get.to(
                        () => const OrderManagementView(),
                        binding: OrderManagementBinding(),
                      );
                      await controller.refreshData();
                    }),
                  )),
              _buildRowDivider(context),
              _buildActionRow(
                context,
                icon: Icons.storefront_outlined,
                title: 'vendor_dashboard.my_shop'.tr,
                subtitle: 'vendor_dashboard.actions.my_shop_subtitle'.tr,
                onTap: controller.onlineOnly(() async {
                  await Get.to(
                    () => const StoreManagementView(),
                    binding: StoreManagementBinding(),
                  );
                  // Le nom de la boutique affiché ici vient de ce tableau de
                  // bord : sans relecture, une modification semblait perdue.
                  await controller.refreshData();
                }),
              ),
              _buildRowDivider(context),
              _buildActionRow(
                context,
                icon: Icons.account_balance_wallet_outlined,
                title: 'vendor_dashboard.actions.wallet'.tr,
                subtitle: 'vendor_dashboard.actions.wallet_subtitle'.tr,
                onTap: controller.onlineOnly(() => Get.toNamed('/wallet')),
              ),
              _buildRowDivider(context),
              _buildActionRow(
                context,
                icon: Icons.account_balance_outlined,
                title: 'vendor_dashboard.actions.payout_account'.tr,
                subtitle: 'vendor_dashboard.actions.payout_account_subtitle'.tr,
                onTap: controller.onlineOnly(() => Get.toNamed('/stripe-connect')),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Nombre lisible d'un coup d'œil : « 1 200 » plutôt que « 1200 ».
  static String _compact(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }

    return buffer.toString();
  }

  Widget _buildRowDivider(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: AppDesign.space4 + 20 + AppDesign.space3),
        child: Divider(height: 1, color: context.ds.border),
      );

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badge,

    /// Colore le compteur : réservé à ce qui demande une action.
    bool isUrgent = false,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final ds = context.ds;
    final radius = BorderRadius.vertical(
      top: Radius.circular(isFirst ? AppDesign.radiusLg : 0),
      bottom: Radius.circular(isLast ? AppDesign.radiusLg : 0),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesign.space4,
            vertical: AppDesign.space4,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: ds.textSecondary),
              SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.body1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ds.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.caption.copyWith(color: ds.textTertiary),
                    ),
                  ],
                ),
              ),
              // Compteur masqué à zéro : un « 0 » signalerait une urgence
              // là où il n'y a rien à traiter.
              if (badge != null && badge > 0) ...[
                SizedBox(width: AppDesign.space2),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDesign.space2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isUrgent ? AppDesign.dangerSubtle : ds.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                  ),
                  constraints: const BoxConstraints(minWidth: 24),
                  child: Text(
                    badge > 99 ? '99+' : badge.toString(),
                    textAlign: TextAlign.center,
                    style: context.caption.copyWith(
                      color: isUrgent ? AppDesign.dangerText : ds.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              SizedBox(width: AppDesign.space1),
              Icon(Icons.chevron_right_rounded, size: 18, color: ds.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // MODE HORS LIGNE
  // ==========================================================================

  /// Bandeau hors ligne et produits en attente d'envoi. Rien en ligne quand
  /// la file est vide.
  Widget _buildOfflineSection(BuildContext context) {
    return Obx(() {
      final offline = !controller.isOnline.value;
      final sync = controller.offlineSync;
      final pending = sync?.pending.toList() ?? const <PendingProduct>[];

      if (!offline && pending.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: EdgeInsets.only(top: AppDesign.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offline) _buildOfflineNotice(context),
            if (offline && pending.isNotEmpty)
              SizedBox(height: AppDesign.space3),
            if (pending.isNotEmpty) _buildPendingCard(context, pending),
          ],
        ),
      );
    });
  }

  Widget _buildOfflineNotice(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(
        color: AppDesign.warningSubtle,
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: AppDesign.warningText),
          SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(
              'vendor_dashboard.offline.notice'.tr,
              style: context.caption.copyWith(color: AppDesign.warningText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(BuildContext context, List<PendingProduct> pending) {
    final ds = context.ds;
    final sync = controller.offlineSync!;
    final failed = pending.where((item) => item.isFailed).length;
    final waiting = pending.length - failed;

    final String subtitle;
    if (sync.isSyncing.value) {
      subtitle = 'vendor_dashboard.pending.sending'.tr;
    } else if (failed > 0) {
      subtitle = failed == 1
          ? 'vendor_dashboard.pending.rejected_one'.tr
          : 'vendor_dashboard.pending.rejected_many'.trParams({'count': '$failed'});
    } else if (!controller.isOnline.value) {
      subtitle = 'vendor_dashboard.pending.publish_when_online'.tr;
    } else {
      subtitle = 'vendor_dashboard.pending.publish_imminent'.tr;
    }

    return Material(
      color: ds.surface,
      borderRadius: BorderRadius.circular(AppDesign.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        onTap: () => AppSheet.show(const _PendingProductsSheet()),
        child: Container(
          padding: EdgeInsets.all(AppDesign.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesign.radiusLg),
            border: Border.all(
              color: failed > 0 ? AppDesign.danger : ds.border,
            ),
          ),
          child: Row(
            children: [
              sync.isSyncing.value
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppDesign.accent,
                      ),
                    )
                  : Icon(
                      failed > 0
                          ? Icons.error_outline_rounded
                          : Icons.cloud_upload_outlined,
                      size: 20,
                      color: failed > 0 ? AppDesign.danger : ds.textSecondary,
                    ),
              SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiting + failed == 1
                          ? 'vendor_dashboard.pending.waiting_one'.tr
                          : 'vendor_dashboard.pending.waiting_many'.trParams({'count': '${waiting + failed}'}),
                      style: context.body1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ds.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.caption.copyWith(
                        color: failed > 0 ? AppDesign.dangerText : ds.textTertiary,
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
    );
  }

  // ==========================================================================
  // COMMUN
  // ==========================================================================

  /// Titre de section. Volontairement discret : le titre de l'écran reste le
  /// seul élément typographique dominant.
  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? action,
    VoidCallback? onAction,
  }) {
    final ds = context.ds;

    return Row(
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
              action,
              style: context.body2.copyWith(
                color: AppDesign.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Enveloppe un contenu dans un `InkWell` uniquement lorsqu'il est cliquable,
/// pour éviter une surface d'encre inerte sur les cartes purement indicatives.
class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.child,
    required this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

/// Détail des produits enregistrés hors ligne : état de chacun, motif d'un
/// refus, et de quoi réessayer ou retirer.
class _PendingProductsSheet extends StatelessWidget {
  const _PendingProductsSheet();

  @override
  Widget build(BuildContext context) {
    final sync = OfflineProductSyncService.to;
    final ds = context.ds;

    return AppSheet(
      title: 'vendor_dashboard.pending.sheet_title'.tr,
      subtitle: 'vendor_dashboard.pending.sheet_subtitle'.tr,
      child: Obx(() {
        final items = sync.pending.toList();
        if (items.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: AppDesign.space6),
            child: Text(
              'vendor_dashboard.pending.all_published'.tr,
              textAlign: TextAlign.center,
              style: context.body2.copyWith(color: ds.textSecondary),
            ),
          );
        }
        return Column(
          children: [
            for (final item in items) _buildItem(context, sync, item),
          ],
        );
      }),
    );
  }

  Widget _buildItem(
    BuildContext context,
    OfflineProductSyncService sync,
    PendingProduct item,
  ) {
    final ds = context.ds;
    final thumbnail = item.imagePaths.isNotEmpty ? item.imagePaths.first : null;
    final syncing = item.status == PendingProductStatus.syncing;

    return Padding(
      padding: EdgeInsets.only(bottom: AppDesign.space3),
      child: Container(
        padding: EdgeInsets.all(AppDesign.space3),
        decoration: BoxDecoration(
          color: ds.surface,
          borderRadius: BorderRadius.circular(AppDesign.radiusMd),
          border: Border.all(
            color: item.isFailed ? AppDesign.danger : ds.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              child: SizedBox(
                width: 48,
                height: 48,
                child: thumbnail != null && File(thumbnail).existsSync()
                    ? Image.file(
                        File(thumbnail),
                        fit: BoxFit.cover,
                        cacheWidth: 144,
                      )
                    : ColoredBox(
                        color: ds.surfaceMuted,
                        child: Icon(Icons.image_outlined, color: ds.textTertiary),
                      ),
              ),
            ),
            SizedBox(width: AppDesign.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ds.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    item.isFailed
                        ? (item.error ?? 'vendor_dashboard.pending.rejected_by_server'.tr)
                        : syncing
                            ? 'vendor_dashboard.pending.sending'.tr
                            : 'vendor_dashboard.pending.entered_on'.trParams({
                                'date': DateFormat('dd/MM').format(item.createdAt),
                                'time': DateFormat('HH:mm').format(item.createdAt),
                              }),
                    style: context.caption.copyWith(
                      color: item.isFailed ? AppDesign.dangerText : ds.textTertiary,
                    ),
                  ),
                  if (!syncing)
                    Row(
                      children: [
                        if (item.isFailed)
                          TextButton(
                            onPressed: () => sync.retry(item.id),
                            child: Text('vendor_dashboard.pending.retry'.tr),
                          ),
                        TextButton(
                          onPressed: () => _confirmRemove(context, sync, item),
                          style: TextButton.styleFrom(
                            foregroundColor: AppDesign.danger,
                          ),
                          child: Text('vendor_dashboard.pending.remove'.tr),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    OfflineProductSyncService sync,
    PendingProduct item,
  ) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('vendor_dashboard.pending.remove_title'.tr),
        content: Text(
          'vendor_dashboard.pending.remove_message'.trParams({'name': item.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('vendor_dashboard.cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: AppDesign.danger),
            child: Text('vendor_dashboard.pending.remove'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) await sync.remove(item.id);
  }
}
