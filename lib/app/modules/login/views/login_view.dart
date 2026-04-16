import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: context.sectionSpacing),

              // Logo ASSO
              _buildLogo(context),

              SizedBox(height: context.sectionSpacing * 1.5),

              // Titre et description
              _buildHeader(context),

              SizedBox(height: context.sectionSpacing * 1.5),

              // Formulaire de téléphone avec country picker
              _buildPhoneForm(context),

              SizedBox(height: context.sectionSpacing),

              // Bouton de connexion
              _buildLoginButton(context),

              SizedBox(height: context.sectionSpacing),

              // Séparateur "OU"
              _buildDivider(context),

              SizedBox(height: context.sectionSpacing),
              
              // Lien vers inscription
              _buildRegisterLink(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Logo ASSO
  Widget _buildLogo(BuildContext context) {
    final deviceType = context.deviceType;
    double logoSize;

    switch (deviceType) {
      case DeviceType.mobile:
        logoSize = 120;
        break;
      case DeviceType.tablet:
        logoSize = 140;
        break;
      case DeviceType.largeTablet:
        logoSize = 160;
        break;
      case DeviceType.iPadPro13:
        logoSize = 180;
        break;
      case DeviceType.desktop:
        logoSize = 160;
        break;
    }

    return Hero(
      tag: 'logo',
      child: Container(
        width: logoSize,
        height: logoSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
            width: logoSize,
            height: logoSize,
          ),
        ),
      ),
    );
  }

  /// En-tête avec titre et description
  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Titre
        Text(
          'Bon retour !',
          textAlign: TextAlign.center,
          style: context.h1.copyWith(
            color: context.primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: context.elementSpacing),

        // Description
        Text(
          'Connectez-vous pour accéder à votre compte',
          textAlign: TextAlign.center,
          style: context.body1.copyWith(
            color: context.secondaryTextColor,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// Formulaire de téléphone avec country picker
  Widget _buildPhoneForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'Numéro de téléphone',
          style: context.subtitle1.copyWith(
            color: context.primaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),

        SizedBox(height: context.elementSpacing),

        // Champ de téléphone avec country picker
        IntlPhoneField(
          controller: controller.phoneController,
          decoration: InputDecoration(
            hintText: 'Entrez votre numéro',
            hintStyle: context.body1.copyWith(
              color: context.secondaryTextColor,
            ),
            border: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: const BorderSide(
                color: AppThemeSystem.primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: context.inputFieldColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.horizontalPadding,
              vertical: context.verticalPadding * 0.75,
            ),
          ),
          initialCountryCode: 'CM', // Cameroun par défaut
          onChanged: (phone) {
            controller.onPhoneChanged(phone.number, phone.countryCode);
          },
          style: context.body1.copyWith(
            color: context.primaryTextColor,
          ),
          dropdownTextStyle: context.body2.copyWith(
            color: context.primaryTextColor,
          ),
        ),

        SizedBox(height: context.elementSpacing * 0.5),

        // Info
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: AppThemeSystem.getFontSize(context, FontSizeType.caption),
              color: context.secondaryTextColor,
            ),
            SizedBox(width: context.elementSpacing * 0.5),
            Expanded(
              child: Text(
                'Nous vous enverrons un code de vérification par SMS',
                style: context.caption.copyWith(
                  color: context.secondaryTextColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Bouton de connexion
  Widget _buildLoginButton(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isLoading.value;
      final isValid = controller.isPhoneValid.value;

      return SizedBox(
        width: double.infinity,
        height: context.buttonHeight,
        child: ElevatedButton(
          onPressed: (isValid && !isLoading) ? controller.login : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeSystem.primaryColor,
            foregroundColor: AppThemeSystem.whiteColor,
            disabledBackgroundColor: context.borderColor,
            disabledForegroundColor: context.secondaryTextColor,
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
            ),
            elevation: context.elevation(ElevationType.low),
          ),
          child: isLoading
              ? SizedBox(
                  height: AppThemeSystem.getFontSize(context, FontSizeType.h5),
                  width: AppThemeSystem.getFontSize(context, FontSizeType.h5),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppThemeSystem.whiteColor,
                    ),
                  ),
                )
              : Text(
                  'Se connecter',
                  style: context.button.copyWith(
                    color: AppThemeSystem.whiteColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    });
  }

  /// Séparateur "OU"
  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: context.borderColor,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.elementSpacing),
          child: Text(
            'OU',
            style: context.caption.copyWith(
              color: context.secondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: context.borderColor,
          ),
        ),
      ],
    );
  }
  /// Lien vers inscription
  Widget _buildRegisterLink(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: controller.goToRegister,
        child: RichText(
          text: TextSpan(
            style: context.body2.copyWith(
              color: context.secondaryTextColor,
            ),
            children: [
              const TextSpan(text: 'Pas encore de compte ? '),
              TextSpan(
                text: 'S\'inscrire',
                style: context.body2.copyWith(
                  color: AppThemeSystem.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
