import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/services/firebase_messaging_service.dart';
import '../../../routes/app_pages.dart';

class RegisterController extends GetxController {
  late TextEditingController phoneController;

  final phoneNumber = ''.obs;
  final countryCode = '+237'.obs;
  final isLoading = false.obs;
  final isPhoneValid = false.obs;
  final fullPhoneNumber = ''.obs;
  final termsAccepted = false.obs;

  @override
  void onInit() {
    super.onInit();
    developer.log('========== REGISTER CONTROLLER INIT ==========', name: 'RegisterController');
    phoneController = TextEditingController();
    ever(phoneNumber, (_) => _validatePhone());
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }

  void _validatePhone() {
    isPhoneValid.value = phoneNumber.value.length >= 8;
    developer.log(
      'Phone validation',
      name: 'RegisterController',
      error: 'Phone: ${phoneNumber.value}, Valid: ${isPhoneValid.value}',
    );
  }

  void onPhoneChanged(String phone, String dialCode) {
    phoneNumber.value = phone;
    countryCode.value = dialCode;
    fullPhoneNumber.value = dialCode + phone;
    developer.log(
      'Phone changed',
      name: 'RegisterController',
      error: 'Full phone: ${fullPhoneNumber.value}',
    );
  }

  Future<void> register() async {
    developer.log(
      '========== REGISTER ATTEMPT ==========',
      name: 'RegisterController',
      error: 'Phone: ${fullPhoneNumber.value}',
    );

    if (!isPhoneValid.value) {
      developer.log('Invalid phone number', name: 'RegisterController');
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
      // Send OTP for registration
      final response = await AuthService.sendOtp(
        phone: phoneNumber.value,
        countryCode: countryCode.value,
      );

      developer.log(
        'Send OTP response',
        name: 'RegisterController',
        error: 'Success: ${response.success}, Message: ${response.message}',
      );

      if (response.success) {
        final isNewUser = response.data?['is_new_user'] ?? true;
        final bypassEnabled = response.data?['bypass_enabled'] ?? false;

        developer.log(
          'OTP sent successfully for registration',
          name: 'RegisterController',
          error: 'Is new user: $isNewUser, Bypass enabled: $bypassEnabled',
        );

        // Check if OTP bypass is enabled for this phone number
        if (bypassEnabled) {
          developer.log(
            '🔓 OTP BYPASS ENABLED - Auto-login via WhatsApp',
            name: 'RegisterController',
            error: 'Phone: ${fullPhoneNumber.value}',
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
            name: 'RegisterController',
            error: 'Phone: ${fullPhoneNumber.value}',
          );

          final verifyResponse = await AuthService.verifyOtp(
            fullPhone: fullPhoneNumber.value,
            otpCode: '000000', // Dummy code - backend will accept any 6-digit code for bypass numbers
          );

          developer.log(
            'Auto-verify response',
            name: 'RegisterController',
            error: 'Success: ${verifyResponse.success}, Message: ${verifyResponse.message}',
          );

          if (verifyResponse.success) {
            developer.log(
              '✅ BYPASS LOGIN SUCCESS',
              name: 'RegisterController',
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

            // Envoyer le token FCM au backend ET s'abonner au topic des annonces
            developer.log('📱 Registering device and subscribing to topics...', name: 'RegisterController');
            try {
              final results = await FirebaseMessagingService.to.registerDeviceAndSubscribe();
              developer.log(
                'FCM registration result',
                name: 'RegisterController',
                error: 'Token sent: ${results['token_sent']}, Topic subscribed: ${results['topic_subscribed']}',
              );
            } catch (e) {
              developer.log(
                'Error registering device/subscribing to topics',
                name: 'RegisterController',
                error: e,
              );
              // On ne bloque pas la navigation même si l'opération échoue
            }

            // Navigate based on profile completeness
            final isNew = verifyResponse.data?['is_new_user'] ?? false;
            developer.log(
              'Bypass navigation decision',
              name: 'RegisterController',
              error: 'Is new user: $isNew',
            );

            if (isNew) {
              developer.log('Navigating to PREFERENCES (bypass)', name: 'RegisterController');
              Get.offAllNamed(Routes.PREFERENCES);
            } else {
              developer.log('Navigating to HOME (bypass)', name: 'RegisterController');
              Get.offAllNamed(Routes.HOME);
            }
          } else {
            developer.log(
              '❌ Bypass auto-verify failed',
              name: 'RegisterController',
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
            'Un code de vérification a été envoyé au ${fullPhoneNumber.value}',
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
              'phoneNumber': fullPhoneNumber.value,
              'isNewUser': isNewUser,
            },
          );
        }
      } else {
        developer.log(
          'OTP send failed',
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
