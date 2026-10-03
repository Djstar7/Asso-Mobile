import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/models/currency_model.dart';
import '../../../routes/app_pages.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/values/country_catalog.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/services/locale_service.dart';

class SettingsController extends GetxController {
  // États
  final isLoading = false.obs;

  // Informations utilisateur
  final userName = ''.obs;
  final userEmail = ''.obs;
  final userPhone = ''.obs;

  // Préférences
  /// Code de la langue affichée (`fr`, `en`), tenu par [LocaleService].
  RxString get selectedLanguage => LocaleService.to.language;
  final notificationsEnabled = true.obs;

  // Pays et devise
  final selectedCountry = ''.obs;
  final selectedCurrency = ''.obs;
  final RxList<Map<String, dynamic>> allCountries = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredCountries = <Map<String, dynamic>>[].obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    _loadPreferences();
    _loadCurrentCountryAndCurrency();
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

    userName.value = fullName.isEmpty ? 'settings.default_user_name'.tr : fullName;
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
              // Clavier ouvert, la boîte ne tient plus sur un petit écran : elle
              // défile plutôt que de déborder sur ses boutons.
              child: SingleChildScrollView(
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
                            'settings.phone_change.title'.tr,
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
                              'settings.phone_change.current'.trParams({'phone': userPhone.value}),
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
                      'settings.phone_change.new_label'.tr,
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
                        hintText: 'settings.phone_change.hint'.tr,
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
                            'settings.phone_change.otp_notice'.tr,
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
                                'common.cancel'.tr,
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
                                'common.continue'.tr,
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
        ),
      );

      if (result == true && phoneController.text.isNotEmpty) {
        final newPhone = phoneController.text.trim();

        // Validate phone number (basic validation)
        if (newPhone.length < 8) {
          Get.snackbar(
            'common.error'.tr,
            'settings.phone_change.invalid'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppDesign.danger,
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
            'settings.phone_change.code_sent'.tr,
            response.message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppDesign.success,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            'common.error'.tr,
            response.message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppDesign.danger,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'common.error'.tr,
        'settings.phone_change.failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
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
                          'settings.cache.title'.tr,
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
                    'settings.cache.confirm_question'.tr,
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
                            'settings.cache.notice'.tr,
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
                              'common.cancel'.tr,
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
                              'settings.cache.clear'.tr,
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
        'common.success'.tr,
        'settings.cache.cleared'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'common.error'.tr,
        'settings.cache.failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
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
                      'settings.delete_account.title'.tr,
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
                          'settings.delete_account.irreversible'.tr,
                          style: context.textStyle(
                            FontSizeType.body2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: context.elementSpacing * 0.75),
                        _buildWarningItem(context, 'settings.delete_account.consequence_data'.tr),
                        _buildWarningItem(context, 'settings.delete_account.consequence_orders'.tr),
                        _buildWarningItem(context, 'settings.delete_account.consequence_products'.tr),
                        _buildWarningItem(context, 'settings.delete_account.consequence_history'.tr),
                      ],
                    ),
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Question finale
                  Center(
                    child: Text(
                      'settings.delete_account.are_you_sure'.tr,
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
                              'common.cancel'.tr,
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
                              'common.continue'.tr,
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
              // Même raison : le clavier réduit la place sous le champ.
              child: SingleChildScrollView(
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
                            'settings.delete_account.final_title'.tr,
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
                      'settings.delete_account.type_instruction'.tr,
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
                          'settings.delete_account.confirm_word'.tr,
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
                        hintText: 'settings.delete_account.type_hint'.tr,
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
                                'common.cancel'.tr,
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
                                if (textController.text.toUpperCase() ==
                                    'settings.delete_account.confirm_word'.tr) {
                                  Get.back(result: true);
                                } else {
                                  Get.snackbar(
                                    'common.error'.tr,
                                    'settings.delete_account.type_exact_error'.trParams({
                                      'word': 'settings.delete_account.confirm_word'.tr,
                                    }),
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
                                'settings.delete_account.delete_permanently'.tr,
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
        ),
      );

      if (finalConfirmed != true) return;

      isLoading.value = true;

      // Call API to delete account
      final response = await AuthService.deleteAccount();

      if (response.success) {
        Get.snackbar(
          'settings.delete_account.deleted_title'.tr,
          'settings.delete_account.deleted_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );

        // Redirect to login page
        await Future.delayed(const Duration(seconds: 1));
        Get.offAllNamed('/login');
      } else {
        Get.snackbar(
          'common.error'.tr,
          response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'common.error'.tr,
        'settings.delete_account.failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
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
                    'settings.logout.title'.tr,
                    style: context.textStyle(
                      FontSizeType.h5,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Message
                  Text(
                    'settings.logout.confirm'.tr,
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
                              'common.cancel'.tr,
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
                              'settings.logout.title'.tr,
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

      Get.offAllNamed(Routes.LOGIN);
    } catch (e) {
      Get.snackbar(
        'common.error'.tr,
        'settings.logout.failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  /// Ouvrir le bottom sheet des préférences
  void goToPreferences() {
    // Feuille standard : titre et croix pour la refermer, hauteur arrêtée
    // sous la barre d'état. L'ancienne, sans croix, pouvait monter jusqu'en
    // haut de l'écran sur un petit téléphone.
    AppSheet.show(
      AppSheet(
        title: 'settings.preferences.title'.tr,
        // Les sections gèrent elles-mêmes leurs marges latérales.
        bodyPadding: const EdgeInsets.only(bottom: AppDesign.space2),
        child: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Pays et Devise
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                child: Text(
                  'settings.preferences.country_currency'.tr,
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.bold,
                    color: AppThemeSystem.grey600,
                  ),
                ),
              ),

              SizedBox(height: context.elementSpacing * 0.75),

              // Country and currency selection
              Container(
                margin: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: openCountrySelection,
                    borderRadius: context.borderRadius(BorderRadiusType.medium),
                    child: Container(
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
                              color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                              borderRadius: context.borderRadius(BorderRadiusType.small),
                            ),
                            child: Icon(
                              Icons.public,
                              color: AppThemeSystem.primaryColor,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: context.elementSpacing),
                          Expanded(
                            child: Obx(() => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedCountry.value.isEmpty
                                          ? 'settings.preferences.select_country'.tr
                                          : selectedCountry.value,
                                      style: context.textStyle(
                                        FontSizeType.body1,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: context.elementSpacing * 0.25),
                                    Text(
                                      selectedCurrency.value.isEmpty
                                          ? 'settings.preferences.no_currency'.tr
                                          : selectedCurrency.value,
                                      style: context.textStyle(
                                        FontSizeType.caption,
                                        color: AppThemeSystem.grey600,
                                      ),
                                    ),
                                  ],
                                )),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppThemeSystem.grey400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: context.sectionSpacing),

              // Section Langue
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                child: Text(
                  'settings.language.title'.tr,
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
                  // Chaque langue est nommée dans sa propre langue : on la
                  // reconnaît même sans lire la langue courante.
                  _buildLanguageOption(
                    context,
                    'fr',
                    'Français',
                    '🇫🇷',
                    isSelected: selectedLanguage.value == 'fr',
                    isAvailable: true,
                  ),
                  _buildLanguageOption(
                    context,
                    'en',
                    'English',
                    '🇬🇧',
                    isSelected: selectedLanguage.value == 'en',
                    isAvailable: true,
                  ),
                ],
              )),

              SizedBox(height: context.sectionSpacing),

              // Section Notifications
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                child: Text(
                  'settings.notifications.title'.tr,
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
                            'settings.notifications.enable'.tr,
                            style: context.textStyle(
                              FontSizeType.body1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: context.elementSpacing * 0.25),
                          Text(
                            'settings.notifications.receive_push'.tr,
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
            ],
          ),
        ),
      ),
    );
  }

  /// Widget pour une option de langue
  Widget _buildLanguageOption(
    BuildContext context,
    String code,
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
                  _saveLanguagePreference(code, language);
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
                            'common.coming_soon'.tr,
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
  Future<void> _saveLanguagePreference(String code, String language) async {
    if (code == selectedLanguage.value) return;
    await LocaleService.to.setLanguage(code, manual: true);

    Get.snackbar(
      'settings.language.changed_title'.tr,
      'settings.language.changed_message'.trParams({'language': language}),
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
      enabled ? 'settings.notifications.enabled_title'.tr : 'settings.notifications.disabled_title'.tr,
      enabled
          ? 'settings.notifications.enabled_message'.tr
          : 'settings.notifications.disabled_message'.tr,
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

  /// Charger le pays et la devise actuels
  void _loadCurrentCountryAndCurrency() {
    if (Get.isRegistered<CurrencyService>()) {
      final country = CurrencyService.to.detectedCountry;
      final currency = CurrencyService.to.userCurrency;

      if (country != null && country.isNotEmpty) {
        selectedCountry.value = country;
      }

      if (currency != null) {
        selectedCurrency.value = '${currency.code} (${currency.symbol})';
      }
    }
  }

  /// Ouvrir le bottom sheet de sélection de pays
  void openCountrySelection() {
    // Fetch countries first
    fetchAllCountriesWithCurrencies();

    // Feuille standard, la liste gérant son propre défilement. L'ancienne
    // avait une hauteur fixe : clavier ouvert, elle montait sous la barre
    // d'état.
    AppSheet.show(
      AppSheet(
        title: 'settings.country.sheet_title'.tr,
        scrollable: false,
        bodyPadding: EdgeInsets.zero,
        child: Builder(
          builder: (context) => Column(
            children: [
              // Search bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                child: TextField(
                  onChanged: filterCountries,
                  decoration: InputDecoration(
                    hintText: 'settings.country.search_hint'.tr,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                    ),
                    filled: true,
                    fillColor: context.inputFieldColor,
                  ),
                ),
              ),

              SizedBox(height: context.elementSpacing),

              // Loading or country list
              Expanded(
                child: Obx(() {
                  if (isLoading.value && allCountries.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (filteredCountries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: AppThemeSystem.grey400,
                          ),
                          SizedBox(height: context.elementSpacing),
                          Text(
                            'settings.country.none_found'.tr,
                            style: context.textStyle(
                              FontSizeType.body1,
                              color: AppThemeSystem.grey600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    // Parcourir la liste referme le clavier de la recherche,
                    // qui en masquait la moitié.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: filteredCountries.length,
                    padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                    itemBuilder: (context, index) {
                      final item = filteredCountries[index];
                      final String country = item['country'];
                      final CurrencyModel currency = item['currency'];

                      // Drapeau fourni par le backend ; repli sur le symbole
                      // monétaire pour un pays absent du catalogue.
                      final flag = (item['flag'] as String?)?.isNotEmpty == true
                          ? item['flag'] as String
                          : CountryCatalog.flagFor(country);

                      return ListTile(
                        leading: flag.isNotEmpty
                            ? SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: Text(
                                    flag,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: AppThemeSystem.primaryColor
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  currency.symbol,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                        title: Text(
                          country,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          '${currency.code} - ${currency.name}',
                          style: TextStyle(
                            color: AppThemeSystem.grey600,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppThemeSystem.grey400,
                        ),
                        onTap: () => _showCountryConfirmationDialog(context, item),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fetch all countries with their currencies from backend
  Future<void> fetchAllCountriesWithCurrencies() async {
    try {
      isLoading.value = true;
      print('🌍 Fetching all countries and currencies from API...');

      final response = await ApiProvider.get('/v1/currencies/all-with-countries');

      print('📡 API Response - Success: ${response.success}');
      print('📡 API Response - Data null?: ${response.data == null}');

      if (response.success && response.data != null) {
        final List currencies = response.data!['data'];
        print('💱 Received ${currencies.length} currencies from API');

        // Transform data to country list with currency info
        List<Map<String, dynamic>> countries = [];

        for (var currency in currencies) {
          final currencyModel = CurrencyModel.fromJson(currency);
          print('   Processing: ${currencyModel.code} with ${currencyModel.countries.length} countries');

          // `countries_detailed` porte le drapeau calculé côté serveur. Le
          // backend renvoyant des noms anglais, le catalogue local (indexé en
          // français) ne saurait pas les retrouver.
          if (currencyModel.countriesDetailed.isNotEmpty) {
            for (final info in currencyModel.countriesDetailed) {
              countries.add({
                'country': info.name,
                'isoCode': info.isoCode,
                'currency': currencyModel,
                'flag': info.flag.isNotEmpty
                    ? info.flag
                    : CountryCatalog.flagForIsoCode(info.isoCode),
              });
            }
          } else {
            for (var country in currencyModel.countries) {
              countries.add({
                'country': country,
                'currency': currencyModel,
                'flag': CountryCatalog.flagFor(country),
              });
            }
          }
        }

        print('📋 Total countries created: ${countries.length}');

        // Sort countries alphabetically
        countries.sort((a, b) =>
          (a['country'] as String).compareTo(b['country'] as String)
        );

        allCountries.value = countries;
        filteredCountries.value = countries;
        print('✅ Countries loaded successfully!');
      } else {
        print('❌ API call failed or no data');
        print('   Message: ${response.message}');
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching countries: $e');
      print('Stack trace: $stackTrace');
      Get.snackbar(
        'common.error'.tr,
        'settings.country.load_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Filter countries based on search query
  void filterCountries(String query) {
    searchQuery.value = query;

    if (query.isEmpty) {
      filteredCountries.value = allCountries;
    } else {
      filteredCountries.value = allCountries.where((item) {
        final country = (item['country'] as String).toLowerCase();
        final currency = (item['currency'] as CurrencyModel);
        final currencyCode = currency.code.toLowerCase();
        final currencyName = currency.name.toLowerCase();
        final search = query.toLowerCase();

        return country.contains(search) ||
               currencyCode.contains(search) ||
               currencyName.contains(search);
      }).toList();
    }
  }

  /// Show confirmation dialog for country selection
  void _showCountryConfirmationDialog(BuildContext context, Map<String, dynamic> countryData) {
    final String country = countryData['country'];
    final CurrencyModel currency = countryData['currency'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('settings.country.confirm_title'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.country.country_line'.trParams({'country': country}),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'settings.country.currency_line'.trParams({
                  'code': currency.code,
                  'symbol': currency.symbol,
                }),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currency.name,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesign.info,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppDesign.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'settings.country.prices_in'.trParams({'code': currency.code}),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppDesign.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('common.cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                selectCountry(countryData);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('common.confirm'.tr),
            ),
          ],
        );
      },
    );
  }

  /// Select a country and its currency
  Future<void> selectCountry(Map<String, dynamic> countryData) async {
    try {
      final CurrencyModel currency = countryData['currency'];
      final String country = countryData['country'];

      isLoading.value = true;

      // Set the currency using CurrencyService
      await CurrencyService.to.setCountryAndCurrency(country, currency);
      await LocaleService.to.applyCountry(
        isoCode: countryData['isoCode'] as String? ?? '',
        country: country,
      );

      // Update local state
      selectedCountry.value = country;
      selectedCurrency.value = '${currency.code} (${currency.symbol})';

      // Close the bottom sheet
      Get.back();

      Get.snackbar(
        'common.success'.tr,
        'settings.country.updated'.trParams({
          'country': country,
          'code': currency.code,
        }),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.successColor,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      print('Error selecting country: $e');
      Get.snackbar(
        'common.error'.tr,
        'settings.country.select_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
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
