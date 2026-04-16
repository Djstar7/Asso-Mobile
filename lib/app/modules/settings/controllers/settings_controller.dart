import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../routes/app_pages.dart';

class SettingsController extends GetxController {
  // États
  final isLoading = false.obs;

  // Informations utilisateur
  final userName = ''.obs;
  final userEmail = ''.obs;
  final userPhone = ''.obs;

  // Préférences
  final selectedLanguage = 'Français'.obs;
  final notificationsEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    _loadPreferences();
  }

  /// Charge les données utilisateur
  void _loadUserData() {
    // Charger depuis le cache d'abord
    final cachedUser = StorageService.getUser();
    if (cachedUser != null) {
      _updateUserData(cachedUser.toJson());
    }

    // Puis rafraîchir depuis l'API
    _refreshUserData();
  }

  /// Charge les préférences depuis le storage local
  void _loadPreferences() {
    final preferences = StorageService.getPreferences();
    if (preferences != null) {
      selectedLanguage.value = preferences['language'] ?? 'Français';
      notificationsEnabled.value = preferences['notifications'] ?? true;
    }
  }

  /// Rafraîchir les données depuis l'API
  Future<void> _refreshUserData() async {
    try {
      final response = await AuthService.getProfile();
      if (response.success && response.data != null) {
        final user = response.data!['user'];
        if (user != null) {
          _updateUserData(Map<String, dynamic>.from(user));
        }
      }
    } catch (e) {
      // Utiliser les données en cache
    }
  }

  /// Mettre à jour les données utilisateur affichées
  void _updateUserData(Map<String, dynamic> data) {
    final firstName = data['first_name'] ?? '';
    final lastName = data['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    userName.value = fullName.isEmpty ? 'Utilisateur' : fullName;
    userEmail.value = data['email'] ?? '';
    userPhone.value = data['phone'] ?? '';
  }

  /// Naviguer vers l'édition du profil
  void editProfile() {
    Get.toNamed(Routes.COMPLETE_PROFILE);
  }

  /// Changer le numéro de téléphone
  Future<void> changePhoneNumber() async {
    try {
      final phoneController = TextEditingController();
      final countryCode = '+237'; // Default country code for Cameroon

      final result = await Get.dialog<bool>(
        Builder(
          builder: (context) => Dialog(
            backgroundColor: AppThemeSystem.getSurfaceColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.large),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: context.isTabletOrLarger ? 500 : double.infinity,
              ),
              padding: EdgeInsets.all(context.horizontalPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône et titre
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.elementSpacing),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                        ),
                        child: Icon(
                          Icons.phone_outlined,
                          color: AppThemeSystem.primaryColor,
                          size: context.deviceType == DeviceType.mobile ? 24 : 28,
                        ),
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: Text(
                          'Changer le numéro de téléphone',
                          style: context.textStyle(
                            FontSizeType.h5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Numéro actuel
                  Container(
                    padding: EdgeInsets.all(context.elementSpacing),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.grey100,
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppThemeSystem.grey600,
                        ),
                        SizedBox(width: context.elementSpacing * 0.5),
                        Expanded(
                          child: Text(
                            'Votre numéro actuel: ${userPhone.value}',
                            style: context.textStyle(
                              FontSizeType.caption,
                              color: AppThemeSystem.grey600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: context.elementSpacing * 1.5),

                  // Champ de saisie
                  Text(
                    'Nouveau numéro de téléphone',
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: context.elementSpacing * 0.5),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: context.textStyle(FontSizeType.body1),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.inputFieldColor,
                      border: OutlineInputBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                        borderSide: const BorderSide(
                          color: AppThemeSystem.primaryColor,
                          width: 2,
                        ),
                      ),
                      prefixText: '$countryCode ',
                      prefixStyle: context.textStyle(
                        FontSizeType.body1,
                        fontWeight: FontWeight.w600,
                      ),
                      hintText: 'Ex: 658895572',
                      hintStyle: context.textStyle(
                        FontSizeType.body1,
                        color: AppThemeSystem.grey400,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.horizontalPadding,
                        vertical: context.elementSpacing,
                      ),
                    ),
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Info OTP
                  Row(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: 14,
                        color: AppThemeSystem.infoColor,
                      ),
                      SizedBox(width: context.elementSpacing * 0.5),
                      Expanded(
                        child: Text(
                          'Un code OTP sera envoyé à ce numéro',
                          style: context.textStyle(
                            FontSizeType.caption,
                            color: AppThemeSystem.infoColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: OutlinedButton(
                            onPressed: () => Get.back(result: false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Annuler',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: context.primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: ElevatedButton(
                            onPressed: () => Get.back(result: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeSystem.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Continuer',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (result == true && phoneController.text.isNotEmpty) {
        final newPhone = phoneController.text.trim();

        // Validate phone number (basic validation)
        if (newPhone.length < 8) {
          Get.snackbar(
            'Erreur',
            'Numéro de téléphone invalide',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        isLoading.value = true;

        // Request phone change
        final response = await AuthService.requestPhoneChange(
          newPhone: newPhone,
          countryCode: countryCode,
        );

        if (response.success) {
          // Navigate to OTP verification page with phone change context
          Get.toNamed('/otp', arguments: {
            'phoneNumber': countryCode + newPhone,
            'isPhoneChange': true, // Special flag to indicate this is phone change
            'newPhone': countryCode + newPhone,
          });

          Get.snackbar(
            'Code envoyé',
            response.message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            'Erreur',
            response.message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de modifier le numéro de téléphone',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Effacer le cache
  Future<void> clearCache() async {
    try {
      final confirmed = await Get.dialog<bool>(
        Builder(
          builder: (context) => Dialog(
            backgroundColor: AppThemeSystem.getSurfaceColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.large),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: context.isTabletOrLarger ? 450 : double.infinity,
              ),
              padding: EdgeInsets.all(context.horizontalPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône et titre
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.elementSpacing),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.warningColor.withValues(alpha: 0.1),
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                        ),
                        child: Icon(
                          Icons.delete_sweep_rounded,
                          color: AppThemeSystem.warningColor,
                          size: context.deviceType == DeviceType.mobile ? 24 : 28,
                        ),
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: Text(
                          'Effacer le cache',
                          style: context.textStyle(
                            FontSizeType.h5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Message
                  Text(
                    'Êtes-vous sûr de vouloir effacer le cache de l\'application ?',
                    style: context.textStyle(
                      FontSizeType.body1,
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Info
                  Container(
                    padding: EdgeInsets.all(context.elementSpacing),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.infoColor.withValues(alpha: 0.1),
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                      border: Border.all(
                        color: AppThemeSystem.infoColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppThemeSystem.infoColor,
                        ),
                        SizedBox(width: context.elementSpacing * 0.5),
                        Expanded(
                          child: Text(
                            'Cette action libérera de l\'espace de stockage mais pourrait ralentir temporairement l\'application.',
                            style: context.textStyle(
                              FontSizeType.caption,
                              color: AppThemeSystem.infoColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: OutlinedButton(
                            onPressed: () => Get.back(result: false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Annuler',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: context.primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: ElevatedButton(
                            onPressed: () => Get.back(result: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeSystem.warningColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppThemeSystem.warningColor.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Effacer',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (confirmed != true) return;

      isLoading.value = true;

      // TODO: Effacer le cache
      await Future.delayed(const Duration(seconds: 1));

      Get.snackbar(
        'Succès',
        'Cache effacé avec succès',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible d\'effacer le cache',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Supprimer le compte
  Future<void> deleteAccount() async {
    try {
      // First confirmation
      final confirmed = await Get.dialog<bool>(
        Builder(
          builder: (context) => Dialog(
            backgroundColor: AppThemeSystem.getSurfaceColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.large),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: context.isTabletOrLarger ? 500 : double.infinity,
              ),
              padding: EdgeInsets.all(context.horizontalPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône d'avertissement
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppThemeSystem.errorColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeSystem.errorColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: AppThemeSystem.errorColor,
                        size: context.deviceType == DeviceType.mobile ? 40 : 48,
                      ),
                    ),
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Titre
                  Center(
                    child: Text(
                      'Supprimer le compte',
                      style: context.textStyle(
                        FontSizeType.h5,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.errorColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Message principal
                  Container(
                    padding: EdgeInsets.all(context.elementSpacing),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.errorColor.withValues(alpha: 0.05),
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                      border: Border.all(
                        color: AppThemeSystem.errorColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cette action est irréversible et entraînera :',
                          style: context.textStyle(
                            FontSizeType.body2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: context.elementSpacing * 0.75),
                        _buildWarningItem(context, 'Suppression de toutes vos données'),
                        _buildWarningItem(context, 'Annulation de vos commandes en cours'),
                        _buildWarningItem(context, 'Suppression de vos produits (si vendeur)'),
                        _buildWarningItem(context, 'Perte de votre historique'),
                      ],
                    ),
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Question finale
                  Center(
                    child: Text(
                      'Êtes-vous absolument sûr ?',
                      style: context.textStyle(
                        FontSizeType.body1,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.errorColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: OutlinedButton(
                            onPressed: () => Get.back(result: false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Annuler',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: context.primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: ElevatedButton(
                            onPressed: () => Get.back(result: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeSystem.errorColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppThemeSystem.errorColor.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Continuer',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (confirmed != true) return;

      // Second confirmation with text input
      final textController = TextEditingController();
      final finalConfirmed = await Get.dialog<bool>(
        Builder(
          builder: (context) => Dialog(
            backgroundColor: AppThemeSystem.getSurfaceColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.large),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: context.isTabletOrLarger ? 450 : double.infinity,
              ),
              padding: EdgeInsets.all(context.horizontalPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône et titre
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.elementSpacing),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.errorColor.withValues(alpha: 0.1),
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: AppThemeSystem.errorColor,
                          size: context.deviceType == DeviceType.mobile ? 24 : 28,
                        ),
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: Text(
                          'Confirmation finale',
                          style: context.textStyle(
                            FontSizeType.h5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Instructions
                  Text(
                    'Pour confirmer la suppression de votre compte, tapez exactement le mot ci-dessous :',
                    style: context.textStyle(
                      FontSizeType.body2,
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Mot à taper en évidence
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.horizontalPadding,
                        vertical: context.elementSpacing * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.errorColor.withValues(alpha: 0.1),
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                        border: Border.all(
                          color: AppThemeSystem.errorColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'SUPPRIMER',
                        style: context.textStyle(
                          FontSizeType.h6,
                          fontWeight: FontWeight.bold,
                          color: AppThemeSystem.errorColor,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: context.elementSpacing * 1.5),

                  // Champ de saisie
                  TextField(
                    controller: textController,
                    textCapitalization: TextCapitalization.characters,
                    style: context.textStyle(
                      FontSizeType.body1,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.inputFieldColor,
                      border: OutlineInputBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                        borderSide: const BorderSide(
                          color: AppThemeSystem.errorColor,
                          width: 2,
                        ),
                      ),
                      hintText: 'Tapez ici...',
                      hintStyle: context.textStyle(
                        FontSizeType.body1,
                        color: AppThemeSystem.grey400,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.horizontalPadding,
                        vertical: context.elementSpacing,
                      ),
                    ),
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: OutlinedButton(
                            onPressed: () => Get.back(result: false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Annuler',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: context.primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: ElevatedButton(
                            onPressed: () {
                              if (textController.text.toUpperCase() == 'SUPPRIMER') {
                                Get.back(result: true);
                              } else {
                                Get.snackbar(
                                  'Erreur',
                                  'Veuillez taper exactement "SUPPRIMER"',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: AppThemeSystem.warningColor,
                                  colorText: Colors.white,
                                  icon: const Icon(Icons.error_outline, color: Colors.white),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeSystem.errorColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppThemeSystem.errorColor.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Supprimer définitivement',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (finalConfirmed != true) return;

      isLoading.value = true;

      // Call API to delete account
      final response = await AuthService.deleteAccount();

      if (response.success) {
        Get.snackbar(
          'Compte supprimé',
          'Votre compte a été supprimé avec succès',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );

        // Redirect to login page
        await Future.delayed(const Duration(seconds: 1));
        Get.offAllNamed('/login');
      } else {
        Get.snackbar(
          'Erreur',
          response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de supprimer le compte',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Se déconnecter
  Future<void> logout() async {
    try {
      final confirmed = await Get.dialog<bool>(
        Builder(
          builder: (context) => Dialog(
            backgroundColor: AppThemeSystem.getSurfaceColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.large),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: context.isTabletOrLarger ? 400 : double.infinity,
              ),
              padding: EdgeInsets.all(context.horizontalPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icône
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: AppThemeSystem.primaryColor,
                      size: context.deviceType == DeviceType.mobile ? 32 : 36,
                    ),
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Titre
                  Text(
                    'Déconnexion',
                    style: context.textStyle(
                      FontSizeType.h5,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Message
                  Text(
                    'Êtes-vous sûr de vouloir vous déconnecter ?',
                    style: context.textStyle(
                      FontSizeType.body1,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: context.sectionSpacing),

                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: OutlinedButton(
                            onPressed: () => Get.back(result: false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Annuler',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: context.primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: SizedBox(
                          height: context.buttonHeight,
                          child: ElevatedButton(
                            onPressed: () => Get.back(result: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeSystem.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: context.borderRadius(BorderRadiusType.medium),
                              ),
                            ),
                            child: Text(
                              'Déconnexion',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (confirmed != true) return;

      try {
        await AuthService.logout();
      } catch (e) {
        StorageService.clearAuth();
      }

      Get.offAllNamed('/login');
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de se déconnecter',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Ouvrir le bottom sheet des préférences
  void goToPreferences() {
    Get.bottomSheet(
      Builder(
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: AppThemeSystem.getSurfaceColor(context),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(
                AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
              ),
              topRight: Radius.circular(
                AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
              ),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: context.bottomSheetPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec poignée
                  Center(
                    child: Container(
                      margin: EdgeInsets.only(
                        top: context.elementSpacing,
                        bottom: context.elementSpacing * 0.5,
                      ),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppThemeSystem.grey300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Titre
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.horizontalPadding,
                      vertical: context.elementSpacing,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.elementSpacing * 0.75),
                          decoration: BoxDecoration(
                            color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                            borderRadius: context.borderRadius(BorderRadiusType.medium),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: AppThemeSystem.primaryColor,
                            size: context.deviceType == DeviceType.mobile ? 24 : 28,
                          ),
                        ),
                        SizedBox(width: context.elementSpacing),
                        Text(
                          'Préférences',
                          style: context.textStyle(
                            FontSizeType.h5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(color: context.borderColor, height: 1),

                  SizedBox(height: context.elementSpacing),

                  // Section Langue
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                    child: Text(
                      'Langue',
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.grey600,
                      ),
                    ),
                  ),

                  SizedBox(height: context.elementSpacing * 0.75),

                  // Options de langue
                  Obx(() => Column(
                    children: [
                      _buildLanguageOption(
                        context,
                        'Français',
                        '🇫🇷',
                        isSelected: selectedLanguage.value == 'Français',
                        isAvailable: true,
                      ),
                      _buildLanguageOption(
                        context,
                        'English',
                        '🇬🇧',
                        isSelected: selectedLanguage.value == 'English',
                        isAvailable: false,
                      ),
                    ],
                  )),

                  SizedBox(height: context.sectionSpacing),

                  // Section Notifications
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                    child: Text(
                      'Notifications',
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.grey600,
                      ),
                    ),
                  ),

                  SizedBox(height: context.elementSpacing * 0.75),

                  // Toggle notifications
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                    padding: EdgeInsets.all(context.elementSpacing),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.elementSpacing * 0.6),
                          decoration: BoxDecoration(
                            color: AppThemeSystem.infoColor.withValues(alpha: 0.1),
                            borderRadius: context.borderRadius(BorderRadiusType.small),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: AppThemeSystem.infoColor,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: context.elementSpacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activer les notifications',
                                style: context.textStyle(
                                  FontSizeType.body1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: context.elementSpacing * 0.25),
                              Text(
                                'Recevoir des notifications push',
                                style: context.textStyle(
                                  FontSizeType.caption,
                                  color: AppThemeSystem.grey600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Obx(() => Switch(
                              value: notificationsEnabled.value,
                              onChanged: (value) {
                                notificationsEnabled.value = value;
                                _saveNotificationPreference(value);
                              },
                              activeTrackColor: AppThemeSystem.primaryColor,
                              thumbColor: WidgetStateProperty.all(Colors.white),
                            )),
                      ],
                    ),
                  ),

                  SizedBox(height: context.sectionSpacing),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  /// Widget pour une option de langue
  Widget _buildLanguageOption(
    BuildContext context,
    String language,
    String flag, {
    required bool isSelected,
    required bool isAvailable,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: context.elementSpacing * 0.25,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable
              ? () {
                  selectedLanguage.value = language;
                  _saveLanguagePreference(language);
                }
              : null,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          child: Container(
            padding: EdgeInsets.all(context.elementSpacing),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppThemeSystem.primaryColor.withValues(alpha: 0.05)
                  : context.surfaceColor,
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              border: Border.all(
                color: isSelected
                    ? AppThemeSystem.primaryColor
                    : context.borderColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Flag
                Text(
                  flag,
                  style: TextStyle(
                    fontSize: context.deviceType == DeviceType.mobile ? 28 : 32,
                  ),
                ),
                SizedBox(width: context.elementSpacing),

                // Nom de la langue
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language,
                        style: context.textStyle(
                          FontSizeType.body1,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isAvailable
                              ? context.primaryTextColor
                              : AppThemeSystem.grey400,
                        ),
                      ),
                      if (!isAvailable) ...[
                        SizedBox(height: context.elementSpacing * 0.25),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.elementSpacing * 0.75,
                            vertical: context.elementSpacing * 0.25,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeSystem.warningColor.withValues(alpha: 0.1),
                            borderRadius: context.borderRadius(BorderRadiusType.small),
                          ),
                          child: Text(
                            'Coming Soon',
                            style: context.textStyle(
                              FontSizeType.caption,
                              fontWeight: FontWeight.w600,
                              color: AppThemeSystem.warningColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Icône de sélection
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(context.elementSpacing * 0.5),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sauvegarder la préférence de langue
  void _saveLanguagePreference(String language) {
    final preferences = StorageService.getPreferences() ?? {};
    preferences['language'] = language;
    StorageService.savePreferences(preferences);

    Get.snackbar(
      'Langue modifiée',
      'La langue a été changée en $language',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.successColor,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle, color: Colors.white),
      duration: const Duration(seconds: 2),
    );
  }

  /// Sauvegarder la préférence de notifications
  void _saveNotificationPreference(bool enabled) {
    final preferences = StorageService.getPreferences() ?? {};
    preferences['notifications'] = enabled;
    StorageService.savePreferences(preferences);

    // TODO: Configurer les notifications système (Firebase, etc.)

    Get.snackbar(
      enabled ? 'Notifications activées' : 'Notifications désactivées',
      enabled
          ? 'Vous recevrez des notifications push'
          : 'Vous ne recevrez plus de notifications push',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: enabled ? AppThemeSystem.successColor : AppThemeSystem.grey600,
      colorText: Colors.white,
      icon: Icon(
        enabled ? Icons.notifications_active : Icons.notifications_off,
        color: Colors.white,
      ),
      duration: const Duration(seconds: 2),
    );
  }

  /// Naviguer vers les factures
  void goToInvoices() {
    Get.toNamed('/invoices');
  }

  /// Naviguer vers À propos
  void goToAbout() {
    Get.toNamed('/about');
  }

  /// Helper widget pour afficher un item d'avertissement
  Widget _buildWarningItem(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.elementSpacing * 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.close_rounded,
            size: 16,
            color: AppThemeSystem.errorColor,
          ),
          SizedBox(width: context.elementSpacing * 0.5),
          Expanded(
            child: Text(
              text,
              style: context.textStyle(
                FontSizeType.body2,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
