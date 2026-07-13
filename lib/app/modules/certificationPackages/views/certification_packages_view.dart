import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/certification_packages_controller.dart';

class CertificationPackagesView extends GetView<CertificationPackagesController> {
  const CertificationPackagesView({super.key});

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
        title: Row(
          children: [
            Icon(
              Icons.verified,
              color: const Color(0xFF1DA1F2),
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Certification',
              style: context.h4.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
                    // Header Section
                    _buildHeaderSection(context),
                    SizedBox(height: context.sectionSpacing),

                    // Benefits Section
                    _buildBenefitsSection(context),
                    SizedBox(height: context.sectionSpacing),

                    // Packages List
                    if (controller.packages.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.verified_outlined,
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

  /// Build header section with gradient
  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding * 1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1DA1F2),
            const Color(0xFF0D7FC6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: context.borderRadius(BorderRadiusType.large),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1DA1F2).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Devenez un Vendeur Certifié',
            style: context.h5.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gagnez la confiance de vos clients et boostez vos ventes avec notre badge de certification officiel',
            style: context.body2.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Build benefits section
  Widget _buildBenefitsSection(BuildContext context) {
    final benefits = [
      {
        'icon': Icons.trending_up,
        'title': 'Visibilité accrue',
        'description': '+300% de visibilité sur vos produits',
        'color': AppThemeSystem.successColor,
      },
      {
        'icon': Icons.verified_user,
        'title': 'Badge de confiance',
        'description': 'Badge bleu affiché sur votre profil',
        'color': const Color(0xFF1DA1F2),
      },
      {
        'icon': Icons.star,
        'title': 'Priorité recherche',
        'description': 'Apparaissez en premier dans les résultats',
        'color': AppThemeSystem.warningColor,
      },
      {
        'icon': Icons.support_agent,
        'title': 'Support prioritaire',
        'description': 'Assistance dédiée 7j/7',
        'color': AppThemeSystem.primaryColor,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pourquoi se certifier ?',
          style: context.h6.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...benefits.map((benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (benefit['color'] as Color).withValues(alpha: 0.05),
                  borderRadius: context.borderRadius(BorderRadiusType.medium),
                  border: Border.all(
                    color: (benefit['color'] as Color).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: benefit['color'] as Color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        benefit['icon'] as IconData,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            benefit['title'] as String,
                            style: context.subtitle1.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            benefit['description'] as String,
                            style: context.caption.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  /// Build packages list
  Widget _buildPackagesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choisissez votre plan',
          style: context.h6.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          controller.packages.length,
          (index) {
            final package = controller.packages[index];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: index < controller.packages.length - 1 ? 16 : 0),
              child: _buildPremiumPackageCard(context, package),
            );
          },
        ),
      ],
    );
  }

  /// Build premium package card with exclusive design
  Widget _buildPremiumPackageCard(
      BuildContext context, Map<String, dynamic> package) {
    final isPopular = package['is_popular'] ?? false;
    final benefits = package['benefits'] as List?;
    final name = package['name'] ?? '';
    final price = package['formatted_price'] ?? '';
    final duration = package['formatted_duration'] ?? '';

    // Determine card color based on package tier
    Color primaryColor;
    Color accentColor;
    IconData badgeIcon;

    if (name.contains('Gold') || name.contains('Or')) {
      primaryColor = const Color(0xFFFFD700);
      accentColor = const Color(0xFFFFD700);
      badgeIcon = Icons.workspace_premium;
    } else if (name.contains('Silver') || name.contains('Argent')) {
      primaryColor = const Color(0xFFC0C0C0);
      accentColor = const Color(0xFF9E9E9E);
      badgeIcon = Icons.stars;
    } else {
      primaryColor = const Color(0xFFCD7F32);
      accentColor = const Color(0xFFD2691E);
      badgeIcon = Icons.verified;
    }

    return Obx(() {
      final isSelected =
          controller.selectedPackage.value?['id'] == package['id'];

      return GestureDetector(
        onTap: () => controller.selectPackage(package),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(context.horizontalPadding),
          decoration: BoxDecoration(
            gradient: isPopular || isSelected
                ? LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.1),
                      accentColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPopular || isSelected ? null : context.surfaceColor,
            borderRadius: context.borderRadius(BorderRadiusType.large),
            border: Border.all(
              color: isPopular || isSelected
                  ? primaryColor
                  : context.borderColor,
              width: isPopular || isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isPopular || isSelected
                    ? primaryColor.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: isPopular || isSelected ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      badgeIcon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
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
                        const SizedBox(height: 4),
                        Text(
                          'Certification Officielle',
                          style: context.caption.copyWith(
                            color: context.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppThemeSystem.warningColor,
                            AppThemeSystem.warningColor.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeSystem.warningColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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

              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: context.h3.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      duration,
                      style: context.body2.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),

              // Benefits
              if (benefits != null && benefits.isNotEmpty) ...[
                SizedBox(height: context.elementSpacing),
                ...List.generate(
                  benefits.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: 18,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            benefits[index].toString(),
                            style: context.body2.copyWith(
                              color: context.primaryTextColor,
                              height: 1.4,
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
                  onPressed: () =>
                      _showPaymentMethodBottomSheet(context, package),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular || isSelected
                        ? primaryColor
                        : context.surfaceColor,
                    foregroundColor: isPopular || isSelected
                        ? Colors.white
                        : primaryColor,
                    elevation: isPopular || isSelected ? 4 : 0,
                    shadowColor: primaryColor.withValues(alpha: 0.3),
                    side: BorderSide(
                      color: primaryColor,
                      width: isPopular || isSelected ? 0 : 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          context.borderRadius(BorderRadiusType.medium),
                    ),
                  ),
                  child: Text(
                    'Obtenir la certification',
                    style: context.button.copyWith(
                      color: isPopular || isSelected
                          ? Colors.white
                          : primaryColor,
                      fontWeight: FontWeight.bold,
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

  /// Show payment method selection bottom sheet (reused from package subscription)
  void _showPaymentMethodBottomSheet(
      BuildContext context, Map<String, dynamic> package) {
    controller.selectPackage(package);

    // Refresh wallet data
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
              'Prix de la certification: ${controller.formatCurrency(price)}',
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
                  // KPay Wallet Option
                  _buildWalletOption(
                    context,
                    title: 'Wallet KPay',
                    balance: controller.wallet.value?.kpayBalance ?? 0,
                    price: price,
                    icon: Icons.phone_android_rounded,
                    color: AppThemeSystem.kpayColor,
                    onTap: () {
                      controller.subscribeWithWallet('kpay');
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
                Get.back();
                Get.offAllNamed('/home', arguments: {'initialTab': 2});
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: context.borderColor,
                  width: 1.5,
                ),
                padding:
                    EdgeInsets.symmetric(vertical: context.elementSpacing),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      context.borderRadius(BorderRadiusType.medium),
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
              color: hasEnoughBalance ? color : context.borderColor,
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
