import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/login_controller.dart';
import '../../../data/providers/auth_service.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/utils/app_design.dart';

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

              // Formulaire email et mot de passe
              _buildEmailForm(context),

              SizedBox(height: context.elementSpacing),

              _buildPasswordForm(context),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showPasswordReset(context),
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),

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

  /// Formulaire email
  Widget _buildEmailForm(BuildContext context) {
    return AppTextField(
      label: 'Adresse e-mail',
      hint: 'exemple@email.com',
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
        label: 'Mot de passe',
        hint: 'Votre mot de passe',
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
          tooltip: controller.obscurePassword.value ? 'Afficher' : 'Masquer',
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
          title: const Text('Réinitialiser le mot de passe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Le libellé de l'étape en cours : sans lui, on recevait un
              // code sans savoir qu'il fallait revenir ici pour le saisir.
              Text(
                codeSent
                    ? 'Saisissez le code reçu par e-mail, puis votre nouveau mot de passe.'
                    : 'Nous vous enverrons un code de vérification à cette adresse.',
                style: context.textStyle(
                  FontSizeType.caption,
                  color: context.ds.textSecondary,
                  height: 1.45,
                ),
              ),
              SizedBox(height: AppDesign.space4),
              AppTextField(
                label: 'Adresse e-mail',
                hint: 'exemple@email.com',
                controller: email,
                enabled: !codeSent,
                keyboardType: TextInputType.emailAddress,
              ),
              if (codeSent) ...[
                SizedBox(height: AppDesign.space4),
                AppTextField(
                  label: 'Code reçu',
                  hint: '6 chiffres',
                  controller: code,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: AppDesign.space4),
                AppTextField(
                  label: 'Nouveau mot de passe',
                  hint: 'Au moins 6 caractères',
                  controller: password,
                  obscureText: true,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
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
                                    ? 'Opération réussie'
                                    : 'Une erreur est survenue'),
                          ),
                        ),
                      );
                      if (response.success) {
                        if (codeSent)
                          Navigator.pop(dialogContext);
                        else
                          setState(() => codeSent = true);
                      }
                    },
              child: Text(
                loading
                    ? 'Veuillez patienter…'
                    : (codeSent ? 'Modifier' : 'Envoyer le code'),
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

  /// Bouton de connexion
  Widget _buildLoginButton(BuildContext context) {
    return Obx(
      () => AppButton(
        label: 'Se connecter',
        size: AppButtonSize.large,
        isLoading: controller.isLoading.value,
        onPressed: controller.isFormValid.value ? controller.login : null,
      ),
    );
  }

  /// Séparateur "OU"
  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: context.borderColor)),
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
        Expanded(child: Container(height: 1, color: context.borderColor)),
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
            style: context.body2.copyWith(color: context.secondaryTextColor),
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
