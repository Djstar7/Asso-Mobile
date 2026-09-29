import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/guest_access.dart';
import '../../../routes/app_pages.dart';

class WelcomerController extends GetxController {
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
    developer.log(
      '========== WELCOMER CONTROLLER INIT ==========',
      name: 'WelcomerController',
    );
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

    developer.log(
      'Form validation',
      name: 'WelcomerController',
      error:
          'Email: $emailValid, Password: $passwordValid, Match: $passwordsMatch, Valid: ${isFormValid.value}',
    );
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
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  /// Visiter l'application sans compte.
  ///
  /// La séquence est partagée avec la connexion, pour que « Passer » se
  /// comporte de la même façon d'un écran à l'autre.
  Future<void> skipWelcome() => GuestAccess.enter();

  Future<void> createAccountWithEmail() async {
    developer.log(
      '========== CREATE ACCOUNT WITH EMAIL ==========',
      name: 'WelcomerController',
      error: 'Email: ${email.value}',
    );

    if (!isFormValid.value) {
      developer.log('Invalid form', name: 'WelcomerController');

      if (!GetUtils.isEmail(email.value)) {
        Get.snackbar(
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
        Get.snackbar(
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
        Get.snackbar(
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
      developer.log('Terms not accepted', name: 'WelcomerController');
      Get.snackbar(
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
      );

      developer.log(
        'Register response',
        name: 'WelcomerController',
        error: 'Success: ${response.success}, Message: ${response.message}',
      );

      if (response.success) {
        developer.log(
          'Registration successful - OTP sent to email',
          name: 'WelcomerController',
          error: 'Email: ${email.value}',
        );

        Get.snackbar(
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

        developer.log('Navigating to OTP screen', name: 'WelcomerController');
        Get.toNamed(
          Routes.OTP,
          arguments: {
            'email': email.value,
            'isNewUser': true,
            'isEmailAuth': true,
          },
        );
      } else {
        developer.log(
          'Registration failed',
          name: 'WelcomerController',
          error: response.message,
        );
        Get.snackbar(
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
      developer.log(
        'Create account error',
        name: 'WelcomerController',
        error: e,
        stackTrace: stackTrace,
      );
      Get.snackbar(
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
    developer.log('Continue with Google', name: 'WelcomerController');
    Get.snackbar(
      'Google',
      'welcomer.google_signing_in'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Implémenter l'authentification Google
    Get.offAllNamed(Routes.HOME);
  }

  void continueWithApple() {
    developer.log('Continue with Apple', name: 'WelcomerController');
    Get.snackbar(
      'Apple',
      'welcomer.apple_signing_in'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Implémenter l'authentification Apple
    Get.offAllNamed(Routes.HOME);
  }

  Future<void> continueAsGuest() => GuestAccess.enter();

  void goToLogin() {
    developer.log('Go to login', name: 'WelcomerController');
    Get.toNamed(Routes.LOGIN);
  }
}
