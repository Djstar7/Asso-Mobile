import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/vendor_dashboard_controller.dart';
import '../../addProduct/views/add_product_view.dart';
import '../../addProduct/bindings/add_product_binding.dart';
import '../../orderManagement/views/order_management_view.dart';
import '../../orderManagement/bindings/order_management_binding.dart';
import '../../storeManagement/views/store_management_view.dart';
import '../../storeManagement/bindings/store_management_binding.dart';
import '../../wallet/views/wallet_view.dart';
import '../../wallet/bindings/wallet_binding.dart';
import 'vendor_dashboard_shimmer.dart';

class VendorDashboardView extends GetView<VendorDashboardController> {
  const VendorDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Le retour normal avec Get.back() est géré automatiquement
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: context.primaryTextColor,
            ),
            onPressed: () {
              // Vérifier si on peut retourner en arrière
              if (Navigator.of(context).canPop()) {
                Get.back();
              } else {
                // Si pas de page précédente, retourner à Home
                Get.offAllNamed('/home');
              }
            },
          ),
          title: Text(
            'Dashboard Vendeur',
            style: context.h5.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          bottom: true,
          child: Obx(() {
            // Show shimmer loading while fetching data
            if (controller.isLoading.value) {
              return const VendorDashboardShimmer();
            }

            // Show actual content once loaded
            return RefreshIndicator(
              onRefresh: () => controller.refreshData(),
              color: AppThemeSystem.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: context.horizontalPadding,
                  right: context.horizontalPadding,
                  top: context.horizontalPadding,
                  // Padding bottom adaptatif pour la barre de navigation système Android
                  bottom: MediaQuery.of(context).viewPadding.bottom > 0
                      ? MediaQuery.of(context).viewPadding.bottom + context.horizontalPadding
                      : context.horizontalPadding * 1.5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header avec logo de la boutique
                    _buildShopHeader(context),

                    SizedBox(height: context.sectionSpacing),

                    // Statistiques
                    _buildStatsSection(context),

                    SizedBox(height: context.sectionSpacing),

                    // Package Info
                    _buildPackageSection(context),

                    SizedBox(height: context.sectionSpacing),

                    // Actions rapides
                    _buildQuickActions(context),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Header avec logo de la boutique
  Widget _buildShopHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(
          color: context.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Logo de la boutique
          Stack(
            children: [
              Container(
                width: context.deviceType == DeviceType.mobile ? 70 : 90,
                height: context.deviceType == DeviceType.mobile ? 70 : 90,
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: context.borderRadius(BorderRadiusType.medium),
                  border: Border.all(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Obx(() {
                  // First check if we have a logo URL from backend
                  if (controller.shopLogoUrl.value != null &&
                      controller.shopLogoUrl.value!.isNotEmpty) {
                    return ClipRRect(
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                      child: Image.network(
                        controller.shopLogoUrl.value!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to icon if image fails to load
                          return Icon(
                            Icons.store,
                            color: AppThemeSystem.primaryColor,
                            size: 36,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: AppThemeSystem.primaryColor,
                            ),
                          );
                        },
                      ),
                    );
                  }
                  // Check if we have a local file (for upload preview)
                  else if (controller.shopLogo.value != null) {
                    return ClipRRect(
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                      child: Image.file(
                        controller.shopLogo.value!,
                        fit: BoxFit.cover,
                      ),
                    );
                  }
                  // Default icon
                  return Icon(
                    Icons.store,
                    color: AppThemeSystem.primaryColor,
                    size: context.deviceType == DeviceType.mobile ? 36 : 48,
                  );
                }),
              ),
              // Badge de statut de vérification
              Obx(() {
                if (controller.verificationStatus.value == 'approved' ||
                    controller.verificationStatus.value == 'verified' ||
                    controller.verificationStatus.value == 'active') {
                  return Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.successColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  );
                } else if (controller.verificationStatus.value == 'rejected') {
                  return Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.errorColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.cancel_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  );
                }
                // Default: pending/unverified
                return Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.warningColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                );
              }),
            ],
          ),
          SizedBox(width: 16),
          // Informations boutique
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom de la boutique avec badge de certification
                Row(
                  children: [
                    Flexible(
                      child: Obx(() => Text(
                        controller.shopName.value,
                        style: context.h5.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                    ),
                    // Badge de certification bleu
                    Obx(() {
                      if (controller.isCertified.value) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1DA1F2).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.verified,
                              color: const Color(0xFF1DA1F2),
                              size: 22,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
                SizedBox(height: 4),
                Obx(() => _buildVerificationBadge(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section statistiques
  Widget _buildStatsSection(BuildContext context) {
    final formatter = NumberFormat('#,###', 'fr_FR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiques',
          style: context.h4.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: context.elementSpacing),
        Row(
          children: [
            Expanded(
              child: Obx(() => _buildStatCard(
                context,
                icon: Icons.shopping_bag_outlined,
                title: 'Commandes',
                value: '${controller.totalOrders.value}',
              )),
            ),
            SizedBox(width: AppThemeSystem.getAdaptiveSpacing(context, baseSpacing: 12)),
            Expanded(
              child: Obx(() => _buildStatCard(
                context,
                icon: Icons.trending_up,
                title: 'Ventes',
                value: '${formatter.format(controller.totalSales.value)} XAF',
                isCompact: true,
                onTap: () {
                  Get.to(
                    () => const WalletView(),
                    binding: WalletBinding(),
                  );
                },
              )),
            ),
          ],
        ),
        SizedBox(height: AppThemeSystem.getAdaptiveSpacing(context, baseSpacing: 12)),
        Row(
          children: [
            Expanded(
              child: Obx(() => _buildStatCard(
                context,
                icon: Icons.inventory_2_outlined,
                title: 'Produits',
                value: '${controller.totalProducts.value}',
              )),
            ),
            SizedBox(width: AppThemeSystem.getAdaptiveSpacing(context, baseSpacing: 12)),
            Expanded(
              child: Obx(() => _buildStatCard(
                context,
                icon: Icons.star_outline,
                title: 'Note',
                value: '${controller.rating.value.toStringAsFixed(1)}',
              )),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    bool isCompact = false,
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
      padding: EdgeInsets.all(context.horizontalPadding * 0.75),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(
          color: context.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppThemeSystem.primaryColor,
            size: context.deviceType == DeviceType.mobile ? 24 : 32,
          ),
          SizedBox(height: AppThemeSystem.getAdaptiveSpacing(context, baseSpacing: 12)),
          Text(
            value,
            style: (isCompact ? context.h5 : context.h3).copyWith(
              fontWeight: FontWeight.bold,
              color: context.primaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: context.caption.copyWith(
              color: context.secondaryTextColor,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        child: cardContent,
      );
    }

    return cardContent;
  }

  /// Actions rapides
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: context.h4.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: context.elementSpacing),
        Obx(() {
          if (controller.totalProducts.value == 0) {
            // Aucun produit : bouton "Ajouter un produit"
            return _buildActionButton(
              context,
              icon: Icons.add_box_outlined,
              title: 'Ajouter un produit',
              subtitle: 'Créez votre premier produit',
              onTap: controller.navigateToAddProduct,
            );
          } else {
            // Au moins 1 produit : bouton "Gérer mes produits" avec badge
            return _buildActionButton(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'Gérer mes produits',
              subtitle: 'Modifier ou supprimer vos produits',
              badge: controller.totalProducts.value,
              onTap: controller.navigateToProductManagement,
            );
          }
        }),
        SizedBox(height: AppThemeSystem.getAdaptiveSpacing(context, baseSpacing: 12)),
        Obx(() {
          return _buildActionButton(
            context,
            icon: Icons.list_alt,
            title: 'Gérer les commandes',
            subtitle: 'Consultez vos commandes',
            badge: controller.pendingOrders.value,
            onTap: () async {
              await Get.to(
                () => const OrderManagementView(),
                binding: OrderManagementBinding(),
              );
              // Rafraîchir le dashboard au retour
              await controller.refreshData();
            },
          );
        }),
        SizedBox(height: AppThemeSystem.getAdaptiveSpacing(context, baseSpacing: 12)),
        _buildActionButton(
          context,
          icon: Icons.store,
          title: 'Ma boutique',
          subtitle: 'Personnalisez votre boutique',
          onTap: () {
            Get.to(
              () => const StoreManagementView(),
              binding: StoreManagementBinding(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badge, // NEW: Badge parameter
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: context.borderRadius(BorderRadiusType.medium),
      child: Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(
            color: context.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Stack( // Wrapper for badge
              children: [
                Container(
                  padding: EdgeInsets.all(
                    context.deviceType == DeviceType.mobile ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    borderRadius: context.borderRadius(BorderRadiusType.small),
                  ),
                  child: Icon(
                    icon,
                    color: AppThemeSystem.primaryColor,
                    size: context.deviceType == DeviceType.mobile ? 24 : 32,
                  ),
                ),
                // Badge
                if (badge != null)
                  Positioned(
                    top: -2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.errorColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeSystem.errorColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      child: Text(
                        badge > 99 ? '99+' : badge.toString(),
                        style: context.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: context.elementSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Build verification status badge
  Widget _buildVerificationBadge(BuildContext context) {
    Color badgeColor;
    Color iconColor;
    IconData badgeIcon;
    String statusText;

    switch (controller.verificationStatus.value) {
      case 'approved':
      case 'verified':
      case 'active':
        badgeColor = AppThemeSystem.successColor;
        iconColor = AppThemeSystem.successColor;
        badgeIcon = Icons.check_circle_outline;
        statusText = 'Vérifié';
        break;
      case 'rejected':
        badgeColor = AppThemeSystem.errorColor;
        iconColor = AppThemeSystem.errorColor;
        badgeIcon = Icons.cancel_outlined;
        statusText = 'Rejeté';
        break;
      case 'pending':
      case 'inactive':
      default:
        badgeColor = AppThemeSystem.warningColor;
        iconColor = AppThemeSystem.warningColor;
        badgeIcon = Icons.pending_outlined;
        statusText = 'Non vérifié';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 12,
            color: iconColor,
          ),
          SizedBox(width: 4),
          Text(
            statusText,
            style: context.caption.copyWith(
              color: iconColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Build package section
  Widget _buildPackageSection(BuildContext context) {
    return Obx(() {
      if (!controller.hasPackage.value) {
        // Pas de package : afficher CTA
        return Container(
          padding: EdgeInsets.all(context.horizontalPadding),
          decoration: BoxDecoration(
            color: AppThemeSystem.warningColor.withValues(alpha: 0.1),
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            border: Border.all(
              color: AppThemeSystem.warningColor,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.warning_amber, color: AppThemeSystem.warningColor, size: 48),
              SizedBox(height: 12),
              Text(
                'Aucun package actif',
                style: context.h5.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Souscrivez à un package de stockage pour publier vos produits',
                style: context.body2,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Get.toNamed('/package-subscription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Voir les packages',
                  style: context.button.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // A un package : afficher les infos complètes
      final packageData = controller.packageInfo.value;
      final packageName = packageData?['package']?['name'] ?? 'Package';
      final packagePrice = packageData?['package']?['formatted_price'] ?? '';
      final expiresAt = controller.packageExpiresAt.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mon package',
            style: context.h4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.elementSpacing),

          Container(
            padding: EdgeInsets.all(context.horizontalPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  AppThemeSystem.successColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: context.borderRadius(BorderRadiusType.large),
              border: Border.all(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with package name and status
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            packageName,
                            style: context.h5.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            packagePrice,
                            style: context.body2.copyWith(
                              color: AppThemeSystem.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.successColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeSystem.successColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Actif',
                            style: context.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: context.elementSpacing),

                Divider(color: context.borderColor),

                SizedBox(height: context.elementSpacing),

                // Storage info
                Row(
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 18,
                      color: context.secondaryTextColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Espace de stockage',
                      style: context.caption.copyWith(
                        color: context.secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: controller.storagePercentageUsed.value / 100,
                    backgroundColor: context.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      controller.storagePercentageUsed.value > 80
                          ? AppThemeSystem.errorColor
                          : controller.storagePercentageUsed.value > 50
                              ? AppThemeSystem.warningColor
                              : AppThemeSystem.successColor,
                    ),
                    minHeight: 14,
                  ),
                ),
                SizedBox(height: 10),

                // Storage stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${controller.storageUsedMb.value.toStringAsFixed(1)} MB utilisés',
                      style: context.body2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${controller.storageTotalMb.value.toStringAsFixed(0)} MB',
                      style: context.body2.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: controller.storagePercentageUsed.value > 80
                          ? AppThemeSystem.errorColor
                          : controller.storagePercentageUsed.value > 50
                              ? AppThemeSystem.warningColor
                              : AppThemeSystem.successColor,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${controller.storagePercentageUsed.value.toStringAsFixed(1)}% utilisé • ${controller.storageRemainingMb.value.toStringAsFixed(1)} MB disponible',
                      style: context.caption.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: context.elementSpacing),

                Divider(color: context.borderColor),

                SizedBox(height: context.elementSpacing),

                // Expiration info
                Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 18,
                      color: controller.daysRemaining.value <= 3
                          ? AppThemeSystem.errorColor
                          : controller.daysRemaining.value <= 7
                              ? AppThemeSystem.warningColor
                              : AppThemeSystem.successColor,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.daysRemaining.value <= 3
                                ? 'Expire bientôt !'
                                : controller.daysRemaining.value <= 7
                                    ? 'Expire dans quelques jours'
                                    : 'Valide jusqu\'au',
                            style: context.caption.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            expiresAt != null
                                ? '${DateFormat('dd MMM yyyy', 'fr_FR').format(DateTime.parse(expiresAt))} (${controller.daysRemaining.value} jour${controller.daysRemaining.value > 1 ? "s" : ""})'
                                : '${controller.daysRemaining.value} jour${controller.daysRemaining.value > 1 ? "s" : ""} restant${controller.daysRemaining.value > 1 ? "s" : ""}',
                            style: context.body2.copyWith(
                              fontWeight: FontWeight.w600,
                              color: controller.daysRemaining.value <= 3
                                  ? AppThemeSystem.errorColor
                                  : controller.daysRemaining.value <= 7
                                      ? AppThemeSystem.warningColor
                                      : context.primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: context.elementSpacing),

                // Upgrade button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Get.toNamed('/package-subscription'),
                    icon: Icon(Icons.upgrade_rounded, size: 18),
                    label: Text(
                      'Améliorer mon package',
                      style: context.button.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

}
