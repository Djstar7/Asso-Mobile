import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/complete_profile_controller.dart';

class CompleteProfileView extends GetView<CompleteProfileController> {
  const CompleteProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceType = AppThemeSystem.getDeviceType(context);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.backgroundColor,
        title: Text(
          'Compléter votre profil',
          style: context.textStyle(
            deviceType == DeviceType.mobile ? FontSizeType.h5 : FontSizeType.h4,
            fontWeight: FontWeight.w600,
            color: context.primaryTextColor,
          ),
        ),
        centerTitle: true,
        leading: null,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with description
            _buildHeaderSection(context, deviceType),

            SizedBox(height: context.sectionSpacing),

            // Form content
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.horizontalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First Name Field
                  _buildTextFieldLabel(context, 'Prénom', true),
                  SizedBox(height: context.elementSpacing),
                  _buildTextField(
                    context,
                    controller.firstNameController,
                    'Entrez votre prénom',
                    Icons.person_outline,
                  ),
                  SizedBox(height: context.sectionSpacing),

                  // Last Name Field
                  _buildTextFieldLabel(context, 'Nom', true),
                  SizedBox(height: context.elementSpacing),
                  _buildTextField(
                    context,
                    controller.lastNameController,
                    'Entrez votre nom',
                    Icons.person_outline,
                  ),
                  SizedBox(height: context.sectionSpacing),

                  // Email Field (Optional)
                  _buildTextFieldLabel(context, 'Email', false),
                  SizedBox(height: context.elementSpacing),
                  _buildTextField(
                    context,
                    controller.emailController,
                    'Entrez votre email (optionnel)',
                    Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: context.sectionSpacing),

                  // Gender Selection
                  _buildTextFieldLabel(context, 'Genre', false),
                  SizedBox(height: context.elementSpacing),
                  _buildGenderSelection(context),
                  SizedBox(height: context.sectionSpacing),

                  // Birth Date Picker
                  _buildTextFieldLabel(context, 'Date de naissance', false),
                  SizedBox(height: context.elementSpacing),
                  _buildBirthDatePicker(context),
                  SizedBox(height: context.sectionSpacing),

                  // Address Field
                  _buildTextFieldLabel(context, 'Adresse', false),
                  SizedBox(height: context.elementSpacing),
                  _buildTextField(
                    context,
                    TextEditingController()..text = controller.address.value,
                    'Entrez votre adresse (optionnelle)',
                    Icons.location_on_outlined,
                    maxLines: 3,
                    onChanged: (value) => controller.address.value = value,
                  ),
                  SizedBox(height: context.sectionSpacing * 2),

                  // Save Button
                  _buildSaveButton(context, deviceType),

