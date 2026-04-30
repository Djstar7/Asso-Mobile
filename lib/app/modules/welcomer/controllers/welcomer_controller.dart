import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/services/firebase_messaging_service.dart';
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
      error: 'Email: $emailValid, Password: $passwordValid, Match: $passwordsMatch, Valid: ${isFormValid.value}',
    );
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

  void skipWelcome() async {
    developer.log('Skip welcome - going to GUEST MODE', name: 'WelcomerController');

    // Enable guest mode
    developer.log('🔓 Enabling guest mode', name: 'WelcomerController');
    StorageService.enableGuestMode();

    // S'abonner au topic des annonces même en mode invité
    developer.log('📱 Subscribing to announcements topic as guest...', name: 'WelcomerController');
    try {
      await FirebaseMessagingService.to.subscribeToAnnouncementsTopic();
      developer.log('✅ Subscribed to announcements topic', name: 'WelcomerController');
    } catch (e) {
      developer.log(
        'Error subscribing to announcements topic',
        name: 'WelcomerController',
        error: e,
      );
      // On ne bloque pas la navigation même si l'opération échoue
    }

    // Check if user has selected a country
    if (!StorageService.hasSelectedCountry) {
      developer.log('No country selected - navigating to COUNTRY_SELECTION', name: 'WelcomerController');
      Get.offAllNamed(Routes.COUNTRY_SELECTION);
    } else {
      developer.log('Country already selected - navigating to HOME', name: 'WelcomerController');
      Get.offAllNamed(Routes.HOME);
    }
  }

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
      developer.log('Terms not accepted', name: 'WelcomerController');
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
        'Create account error',
        name: 'WelcomerController',
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

  void continueWithGoogle() {
    developer.log('Continue with Google', name: 'WelcomerController');
    Get.snackbar(
      'Google',
      'Connexion avec Google...',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Implémenter l'authentification Google
    Get.offAllNamed(Routes.HOME);
  }

  void continueWithApple() {
    developer.log('Continue with Apple', name: 'WelcomerController');
    Get.snackbar(
      'Apple',
      'Connexion avec Apple...',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Implémenter l'authentification Apple
    Get.offAllNamed(Routes.HOME);
  }

  void continueAsGuest() async {
    developer.log(
      'Continue as guest - going to HOME in GUEST MODE',
      name: 'WelcomerController',
    );

    // Enable guest mode
    developer.log('🔓 Enabling guest mode', name: 'WelcomerController');
    StorageService.enableGuestMode();

    // S'abonner au topic des annonces même en mode invité
    developer.log('📱 Subscribing to announcements topic as guest...', name: 'WelcomerController');
    try {
      await FirebaseMessagingService.to.subscribeToAnnouncementsTopic();
      developer.log('✅ Subscribed to announcements topic', name: 'WelcomerController');
    } catch (e) {
      developer.log(
        'Error subscribing to announcements topic',
        name: 'WelcomerController',
        error: e,
      );
      // On ne bloque pas la navigation même si l'opération échoue
    }

    Get.offAllNamed(Routes.HOME);
  }

  void goToLogin() {
    developer.log('Go to login', name: 'WelcomerController');
    Get.toNamed(Routes.LOGIN);
  }
}
