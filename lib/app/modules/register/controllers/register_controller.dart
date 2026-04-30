import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/services/firebase_messaging_service.dart';
import '../../../routes/app_pages.dart';

class RegisterController extends GetxController {
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
    developer.log('========== REGISTER CONTROLLER INIT ==========', name: 'RegisterController');
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();

    ever(email, (_) => _validateForm());
    ever(password, (_) => _validateForm());
    ever(confirmPassword, (_) => _validateForm());
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  void _validateForm() {
    final emailValid = GetUtils.isEmail(email.value);
    final passwordValid = password.value.length >= 6;
    final passwordsMatch = password.value == confirmPassword.value;

    isFormValid.value = emailValid && passwordValid && passwordsMatch;

    developer.log(
      'Form validation',
      name: 'RegisterController',
      error: 'Email: $emailValid, Password: $passwordValid, Match: $passwordsMatch, Valid: ${isFormValid.value}',
    );
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword.value = !obscureConfirmPassword.value;
  }

  Future<void> register() async {
    developer.log(
      '========== REGISTER ATTEMPT ==========',
      name: 'RegisterController',
      error: 'Email: ${email.value}',
    );

    if (!isFormValid.value) {
      developer.log('Invalid form', name: 'RegisterController');

      if (!GetUtils.isEmail(email.value)) {
        Get.snackbar(
          'Email invalide',
          'Veuillez entrer une adresse email valide',
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
          'Mot de passe trop court',
          'Le mot de passe doit contenir au moins 6 caractères',
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
          'Mots de passe différents',
          'Les mots de passe ne correspondent pas',
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
      developer.log('Terms not accepted', name: 'RegisterController');
      Get.snackbar(
        'Politique requise',
        'Veuillez accepter notre Politique de Confidentialité pour continuer',
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
        name: 'RegisterController',
        error: 'Success: ${response.success}, Message: ${response.message}',
      );

      if (response.success) {
        developer.log(
          'Registration successful - OTP sent to email',
          name: 'RegisterController',
          error: 'Email: ${email.value}',
        );

        Get.snackbar(
          'Code envoyé',
          'Un code de vérification a été envoyé à ${email.value}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );

        await Future.delayed(const Duration(milliseconds: 500));

        developer.log('Navigating to OTP screen', name: 'RegisterController');
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
          name: 'RegisterController',
          error: response.message,
        );
        Get.snackbar(
          'Erreur',
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
        'Register error',
        name: 'RegisterController',
        error: e,
        stackTrace: stackTrace,
      );
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue. Veuillez réessayer.',
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

  void goToLogin() {
    developer.log('Navigating to login', name: 'RegisterController');
    Get.offNamed(Routes.LOGIN);
  }
}
