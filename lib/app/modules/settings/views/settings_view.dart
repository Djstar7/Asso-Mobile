import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.primaryTextColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Paramètres',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Section Profil
            _buildProfileSection(context),

            SizedBox(height: context.sectionSpacing),

            // Section Compte
            _buildSectionTitle(context, 'Compte'),
            SizedBox(height: context.elementSpacing),
            _buildSettingsCard(
              context,
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.phone_outlined,
                  title: 'Changer le numéro de téléphone',
                  subtitle: 'Modifier votre numéro de téléphone',
                  onTap: controller.changePhoneNumber,
                ),
              ],
            ),

            SizedBox(height: context.sectionSpacing),

            // Section Application
            _buildSectionTitle(context, 'Application'),
            SizedBox(height: context.elementSpacing),
            _buildSettingsCard(
              context,
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.storage,
                  title: 'Effacer le cache',
                  subtitle: 'Libérer de l\'espace de stockage',
                  onTap: controller.clearCache,
                ),
                Divider(color: context.borderColor, height: 1),
                _buildSettingsTile(
                  context,
                  icon: Icons.tune,
                  title: 'Préférences',
                  subtitle: 'Notifications, thème, langue',
                  onTap: controller.goToPreferences,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              ],
            ),

            SizedBox(height: context.sectionSpacing),

            // Section Données et confidentialité
            _buildSectionTitle(context, 'Données et confidentialité'),
            SizedBox(height: context.elementSpacing),
            _buildSettingsCard(
              context,
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'Factures',
                  subtitle: 'Consulter l\'historique de vos factures',
                  onTap: controller.goToInvoices,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                Divider(color: context.borderColor, height: 1),
                _buildSettingsTile(
                  context,
                  icon: Icons.delete_forever_outlined,
                  title: 'Supprimer mon compte',
                  subtitle: 'Supprimer définitivement votre compte',
                  onTap: controller.deleteAccount,
                  textColor: Colors.red,
                ),
              ],
            ),

            SizedBox(height: context.sectionSpacing),

            // Section À propos
            _buildSectionTitle(context, 'À propos'),
            SizedBox(height: context.elementSpacing),
            _buildSettingsCard(
              context,
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'À propos',
                  subtitle: 'Version, conditions d\'utilisation',
                  onTap: controller.goToAbout,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              ],
            ),

            SizedBox(height: context.sectionSpacing),

            // Bouton de déconnexion
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),

            SizedBox(height: context.sectionSpacing),

            // Version de l'app
            Text(
              'Version 1.0.0',
              style: context.caption.copyWith(color: context.secondaryTextColor),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Obx(() => Container(
          margin: EdgeInsets.all(context.horizontalPadding),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppThemeSystem.primaryColor,
                AppThemeSystem.primaryColor.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            boxShadow: [
              BoxShadow(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Informations
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.userName.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.userEmail.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.userPhone.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Bouton d'édition
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: controller.editProfile,
                  tooltip: 'Modifier le profil',
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: Text(
        title,
        style: context.h6.copyWith(
          fontWeight: FontWeight.bold,
          color: AppThemeSystem.primaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? textColor,
  }) {
    final effectiveTextColor = textColor ?? context.primaryTextColor;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor == Colors.red
              ? Colors.red.withValues(alpha: 0.1)
              : AppThemeSystem.primaryColor.withValues(alpha: 0.1),
          borderRadius: context.borderRadius(BorderRadiusType.small),
        ),
        child: Icon(
          icon,
          color: textColor ?? AppThemeSystem.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: context.body2.copyWith(
          fontWeight: FontWeight.w600,
          color: effectiveTextColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: context.caption,
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
