import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../data/providers/auth_service.dart';
import '../controllers/login_controller.dart';

/// Connexion.
///
/// L'écran repose sur [AuthScaffold] : bandeau animé, puis formulaire sur une
/// feuille claire. La visite sans compte est proposée ici comme à
/// l'inscription — on ne force pas à créer un compte pour regarder le
/// catalogue.
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      animationAsset: 'assets/lotties/Ecommerce.json',
      title: 'login.title'.tr,
      subtitle: 'login.subtitle'.tr,
      onSkip: controller.continueAsGuest,
      children: [
        _buildEmailForm(context),
        SizedBox(height: AppDesign.space4),
        _buildPasswordForm(context),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showPasswordReset(context),
            // Sans couleur explicite, le lien tombe sur le violet Material
            // par défaut, étranger à la palette de l'application.
            style: TextButton.styleFrom(foregroundColor: AppDesign.accent),
            child: Text(
              'login.forgot_password'.tr,
              style: context.textStyle(
                FontSizeType.caption,
                fontWeight: FontWeight.w600,
                color: AppDesign.accent,
              ),
            ),
          ),
        ),
        SizedBox(height: AppDesign.space3),
        _buildLoginButton(context),
        SizedBox(height: AppDesign.space6),
        const AuthDivider(),
        SizedBox(height: AppDesign.space2),
        AuthSwitchLink(
          question: 'login.no_account'.tr,
          action: 'login.sign_up'.tr,
          onPressed: controller.goToRegister,
        ),
      ],
    );
  }

  /// Formulaire email
  Widget _buildEmailForm(BuildContext context) {
    return AppTextField(
      label: 'welcomer.email_label'.tr,
      hint: 'welcomer.email_hint'.tr,
      controller: controller.emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      onChanged: (value) => controller.email.value = value,
    );
  }

  /// Formulaire mot de passe
  Widget _buildPasswordForm(BuildContext context) {
    return Obx(
      () => AppTextField(
        label: 'welcomer.password_label'.tr,
        hint: 'login.password_hint'.tr,
        controller: controller.passwordController,
        obscureText: controller.obscurePassword.value,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        onChanged: (value) => controller.password.value = value,
        // La connexion part directement depuis le clavier, sans obliger à
        // le refermer pour atteindre le bouton.
        onSubmitted: (_) {
          if (controller.isFormValid.value && !controller.isLoading.value) {
            controller.login();
          }
        },
        suffixIcon: AppIconButton(
          icon: controller.obscurePassword.value
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 19,
          color: context.ds.textTertiary,
          tooltip: controller.obscurePassword.value ? 'welcomer.show_password'.tr : 'welcomer.hide_password'.tr,
          onPressed: controller.togglePasswordVisibility,
        ),
      ),
    );
  }

  /// Bouton de connexion
  Future<void> _showPasswordReset(BuildContext context) async {
    final email = TextEditingController(text: controller.email.value);
    final code = TextEditingController();
    final password = TextEditingController();
    var codeSent = false;
    var loading = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('login.reset.title'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Le libellé de l'étape en cours : sans lui, on recevait un
              // code sans savoir qu'il fallait revenir ici pour le saisir.
              Text(
                codeSent
                    ? 'login.reset.enter_code'.tr
                    : 'login.reset.will_send_code'.tr,
                style: context.textStyle(
                  FontSizeType.caption,
                  color: context.ds.textSecondary,
                  height: 1.45,
                ),
              ),
              SizedBox(height: AppDesign.space4),
              AppTextField(
                label: 'welcomer.email_label'.tr,
                hint: 'welcomer.email_hint'.tr,
                controller: email,
                enabled: !codeSent,
                keyboardType: TextInputType.emailAddress,
              ),
              if (codeSent) ...[
                SizedBox(height: AppDesign.space4),
                AppTextField(
                  label: 'login.reset.code_label'.tr,
                  hint: 'login.reset.code_hint'.tr,
                  controller: code,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: AppDesign.space4),
                AppTextField(
                  label: 'login.reset.new_password'.tr,
                  hint: 'welcomer.password_hint'.tr,
                  controller: password,
                  obscureText: true,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: Text('common.cancel'.tr),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() => loading = true);
                      final response = codeSent
                          ? await AuthService.resetPassword(
                              email: email.text.trim(),
                              code: code.text.trim(),
                              password: password.text,
                            )
                          : await AuthService.requestPasswordReset(
                              email.text.trim(),
                            );
                      if (!dialogContext.mounted) return;
                      setState(() => loading = false);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            response.message ??
                                (response.success
                                    ? 'login.reset.success'.tr
                                    : 'common.generic_error'.tr),
                          ),
                        ),
                      );
                      if (response.success) {
                        if (codeSent) {
                          Navigator.pop(dialogContext);
                        } else {
                          setState(() => codeSent = true);
                        }
                      }
                    },
              child: Text(
                loading
                    ? 'common.please_wait'.tr
                    : (codeSent ? 'common.edit'.tr : 'login.reset.send_code'.tr),
              ),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    code.dispose();
    password.dispose();
  }

  /// Action principale de l'écran.
  Widget _buildLoginButton(BuildContext context) {
    return Obx(
      () => AppButton(
        label: 'welcomer.sign_in'.tr,
        size: AppButtonSize.large,
        isLoading: controller.isLoading.value,
        onPressed: controller.isFormValid.value ? controller.login : null,
      ),
    );
  }
}
