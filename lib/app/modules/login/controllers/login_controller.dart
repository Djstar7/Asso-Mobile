import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/guest_access.dart';
import '../../../data/services/firebase_messaging_service.dart';
import '../../../routes/app_pages.dart';

class LoginController extends GetxController {
  late TextEditingController emailController;
  late TextEditingController passwordController;

  final email = ''.obs;
  final password = ''.obs;
  final isLoading = false.obs;
  final isFormValid = false.obs;
  final obscurePassword = true.obs;

  @override
  void onInit() {
    super.onInit();
    developer.log(
      '========== LOGIN CONTROLLER INIT ==========',
      name: 'LoginController',
    );
    emailController = TextEditingController();
    passwordController = TextEditingController();
    ever(email, (_) => _validateForm());
    ever(password, (_) => _validateForm());
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void _validateForm() {
    final emailValid = GetUtils.isEmail(email.value);
    final passwordValid = password.value.length >= 6;

    isFormValid.value = emailValid && passwordValid;

    developer.log(
      'Form validation',
      name: 'LoginController',
      error:
          'Email: $emailValid, Password: $passwordValid, Valid: ${isFormValid.value}',
    );
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  Future<void> login() async {
    var loginSucceeded = false;
    developer.log(
      '========== LOGIN ATTEMPT ==========',
      name: 'LoginController',
      error: 'Email: ${email.value}',
    );

    if (!isFormValid.value) {
      developer.log('Invalid form', name: 'LoginController');
      Get.snackbar(
        'Formulaire invalide',
        'Veuillez vérifier vos identifiants',
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
      // Login with email - direct login without OTP
      final response = await AuthService.loginWithEmail(
        email: email.value,
        password: password.value,
      );

      developer.log(
        'Login response',
        name: 'LoginController',
        error: 'Success: ${response.success}, Message: ${response.message}',
      );

      if (response.success) {
        developer.log(
          '✅ LOGIN SUCCESS',
          name: 'LoginController',
          error: 'Email: ${email.value}',
        );

        // Envoyer le token FCM au backend ET s'abonner au topic des annonces
        developer.log(
          '📱 Registering device and subscribing to topics...',
          name: 'LoginController',
        );
        try {
          final results = await FirebaseMessagingService.to
              .registerDeviceAndSubscribe()
              // Une borne de temps, et non le seul `catch` : privé de services
              // Google Play, l'abonnement ne rend jamais la main et ne lève
              // rien — la connexion restait alors suspendue sans fin.
              .timeout(const Duration(seconds: 10));
          developer.log(
            'FCM registration result',
            name: 'LoginController',
            error:
                'Token sent: ${results['token_sent']}, Topic subscribed: ${results['topic_subscribed']}',
          );
        } catch (e) {
          developer.log(
            'Error registering device/subscribing to topics',
            name: 'LoginController',
            error: e,
          );
          // On ne bloque pas la navigation même si l'opération échoue
        }

        loginSucceeded = true;
      } else {
        developer.log(
          'Login failed',
          name: 'LoginController',
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
        'Login error',
        name: 'LoginController',
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
      // Toujours terminer l'Obx du formulaire AVANT de retirer LoginView de
      // l'arbre. Une mutation après Get.offAll/Get.back provoquait le crash
      // "dirty widget in the wrong build scope" sur Flutter Web.
      isLoading.value = false;
    }

    if (loginSucceeded) {
      await _finishLoginNavigation();
    }
  }

  Future<void> _finishLoginNavigation() async {
    developer.log('Navigating after login', name: 'LoginController');

    // Laisser Flutter terminer la frame du bouton/loader avant toute mutation
    // de la pile de navigation.
    await WidgetsBinding.instance.endOfFrame;

    // Reconstruire l'accueil depuis zéro, y compris quand la connexion a été
    // ouverte depuis l'accueil invité : `SessionReset.onLogin()` vient de
    // supprimer les controllers permanents remplis de données anonymes, et
    // `Get.back()` réafficherait une vue dont les controllers n'existent plus.
    // `offAllNamed` rejoue HomeBinding, qui les recrée sous l'identité connectée.
    Get.offAllNamed(Routes.HOME);

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    });
  }

  void goToRegister() {
    developer.log('Navigating to register/welcomer', name: 'LoginController');
    Get.offNamed(Routes.WELCOMER);
  }

  /// Visiter l'application sans compte, depuis la connexion.
  ///
  /// Même parcours que « Passer » à l'inscription : on ne crée pas une
  /// seconde définition du mode invité.
  Future<void> continueAsGuest() => GuestAccess.enter();
}
