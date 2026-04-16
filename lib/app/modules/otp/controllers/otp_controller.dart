import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/services/firebase_messaging_service.dart';
import '../../../routes/app_pages.dart';

class OtpController extends GetxController {
  late List<TextEditingController> otpControllers;
  late List<FocusNode> focusNodes;

  final phoneNumber = ''.obs;
  final secondsRemaining = 120.obs;
  final isLoading = false.obs;
  final isOtpComplete = false.obs;
  final isNewUser = false.obs;
  final isPhoneChange = false.obs;
  final newPhone = ''.obs;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    developer.log('========== OTP CONTROLLER INIT ==========', name: 'OtpController');

    if (Get.arguments != null) {
      phoneNumber.value = Get.arguments['phoneNumber'] ?? '';
      isNewUser.value = Get.arguments['isNewUser'] ?? false;
      isPhoneChange.value = Get.arguments['isPhoneChange'] ?? false;
      newPhone.value = Get.arguments['newPhone'] ?? '';
      developer.log(
        'Arguments received',
        name: 'OtpController',
        error: 'Phone: ${phoneNumber.value}, Is new user: ${isNewUser.value}, Is phone change: ${isPhoneChange.value}',
      );
    }

    otpControllers = List.generate(6, (index) => TextEditingController());
    focusNodes = List.generate(6, (index) => FocusNode());

