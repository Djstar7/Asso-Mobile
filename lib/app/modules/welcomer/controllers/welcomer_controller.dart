import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../routes/app_pages.dart';

class WelcomerController extends GetxController {
  final phoneController = TextEditingController();
  final RxString phoneNumber = ''.obs;
  final RxString countryCode = '+237'.obs;
  final RxString rawPhone = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isPhoneValid = false.obs;
  final RxBool termsAccepted = false.obs;

  @override
  void onInit() {
    super.onInit();
    developer.log(
      '========== WELCOMER CONTROLLER INIT ==========',
      name: 'WelcomerController',
    );
    ever(rawPhone, (_) => _validatePhone());
  }

  void _validatePhone() {
    isPhoneValid.value = rawPhone.value.length >= 8;
    developer.log(
      'Phone validation',
      name: 'WelcomerController',
      error: 'Raw phone: ${rawPhone.value}, Valid: ${isPhoneValid.value}',
    );
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }

  void skipWelcome() {
    developer.log('Skip welcome - going to HOME', name: 'WelcomerController');
    Get.offAllNamed(Routes.HOME);
  }

  Future<void> createAccountWithPhone() async {
    developer.log(
      '========== CREATE ACCOUNT WITH PHONE ==========',
      name: 'WelcomerController',
      error: 'Full phone: ${phoneNumber.value}, Raw: ${rawPhone.value}',
    );

    if (!isPhoneValid.value || phoneNumber.value.isEmpty) {
      developer.log('Invalid phone number', name: 'WelcomerController');
      Get.snackbar(
        'Numéro invalide',
        'Veuillez entrer un numéro de téléphone valide',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
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
      // Send OTP for registration via /v1/auth/send-otp
      developer.log(
        'Sending OTP via AuthService',
        name: 'WelcomerController',
        error:
            'Raw phone: ${rawPhone.value}, Country code: ${countryCode.value}',
      );

      final response = await AuthService.sendOtp(
        phone: rawPhone.value,
        countryCode: countryCode.value,
      );

      developer.log(
        'Send OTP response',
        name: 'WelcomerController',
        error: 'Success: ${response.success}, Message: ${response.message}',
      );

      if (response.success) {
        final isNewUser = response.data?['is_new_user'] ?? true;
        final bypassEnabled = response.data?['bypass_enabled'] ?? false;

        developer.log(
          'OTP sent successfully for registration',
          name: 'WelcomerController',
          error: 'Is new user: $isNewUser, Bypass enabled: $bypassEnabled',
        );

        // Check if OTP bypass is enabled for this phone number
        if (bypassEnabled) {
          developer.log(
            '🔓 OTP BYPASS ENABLED - Auto-login via WhatsApp',
            name: 'WelcomerController',
            error: 'Phone: ${phoneNumber.value}',
          );

          Get.snackbar(
            'Connexion en cours',
            'Bienvenue',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );

          await Future.delayed(const Duration(milliseconds: 500));

          // Automatically verify with a dummy OTP code
          developer.log(
            'Auto-verifying OTP with bypass',
            name: 'WelcomerController',
            error: 'Phone: ${phoneNumber.value}',
          );

          final verifyResponse = await AuthService.verifyOtp(
            fullPhone: phoneNumber.value,
            otpCode:
                '000000', // Dummy code - backend will accept any 6-digit code for bypass numbers
          );

          developer.log(
            'Auto-verify response',
            name: 'WelcomerController',
            error:
                'Success: ${verifyResponse.success}, Message: ${verifyResponse.message}',
          );

          if (verifyResponse.success) {
            developer.log(
              '✅ BYPASS LOGIN SUCCESS',
              name: 'WelcomerController',
              error: 'Navigating to home...',
            );

            Get.snackbar(
              'Succès',
              'Connexion réussie via WhatsApp',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Get.theme.colorScheme.primary,
              colorText: Get.theme.colorScheme.onPrimary,
              duration: const Duration(seconds: 2),
              margin: const EdgeInsets.all(16),
              borderRadius: 12,
            );

            await Future.delayed(const Duration(milliseconds: 500));

            // Navigate based on profile completeness
            final isNew = verifyResponse.data?['is_new_user'] ?? false;
            developer.log(
              'Bypass navigation decision',
              name: 'WelcomerController',
              error: 'Is new user: $isNew',
            );

            if (isNew) {
              developer.log(
                'Navigating to PREFERENCES (bypass)',
                name: 'WelcomerController',
              );
              Get.offAllNamed(Routes.PREFERENCES);
            } else {
              developer.log(
                'Navigating to HOME (bypass)',
                name: 'WelcomerController',
              );
              Get.offAllNamed(Routes.HOME);
            }
          } else {
            developer.log(
              '❌ Bypass auto-verify failed',
              name: 'WelcomerController',
              error: verifyResponse.message,
            );
            Get.snackbar(
              'Erreur',
              'Échec de la connexion automatique: ${verifyResponse.message}',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Get.theme.colorScheme.error,
              colorText: Get.theme.colorScheme.onError,
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.all(16),
              borderRadius: 12,
            );
          }
        } else {
          // Normal flow - show OTP screen
          Get.snackbar(
            'Code envoyé',
            'Un code de vérification a été envoyé au ${phoneNumber.value}',
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
              'phoneNumber': phoneNumber.value,
              'isNewUser': isNewUser,
            },
          );
        }
      } else {
        developer.log(
          'OTP send failed',
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

  void continueAsGuest() {
    developer.log(
      'Continue as guest - going to HOME',
      name: 'WelcomerController',
    );
    Get.offAllNamed(Routes.HOME);
  }

  void goToLogin() {
    developer.log('Go to login', name: 'WelcomerController');
    Get.toNamed(Routes.LOGIN);
  }
}
