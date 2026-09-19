import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/markdown_bottom_sheet.dart';
import '../controllers/welcomer_controller.dart';

/// Création de compte, premier écran après l'introduction.
///
/// La mise en page a été resserrée : l'illustration occupait plus du
/// tiers de la hauteur et repoussait le formulaire hors de l'écran. Les
/// champs portent désormais un libellé permanent et le mot de passe indique
/// sa règle de validité avant l'envoi plutôt qu'après.
class WelcomerView extends GetView<WelcomerController> {
  const WelcomerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ds.canvas,
      body: SafeArea(
        child: AppContentWidth(
          maxWidth: 520,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppDesign.space2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: controller.skipWelcome,
                      style: TextButton.styleFrom(
                        foregroundColor: context.ds.textSecondary,
                      ),
                      child: Text(
                        'Passer',
                        style: context.textStyle(
                          FontSizeType.body2,
                          fontWeight: FontWeight.w600,
                          color: context.ds.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    context.ds.gutter,
                    0,
                    context.ds.gutter,
                    AppDesign.space8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      SizedBox(height: AppDesign.space8),
                      _buildForm(context),
                      SizedBox(height: AppDesign.space5),
                      _buildTermsRow(context),
                      SizedBox(height: AppDesign.space5),
                      _buildSubmit(context),
                      SizedBox(height: AppDesign.space6),
                      _buildLoginLink(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Le logo de marque remplace l'illustration jaune, dont la palette
        // n'avait aucun rapport avec l'identité de l'application.
        Container(
          width: 72,
          height: 72,
          padding: EdgeInsets.all(AppDesign.space3),
          decoration: BoxDecoration(
            color: context.ds.surface,
            shape: BoxShape.circle,
            border: Border.all(color: context.ds.border),
          ),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
        SizedBox(height: AppDesign.space5),
        Text(
          'Créer votre compte',
          textAlign: TextAlign.center,
          style: context.textStyle(
            FontSizeType.h4,
            fontWeight: FontWeight.w700,
            color: context.ds.textPrimary,
          ),
        ),
        SizedBox(height: AppDesign.space2),
        Text(
          'Achetez, vendez et suivez vos commandes depuis un seul endroit.',
          textAlign: TextAlign.center,
          style: context.textStyle(
            FontSizeType.body2,
            color: context.ds.textSecondary,
            height: 1.5,
          ),
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

  Widget _buildLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Vous avez déjà un compte ?',
            style: context.textStyle(
              FontSizeType.body2,
              color: context.ds.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: controller.goToLogin,
          child: Text(
            'Se connecter',
            style: context.textStyle(
              FontSizeType.body2,
              fontWeight: FontWeight.w600,
              color: AppDesign.accent,
            ),
          ),
        ),
      ],
    );
  }
}
