import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/package_subscription_controller.dart';

class PackageSubscriptionView extends GetView<PackageSubscriptionController> {
  const PackageSubscriptionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: context.primaryTextColor,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        centerTitle: false,
        title: Text(
          'Sélectionner un Plan',
          style: context.h4.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Obx(() {
          if (controller.isLoading.value && controller.packages.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppThemeSystem.primaryColor,
                ),
                strokeWidth: 3,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refreshPackages,
            color: AppThemeSystem.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  left: context.horizontalPadding,
                  right: context.horizontalPadding,
                  top: context.horizontalPadding,
                  bottom: MediaQuery.of(context).padding.bottom + context.horizontalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet Balance Section
                    // _buildWalletSection(context),
                    // SizedBox(height: context.sectionSpacing),

                    // Current Package Section (if exists)
                    if (controller.hasPackage.value) ...[
                      _buildCurrentPackageSection(context),
                      SizedBox(height: context.sectionSpacing),
                    ],

                    // Available Packages
                    if (controller.packages.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: context.secondaryTextColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun package disponible',
                                style: context.body1.copyWith(
                                  color: context.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      _buildPackagesList(context),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Build wallet balance row - method kept for future use
  // ignore: unused_element
  Widget _buildWalletBalanceRow(
    BuildContext context,
    String label,
    double balance,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  label == 'FreeMoPay'
                      ? Icons.phone_android_rounded
                      : Icons.payment_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: context.body2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            controller.formatCurrency(balance),
            style: context.subtitle1.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build current package section with modern design
  Widget _buildCurrentPackageSection(BuildContext context) {
    final vendorPackage = controller.currentVendorPackage.value;
    if (vendorPackage == null) return const SizedBox.shrink();

    final storageTotalMb = (vendorPackage['storage_total_mb'] ?? 0).toDouble();
    final storageUsedMb = (vendorPackage['storage_used_mb'] ?? 0).toDouble();
    final storagePercentageUsed = (vendorPackage['storage_percentage_used'] ?? 0).toDouble();
    final daysRemaining = vendorPackage['days_remaining'] ?? 0;
    final packageData = vendorPackage['package'];

    return Container(
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.large),
        border: Border.all(
          color: AppThemeSystem.successColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeSystem.successColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Actuel',
                      style: context.caption.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      packageData?['name'] ?? 'Package Actuel',
                      style: context.h6.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.formatCurrency((packageData?['price'] ?? 0).toDouble()),
                      style: context.subtitle1.copyWith(
                        color: AppThemeSystem.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppThemeSystem.successColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Actif',
                  style: context.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.elementSpacing),

          // Storage Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stockage utilisé',
                      style: context.body2.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${storagePercentageUsed.toStringAsFixed(1)}%',
                      style: context.subtitle1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: storagePercentageUsed / 100,
                    backgroundColor: context.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      storagePercentageUsed > 80
                          ? AppThemeSystem.errorColor
                          : storagePercentageUsed > 50
                              ? AppThemeSystem.warningColor
                              : AppThemeSystem.successColor,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${storageUsedMb.toStringAsFixed(1)} MB',
                      style: context.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${storageTotalMb.toStringAsFixed(0)} MB',
                      style: context.caption.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expiration warning
          if (daysRemaining <= 7)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeSystem.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppThemeSystem.warningColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: AppThemeSystem.warningColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Expire dans $daysRemaining jour${daysRemaining > 1 ? "s" : ""}',
                      style: context.caption.copyWith(
                        color: AppThemeSystem.warningColor,
                        fontWeight: FontWeight.w600,
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

  /// Build packages list with modern card design
  Widget _buildPackagesList(BuildContext context) {
    return Column(
      children: List.generate(
        controller.packages.length,
        (index) {
          final package = controller.packages[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index < controller.packages.length - 1 ? 16 : 0),
            child: _buildModernPackageCard(context, package),
          );
        },
      ),
    );
  }

  /// Build modern package card inspired by the reference image
  Widget _buildModernPackageCard(BuildContext context, Map<String, dynamic> package) {
    final isPopular = package['is_popular'] ?? false;
    final benefits = package['benefits'] as List?;
    final name = package['name'] ?? '';
    final price = (package['price'] ?? 0).toDouble();
    final storage = package['formatted_storage_size'] ?? '';
    final duration = package['formatted_duration'] ?? '';

    return Obx(() {
      final isSelected = controller.selectedPackage.value?['id'] == package['id'];

      return GestureDetector(
        onTap: () => controller.selectPackage(package),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(context.horizontalPadding),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: context.borderRadius(BorderRadiusType.large),
            border: Border.all(
              color: isPopular
                  ? AppThemeSystem.warningColor
                  : isSelected
                      ? AppThemeSystem.primaryColor
                      : context.borderColor,
              width: isPopular || isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isPopular
                    ? AppThemeSystem.warningColor.withValues(alpha: 0.15)
                    : isSelected
                        ? AppThemeSystem.primaryColor.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.05),
                blurRadius: isPopular || isSelected ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with radio and popular badge
              Row(
                children: [
                  // Radio button indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppThemeSystem.primaryColor
                            : context.borderColor,
                        width: 2,
                      ),
                      color: isSelected
                          ? AppThemeSystem.primaryColor
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(
                              Icons.circle,
                              size: 12,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Plan name and subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: context.h6.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'pour Stockage',
                          style: context.body2.copyWith(
                            color: context.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Popular badge
                  if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.warningColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'POPULAIRE',
                        style: context.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: context.elementSpacing),

              // Price and period
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    controller.formatCurrency(price),
                    style: context.h4.copyWith(
                      color: AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      duration,
                      style: context.body2.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),

              // Storage info
              SizedBox(height: context.elementSpacing),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 16,
                      color: AppThemeSystem.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      storage,
                      style: context.caption.copyWith(
                        color: AppThemeSystem.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Benefits
              if (benefits != null && benefits.isNotEmpty) ...[
                SizedBox(height: context.elementSpacing),
                ...List.generate(
                  benefits.length > 4 ? 4 : benefits.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppThemeSystem.successColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            benefits[index].toString(),
                            style: context.body2.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Subscribe button
              SizedBox(height: context.elementSpacing),
              SizedBox(
                width: double.infinity,
                height: context.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => _showPaymentMethodBottomSheet(context, package),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular || isSelected
                        ? AppThemeSystem.primaryColor
                        : context.surfaceColor,
                    foregroundColor: isPopular || isSelected
                        ? Colors.white
                        : AppThemeSystem.primaryColor,
                    elevation: 0,
                    side: BorderSide(
                      color: AppThemeSystem.primaryColor,
                      width: isPopular || isSelected ? 0 : 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                    ),
                  ),
                  child: Text(
                    'Choisir ce plan',
                    style: context.button.copyWith(
                      color: isPopular || isSelected
                          ? Colors.white
                          : AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Show payment method selection bottom sheet
  void _showPaymentMethodBottomSheet(BuildContext context, Map<String, dynamic> package) {
    controller.selectPackage(package);

    // Refresh wallet data (will update automatically via Obx)
    controller.loadWallet();

    final price = (package['price'] ?? 0).toDouble();

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: context.horizontalPadding,
          right: context.horizontalPadding,
          top: context.verticalPadding,
          bottom: context.bottomSheetPadding,
        ),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: context.elementSpacing),

            // Title
            Text(
              'Choisir votre méthode de paiement',
              style: context.h6.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.elementSpacing / 2),

            Text(
              'Prix du package: ${controller.formatCurrency(price)}',
              style: context.body2.copyWith(
                color: context.secondaryTextColor,
              ),
            ),
            SizedBox(height: context.sectionSpacing),

            // Wallet loading indicator or options
            Obx(() {
              final isLoadingWallet = controller.isLoadingWallet.value;

              if (isLoadingWallet) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppThemeSystem.primaryColor,
                          ),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chargement des soldes...',
                          style: context.body2.copyWith(
                            color: context.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // FreeMoPay Wallet Option
                  _buildWalletOption(
                    context,
                    title: 'Wallet FreeMoPay',
                    balance: controller.wallet.value?.freemopayBalance ?? 0,
                    price: price,
                    icon: Icons.phone_android_rounded,
                    color: AppThemeSystem.freemopayColor,
                    onTap: () {
                      controller.subscribeWithWallet('freemopay');
                    },
                  ),
                  SizedBox(height: context.elementSpacing),

                  // PayPal Wallet Option
                  _buildWalletOption(
                    context,
                    title: 'Wallet PayPal',
                    balance: controller.wallet.value?.paypalBalance ?? 0,
                    price: price,
                    icon: Icons.payment_rounded,
                    color: AppThemeSystem.paypalColor,
                    onTap: () {
                      controller.subscribeWithWallet('paypal');
                    },
                  ),
                ],
              );
            }),
            SizedBox(height: context.elementSpacing),

            // Recharge Wallet Button
            OutlinedButton(
              onPressed: () {
                Get.back(); // Fermer le bottom sheet
                // Naviguer vers /home et sélectionner le tab Wallet (index 2)
                Get.offAllNamed('/home', arguments: {'initialTab': 2});
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: context.borderColor,
                  width: 1.5,
                ),
                padding: EdgeInsets.symmetric(vertical: context.elementSpacing),
                shape: RoundedRectangleBorder(
                  borderRadius: context.borderRadius(BorderRadiusType.medium),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: AppThemeSystem.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recharger mon wallet',
                    style: context.button.copyWith(
                      color: AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  /// Build wallet option card
  Widget _buildWalletOption(
    BuildContext context, {
    required String title,
    required double balance,
    required double price,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final hasEnoughBalance = balance >= price;

    return Obx(() {
      final isLoading = controller.isLoading.value;

      return InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        child: Container(
          padding: EdgeInsets.all(context.horizontalPadding),
          decoration: BoxDecoration(
            color: hasEnoughBalance
                ? color.withValues(alpha: 0.05)
                : context.surfaceColor,
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            border: Border.all(
              color: hasEnoughBalance
                  ? color
                  : context.borderColor,
              width: hasEnoughBalance ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: context.elementSpacing),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.subtitle1.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solde: ${controller.formatCurrency(balance)}',
                      style: context.caption.copyWith(
                        color: hasEnoughBalance
                            ? AppThemeSystem.successColor
                            : AppThemeSystem.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Status
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasEnoughBalance)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppThemeSystem.successColor,
                  size: 24,
                )
              else
                Icon(
                  Icons.lock_rounded,
                  color: AppThemeSystem.errorColor,
                  size: 20,
                ),
            ],
          ),
        ),
      );
    });
  }
}
