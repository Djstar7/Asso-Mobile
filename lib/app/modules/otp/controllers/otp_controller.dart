import 'package:asso/app/core/utils/app_feedback.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/services/firebase_messaging_service.dart';
import '../../../routes/app_pages.dart';

class OtpController extends GetxController {
  late List<TextEditingController> otpControllers;
  late List<FocusNode> focusNodes;

  final phoneNumber = ''.obs;
  final email = ''.obs;
  final secondsRemaining = 120.obs;
  final isLoading = false.obs;
  final isOtpComplete = false.obs;
  final isNewUser = false.obs;
  final isPhoneChange = false.obs;
  final isEmailAuth = false.obs;
  final newPhone = ''.obs;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();

    if (Get.arguments != null) {
      phoneNumber.value = Get.arguments['phoneNumber'] ?? '';
      email.value = Get.arguments['email'] ?? '';
      isNewUser.value = Get.arguments['isNewUser'] ?? false;
      isPhoneChange.value = Get.arguments['isPhoneChange'] ?? false;
      isEmailAuth.value = Get.arguments['isEmailAuth'] ?? false;
      newPhone.value = Get.arguments['newPhone'] ?? '';
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
    secondsRemaining.value = 120;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining.value > 0) {
        secondsRemaining.value--;
      } else {
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
    }
  }

  String getOtpCode() {
    return otpControllers.map((c) => c.text).join();
  }

  Future<void> resendOtp() async {

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


    for (var controller in otpControllers) {
      controller.clear();
    }
    isOtpComplete.value = false;
    _startTimer();
    focusNodes[0].requestFocus();

    AppFeedback.show(
      response.success ? 'otp.code_resent_title'.tr : 'common.error'.tr,
      response.success
          ? 'otp.code_resent_message'.trParams({'phone': phoneNumber.value})
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
    Get.back();
  }

  Future<void> verifyOtp() async {

    if (!isOtpComplete.value) {
      AppFeedback.show(
        'otp.incomplete_title'.tr,
        'otp.incomplete_message'.tr,
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

        final response = await AuthService.confirmPhoneChange(
          newPhone: newPhone.value,
          otpCode: otpCode,
        );


        if (response.success) {
          AppFeedback.show(
            'common.success'.tr,
            'otp.phone_changed'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );

          await Future.delayed(const Duration(milliseconds: 500));

          // After successful phone change, go back to settings
          Get.offAllNamed(Routes.SETTINGS);
        } else {
          AppFeedback.show(
            'otp.incorrect_code'.tr,
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
        // Normal OTP verification for login (phone or email)
        final response = isEmailAuth.value
            ? await _verifyEmailOtp(otpCode)
            : await _verifyPhoneOtp(otpCode);


        if (response.success) {
          AppFeedback.show(
            'common.success'.tr,
            'login.success'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );

          await Future.delayed(const Duration(milliseconds: 500));

          // Envoyer le token FCM au backend ET s'abonner au topic des annonces
          try {
            final results = await FirebaseMessagingService.to
                .registerDeviceAndSubscribe()
                // Une borne de temps, et non le seul `catch` : privé de
                // services Google Play, l'abonnement ne rend jamais la main
                // et ne lève rien — la validation restait suspendue sans fin.
                .timeout(const Duration(seconds: 10));
          } catch (e) {
            // On ne bloque pas la navigation même si l'opération échoue
          }

          // Aucun rafraichissement manuel ici : `SessionReset.onLogin()` a
          // supprime les controllers permanents de la session invite, et le
          // `offAllNamed` ci-dessous les recree via les bindings sous l'identite
          // du compte connecte.

          // Navigate based on profile completeness
          final isNew = response.data?['is_new_user'] ?? false;

          if (isNew) {
            Get.offAllNamed(Routes.PREFERENCES, arguments: {'onboarding': true});
          } else {
            Get.offAllNamed(Routes.HOME);
          }
        } else {
          AppFeedback.show(
            'otp.incorrect_code'.tr,
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

  Future<dynamic> _verifyEmailOtp(String otpCode) async {

    return await AuthService.verifyEmailOtp(
      email: email.value,
      otpCode: otpCode,
    );
  }

  Future<dynamic> _verifyPhoneOtp(String otpCode) async {

    return await AuthService.verifyOtp(
      fullPhone: phoneNumber.value,
      otpCode: otpCode,
    );
  }
}
