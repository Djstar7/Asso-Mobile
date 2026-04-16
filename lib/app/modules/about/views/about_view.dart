import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/about_controller.dart';

class AboutView extends GetView<AboutController> {
  const AboutView({super.key});

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
          'À propos',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Section Logo et Version
            _buildHeaderSection(context),

            SizedBox(height: context.sectionSpacing),

            // Informations de l'application
            _buildAppInfoSection(context),

            SizedBox(height: context.sectionSpacing),

            // Liens légaux
            _buildLegalSection(context),

            SizedBox(height: context.sectionSpacing),

            // Section Feedback
            _buildFeedbackSection(context),

            const SizedBox(height: 32),

            // Copyright
            _buildCopyright(context),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeSystem.primaryColor,
            AppThemeSystem.primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Logo placeholder
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.shopping_bag,
              size: 50,
              color: AppThemeSystem.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Obx(() => Text(
            controller.appName.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          )),
          const SizedBox(height: 8),
          Obx(() => Text(
            'Version ${controller.appVersion.value} (${controller.buildNumber.value})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          )),
          const SizedBox(height: 4),
          Text(
            controller.releaseDate,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'À propos de l\'application',
            style: context.body1.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Obx(() => Text(
            controller.appDescription.value.isNotEmpty
                ? controller.appDescription.value
                : 'Asso Market est une plateforme de commerce en ligne qui connecte '
                    'les vendeurs et les acheteurs au Cameroun. Nous offrons une expérience '
                    'd\'achat simple, rapide et sécurisée avec livraison à domicile.',
            style: context.body2.copyWith(height: 1.5),
          )),
        ],
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          _buildLegalItem(
            context,
            icon: Icons.description,
            title: 'Conditions d\'utilisation',
            subtitle: 'Consultez nos conditions d\'utilisation',
            onTap: controller.showTermsOfService,
          ),
          Divider(color: context.borderColor, height: 1),
          _buildLegalItem(
            context,
            icon: Icons.privacy_tip,
            title: 'Politique de confidentialité',
            subtitle: 'Comment nous protégeons vos données',
            onTap: controller.showPrivacyPolicy,
          ),
          Divider(color: context.borderColor, height: 1),
          _buildLegalItem(
            context,
            icon: Icons.info_outline,
            title: 'Licences open source',
            subtitle: 'Bibliothèques et licences utilisées',
            onTap: controller.showLicenses,
          ),
        ],
      ),
    );
  }

  Widget _buildLegalItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppThemeSystem.primaryColor, size: 20),
      ),
      title: Text(title, style: context.body2.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: context.caption),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildFeedbackSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: ElevatedButton.icon(
        onPressed: controller.sendFeedback,
        icon: const Icon(Icons.feedback_outlined),
        label: const Text('Envoyer un feedback'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeSystem.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }

  Widget _buildCopyright(BuildContext context) {
    return Column(
      children: [
        Text(
          '© 2026 ${controller.appName}',
          style: context.caption.copyWith(color: context.secondaryTextColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Tous droits réservés',
          style: context.caption.copyWith(color: context.secondaryTextColor),
        ),
      ],
    );
  }
}