    _startTimer();
  }

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNodes.isNotEmpty) {
        focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void onClose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.onClose();
  }

  void _startTimer() {
    developer.log('Starting OTP timer (120s)', name: 'OtpController');
    secondsRemaining.value = 120;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining.value > 0) {
        secondsRemaining.value--;
      } else {
        developer.log('OTP timer expired', name: 'OtpController');
        timer.cancel();
      }
    });
  }

  void onOtpChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 5) {
        focusNodes[index + 1].requestFocus();
      } else {
        focusNodes[index].unfocus();
      }
    } else {
      if (index > 0) {
        focusNodes[index - 1].requestFocus();
      }
    }
    _checkOtpComplete();
  }

  void _checkOtpComplete() {
    isOtpComplete.value = otpControllers.every((c) => c.text.isNotEmpty);
    if (isOtpComplete.value) {
      developer.log(
        'OTP complete',
        name: 'OtpController',
        error: 'Code: ${getOtpCode()}',
      );
    }
  }

  String getOtpCode() {
    return otpControllers.map((c) => c.text).join();
  }

  Future<void> resendOtp() async {
    developer.log(
      '========== RESEND OTP ==========',
      name: 'OtpController',
      error: 'Phone: ${phoneNumber.value}, Is phone change: ${isPhoneChange.value}',
    );

    // Extract raw phone from full phone
    final rawPhone = phoneNumber.value.replaceAll(RegExp(r'^\+\d{1,3}'), '');
    final countryCode = phoneNumber.value.contains('+')
        ? phoneNumber.value.replaceAll(RegExp(r'\d{8,}$'), '')
        : '+237';

    final response = isPhoneChange.value
        ? await AuthService.requestPhoneChange(
            newPhone: rawPhone,
            countryCode: countryCode,
          )
        : await AuthService.sendOtp(
            phone: rawPhone,
            countryCode: countryCode,
          );

    developer.log(
      'Resend OTP response',
      name: 'OtpController',
      error: 'Success: ${response.success}',
    );

    for (var controller in otpControllers) {
      controller.clear();
    }
    isOtpComplete.value = false;
    _startTimer();
    focusNodes[0].requestFocus();

    Get.snackbar(
      response.success ? 'Code renvoyé' : 'Erreur',
      response.success
          ? 'Un nouveau code a été envoyé au ${phoneNumber.value}'
          : response.message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: response.success
          ? Get.theme.colorScheme.primary
          : Get.theme.colorScheme.error,
      colorText: response.success
          ? Get.theme.colorScheme.onPrimary
          : Get.theme.colorScheme.onError,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  void changePhoneNumber() {
    developer.log('Changing phone number - going back', name: 'OtpController');
    Get.back();
  }

  Future<void> verifyOtp() async {
    developer.log(
      '========== VERIFY OTP ==========',
      name: 'OtpController',
      error: 'OTP complete: ${isOtpComplete.value}, Is phone change: ${isPhoneChange.value}',
    );

    if (!isOtpComplete.value) {
      developer.log('OTP incomplete', name: 'OtpController');
      Get.snackbar(
        'Code incomplet',
        'Veuillez entrer le code à 6 chiffres',
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
      final otpCode = getOtpCode();

      // Check if this is a phone change verification
      if (isPhoneChange.value) {
        developer.log(
          'Verifying OTP for phone change',
          name: 'OtpController',
          error: 'New phone: ${newPhone.value}, Code: $otpCode',
        );

        final response = await AuthService.confirmPhoneChange(
          newPhone: newPhone.value,
          otpCode: otpCode,
        );

        developer.log(
          'Phone change OTP verification response',
          name: 'OtpController',
          error: 'Success: ${response.success}, Message: ${response.message}',
        );

        if (response.success) {
          Get.snackbar(
            'Succès',
            'Numéro de téléphone modifié avec succès',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );

          await Future.delayed(const Duration(milliseconds: 500));

          // After successful phone change, go back to settings
          developer.log('Phone changed successfully - going to SETTINGS', name: 'OtpController');
          Get.offAllNamed(Routes.SETTINGS);
        } else {
          developer.log(
            'Phone change OTP verification failed',
            name: 'OtpController',
            error: response.message,
          );
          Get.snackbar(
            'Code incorrect',
            response.message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );

          for (var controller in otpControllers) {
            controller.clear();
          }
          isOtpComplete.value = false;
          focusNodes[0].requestFocus();
        }
      } else {
        // Normal OTP verification for login
        developer.log(
          'Verifying OTP for login',
          name: 'OtpController',
          error: 'Phone: ${phoneNumber.value}, Code: $otpCode, Is new user: ${isNewUser.value}',
        );

        final response = await AuthService.verifyOtp(
          fullPhone: phoneNumber.value,
          otpCode: otpCode,
        );

        developer.log(
          'Verify OTP response',
          name: 'OtpController',
          error: 'Success: ${response.success}, Message: ${response.message}',
        );

        if (response.success) {
          Get.snackbar(
            'Succès',
            'Connexion réussie',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );

          await Future.delayed(const Duration(milliseconds: 500));

          // Envoyer le token FCM au backend ET s'abonner au topic des annonces
          developer.log('📱 Registering device and subscribing to topics...', name: 'OtpController');
          try {
            final results = await FirebaseMessagingService.to.registerDeviceAndSubscribe();
            developer.log(
              'FCM registration result',
              name: 'OtpController',
              error: 'Token sent: ${results['token_sent']}, Topic subscribed: ${results['topic_subscribed']}',
            );
          } catch (e) {
            developer.log(
              'Error registering device/subscribing to topics',
              name: 'OtpController',
              error: e,
            );
            // On ne bloque pas la navigation même si l'opération échoue
          }

          // Navigate based on profile completeness
          final isNew = response.data?['is_new_user'] ?? false;
          developer.log(
            'Navigation decision',
            name: 'OtpController',
            error: 'Is new user: $isNew',
          );

          if (isNew) {
            developer.log('Navigating to PREFERENCES', name: 'OtpController');
            Get.offAllNamed(Routes.PREFERENCES);
          } else {
            developer.log('Navigating to HOME', name: 'OtpController');
            Get.offAllNamed(Routes.HOME);
          }
        } else {
          developer.log(
            'OTP verification failed',
            name: 'OtpController',
            error: response.message,
          );
          Get.snackbar(
            'Code incorrect',
            response.message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.error,
            colorText: Get.theme.colorScheme.onError,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );

          for (var controller in otpControllers) {
            controller.clear();
          }
          isOtpComplete.value = false;
          focusNodes[0].requestFocus();
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'OTP verification error',
        name: 'OtpController',
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
}
