import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/wallet_controller.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/controllers/app_config_controller.dart';

class WithdrawWalletView extends GetView<WalletController> {
  const WithdrawWalletView({super.key});

  @override
  Widget build(BuildContext context) {
    final appConfig = Get.find<AppConfigController>();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Retrait',
          style: context.h2.copyWith(color: context.colors.onPrimary),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: context.colors.primary,
        iconTheme: IconThemeData(color: context.colors.onPrimary),
      ),
      body: SafeArea(
        bottom: true,
        child: RefreshIndicator(
          onRefresh: () => controller.loadWithdrawalBalances(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: context.horizontalPadding,
              right: context.horizontalPadding,
              top: context.sectionSpacing,
              bottom:
                  MediaQuery.of(context).viewPadding.bottom +
                  context.sectionSpacing,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Solde total avec design moderne
                _buildModernBalanceCard(context),

                SizedBox(height: context.sectionSpacing * 1.5),

                // Titre avec style
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: context.elementSpacing),
                    Text(
                      'Méthodes de retrait',
                      style: context.h3.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: context.elementSpacing * 1.5),

                // FreeMoPay Card moderne
                _buildModernFreeMoPayCard(context),

                SizedBox(height: context.elementSpacing * 1.5),

                // PayPal Card moderne
                _buildModernPayPalCard(context),

                SizedBox(height: context.sectionSpacing * 1.5),

                // Info élégante
                _buildModernInfoNote(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernBalanceCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding * 1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary,
            context.colors.primary.withValues(alpha: 0.85),
            context.colors.secondary.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: context.borderRadius(BorderRadiusType.large),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.elementSpacing * 0.6),
                decoration: BoxDecoration(
                  color: context.colors.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: context.colors.onPrimary,
                  size: 20,
                ),
              ),
              SizedBox(width: context.elementSpacing),
              Text(
                'Solde Total Disponible',
                style: context.body1.copyWith(
                  color: context.colors.onPrimary.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: context.elementSpacing * 1.5),
          Obx(
            () => Text(
              '${controller.totalWithdrawableBalance.value.toStringAsFixed(0)} FCFA',
              style: context.h1.copyWith(
                color: context.colors.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize:
                    AppThemeSystem.getFontSize(context, FontSizeType.h1) * 1.4,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFreeMoPayCard(BuildContext context) {
    return Obx(
      () => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: controller.freemopayBalance.value > 0
              ? () => _showModernFreeMoPayBottomSheet(context)
              : null,
          borderRadius: context.borderRadius(BorderRadiusType.large),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: controller.freemopayBalance.value > 0
                    ? [
                        AppThemeSystem.freemopayColor.withValues(alpha: 0.08),
                        AppThemeSystem.freemopayColor.withValues(alpha: 0.03),
                      ]
                    : [context.surfaceColor, context.surfaceColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: context.borderRadius(BorderRadiusType.large),
              border: Border.all(
                color: controller.freemopayBalance.value > 0
                    ? AppThemeSystem.freemopayColor.withValues(alpha: 0.3)
                    : context.borderColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(context.horizontalPadding * 1.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.elementSpacing),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppThemeSystem.freemopayColor,
                              AppThemeSystem.freemopayColor.withValues(
                                alpha: 0.7,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppThemeSystem.freemopayColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.phone_android_rounded,
                          color: AppThemeSystem.whiteColor,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: context.elementSpacing * 1.2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mobile Money',
                              style: context.h4.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Orange Money • MTN MoMo',
                              style: context.caption.copyWith(
                                color: context.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(context.elementSpacing * 0.5),
                        decoration: BoxDecoration(
                          color: controller.freemopayBalance.value > 0
                              ? AppThemeSystem.freemopayColor.withValues(
                                  alpha: 0.1,
                                )
                              : context.borderColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: controller.freemopayBalance.value > 0
                              ? AppThemeSystem.freemopayColor
                              : context.secondaryTextColor.withValues(
                                  alpha: 0.5,
                                ),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.elementSpacing * 1.5),
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: context.elementSpacing * 0.8,
                      horizontal: context.elementSpacing * 1.2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? context.surfaceColor
                          : AppThemeSystem.whiteColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18,
                              color: context.secondaryTextColor,
                            ),
                            SizedBox(width: context.elementSpacing * 0.6),
                            Text(
                              'Disponible',
                              style: context.body2.copyWith(
                                color: context.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${controller.freemopayBalance.value.toStringAsFixed(0)} FCFA',
                          style: context.subtitle1.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppThemeSystem.freemopayColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.freemopayBalance.value > 0) ...[
                    SizedBox(height: context.elementSpacing),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: context.colors.tertiary,
                        ),
                        SizedBox(width: context.elementSpacing * 0.5),
                        Text(
                          'Minimum 50 FCFA',
                          style: context.caption.copyWith(
                            color: context.colors.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernPayPalCard(BuildContext context) {
    return Obx(
      () => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: controller.paypalBalance.value > 0
              ? () => _showModernPayPalBottomSheet(context)
              : null,
          borderRadius: context.borderRadius(BorderRadiusType.large),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: controller.paypalBalance.value > 0
                    ? [
                        AppThemeSystem.paypalColor.withValues(alpha: 0.08),
                        AppThemeSystem.paypalColor.withValues(alpha: 0.03),
                      ]
                    : [context.surfaceColor, context.surfaceColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: context.borderRadius(BorderRadiusType.large),
              border: Border.all(
                color: controller.paypalBalance.value > 0
                    ? AppThemeSystem.paypalColor.withValues(alpha: 0.3)
                    : context.borderColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(context.horizontalPadding * 1.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.elementSpacing),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppThemeSystem.paypalColor,
                              AppThemeSystem.paypalColor.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppThemeSystem.paypalColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.payment_rounded,
                          color: AppThemeSystem.whiteColor,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: context.elementSpacing * 1.2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PayPal',
                              style: context.h4.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Virement international',
                              style: context.caption.copyWith(
                                color: context.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(context.elementSpacing * 0.5),
                        decoration: BoxDecoration(
                          color: controller.paypalBalance.value > 0
                              ? AppThemeSystem.paypalColor.withValues(
                                  alpha: 0.1,
                                )
                              : context.borderColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: controller.paypalBalance.value > 0
                              ? AppThemeSystem.paypalColor
                              : context.secondaryTextColor.withValues(
                                  alpha: 0.5,
                                ),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.elementSpacing * 1.5),
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: context.elementSpacing * 0.8,
                      horizontal: context.elementSpacing * 1.2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? context.surfaceColor
                          : AppThemeSystem.whiteColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18,
                              color: context.secondaryTextColor,
                            ),
                            SizedBox(width: context.elementSpacing * 0.6),
                            Text(
                              'Disponible',
                              style: context.body2.copyWith(
                                color: context.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${controller.paypalBalance.value.toStringAsFixed(0)} FCFA',
                          style: context.subtitle1.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppThemeSystem.paypalColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.paypalBalance.value > 0) ...[
                    SizedBox(height: context.elementSpacing),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: context.colors.tertiary,
                        ),
                        SizedBox(width: context.elementSpacing * 0.5),
                        Text(
                          'Minimum \$10 USD (~6 000 FCFA)',
                          style: context.caption.copyWith(
                            color: context.colors.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoNote(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.elementSpacing * 1.2),
      decoration: BoxDecoration(
        color: context.colors.tertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.tertiary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(context.elementSpacing * 0.5),
            decoration: BoxDecoration(
              color: context.colors.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: context.colors.tertiary,
              size: 20,
            ),
          ),
          SizedBox(width: context.elementSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Délai de traitement',
                  style: context.body2.copyWith(
                    color: context.colors.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Les retraits sont traités dans un délai de 48 heures.',
                  style: context.caption.copyWith(
                    color: context.colors.tertiary.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showModernFreeMoPayBottomSheet(BuildContext context) {
    final appConfig = Get.find<AppConfigController>();
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedMethod = 'om';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.all(context.horizontalPadding * 1.5),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar moderne
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(
                          bottom: context.elementSpacing * 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.borderColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header avec gradient
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.elementSpacing),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppThemeSystem.freemopayColor,
                                AppThemeSystem.freemopayColor.withValues(
                                  alpha: 0.7,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppThemeSystem.freemopayColor.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.phone_android_rounded,
                            color: AppThemeSystem.whiteColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: context.elementSpacing * 1.2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Retrait Mobile Money',
                                style: context.h3.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Mobile Money',
                                style: context.caption.copyWith(
                                  color: context.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.primaryTextColor,
                          ),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          padding: EdgeInsets.all(context.elementSpacing * 0.5),
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            backgroundColor: context.borderColor.withValues(
                              alpha: 0.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: context.sectionSpacing),

                    // Solde disponible élégant
                    Container(
                      padding: EdgeInsets.all(context.elementSpacing * 1.2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppThemeSystem.freemopayColor.withValues(
                              alpha: 0.08,
                            ),
                            AppThemeSystem.freemopayColor.withValues(
                              alpha: 0.03,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppThemeSystem.freemopayColor.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              context.elementSpacing * 0.6,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeSystem.freemopayColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppThemeSystem.freemopayColor,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: context.elementSpacing),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Solde disponible',
                                  style: context.caption.copyWith(
                                    color: context.secondaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Obx(
                                  () => Text(
                                    '${controller.freemopayBalance.value.toStringAsFixed(0)} FCFA',
                                    style: context.h4.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppThemeSystem.freemopayColor,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.sectionSpacing),

                    // Méthode de paiement
                    Text(
                      'Méthode de paiement',
                      style: context.subtitle1.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: context.elementSpacing),
                    StatefulBuilder(
                      builder: (ctx, setState) => Row(
                        children: [
                          Expanded(
                            child: _buildModernRadioTile(
                              context: context,
                              title: 'Orange Money',
                              subtitle: 'OM',
                              icon: Icons.phone_android_rounded,
                              value: 'om',
                              groupValue: selectedMethod,
                              color: AppThemeSystem.freemopayColor,
                              onChanged: (value) =>
                                  setState(() => selectedMethod = value!),
                            ),
                          ),
                          SizedBox(width: context.elementSpacing),
                          Expanded(
                            child: _buildModernRadioTile(
                              context: context,
                              title: 'MTN MoMo',
                              subtitle: 'MoMo',
                              icon: Icons.phone_iphone_rounded,
                              value: 'momo',
                              groupValue: selectedMethod,
                              color: const Color(0xFFFFCC00),
                              onChanged: (value) =>
                                  setState(() => selectedMethod = value!),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.sectionSpacing),

                    // Champs du formulaire
                    Text(
                      'Numéro de téléphone',
                      style: context.subtitle2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: context.elementSpacing * 0.6),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: context.body1,
                      decoration: InputDecoration(
                        hintText: '06XXXXXXXX',
                        hintStyle: context.body1.copyWith(
                          color: context.secondaryTextColor.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.phone_rounded,
                          color: AppThemeSystem.freemopayColor,
                        ),
                        filled: true,
                        fillColor: context.inputFieldColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppThemeSystem.freemopayColor,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un numéro';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: context.elementSpacing * 1.5),

                    Text(
                      'Montant (FCFA)',
                      style: context.subtitle2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: context.elementSpacing * 0.6),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: context.body1.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: AppThemeSystem.getFontSize(
                          context,
                          FontSizeType.h4,
                        ),
                      ),
                      decoration: InputDecoration(
                        hintText: '50 FCFA au minimum',
                        hintStyle: context.body1.copyWith(
                          color: context.secondaryTextColor.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.payments_rounded,
                          color: AppThemeSystem.freemopayColor,
                        ),
                        filled: true,
                        fillColor: context.inputFieldColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppThemeSystem.freemopayColor,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un montant';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount < appConfig.minWithdrawalAmount) {
                          return 'Montant minimum : ${appConfig.minWithdrawalAmount.toStringAsFixed(0)} FCFA';
                        }
                        if (amount > controller.freemopayBalance.value) {
                          return 'Solde insuffisant';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: context.sectionSpacing * 1.5),

                    // Boutons modernes
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(bottomSheetContext),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(
                                double.infinity,
                                context.buttonHeight,
                              ),
                              side: BorderSide(color: context.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text('Annuler', style: context.button),
                          ),
                        ),
                        SizedBox(width: context.elementSpacing),
                        Expanded(
                          flex: 3,
                          child: Obx(() {
                            final padding = context.horizontalPadding;
                            return ElevatedButton(
                              onPressed: controller.isProcessingPayment.value
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        final amount = double.parse(
                                          amountController.text,
                                        );

                                        final result = await controller
                                            .initiateFreeMoPayWithdrawal(
                                              amount: amount,
                                              paymentMethod: selectedMethod,
                                              phoneNumber: phoneController.text,
                                            );

                                        if (result['success'] == true) {
                                          if (bottomSheetContext.mounted)
                                            Navigator.pop(bottomSheetContext);
                                          Get.snackbar(
                                            'Succès',
                                            'Retrait initié avec succès',
                                            backgroundColor:
                                                AppThemeSystem.successColor,
                                            colorText:
                                                AppThemeSystem.whiteColor,
                                            snackPosition: SnackPosition.BOTTOM,
                                            margin: EdgeInsets.all(padding),
                                            borderRadius: 12,
                                          );
                                        } else {
                                          Get.snackbar(
                                            'Erreur',
                                            result['message'] ??
                                                'Une erreur est survenue',
                                            backgroundColor:
                                                AppThemeSystem.errorColor,
                                            colorText:
                                                AppThemeSystem.whiteColor,
                                            snackPosition: SnackPosition.BOTTOM,
                                            margin: EdgeInsets.all(padding),
                                            borderRadius: 12,
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(
                                  double.infinity,
                                  context.buttonHeight,
                                ),
                                backgroundColor: AppThemeSystem.freemopayColor,
                                foregroundColor: AppThemeSystem.whiteColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: controller.isProcessingPayment.value
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppThemeSystem.whiteColor,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Retirer',
                                          style: context.button.copyWith(
                                            color: AppThemeSystem.whiteColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(
                                          width: context.elementSpacing * 0.5,
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            );
                          }),
                        ),
                      ],
                    ),

                    SizedBox(height: context.elementSpacing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showModernPayPalBottomSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final emailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.all(context.horizontalPadding * 1.5),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar moderne
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(
                          bottom: context.elementSpacing * 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.borderColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header avec gradient
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.elementSpacing),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppThemeSystem.paypalColor,
                                AppThemeSystem.paypalColor.withValues(
                                  alpha: 0.7,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppThemeSystem.paypalColor.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.payment_rounded,
                            color: AppThemeSystem.whiteColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: context.elementSpacing * 1.2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Retrait PayPal',
                                style: context.h3.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Virement international',
                                style: context.caption.copyWith(
                                  color: context.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.primaryTextColor,
                          ),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          padding: EdgeInsets.all(context.elementSpacing * 0.5),
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            backgroundColor: context.borderColor.withValues(
                              alpha: 0.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: context.sectionSpacing),

                    // Solde disponible élégant
                    Container(
                      padding: EdgeInsets.all(context.elementSpacing * 1.2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppThemeSystem.paypalColor.withValues(alpha: 0.08),
                            AppThemeSystem.paypalColor.withValues(alpha: 0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppThemeSystem.paypalColor.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              context.elementSpacing * 0.6,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeSystem.paypalColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppThemeSystem.paypalColor,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: context.elementSpacing),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Solde disponible',
                                  style: context.caption.copyWith(
                                    color: context.secondaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Obx(
                                  () => Text(
                                    '${controller.paypalBalance.value.toStringAsFixed(0)} FCFA',
                                    style: context.h4.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppThemeSystem.paypalColor,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.sectionSpacing),

                    // Champs du formulaire
                    Text(
                      'Email PayPal',
                      style: context.subtitle2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: context.elementSpacing * 0.6),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: context.body1,
                      decoration: InputDecoration(
                        hintText: 'votre-email@paypal.com',
                        hintStyle: context.body1.copyWith(
                          color: context.secondaryTextColor.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.email_rounded,
                          color: AppThemeSystem.paypalColor,
                        ),
                        filled: true,
                        fillColor: context.inputFieldColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppThemeSystem.paypalColor,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un email';
                        }
                        if (!value.contains('@')) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: context.elementSpacing * 1.5),

                    Text(
                      'Montant (USD)',
                      style: context.subtitle2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: context.elementSpacing * 0.6),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: context.body1.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: AppThemeSystem.getFontSize(
                          context,
                          FontSizeType.h4,
                        ),
                      ),
                      decoration: InputDecoration(
                        hintText: '10 USD au minimum',
                        hintStyle: context.body1.copyWith(
                          color: context.secondaryTextColor.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.attach_money_rounded,
                          color: AppThemeSystem.paypalColor,
                        ),
                        filled: true,
                        fillColor: context.inputFieldColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppThemeSystem.paypalColor,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un montant';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount < 10) {
                          return 'Montant minimum : \$10 USD';
                        }
                        final amountInFcfa = amount * 600;
                        if (amountInFcfa > controller.paypalBalance.value) {
                          return 'Solde insuffisant';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: context.sectionSpacing * 1.5),

                    // Boutons modernes
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(bottomSheetContext),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(
                                double.infinity,
                                context.buttonHeight,
                              ),
                              side: BorderSide(color: context.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text('Annuler', style: context.button),
                          ),
                        ),
                        SizedBox(width: context.elementSpacing),
                        Expanded(
                          flex: 3,
                          child: Obx(() {
                            final padding = context.horizontalPadding;
                            return ElevatedButton(
                              onPressed: controller.isProcessingPayment.value
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        final amount = double.parse(
                                          amountController.text,
                                        );

                                        final result = await controller
                                            .initiatePayPalWithdrawal(
                                              amount: amount,
                                              paypalEmail: emailController.text,
                                            );

                                        if (result['success'] == true) {
                                          if (bottomSheetContext.mounted)
                                            Navigator.pop(bottomSheetContext);
                                          Get.snackbar(
                                            'Succès',
                                            'Retrait PayPal initié avec succès',
                                            backgroundColor:
                                                AppThemeSystem.successColor,
                                            colorText:
                                                AppThemeSystem.whiteColor,
                                            snackPosition: SnackPosition.BOTTOM,
                                            margin: EdgeInsets.all(padding),
                                            borderRadius: 12,
                                          );
                                        } else {
                                          Get.snackbar(
                                            'Erreur',
                                            result['message'] ??
                                                'Une erreur est survenue',
                                            backgroundColor:
                                                AppThemeSystem.errorColor,
                                            colorText:
                                                AppThemeSystem.whiteColor,
                                            snackPosition: SnackPosition.BOTTOM,
                                            margin: EdgeInsets.all(padding),
                                            borderRadius: 12,
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(
                                  double.infinity,
                                  context.buttonHeight,
                                ),
                                backgroundColor: AppThemeSystem.paypalColor,
                                foregroundColor: AppThemeSystem.whiteColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: controller.isProcessingPayment.value
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppThemeSystem.whiteColor,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Retirer',
                                          style: context.button.copyWith(
                                            color: AppThemeSystem.whiteColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(
                                          width: context.elementSpacing * 0.5,
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            );
                          }),
                        ),
                      ],
                    ),

                    SizedBox(height: context.elementSpacing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernRadioTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required String groupValue,
    required Color color,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: EdgeInsets.all(context.elementSpacing),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.05),
                  ],
                )
              : null,
          color: isSelected ? null : context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : context.borderColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : context.secondaryTextColor,
              size: 28,
            ),
            SizedBox(height: context.elementSpacing * 0.6),
            Text(
              subtitle,
              style: context.body2.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? color : context.primaryTextColor,
              ),
            ),
            SizedBox(height: 2),
            Text(
              title,
              style: context.caption.copyWith(
                color: context.secondaryTextColor,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
