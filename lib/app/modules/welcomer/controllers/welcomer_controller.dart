import 'package:asso/app/core/utils/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/guest_access.dart';
import '../../../routes/app_pages.dart';

class WelcomerController extends GetxController {
  // Prénom et nom facultatifs : sans eux, le compte s'affiche « Utilisateur ».
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;

  final email = ''.obs;
  final password = ''.obs;
  final confirmPassword = ''.obs;
  final isLoading = false.obs;
  final isFormValid = false.obs;
  final termsAccepted = false.obs;
  final obscurePassword = true.obs;
  final obscureConfirmPassword = true.obs;

  @override
  void onInit() {
    super.onInit();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();

    ever(email, (_) => _validateForm());
    ever(password, (_) => _validateForm());
    ever(confirmPassword, (_) => _validateForm());
  }

  void _validateForm() {
    final emailValid = GetUtils.isEmail(email.value);
    final passwordValid = password.value.length >= 6;
    final passwordsMatch = password.value == confirmPassword.value;

    isFormValid.value = emailValid && passwordValid && passwordsMatch;

  }

  /// La création de compte n'est proposée qu'une fois le formulaire valide
  /// ET la politique de confidentialité acceptée : le bouton reste inactif
  /// tant que la case n'est pas cochée.
  bool get canSubmit => isFormValid.value && termsAccepted.value;

  void toggleTermsAccepted() {
    termsAccepted.value = !termsAccepted.value;
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword.value = !obscureConfirmPassword.value;
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Visiter l'application sans compte.
  ///
  /// La séquence est partagée avec la connexion, pour que « Passer » se
  /// comporte de la même façon d'un écran à l'autre.
  Future<void> skipWelcome() => GuestAccess.enter();

  Future<void> createAccountWithEmail() async {

    if (!isFormValid.value) {

      if (!GetUtils.isEmail(email.value)) {
        AppFeedback.show(
          'welcomer.invalid_email_title'.tr,
          'welcomer.invalid_email_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      if (password.value.length < 6) {
        AppFeedback.show(
          'welcomer.password_too_short_title'.tr,
          'welcomer.password_too_short_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      if (password.value != confirmPassword.value) {
        AppFeedback.show(
          'welcomer.passwords_mismatch_title'.tr,
          'welcomer.passwords_mismatch_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      return;
    }

    if (!termsAccepted.value) {
      AppFeedback.show(
        'welcomer.policy_required_title'.tr,
        'welcomer.policy_required_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    isLoading.value = true;

    try {
      // Register with email
      final response = await AuthService.registerWithEmail(
        email: email.value,
        password: password.value,
        passwordConfirmation: confirmPassword.value,
        firstName: _optional(firstNameController.text),
        lastName: _optional(lastNameController.text),
      );


      if (response.success) {

        AppFeedback.show(
          'welcomer.code_sent_title'.tr,
          'welcomer.code_sent_message'.trParams({'email': email.value}),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );

        await Future.delayed(const Duration(milliseconds: 500));

        Get.toNamed(
          Routes.OTP,
          arguments: {
            'email': email.value,
            'isNewUser': true,
            'isEmailAuth': true,
          },
        );
      } else {
        AppFeedback.show(
          'common.error'.tr,
          response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e, stackTrace) {
      AppFeedback.show(
        'common.error'.tr,
        'common.generic_error_retry'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void continueWithGoogle() {
    AppFeedback.show(
      'Google',
      'welcomer.google_signing_in'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Implémenter l'authentification Google
    Get.offAllNamed(Routes.HOME);
  }

  void continueWithApple() {
    AppFeedback.show(
      'Apple',
      'welcomer.apple_signing_in'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Implémenter l'authentification Apple
    Get.offAllNamed(Routes.HOME);
  }

  Future<void> continueAsGuest() => GuestAccess.enter();

  void goToLogin() {
    Get.toNamed(Routes.LOGIN);
  }
}
