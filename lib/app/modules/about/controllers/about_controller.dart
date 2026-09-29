import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/values/constants.dart';
import '../../../data/providers/api_provider.dart';
import '../../../core/utils/app_design.dart';
import '../../legal/controllers/legal_controller.dart';

class AboutController extends GetxController {
  final isLoading = false.obs;

  // Informations de l'application (from API)
  final appName = 'Asso Market'.obs;
  final appVersion = '1.0.0'.obs;
  final buildNumber = '1'.obs;
  final appDescription = ''.obs;
  final appLogo = Rx<String?>(null);

  // Contact
  final contactEmail = ''.obs;
  final contactPhone = ''.obs;
  final contactAddress = ''.obs;
  final contactWebsite = ''.obs;

  // Legal
  // Documents légaux du back-office (CGU, CGV, confidentialité…).
  final legalDocuments = <LegalDocument>[].obs;

  // Credits
  final developedBy = 'ASSO Team'.obs;
  final copyright = ''.obs;

  String get releaseDate => 'about.release_date'.tr;

  // Réseaux sociaux
  final socialLinks = <SocialLink>[].obs;

  @override
  void onInit() {
    super.onInit();
    developer.log('========== ABOUT CONTROLLER INIT ==========', name: 'AboutController');
    fetchAboutData();
  }

  /// Fetch about data from API
  Future<void> fetchAboutData() async {
    isLoading.value = true;

    developer.log('========== FETCH ABOUT DATA ==========', name: 'AboutController');

    try {
      final response = await ApiProvider.get(AppConstants.aboutUrl);

      developer.log(
        'About data response',
        name: 'AboutController',
        error: 'Success: ${response.success}',
      );

      if (response.success && response.data != null) {
        final aboutData = response.data!['about'] as Map<String, dynamic>;

        // App info
        appName.value = aboutData['app_name'] as String? ?? 'ASSO';
        appVersion.value = aboutData['version'] as String? ?? '1.0.0';
        buildNumber.value = aboutData['build_number'] as String? ?? '1';
        appDescription.value = aboutData['description'] as String? ?? '';
        appLogo.value = aboutData['logo'] as String?;

        // Contact
        final contact = aboutData['contact'] as Map<String, dynamic>?;
        if (contact != null) {
          contactEmail.value = contact['email'] as String? ?? '';
          contactPhone.value = contact['phone'] as String? ?? '';
          contactAddress.value = contact['address'] as String? ?? '';
          contactWebsite.value = contact['website'] as String? ?? '';
        }

        // Legal
        final legal = aboutData['legal'] as Map<String, dynamic>?;
        if (legal != null) {
          legalDocuments.assignAll(LegalDocument.listFrom(legal['pages']));
        }

        // Social
        final social = aboutData['social'] as Map<String, dynamic>?;
        if (social != null) {
          final links = <SocialLink>[];

          if (social['facebook'] != null && (social['facebook'] as String).isNotEmpty) {
            links.add(SocialLink(
              name: 'Facebook',
              icon: Icons.facebook,
              url: social['facebook'] as String,
              color: const Color(0xFF1877F2),
            ));
          }

          if (social['twitter'] != null && (social['twitter'] as String).isNotEmpty) {
            links.add(SocialLink(
              name: 'Twitter',
              icon: Icons.close,
              url: social['twitter'] as String,
              color: Colors.black,
            ));
          }

          if (social['instagram'] != null && (social['instagram'] as String).isNotEmpty) {
            links.add(SocialLink(
              name: 'Instagram',
              icon: Icons.camera_alt,
              url: social['instagram'] as String,
              color: const Color(0xFFE4405F),
            ));
          }

          socialLinks.value = links;
        }

        // Credits
        final credits = aboutData['credits'] as Map<String, dynamic>?;
        if (credits != null) {
          developedBy.value = credits['developed_by'] as String? ?? 'ASSO Team';
          copyright.value = credits['copyright'] as String? ?? '';
        }

        developer.log('About data loaded successfully', name: 'AboutController');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching about data',
        name: 'AboutController',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Ouvrir un lien
  Future<void> openUrl(String url) async {
    if (url.isEmpty) {
      Get.snackbar(
        'common.error'.tr,
        'about.errors.url_unavailable'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.accent,
        colorText: Colors.white,
      );
      return;
    }

    developer.log('Opening URL', name: 'AboutController', error: 'URL: $url');

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'common.error'.tr,
          'about.errors.open_link'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      developer.log('Error opening URL', name: 'AboutController', error: e);
      Get.snackbar(
        'common.error'.tr,
        'about.errors.open_link'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  /// Ouvrir un lien social
  void openSocialLink(String url) {
    openUrl(url);
  }

  /// Contacter le support
  void contactSupport() {
    if (contactEmail.value.isNotEmpty) {
      openUrl('mailto:${contactEmail.value}');
    } else {
      Get.snackbar(
        'about.unavailable'.tr,
        'about.errors.contact_email_unavailable'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.accent,
        colorText: Colors.white,
      );
    }
  }

  /// Envoyer un feedback
  void sendFeedback() {
    if (contactEmail.value.isNotEmpty) {
      openUrl('mailto:${contactEmail.value}?subject=Feedback%20ASSO%20Market');
    } else {
      Get.snackbar(
        'about.unavailable'.tr,
        'about.errors.contact_email_unavailable'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.accent,
        colorText: Colors.white,
      );
    }
  }
}

class SocialLink {
  final String name;
  final IconData icon;
  final String url;
  final Color color;

  SocialLink({
    required this.name,
    required this.icon,
    required this.url,
    required this.color,
  });
}
