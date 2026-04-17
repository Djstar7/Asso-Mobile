import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: context.primaryTextColor,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Devenir Vendeur',
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
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: context.elementSpacing),

          // Titre
          Text(
            'Informations personnelles',
            style: context.h3.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: context.elementSpacing * 0.5),

          Text(
            'Complétez votre profil pour devenir vendeur',
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
                  'Photo de profil *',
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
                                    'Chargement...',
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
                                  child: Image.file(
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
                  'Appuyez pour ajouter une photo',
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
            'Type de compte *',
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
                              type,
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
            'Genre *',
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
                              gender,
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
            'Prénom *',
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
              hintText: 'Votre prénom',
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
            'Nom *',
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
              hintText: 'Votre nom',
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
            'Email (optionnel)',
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
              hintText: 'votre.email@exemple.com',
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
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: context.elementSpacing),

          // Titre
          Text(
            'Configuration de votre boutique',
            style: context.h3.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: context.elementSpacing * 0.5),

          Text(
            'Configurez votre espace de vente',
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
                  'Logo de la boutique *',
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
                                    'Chargement...',
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
                                  child: Image.file(
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
                  'Appuyez pour ajouter un logo',
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
            'Nom de la boutique *',
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
              hintText: 'Ex: Boutique Kira',
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
            'Description de votre activité *',
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
              hintText: 'Décrivez votre activité et vos produits...',
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
            'Emplacement de la boutique *',
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
                            'Appuyez pour ouvrir la carte',
                            style: context.body1.copyWith(
                              color: context.secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Sélectionnez votre position',
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
                            'Modifier',
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
                        'Vérification de la zone de livraison...',
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
                          'Zone de livraison disponible',
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
                          'Hors zone de livraison - Veuillez choisir un autre emplacement',
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
                  'Secteurs d\'activité *',
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
                    tooltip: 'Recharger les catégories',
                  );
                }
                return SizedBox.shrink();
              }),
            ],
          ),
          SizedBox(height: context.elementSpacing * 0.5),
          Text(
            'Sélectionnez une ou plusieurs catégories',
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
                        'Chargement des catégories...',
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
                      label: Text('Réessayer'),
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
                  'Aucune catégorie disponible',
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
              'Félicitations !',
              style: context.h2.copyWith(
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.successColor,
              ),
            ),

            SizedBox(height: context.elementSpacing),

            Text(
              'Votre demande a été envoyée',
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
                  'Accéder à ma boutique',
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
              'Vous pourrez commencer vos premières configurations',
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
                      'Précédent',
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
                          isFirstStep ? 'Suivant' : 'Finaliser',
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
