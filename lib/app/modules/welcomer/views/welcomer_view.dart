import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/markdown_bottom_sheet.dart';
import '../controllers/welcomer_controller.dart';

/// Création de compte, premier écran après l'introduction.
///
/// Partage son ossature avec la connexion ([AuthScaffold]) : bandeau animé
/// puis formulaire sur une feuille claire. Passer de l'inscription à la
/// connexion ne fait donc plus changer la mise en page.
class WelcomerView extends GetView<WelcomerController> {
  const WelcomerView({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      animationAsset: 'assets/lotties/Sales and Consulting.json',
      title: 'welcomer.title'.tr,
      subtitle:
          'welcomer.subtitle'.tr,
      onSkip: controller.skipWelcome,
      // Formulaire long (trois champs, conditions, bouton) : un bandeau
      // aussi haut qu'à la connexion repoussait « Créer mon compte »
      // hors de l'écran à l'ouverture.
      bannerRatio: 0.18,
      children: [
        _buildForm(context),
        SizedBox(height: AppDesign.space5),
        _buildTermsRow(context),
        SizedBox(height: AppDesign.space5),
        _buildSubmit(context),
        SizedBox(height: AppDesign.space6),
        const AuthDivider(),
        SizedBox(height: AppDesign.space2),
        AuthSwitchLink(
          question: 'welcomer.have_account'.tr,
          action: 'welcomer.sign_in'.tr,
          onPressed: controller.goToLogin,
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'welcomer.email_label'.tr,
          hint: 'welcomer.email_hint'.tr,
          controller: controller.emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onChanged: (value) => controller.email.value = value,
        ),
        SizedBox(height: AppDesign.space4),
        Obx(
          () => AppTextField(
            label: 'welcomer.password_label'.tr,
            hint: 'welcomer.password_hint'.tr,
            controller: controller.passwordController,
            obscureText: controller.obscurePassword.value,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (value) => controller.password.value = value,
            helperText: 'welcomer.password_helper'.tr,
            suffixIcon: _visibilityToggle(
              context,
              isObscured: controller.obscurePassword.value,
              onPressed: controller.togglePasswordVisibility,
            ),
          ),
        ),
        SizedBox(height: AppDesign.space4),
        Obx(() {
          // L'écart entre les deux mots de passe est signalé pendant la
          // saisie, au lieu d'être découvert au moment de l'envoi.
          final confirm = controller.confirmPassword.value;
          final mismatch =
              confirm.isNotEmpty && confirm != controller.password.value;

          return AppTextField(
            label: 'welcomer.confirm_password_label'.tr,
            hint: 'welcomer.confirm_password_hint'.tr,
            controller: controller.confirmPasswordController,
            obscureText: controller.obscureConfirmPassword.value,
            textInputAction: TextInputAction.done,
            onChanged: (value) => controller.confirmPassword.value = value,
            errorText: mismatch ? 'welcomer.passwords_differ'.tr : null,
            suffixIcon: _visibilityToggle(
              context,
              isObscured: controller.obscureConfirmPassword.value,
              onPressed: controller.toggleConfirmPasswordVisibility,
            ),
          );
        }),
      ],
    );
  }

  Widget _visibilityToggle(
    BuildContext context, {
    required bool isObscured,
    required VoidCallback onPressed,
  }) {
    return AppIconButton(
      icon: isObscured
          ? Icons.visibility_off_outlined
          : Icons.visibility_outlined,
      size: 19,
      color: context.ds.textTertiary,
      tooltip: isObscured ? 'welcomer.show_password'.tr : 'welcomer.hide_password'.tr,
      onPressed: onPressed,
    );
  }

  Widget _buildTermsRow(BuildContext context) {
    // Toute la ligne coche la case : la seule case de 24 px était difficile
    // à atteindre. Le lien garde son propre geste et ouvre la politique.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.toggleTermsAccepted,
      child: Obx(
        () => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: controller.termsAccepted.value,
                onChanged: (value) =>
                    controller.termsAccepted.value = value ?? false,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            SizedBox(width: AppDesign.space3),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: context.textStyle(
                    FontSizeType.caption,
                    color: context.ds.textSecondary,
                    height: 1.45,
                  ),
                  children: [
                    TextSpan(text: 'welcomer.terms_prefix'.tr),
                    TextSpan(
                      text: 'welcomer.privacy_policy_link'.tr,
                      style: TextStyle(
                        color: AppDesign.accent,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => MarkdownBottomSheet.show(
                          context: context,
                          title: 'welcomer.privacy_policy_title'.tr,
                          assetPath: 'Politique de confidentialité.md',
                        ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmit(BuildContext context) {
    return Obx(
      () => AppButton(
        label: 'welcomer.submit'.tr,
        size: AppButtonSize.large,
        isLoading: controller.isLoading.value,
        onPressed: controller.canSubmit
            ? controller.createAccountWithEmail
            : null,
      ),
    );
  }
}