                  // Espacement pour la barre de navigation native du téléphone
                  SizedBox(
                    height: MediaQuery.of(context).viewPadding.bottom +
                        context.verticalPadding,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, DeviceType deviceType) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.horizontalPadding * 1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeSystem.primaryColor,
            AppThemeSystem.tertiaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  deviceType == DeviceType.mobile ? 12 : 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: context.borderRadius(BorderRadiusType.medium),
                ),
                child: Icon(
                  Icons.person_add_outlined,
                  color: Colors.white,
                  size: deviceType == DeviceType.mobile ? 28 : 36,
                ),
              ),
              SizedBox(width: context.elementSpacing * 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finalisez votre profil',
                      style: context.textStyle(
                        deviceType == DeviceType.mobile
                            ? FontSizeType.h5
                            : FontSizeType.h4,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: context.elementSpacing * 0.5),
                    Text(
                      'Complétez vos informations pour continuer',
                      style: context.textStyle(
                        deviceType == DeviceType.mobile
                            ? FontSizeType.body2
                            : FontSizeType.body1,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldLabel(
    BuildContext context,
    String label,
    bool isRequired,
  ) {
    final deviceType = AppThemeSystem.getDeviceType(context);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: context.textStyle(
              deviceType == DeviceType.mobile
                  ? FontSizeType.body2
                  : FontSizeType.body1,
              fontWeight: FontWeight.w600,
              color: context.primaryTextColor,
            ),
          ),
          if (isRequired) ...[
            TextSpan(
              text: ' *',
              style: context.textStyle(
                deviceType == DeviceType.mobile
                    ? FontSizeType.body2
                    : FontSizeType.body1,
                fontWeight: FontWeight.w600,
                color: AppThemeSystem.errorColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController textController,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    final deviceType = AppThemeSystem.getDeviceType(context);

    return TextField(
      controller: textController,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: AppThemeSystem.primaryColor,
          size: deviceType == DeviceType.mobile ? 20 : 24,
        ),
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
          borderSide: BorderSide(
            color: AppThemeSystem.primaryColor,
            width: deviceType == DeviceType.mobile ? 2 : 2.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding,
          vertical: context.verticalPadding * 0.75,
        ),
        hintStyle: context.textStyle(
          deviceType == DeviceType.mobile
              ? FontSizeType.body2
              : FontSizeType.body1,
          color: context.secondaryTextColor,
        ),
      ),
      style: context.textStyle(
        deviceType == DeviceType.mobile
            ? FontSizeType.body1
            : FontSizeType.subtitle1,
        color: context.primaryTextColor,
      ),
    );
  }

  Widget _buildGenderSelection(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _buildGenderChip(
              context,
              'Homme',
              'H',
              controller.selectedGender.value == 'H',
              () => controller.selectGender('H'),
            ),
          ),
          SizedBox(width: context.elementSpacing),
          Expanded(
            child: _buildGenderChip(
              context,
              'Femme',
              'F',
              controller.selectedGender.value == 'F',
              () => controller.selectGender('F'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(
    BuildContext context,
    String label,
    String value,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final deviceType = AppThemeSystem.getDeviceType(context);
    final isDark = AppThemeSystem.isDarkMode(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: context.verticalPadding * 0.75,
          horizontal: context.horizontalPadding * 0.5,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeSystem.primaryColor
              : context.surfaceColor,
          border: Border.all(
            color: isSelected
                ? AppThemeSystem.primaryColor
                : context.borderColor,
            width: deviceType == DeviceType.mobile ? 2 : 2.5,
          ),
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value == 'H' ? Icons.male_outlined : Icons.female_outlined,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? AppThemeSystem.grey300
                      : context.secondaryTextColor),
              size: deviceType == DeviceType.mobile ? 20 : 24,
            ),
            SizedBox(width: context.elementSpacing * 0.75),
            Text(
              label,
              style: context.textStyle(
                deviceType == DeviceType.mobile
                    ? FontSizeType.body1
                    : FontSizeType.subtitle1,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : context.primaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthDatePicker(BuildContext context) {
    final deviceType = AppThemeSystem.getDeviceType(context);
    final isDark = AppThemeSystem.isDarkMode(context);

    return Obx(
      () => GestureDetector(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: controller.birthDate.value ?? DateTime.now(),
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: isDark
                      ? ColorScheme.dark(
                          primary: AppThemeSystem.primaryColor,
                          onPrimary: Colors.white,
                          surface: AppThemeSystem.darkCardColor,
                          onSurface: Colors.white,
                        )
                      : ColorScheme.light(
                          primary: AppThemeSystem.primaryColor,
                          onPrimary: Colors.white,
                          surface: context.surfaceColor,
                        ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null) {
            controller.selectBirthDate(picked);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.verticalPadding * 0.75,
          ),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border.all(
              color: context.borderColor,
              width: 1,
            ),
            borderRadius: context.borderRadius(BorderRadiusType.medium),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: AppThemeSystem.primaryColor,
                size: deviceType == DeviceType.mobile ? 20 : 24,
              ),
              SizedBox(width: context.horizontalPadding),
              Expanded(
                child: Text(
                  controller.birthDate.value != null
                      ? '${controller.birthDate.value!.day.toString().padLeft(2, '0')}/${controller.birthDate.value!.month.toString().padLeft(2, '0')}/${controller.birthDate.value!.year}'
                      : 'Sélectionnez une date',
                  style: context.textStyle(
                    deviceType == DeviceType.mobile
                        ? FontSizeType.body1
                        : FontSizeType.subtitle1,
                    color: controller.birthDate.value != null
                        ? context.primaryTextColor
                        : context.secondaryTextColor,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: deviceType == DeviceType.mobile ? 16 : 18,
                color: AppThemeSystem.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, DeviceType deviceType) {
    final isDark = AppThemeSystem.isDarkMode(context);
    // Le bouton orange a toujours du texte blanc pour une meilleure lisibilité
    final buttonTextColor = Colors.white;

    return Obx(
      () => SizedBox(
        width: double.infinity,
        height: context.buttonHeight,
        child: ElevatedButton.icon(
          onPressed: controller.isLoading.value
              ? null
              : () => controller.saveProfile(),
          icon: controller.isLoading.value
              ? SizedBox(
                  width: deviceType == DeviceType.mobile ? 20 : 24,
                  height: deviceType == DeviceType.mobile ? 20 : 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      buttonTextColor,
                    ),
                  ),
                )
              : Icon(
                  Icons.check_circle_outline,
                  size: deviceType == DeviceType.mobile ? 20 : 24,
                ),
          label: Text(
            controller.isLoading.value
                ? 'Enregistrement...'
                : 'Enregistrer le profil',
            style: context.textStyle(
              deviceType == DeviceType.mobile
                  ? FontSizeType.button
                  : FontSizeType.subtitle1,
              fontWeight: FontWeight.w600,
              color: buttonTextColor,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeSystem.primaryColor,
            foregroundColor: buttonTextColor,
            disabledBackgroundColor: isDark
                ? AppThemeSystem.grey700
                : AppThemeSystem.grey400,
            disabledForegroundColor: isDark
                ? AppThemeSystem.grey500
                : Colors.white.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
            ),
            elevation: isDark ? 4 : 2,
            shadowColor: AppThemeSystem.primaryColor.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
