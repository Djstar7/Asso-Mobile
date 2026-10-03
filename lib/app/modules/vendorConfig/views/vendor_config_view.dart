import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/media_helper.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/vendor_config_controller.dart';

class VendorConfigView extends GetView<VendorConfigController> {
  const VendorConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'vendor_config.view.title'.tr,
          style: context.h5.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Obx(() {
        return Column(
          children: [
            // Stepper indicator
            _buildStepperIndicator(context),

            // Content
            Expanded(
              child: controller.currentStep.value == 0
                  ? _buildStep1(context)
                  : controller.currentStep.value == 1
                      ? _buildStep2(context)
                      : _buildStep3(context),
            ),

            // Navigation buttons
            if (controller.currentStep.value < 2)
              _buildNavigationButtons(context),
          ],
        );
      }),
    );
  }

  /// Indicateur de progression
  Widget _buildStepperIndicator(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: context.verticalPadding,
      ),
      child: Row(
        children: [
          _buildStepCircle(context, 1, controller.currentStep.value >= 0),
          Expanded(
            child: Container(
              height: 2,
              color: controller.currentStep.value >= 1
                  ? AppThemeSystem.primaryColor
                  : context.borderColor,
            ),
          ),
          _buildStepCircle(context, 2, controller.currentStep.value >= 1),
          Expanded(
            child: Container(
              height: 2,
              color: controller.currentStep.value >= 2
                  ? AppThemeSystem.primaryColor
                  : context.borderColor,
            ),
          ),
          _buildStepCircle(context, 3, controller.currentStep.value >= 2),
        ],
      ),
    );
  }

  Widget _buildStepCircle(BuildContext context, int step, bool isActive) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? AppThemeSystem.primaryColor : context.surfaceColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? AppThemeSystem.primaryColor : context.borderColor,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '$step',
          style: context.body1.copyWith(
            color: isActive ? Colors.white : context.secondaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Étape 1: Profil personnel
  Widget _buildStep1(BuildContext context) {
    return SingleChildScrollView(
      controller: controller.step1ScrollController,
      // Les boutons d'étape sont sous le formulaire : faire défiler referme
      // le clavier qui les recouvrait.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: context.elementSpacing),

          // Titre
          Text(
            'vendor_config.view.personal_info'.tr,
            style: context.h3.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: context.elementSpacing * 0.5),

          Text(
            'vendor_config.view.personal_info_subtitle'.tr,
            style: context.body2.copyWith(
              color: context.secondaryTextColor,
            ),
          ),

          SizedBox(height: context.sectionSpacing),

          // Photo de profil - EN PREMIER
          Center(
            child: Column(
              children: [
                Text(
                  'vendor_config.view.profile_photo_label'.tr,
                  style: context.subtitle1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.elementSpacing),
                Obx(() {
                  return GestureDetector(
                    onTap: controller.isPickingProfileImage.value
                        ? null
                        : controller.pickProfileImage,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeSystem.primaryColor,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: controller.isPickingProfileImage.value
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppThemeSystem.primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'vendor_config.view.loading'.tr,
                                    style: context.caption.copyWith(
                                      color: AppThemeSystem.primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : controller.profileImage.value != null
                              ? ClipOval(
                                  child: MediaHelper.buildImagePreview(
                                    controller.profileImage.value!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.add_a_photo,
                                  color: AppThemeSystem.primaryColor,
                                  size: 48,
                                ),
                    ),
                  );
                }),
                SizedBox(height: context.elementSpacing * 0.5),
                Text(
                  'vendor_config.view.tap_add_photo'.tr,
                  style: context.caption.copyWith(
                    color: context.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: context.sectionSpacing * 1.5),

          // Type de compte - EN DEUXIEME
          Text(
            'vendor_config.view.account_type_label'.tr,
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          Obx(() => Row(
                children: controller.accountTypes.map((type) {
                  final isSelected = controller.selectedAccountType.value == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => controller.selectedAccountType.value = type,
                      child: Container(
                        margin: EdgeInsets.only(
                          right: type == controller.accountTypes.first ? 12 : 0,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: context.verticalPadding,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                              : context.surfaceColor,
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                          border: Border.all(
                            color: isSelected
                                ? AppThemeSystem.primaryColor
                                : context.borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              type == 'Entreprise'
                                  ? Icons.business
                                  : Icons.person,
                              color: isSelected
                                  ? AppThemeSystem.primaryColor
                                  : context.secondaryTextColor,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              type == 'Entreprise'
                                  ? 'vendor_config.view.company'.tr
                                  : 'vendor_config.view.individual'.tr,
                              style: context.body1.copyWith(
                                color: isSelected
                                    ? AppThemeSystem.primaryColor
                                    : context.primaryTextColor,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )),

          SizedBox(height: context.sectionSpacing),

          // Genre - EN TROISIEME horizontalement
          Text(
            'vendor_config.view.gender_label'.tr,
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          Obx(() => Row(
                children: controller.genders.map((gender) {
                  final isSelected = controller.selectedGender.value == gender;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => controller.selectedGender.value = gender,
                      child: Container(
                        margin: EdgeInsets.only(
                          right: gender == controller.genders.first ? 12 : 0,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: context.verticalPadding,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                              : context.surfaceColor,
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                          border: Border.all(
                            color: isSelected
                                ? AppThemeSystem.primaryColor
                                : context.borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              gender == 'Homme'
                                  ? Icons.male
                                  : Icons.female,
                              color: isSelected
                                  ? AppThemeSystem.primaryColor
                                  : context.secondaryTextColor,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              gender == 'Homme'
                                  ? 'vendor_config.view.male'.tr
                                  : 'vendor_config.view.female'.tr,
                              style: context.body1.copyWith(
                                color: isSelected
                                    ? AppThemeSystem.primaryColor
                                    : context.primaryTextColor,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )),

          SizedBox(height: context.sectionSpacing),

          // Prénom
          Text(
            'vendor_config.view.first_name_label'.tr,
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          TextField(
            controller: controller.firstNameController,
            style: TextStyle(
              color: AppThemeSystem.getPrimaryTextColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'vendor_config.view.first_name_hint'.tr,
              filled: true,
              fillColor: context.inputFieldColor,
              prefixIcon: Icon(Icons.person_outline),
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
            ),
          ),

          SizedBox(height: context.sectionSpacing),

          // Nom
          Text(
            'vendor_config.view.last_name_label'.tr,
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          TextField(
            controller: controller.lastNameController,
            style: TextStyle(
              color: AppThemeSystem.getPrimaryTextColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'vendor_config.view.last_name_hint'.tr,
              filled: true,
              fillColor: context.inputFieldColor,
              prefixIcon: Icon(Icons.badge_outlined),
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
            ),
          ),

          SizedBox(height: context.sectionSpacing),

          // Email (optionnel)
          Text(
            'vendor_config.view.email_label'.tr,
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          TextField(
            controller: controller.emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              color: AppThemeSystem.getPrimaryTextColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'vendor_config.view.email_hint'.tr,
              filled: true,
              fillColor: context.inputFieldColor,
              prefixIcon: Icon(Icons.email_outlined),
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
            ),
          ),

          SizedBox(height: context.verticalPadding * 2),
        ],
      ),
    );
  }

  /// Étape 2: Configuration boutique
  Widget _buildStep2(BuildContext context) {
    return SingleChildScrollView(
      controller: controller.step2ScrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: context.elementSpacing),

          // Titre
          Text(
            'vendor_config.view.shop_setup'.tr,
            style: context.h3.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: context.elementSpacing * 0.5),

          Text(
            'vendor_config.view.shop_setup_subtitle'.tr,
            style: context.body2.copyWith(
              color: context.secondaryTextColor,
            ),
          ),

          SizedBox(height: context.sectionSpacing),

          // Logo boutique
          Center(
            child: Column(
              children: [
                Text(
                  'vendor_config.view.shop_logo_label'.tr,
                  style: context.subtitle1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.elementSpacing),
                Obx(() {
                  return GestureDetector(
                    onTap: controller.isPickingShopLogo.value
                        ? null
                        : controller.pickShopLogo,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                        borderRadius: context.borderRadius(BorderRadiusType.large),
                        border: Border.all(
                          color: AppThemeSystem.primaryColor,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: controller.isPickingShopLogo.value
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppThemeSystem.primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'vendor_config.view.loading'.tr,
                                    style: context.caption.copyWith(
                                      color: AppThemeSystem.primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : controller.shopLogo.value != null
                              ? ClipRRect(
                                  borderRadius: context.borderRadius(BorderRadiusType.large),
                                  child: MediaHelper.buildImagePreview(
                                    controller.shopLogo.value!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.store,
                                  color: AppThemeSystem.primaryColor,
                                  size: 48,
                                ),
                    ),
                  );
                }),
                SizedBox(height: context.elementSpacing * 0.5),
                Text(
                  'vendor_config.view.tap_add_logo'.tr,
                  style: context.caption.copyWith(
                    color: context.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: context.sectionSpacing * 1.5),

          // Nom de la boutique
          Text(
            'vendor_config.view.shop_name_label'.tr,
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          TextField(
            controller: controller.shopNameController,
            style: TextStyle(
              color: AppThemeSystem.getPrimaryTextColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'vendor_config.view.shop_name_hint'.tr,
              filled: true,
              fillColor: context.inputFieldColor,
              prefixIcon: Icon(Icons.store_outlined),
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
            ),
          ),

          SizedBox(height: context.sectionSpacing),

          // Description
          Text(
            'vendor_config.view.description_label'.tr,
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          TextField(
            controller: controller.shopDescriptionController,
            maxLines: 4,
            style: TextStyle(
              color: AppThemeSystem.getPrimaryTextColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'vendor_config.view.description_hint'.tr,
              filled: true,
              fillColor: context.inputFieldColor,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.description_outlined),
              ),
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
            ),
          ),

          SizedBox(height: context.sectionSpacing),

          // Emplacement (carte OpenStreetMap)
          Text(
            'vendor_config.view.location_label'.tr,
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          Center(
            child: GestureDetector(
              onTap: controller.openMapPicker,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: context.borderRadius(BorderRadiusType.medium),
                  border: Border.all(
                    color: context.borderColor,
                    width: 2,
                  ),
                ),
                child: Obx(() {
                  if (controller.shopLocation.value.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 48,
                            color: AppThemeSystem.primaryColor,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'vendor_config.view.tap_open_map'.tr,
                            style: context.body1.copyWith(
                              color: context.secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'vendor_config.view.select_position'.tr,
                            style: context.caption.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
            
                  return Padding(
                    padding: EdgeInsets.all(context.horizontalPadding * 0.75),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 36,
                          color: AppThemeSystem.successColor,
                        ),
                        SizedBox(height: 6),
                        Text(
                          controller.shopLocation.value,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: controller.openMapPicker,
                          icon: Icon(Icons.edit_location, size: 16),
                          label: Text(
                            'vendor_config.view.edit'.tr,
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppThemeSystem.primaryColor,
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

          SizedBox(height: context.elementSpacing),

          // Statut de la zone de livraison
          Obx(() {
            if (controller.shopLocation.value.isNotEmpty &&
                controller.isCheckingDeliveryAvailability.value) {
              return Container(
                padding: EdgeInsets.all(context.verticalPadding),
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: context.borderRadius(BorderRadiusType.medium),
                  border: Border.all(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppThemeSystem.primaryColor,
                        ),
                      ),
                    ),
                    SizedBox(width: context.elementSpacing),
                    Expanded(
                      child: Text(
                        'vendor_config.checking_zone'.tr,
                        style: context.body2.copyWith(
                          color: AppThemeSystem.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else if (controller.shopLocation.value.isNotEmpty) {
              if (controller.isDeliveryAvailable.value) {
                return Container(
                  padding: EdgeInsets.all(context.verticalPadding),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.successColor.withValues(alpha: 0.1),
                    borderRadius: context.borderRadius(BorderRadiusType.medium),
                    border: Border.all(
                      color: AppThemeSystem.successColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppThemeSystem.successColor,
                        size: 20,
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: Text(
                          'vendor_config.view.zone_available'.tr,
                          style: context.body2.copyWith(
                            color: AppThemeSystem.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Container(
                  padding: EdgeInsets.all(context.verticalPadding),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.errorColor.withValues(alpha: 0.1),
                    borderRadius: context.borderRadius(BorderRadiusType.medium),
                    border: Border.all(
                      color: AppThemeSystem.errorColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error,
                        color: AppThemeSystem.errorColor,
                        size: 20,
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: Text(
                          'vendor_config.view.zone_unavailable'.tr,
                          style: context.body2.copyWith(
                            color: AppThemeSystem.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            }
            return SizedBox.shrink();
          }),

          SizedBox(height: context.sectionSpacing),

          // Catégories
          Row(
            children: [
              Expanded(
                child: Text(
                  'vendor_config.view.sectors_label'.tr,
                  style: context.subtitle1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Refresh button si erreur
              Obx(() {
                if (controller.categoriesLoadError.value.isNotEmpty) {
                  return IconButton(
                    icon: Icon(Icons.refresh, size: 20),
                    onPressed: controller.refreshCategories,
                    tooltip: 'vendor_config.view.reload_categories'.tr,
                  );
                }
                return SizedBox.shrink();
              }),
            ],
          ),
          SizedBox(height: context.elementSpacing * 0.5),
          Text(
            'vendor_config.view.select_categories'.tr,
            style: context.caption.copyWith(
              color: context.secondaryTextColor,
            ),
          ),
          SizedBox(height: context.elementSpacing),

          // État de chargement, erreur ou catégories
          Obx(() {
            // Loading state
            if (controller.isCategoriesLoading.value) {
              return Container(
                padding: EdgeInsets.all(context.verticalPadding),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: context.elementSpacing),
                      Text(
                        'vendor_config.view.loading_categories'.tr,
                        style: context.caption.copyWith(
                          color: context.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Error state
            if (controller.categoriesLoadError.value.isNotEmpty) {
              return Container(
                padding: EdgeInsets.all(context.verticalPadding),
                decoration: BoxDecoration(
                  color: AppThemeSystem.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppThemeSystem.errorColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppThemeSystem.errorColor,
                      size: 32,
                    ),
                    SizedBox(height: context.elementSpacing * 0.5),
                    Text(
                      controller.categoriesLoadError.value,
                      style: context.body2.copyWith(
                        color: AppThemeSystem.errorColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: context.elementSpacing),
                    ElevatedButton.icon(
                      onPressed: controller.refreshCategories,
                      icon: Icon(Icons.refresh, size: 18),
                      label: Text('vendor_config.view.retry'.tr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeSystem.errorColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Categories loaded - display chips
            if (controller.categories.isEmpty) {
              return Container(
                padding: EdgeInsets.all(context.verticalPadding),
                child: Text(
                  'vendor_config.view.no_category'.tr,
                  style: context.body2.copyWith(
                    color: context.secondaryTextColor,
                  ),
                ),
              );
            }

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: controller.categories.map((category) {
                final isSelected = controller.selectedCategories.contains(category.name);
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.name),
                      if (category.productsCount != null && category.productsCount! > 0)
                        Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text(
                            '(${category.productsCount})',
                            style: context.caption.copyWith(
                              color: isSelected ? Colors.white70 : context.secondaryTextColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    controller.toggleCategory(category.name);
                  },
                  selectedColor: AppThemeSystem.primaryColor,
                  checkmarkColor: Colors.white,
                  backgroundColor: context.surfaceColor,
                  side: BorderSide(
                    color: isSelected
                        ? AppThemeSystem.primaryColor
                        : context.borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                  labelStyle: context.body2.copyWith(
                    color: isSelected ? Colors.white : context.primaryTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                );
              }).toList(),
            );
          }),

          SizedBox(height: context.verticalPadding * 2),
        ],
      ),
    );
  }

  /// Étape 3: Félicitations et statut pending
  Widget _buildStep3(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        controller: controller.step3ScrollController,
        padding: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône de succès
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppThemeSystem.successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppThemeSystem.successColor,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: AppThemeSystem.successColor,
              ),
            ),

            SizedBox(height: context.sectionSpacing * 1.5),

            // Titre de félicitations
            Text(
              'vendor_config.view.congrats'.tr,
              style: context.h2.copyWith(
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.successColor,
              ),
            ),

            SizedBox(height: context.elementSpacing),

            Text(
              'vendor_config.view.request_sent'.tr,
              style: context.h4.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            SizedBox(height: context.sectionSpacing * 1.5),
            // Bouton pour continuer vers la boutique
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.navigateToShop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: context.verticalPadding * 1.25,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: context.borderRadius(BorderRadiusType.large),
                  ),
                  elevation: 2,
                ),
                icon: Icon(Icons.store, size: 24),
                label: Text(
                  'vendor_config.view.go_to_shop'.tr,
                  style: context.button.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            SizedBox(height: context.elementSpacing),

            // Texte d'information supplémentaire
            Text(
              'vendor_config.view.first_setup'.tr,
              textAlign: TextAlign.center,
              style: context.caption.copyWith(
                color: context.secondaryTextColor,
              ),
            ),

            SizedBox(height: context.sectionSpacing * 2),
          ],
        ),
      ),
    );
  }

  /// Boutons de navigation
  Widget _buildNavigationButtons(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final isLoading = controller.isLoading.value;
          final isFirstStep = controller.currentStep.value == 0;
          final isSecondStep = controller.currentStep.value == 1;

          // Check if all required fields in Step 2 are filled
          final isStep2Complete = isSecondStep &&
              controller.shopNameText.value.trim().isNotEmpty &&
              controller.shopDescriptionText.value.trim().isNotEmpty &&
              controller.shopLogo.value != null &&
              controller.shopLocation.value.isNotEmpty &&
              controller.selectedCategories.isNotEmpty;

          // Button is enabled only if:
          // - Not loading
          // - If Step 2: all fields filled (shopLocation can only be filled if position is valid)
          // - If Step 1: proceed normally (will be validated in controller)
          final isButtonEnabled = !isLoading &&
              (!isSecondStep || isStep2Complete);

          return Row(
            children: [
              // Bouton Précédent
              if (!isFirstStep)
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.previousStep,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: context.verticalPadding * 0.75,
                      ),
                      side: BorderSide(
                        color: context.borderColor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                      ),
                    ),
                    child: Text(
                      'vendor_config.view.previous'.tr,
                      style: context.button.copyWith(
                        color: context.primaryTextColor,
                      ),
                    ),
                  ),
                ),

              if (!isFirstStep) SizedBox(width: 12),

              // Bouton Suivant/Finaliser
              Expanded(
                flex: isFirstStep ? 1 : 1,
                child: ElevatedButton(
                  onPressed: isButtonEnabled ? controller.nextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeSystem.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.borderColor,
                    disabledForegroundColor: context.secondaryTextColor,
                    padding: EdgeInsets.symmetric(
                      vertical: context.verticalPadding * 0.75,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          isFirstStep ? 'vendor_config.view.next'.tr : 'vendor_config.view.finish'.tr,
                          style: context.button.copyWith(
                            color: isButtonEnabled ? Colors.white : context.secondaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
