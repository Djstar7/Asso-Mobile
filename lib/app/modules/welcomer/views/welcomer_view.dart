import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:lottie/lottie.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/markdown_bottom_sheet.dart';
import '../controllers/welcomer_controller.dart';

class WelcomerView extends GetView<WelcomerController> {
  const WelcomerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            // Bouton SAUTER en haut à droite
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppThemeSystem.getHorizontalPadding(context),
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: controller.skipWelcome,
                    child: Text(
                      'SAUTER',
                      style: context.textStyle(
                        FontSizeType.button,
                        color: AppThemeSystem.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenu principal avec scroll si nécessaire
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: AppThemeSystem.getHorizontalPadding(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Animation Lottie compacte
                    SizedBox(
                      height: AppThemeSystem.getDeviceType(context) == DeviceType.mobile ? 200 : 240,
                      child: Lottie.asset(
                        'assets/lotties/Sales and Consulting.json',
                        fit: BoxFit.contain,
                        repeat: true,
                        animate: true,
                      ),
                    ),

                    SizedBox(height: AppThemeSystem.getElementSpacing(context)),

                    // Titre
                    Text(
                      'Marketplace Asso',
                      textAlign: TextAlign.center,
                      style: context.textStyle(
                        FontSizeType.h2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 8),

                    // Slogan
                    Text(
                      'Ton marché dans ta poche',
                      textAlign: TextAlign.center,
                      style: context.textStyle(
                        FontSizeType.subtitle1,
                        color: AppThemeSystem.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

                    // Input numéro de téléphone avec country picker
                    IntlPhoneField(
                      controller: controller.phoneController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        border: OutlineInputBorder(
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                          borderSide: BorderSide(color: AppThemeSystem.grey300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                          borderSide: BorderSide(color: AppThemeSystem.grey300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                          borderSide: BorderSide(color: AppThemeSystem.primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: AppThemeSystem.getSurfaceColor(context),
                      ),
                      initialCountryCode: 'CM', // Cameroun par défaut
                      onChanged: (phone) {
                        controller.phoneNumber.value = phone.completeNumber;
                        controller.countryCode.value = phone.countryCode;
                        controller.rawPhone.value = phone.number;
                      },
                      style: context.textStyle(FontSizeType.body1),
                    ),

                    SizedBox(height: AppThemeSystem.getElementSpacing(context)),

                    // Checkbox d'acceptation de la Politique de Confidentialité
                    Obx(() => Row(
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
                                style: context.textStyle(
                                  FontSizeType.caption,
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
                    )),

                    SizedBox(height: AppThemeSystem.getElementSpacing(context)),

                    // Bouton principal "Créer mon compte"
                    Obx(() {
                      final isLoading = controller.isLoading.value;
                      final isValid = controller.isPhoneValid.value;

                      return SizedBox(
                        width: double.infinity,
                        height: AppThemeSystem.getButtonHeight(context),
                        child: ElevatedButton(
                          onPressed: (isValid && !isLoading) ? controller.createAccountWithPhone : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeSystem.primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppThemeSystem.grey300,
                            disabledForegroundColor: AppThemeSystem.grey600,
                            shape: RoundedRectangleBorder(
                              borderRadius: context.borderRadius(BorderRadiusType.medium),
                            ),
                            elevation: 2,
                          ),
                          child: isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Créer mon compte',
                                  style: context.textStyle(
                                    FontSizeType.button,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      );
                    }),

                    SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

                    // Séparateur "OU"
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppThemeSystem.grey300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OU',
                            style: context.textStyle(
                              FontSizeType.caption,
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppThemeSystem.grey300)),
                      ],
                    ),

                    SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

                    // Lien "Continuer en tant qu'invité"
                    TextButton(
                      onPressed: controller.continueAsGuest,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: context.secondaryTextColor,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Continuer en tant qu\'invité',
                            style: context.textStyle(
                              FontSizeType.body2,
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: AppThemeSystem.getElementSpacing(context)),

                    // Lien "Se connecter"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Vous avez déjà un compte ? ',
                          style: context.textStyle(
                            FontSizeType.body2,
                            color: context.secondaryTextColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: controller.goToLogin,
                          child: Text(
                            'Se connecter',
                            style: context.textStyle(
                              FontSizeType.body2,
                              color: AppThemeSystem.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: AppThemeSystem.getVerticalPadding(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton(
    BuildContext context, {
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
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
}
