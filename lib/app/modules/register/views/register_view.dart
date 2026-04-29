import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/markdown_bottom_sheet.dart';
import '../controllers/register_controller.dart';

class RegisterView extends GetView<RegisterController> {
  const RegisterView({super.key});

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

              // Checkbox d'acceptation des CGU
              _buildTermsCheckbox(context),

              SizedBox(height: context.sectionSpacing),

              // Bouton d'inscription
              _buildRegisterButton(context),

              SizedBox(height: context.sectionSpacing),

              // Séparateur "OU"
              _buildDivider(context),

              SizedBox(height: context.sectionSpacing),

              // Boutons de connexion sociale
              _buildSocialButtons(context),

              SizedBox(height: context.sectionSpacing),

              // Lien vers connexion
              _buildLoginLink(context),
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
          borderRadius: context.borderRadius(BorderRadiusType.large),
          boxShadow: [
            BoxShadow(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: context.borderRadius(BorderRadiusType.large),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
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
          'Créer un compte',
          textAlign: TextAlign.center,
          style: context.h1.copyWith(
            color: context.primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: context.elementSpacing),

        // Description
        Text(
          'Inscrivez-vous pour commencer votre expérience',
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
      ],
    );
  }

  /// Bouton d'inscription
  Widget _buildRegisterButton(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isLoading.value;
      final isValid = controller.isPhoneValid.value;

      return SizedBox(
        width: double.infinity,
        height: context.buttonHeight,
        child: ElevatedButton(
          onPressed: (isValid && !isLoading) ? controller.register : null,
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
                  'S\'inscrire',
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

  /// Boutons de connexion sociale
  Widget _buildSocialButtons(BuildContext context) {
    return Row(
      children: [
        // Google
        Expanded(
          child: _buildSocialButton(
            context,
            icon: Icons.g_mobiledata_rounded,
            label: 'Google',
            backgroundColor: Colors.white,
            textColor: AppThemeSystem.grey800,
            borderColor: AppThemeSystem.grey300,
            onPressed: () {
              // TODO: Implémenter Google Sign In
            },
          ),
        ),

        SizedBox(width: context.elementSpacing),

        // Apple
        Expanded(
          child: _buildSocialButton(
            context,
            icon: Icons.apple_rounded,
            label: 'Apple',
            backgroundColor: const Color(0xFF8BC34A),
            textColor: Colors.white,
            onPressed: () {
              // TODO: Implémenter Apple Sign In
            },
          ),
        ),
      ],
    );
  }

  /// Un bouton de connexion sociale
  Widget _buildSocialButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: borderColor != null ? 0 : 1,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            side: borderColor != null
                ? BorderSide(color: borderColor, width: 1.5)
                : BorderSide.none,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: textColor),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lien vers connexion
  Widget _buildLoginLink(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: controller.goToLogin,
        child: RichText(
          text: TextSpan(
            style: context.body2.copyWith(
              color: context.secondaryTextColor,
            ),
            children: [
              const TextSpan(text: 'Vous avez déjà un compte ? '),
              TextSpan(
                text: 'Se connecter',
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

  /// Checkbox d'acceptation de la Politique de Confidentialité
  Widget _buildTermsCheckbox(BuildContext context) {
    return Obx(() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: controller.termsAccepted.value,
          onChanged: (value) {
            controller.termsAccepted.value = value ?? false;
          },
          activeColor: AppThemeSystem.primaryColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(
                style: context.caption.copyWith(
                  color: context.secondaryTextColor,
                ),
                children: [
                  const TextSpan(text: 'En continuant, vous acceptez notre '),
                  TextSpan(
                    text: 'Politique de Confidentialité',
                    style: TextStyle(
                      color: AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        MarkdownBottomSheet.show(
                          context: context,
                          title: 'Politique de Confidentialité',
                          assetPath: 'Politique de confidentialité.md',
                        );
                      },
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    ));
  }
}
