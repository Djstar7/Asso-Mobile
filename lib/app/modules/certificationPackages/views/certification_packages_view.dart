import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/certification_packages_controller.dart';
import '../../payment/widgets/payment_method_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../wallet/views/payment_webview.dart';
import '../../../data/services/stripe_native_service.dart';

class CertificationPackagesView
    extends GetView<CertificationPackagesController> {
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
            Icon(Icons.verified, color: const Color(0xFF1DA1F2), size: 28),
            const SizedBox(width: 12),
            Text(
              'Certification',
              style: context.h4.copyWith(fontWeight: FontWeight.w700),
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
                  bottom:
                      MediaQuery.of(context).padding.bottom +
                      context.horizontalPadding,
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
          colors: [const Color(0xFF1DA1F2), const Color(0xFF0D7FC6)],
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
            child: const Icon(Icons.verified, color: Colors.white, size: 32),
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
          style: context.h6.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...benefits.map(
          (benefit) => Padding(
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
          ),
        ),
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
          style: context.h6.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...List.generate(controller.packages.length, (index) {
          final package = controller.packages[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < controller.packages.length - 1 ? 16 : 0,
            ),
            child: _buildPremiumPackageCard(context, package),
          );
        }),
      ],
    );
  }

  /// Build premium package card with exclusive design
  Widget _buildPremiumPackageCard(
    BuildContext context,
    Map<String, dynamic> package,
  ) {
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
                    child: Icon(badgeIcon, color: Colors.white, size: 28),
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
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                            color: AppThemeSystem.warningColor.withValues(
                              alpha: 0.3,
                            ),
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
                  onPressed: () => _choosePaymentAndOrder(context, package),
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
                      borderRadius: context.borderRadius(
                        BorderRadiusType.medium,
                      ),
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

  /// Ouvre le sélecteur STANDARD de moyen de paiement puis lance le sous-parcours
  /// correspondant au rail choisi (identique à toutes les pages de paiement).
  void _choosePaymentAndOrder(
    BuildContext context,
    Map<String, dynamic> package,
  ) async {
    final packageId = package['id'] as int;
    final price = (package['price'] ?? 0).toDouble();

    final method = await PaymentMethodSelector.show(
      amount: price,
      currency: 'XAF',
      amountLabel: 'Prix de la certification',
    );
    if (method == null) return; // annulé

    switch (method.code) {
      case 'kpay':
        await _confirmOrder(context, packageId, price);
        break;
      case 'paypal':
        await _payViaRedirect(context, packageId, 'paypal_direct', 'paypal');
        break;
      case 'stripe':
        await _payViaCard(context, packageId);
        break;
      default:
        Get.snackbar(
          'Indisponible',
          "Ce moyen de paiement n'est pas encore disponible pour les certifications.",
          snackPosition: SnackPosition.BOTTOM,
        );
    }
  }

  /// Sous-parcours KPay direct (USSD).
  Future<void> _confirmOrder(
    BuildContext context,
    int packageId,
    double amount,
  ) async {
    final selection = await KpayDirectPaymentSheet.show(
      amount: amount,
      amountLabel: 'Prix de la certification',
    );
    if (selection == null) return; // paiement annulé

    final success = await controller.createOrder(
      packageId: packageId,
      paymentMode: 'kpay_direct',
      kpayProvider: selection['provider'],
      kpayPhone: selection['phone'],
    );

    if (success) {
      Get.snackbar(
        'Commande créée !',
        'Validez le paiement sur votre téléphone (USSD). Vous serez notifié dès confirmation.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  /// Sous-parcours PayPal (checkout WebView, ou navigateur système hors mobile).
  Future<void> _payViaRedirect(
    BuildContext context,
    int packageId,
    String paymentMode,
    String methodCode,
  ) async {
    final data = await controller.createRedirectOrder(
      packageId: packageId,
      paymentMode: paymentMode,
    );
    if (data == null)
      return; // échec / lien indisponible (snackbar déjà affiché)

    final orderId = data['order_id'] as int;
    final approvalUrl = data['approval_url'] as String;

    if (!(GetPlatform.isAndroid || GetPlatform.isIOS)) {
      final launched = await launchUrl(
        Uri.parse(approvalUrl),
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        controller.pollOrderPayment(orderId);
        Get.snackbar(
          'Paiement ouvert dans le navigateur',
          'Terminez le paiement, la confirmation est automatique.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 6),
        );
      } else {
        Get.snackbar(
          'Erreur',
          "Impossible d'ouvrir la page de paiement.",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return;
    }

    final result = await Get.to<Map<String, dynamic>>(
      () => PaymentWebView(
        paymentUrl: approvalUrl,
        paymentMethod: methodCode,
        paymentId: orderId,
      ),
    );

    if (result != null && result['success'] == true) {
      controller.pollOrderPayment(orderId);
      Get.snackbar(
        'Paiement en cours',
        'Votre paiement est en cours de confirmation. Vous serez notifié.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } else {
      Get.snackbar(
        'Paiement annulé',
        'Le paiement n\'a pas été finalisé.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Sous-parcours CARTE (Payment Sheet Stripe native).
  Future<void> _payViaCard(BuildContext context, int packageId) async {
    if (!StripeNativeService.isSupported) {
      Get.snackbar(
        'Indisponible',
        "Le paiement par carte est disponible sur l'application mobile.",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final data = await controller.createCardOrder(packageId: packageId);
    if (data == null) return; // échec (snackbar déjà affiché)

    final orderId = data['order_id'] as int;

    try {
      final ok = await StripeNativeService().payWithCard(
        publishableKey: data['publishable_key'] as String,
        clientSecret: data['client_secret'] as String,
      );

      if (!ok) {
        Get.snackbar(
          'Paiement annulé',
          "Le paiement n'a pas été finalisé.",
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      controller.pollOrderPayment(orderId);
      Get.snackbar(
        'Paiement en cours',
        'Votre paiement est en cours de confirmation. Vous serez notifié.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }
}
