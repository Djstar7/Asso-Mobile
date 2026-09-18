import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../../routes/app_pages.dart';

class CompleteProfileController extends GetxController {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();

  final RxString selectedGender = ''.obs;
  final Rx<DateTime?> birthDate = Rx<DateTime?>(null);
  final RxString address = ''.obs;
  final RxBool isLoading = false.obs;
  late final String returnRoute;

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    returnRoute = arguments is Map && arguments['returnTo'] is String
        ? arguments['returnTo'] as String
        : (StorageService.getUser()?.role == 'vendeur'
              ? Routes.VENDOR_DASHBOARD
              : Routes.HOME);
    // Pre-fill from cached user data
    final user = StorageService.getUser();
    if (user != null) {
      firstNameController.text = user.firstName ?? '';
      lastNameController.text = user.lastName ?? '';
      emailController.text = user.email ?? '';

      // Mapper les valeurs backend vers les valeurs UI
      final backendGender = user.gender ?? '';
      final reverseGenderMap = {'male': 'H', 'female': 'F'};
      selectedGender.value = reverseGenderMap[backendGender] ?? '';

      // Pré-remplir la date de naissance si elle existe
      final userBirthDate = user.birthDate;
      if (userBirthDate != null && userBirthDate.isNotEmpty) {
        try {
          birthDate.value = DateTime.parse(userBirthDate);
        } catch (e) {
          print('Error parsing birth date: $e');
        }
      }

      address.value = user.address ?? '';
    }
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    super.onClose();
  }

  Future<void> saveProfile() async {
    if (firstNameController.text.isEmpty || lastNameController.text.isEmpty) {
      Get.snackbar(
        'Champs requis',
        'Veuillez remplir votre prénom et nom',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    isLoading.value = true;

    try {
      final data = <String, dynamic>{
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
      };

      if (emailController.text.isNotEmpty) {
        data['email'] = emailController.text.trim();
      }
      if (selectedGender.value.isNotEmpty) {
        // Mapper les valeurs UI vers les valeurs backend
        final genderMap = {'H': 'male', 'F': 'female'};
        data['gender'] =
            genderMap[selectedGender.value] ?? selectedGender.value;
      }
      if (birthDate.value != null) {
        data['birth_date'] = birthDate.value!.toIso8601String().split('T')[0];
      }
      if (address.value.isNotEmpty) {
        data['address'] = address.value;
      }

      final response = await AuthService.updateProfile(data);

      if (response.success) {
        // Le cache est déjà mis à jour dans AuthService.updateProfile
        // Mais on va forcer un refresh du profil si on revient en arrière

        Get.snackbar(
          'Profil complété',
          'Votre profil a été mis à jour avec succès',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );

        await Future.delayed(const Duration(milliseconds: 500));

        // Forcer le refresh du ProfileController si il existe
        try {
          if (Get.isRegistered<ProfileController>()) {
            final profileController = Get.find<ProfileController>();
            await profileController.reloadProfile();
          }
        } catch (e) {
          print('Could not refresh ProfileController: $e');
        }

        // Utiliser Get.back() au lieu de Get.offAllNamed() pour éviter le duplicate GlobalKey
        navigateBack();
      } else {
        Get.snackbar(
          'Erreur',
          response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void selectGender(String gender) {
    selectedGender.value = gender;
  }

  void selectBirthDate(DateTime date) {
    birthDate.value = date;
  }

  void navigateBack() {
    final navigator = Get.key.currentState;
    if (navigator != null && navigator.canPop()) {
      Get.back();
      return;
    }
    Get.offAllNamed(returnRoute);
  }

  void goToMainDestination() => Get.offAllNamed(returnRoute);
}
