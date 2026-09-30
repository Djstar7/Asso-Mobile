import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/certification_packages_controller.dart';
import '../../packageSubscription/widgets/sales_code_field.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../../data/providers/currency_service.dart';
import '../../payment/widgets/wallet_payment_confirm_dialog.dart';
import '../../../data/models/payment_method_option.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../../data/services/stripe_native_service.dart';

class CertificationPackagesView
    extends GetView<CertificationPackagesController> {
  const CertificationPackagesView({super.key});

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
          'certification.view.title'.tr,
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
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppDesign.accent),
                strokeWidth: 2.5,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refreshPackages,
            color: AppDesign.accent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Le code vendeur se saisit au milieu de la page : un geste de
              // défilement referme le clavier pour revoir les formules.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: AppContentWidth(
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
                      _buildIntro(context),
                      SizedBox(height: AppDesign.space4),
                      _buildBenefits(context),
                      SizedBox(height: AppDesign.space8),

                      Text(
                        'certification.view.choose'.tr,
                        style: context.subtitle1.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ds.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppDesign.space1),
                      Text(
                        'certification.view.badge_duration'.tr,
                        style: context.body2.copyWith(color: ds.textSecondary),
                      ),
                      SizedBox(height: AppDesign.space4),
                      if (controller.packages.isEmpty)
                        _buildEmptyState(context)
                      else
                        _buildPackagesList(context),

                      SizedBox(height: AppDesign.space8),

                      // Code commercial (P6) : secondaire, donc après le
                      // choix de la formule, comme sur les forfaits.
                      SalesCodeField(input: controller.salesCode),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Présentation : le badge bleu est la seule couleur de l'écran hors
  /// accent, car c'est précisément ce que le vendeur obtient (couleur
  /// « info » réservée au badge de certification, voir DESIGN.md).
  Widget _buildIntro(BuildContext context) {
    final ds = context.ds;
    return AppCard(
      padding: EdgeInsets.all(AppDesign.space5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppDesign.infoSubtle,
              borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppDesign.info,
              size: 24,
            ),
          ),
          SizedBox(width: AppDesign.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'certification.view.hero_title'.tr,
                  style: context.h6.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ds.textPrimary,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: AppDesign.space1),
                Text(
                  'certification.view.hero_subtitle'.tr,
                  style: context.body2.copyWith(
                    color: ds.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Avantages : une seule carte, icônes neutres. La hiérarchie vient de la
  /// typographie, pas d'une couleur par ligne.
  Widget _buildBenefits(BuildContext context) {
    final ds = context.ds;
    final benefits = [
      (
        Icons.trending_up_rounded,
        'certification.view.benefit_visibility'.tr,
        'certification.view.benefit_visibility_desc'.tr,
      ),
      (
        Icons.verified_user_outlined,
        'certification.view.benefit_badge'.tr,
        'certification.view.benefit_badge_desc'.tr,
      ),
      (
        Icons.search_rounded,
        'certification.view.benefit_search'.tr,
        'certification.view.benefit_search_desc'.tr,
      ),
      (
        Icons.support_agent_rounded,
        'certification.view.benefit_support'.tr,
        'certification.view.benefit_support_desc'.tr,
      ),
    ];

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesign.space4,
        vertical: AppDesign.space2,
      ),
      child: Column(
        children: [
          for (var i = 0; i < benefits.length; i++) ...[
            if (i > 0) Divider(height: 1, color: ds.border),
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppDesign.space3),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ds.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                    ),
                    child: Icon(benefits[i].$1, size: 20, color: ds.icon),
                  ),
                  SizedBox(width: AppDesign.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          benefits[i].$2,
                          style: context.body1.copyWith(
                            fontWeight: FontWeight.w600,
                            color: ds.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          benefits[i].$3,
                          style: context.body2.copyWith(
                            color: ds.textSecondary,
                          ),
                        ),
                      ],
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

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: Icons.verified_outlined,
      title: 'certification.view.empty_title'.tr,
      message: 'certification.view.empty_message'.tr,
      actionLabel: 'certification.view.refresh'.tr,
      onAction: controller.refreshPackages,
    );
  }

  Widget _buildPackagesList(BuildContext context) {
    return Column(
      children: List.generate(
        controller.packages.length,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index < controller.packages.length - 1
                ? AppDesign.space3
                : 0,
          ),
          child: _buildPackageCard(context, controller.packages[index]),
        ),
      ),
    );
  }

  /// Carte d'une formule, sur le modèle des forfaits de stockage : neutre,
  /// l'accent orange ne marque que la sélection, et l'action n'apparaît que
  /// sur la formule choisie.
  Widget _buildPackageCard(BuildContext context, Map<String, dynamic> package) {
    final ds = context.ds;
    final isPopular = package['is_popular'] == true;
    final benefits = (package['benefits'] as List?) ?? const [];
    final name = package['name']?.toString() ?? '';
    final priceXaf = (package['price'] ?? 0).toDouble();
    final duration = package['formatted_duration']?.toString() ?? '';

    return Obx(() {
      final isSelected =
          controller.selectedPackage.value?['id'] == package['id'];

      return Semantics(
        button: true,
        selected: isSelected,
        label: '$name, ${controller.formatCurrency(priceXaf)} $duration',
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSelectionDot(isSelected: isSelected),
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
                      AppBadge(
                        label: 'package_subscription.view.recommended'.tr,
                        tone: AppBadgeTone.accent,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: AppDesign.space4),

                // Prix : l'information la plus lourde de la carte, dans la
                // devise de l'utilisateur.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        controller.formatCurrency(priceXaf),
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

                if (benefits.isNotEmpty) ...[
                  SizedBox(height: AppDesign.space4),
                  Divider(height: 1, color: ds.border),
                  SizedBox(height: AppDesign.space4),
                  for (var i = 0; i < benefits.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == benefits.length - 1 ? 0 : AppDesign.space3,
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
                              benefits[i].toString(),
                              style: context.body2.copyWith(
                                color: ds.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: isSelected
                      ? Padding(
                          padding: EdgeInsets.only(top: AppDesign.space5),
                          child: AppButton(
                            label: 'certification.view.get_certification'.tr,
                            icon: Icons.verified_outlined,
                            size: AppButtonSize.large,
                            isLoading: controller.isCreatingOrder.value,
                            onPressed: () =>
                                _choosePaymentAndOrder(context, package),
                          ),
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

  /// Ouvre le sélecteur STANDARD de moyen de paiement puis lance le sous-parcours
  /// correspondant au rail choisi (identique à toutes les pages de paiement).
  void _choosePaymentAndOrder(
    BuildContext context,
    Map<String, dynamic> package,
  ) async {
    final packageId = package['id'] as int;
    final price = (package['price'] ?? 0)
        .toDouble(); // XAF (devise des forfaits)

    // Code commercial saisi : il doit être valide avant de payer (P6).
    if (!await controller.salesCode.ensureReady()) return;

    final display = CurrencyService.displayFromPivot(price);

    final method = await PaymentMethodSelector.show(
      amount: display.amount,
      currency: display.currency,
      amountLabel: 'certification.view.price'.tr,
      allowedCodes: const {'kpay', 'stripe'},
      includeWallet: true,
    );
    if (method == null) return; // annulé

    switch (method.code) {
      case 'wallet':
        await _payViaWallet(package, price, method);
        break;
      case 'kpay':
        await _confirmOrder(context, packageId, price);
        break;
      case 'stripe':
        await _payViaCard(context, packageId);
        break;
      default:
        Get.snackbar(
          'package_subscription.unavailable'.tr,
          'certification.view.method_unavailable'.tr,
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
      amountLabel: 'certification.view.price'.tr,
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
        'certification.view.order_created'.tr,
        'certification.view.validate_ussd'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  /// Sous-parcours Wallet ASSO : débit du solde et certification immédiate.
  Future<void> _payViaWallet(
    Map<String, dynamic> package,
    double price,
    PaymentMethodOption method,
  ) async {
    final confirmed = await WalletPaymentConfirmDialog.show(
      itemLabel: '${package['name'] ?? 'certification.view.title'.tr}',
      amount: price,
      balance: method.balance ?? 0,
      salesCode: controller.salesCode.code,
    );
    if (!confirmed) return;

    final message = await controller.payWithWallet(
      packageId: package['id'] as int,
    );
    if (message == null) return; // erreur déjà affichée

    Get.snackbar(
      'certification.view.certified'.tr,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppDesign.success,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  /// Sous-parcours CARTE (Payment Sheet Stripe native).
  Future<void> _payViaCard(BuildContext context, int packageId) async {
    if (!StripeNativeService.isSupported) {
      Get.snackbar(
        'package_subscription.unavailable'.tr,
        'wallet.recharge.card_mobile_only'.tr,
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
          'wallet.webview.cancelled'.tr,
          'package_subscription.payment_not_finalized'.tr,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      controller.pollOrderPayment(orderId);
      Get.snackbar(
        'package_subscription.payment_in_progress'.tr,
        'package_subscription.payment_confirming'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar(
        'certification.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }
}
