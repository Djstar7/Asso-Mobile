import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/values/constants.dart';
import '../../../data/providers/api_provider.dart';

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
  final termsUrl = ''.obs;
  final privacyUrl = ''.obs;
  final licensesUrl = ''.obs;

  // Credits
  final developedBy = 'ASSO Team'.obs;
  final copyright = ''.obs;

  final releaseDate = 'Mars 2026';

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
          termsUrl.value = legal['terms_url'] as String? ?? '';
          privacyUrl.value = legal['privacy_url'] as String? ?? '';
          licensesUrl.value = legal['licenses_url'] as String? ?? '';
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
        'Erreur',
        'URL non disponible',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
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
          'Erreur',
          'Impossible d\'ouvrir le lien',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      developer.log('Error opening URL', name: 'AboutController', error: e);
      Get.snackbar(
        'Erreur',
        'Impossible d\'ouvrir le lien',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Ouvrir un lien social
  void openSocialLink(String url) {
    openUrl(url);
  }

  /// Afficher les conditions d'utilisation
  void showTermsOfService() {
    if (termsUrl.value.isNotEmpty) {
      openUrl(termsUrl.value);
    } else {
      Get.snackbar(
        'Non disponible',
        'Les conditions d\'utilisation ne sont pas encore disponibles',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  /// Afficher la politique de confidentialité
  void showPrivacyPolicy() {
    if (privacyUrl.value.isNotEmpty) {
      openUrl(privacyUrl.value);
    } else {
      Get.snackbar(
        'Non disponible',
        'La politique de confidentialité n\'est pas encore disponible',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  /// Afficher les licences
  void showLicenses() {
    if (licensesUrl.value.isNotEmpty) {
      openUrl(licensesUrl.value);
    } else {
      Get.snackbar(
        'Non disponible',
        'Les licences ne sont pas encore disponibles',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  /// Contacter le support
  void contactSupport() {
    if (contactEmail.value.isNotEmpty) {
      openUrl('mailto:${contactEmail.value}');
    } else {
      Get.snackbar(
        'Non disponible',
        'Email de contact non disponible',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
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
        'Non disponible',
        'Email de contact non disponible',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
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
