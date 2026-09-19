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
      title: 'Créer votre compte',
      subtitle:
          'Achetez, vendez et suivez vos commandes depuis un seul endroit.',
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
          question: 'Vous avez déjà un compte ?',
          action: 'Se connecter',
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
          label: 'Adresse e-mail',
          hint: 'exemple@email.com',
          controller: controller.emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onChanged: (value) => controller.email.value = value,
        ),
        SizedBox(height: AppDesign.space4),
        Obx(
          () => AppTextField(
            label: 'Mot de passe',
            hint: 'Au moins 6 caractères',
            controller: controller.passwordController,
            obscureText: controller.obscurePassword.value,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (value) => controller.password.value = value,
            helperText: 'Utilisez 6 caractères ou plus.',
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
            label: 'Confirmer le mot de passe',
            hint: 'Saisissez à nouveau le mot de passe',
            controller: controller.confirmPasswordController,
            obscureText: controller.obscureConfirmPassword.value,
            textInputAction: TextInputAction.done,
            onChanged: (value) => controller.confirmPassword.value = value,
            errorText: mismatch ? 'Les deux mots de passe diffèrent.' : null,
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
      tooltip: isObscured ? 'Afficher' : 'Masquer',
      onPressed: onPressed,
    );
  }

  Widget _buildTermsRow(BuildContext context) {
    return Obx(
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
                  const TextSpan(text: "J'accepte la "),
                  TextSpan(
                    text: 'politique de confidentialité',
                    style: TextStyle(
                      color: AppDesign.accent,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => MarkdownBottomSheet.show(
                        context: context,
                        title: 'Politique de confidentialité',
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
    );
  }

  Widget _buildSubmit(BuildContext context) {
    return Obx(
      () => AppButton(
        label: 'Créer mon compte',
        size: AppButtonSize.large,
        isLoading: controller.isLoading.value,
        onPressed: controller.isFormValid.value
            ? controller.createAccountWithEmail
            : null,
      ),
    );
  }
}
