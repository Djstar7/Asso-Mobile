import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';

class HelpController extends GetxController {
  // État de chargement
  final isLoading = false.obs;

  // Recherche
  final searchController = TextEditingController();
  final searchQuery = ''.obs;

  // Sujets d'aide (getter : les textes suivent la langue courante)
  List<SupportTopic> get supportTopics => [
    SupportTopic(
      icon: Icons.shopping_cart_outlined,
      title: 'help.categories.orders'.tr,
      description: 'help.topics.orders.description'.tr,
      items: [
        'help.topics.orders.place_order'.tr,
        'help.topics.orders.track_order'.tr,
        'help.topics.orders.cancel_order'.tr,
        'help.topics.orders.return_product'.tr,
      ],
    ),
    SupportTopic(
      icon: Icons.payment_outlined,
      title: 'help.categories.payments'.tr,
      description: 'help.topics.payments.description'.tr,
      items: [
        'help.topics.payments.accepted_methods'.tr,
        'help.topics.payments.security'.tr,
        'help.topics.payments.issues'.tr,
        'help.topics.payments.refunds'.tr,
      ],
    ),
    SupportTopic(
      icon: Icons.person_outline,
      title: 'help.categories.account'.tr,
      description: 'help.topics.account.description'.tr,
      items: [
        'help.topics.account.create'.tr,
        'help.topics.account.edit_info'.tr,
        'help.topics.account.forgot_password'.tr,
        'help.topics.account.delete'.tr,
      ],
    ),
    SupportTopic(
      icon: Icons.local_shipping_outlined,
      title: 'help.categories.delivery'.tr,
      description: 'help.topics.delivery.description'.tr,
      items: [
        'help.topics.delivery.zones'.tr,
        'help.topics.delivery.fees'.tr,
        'help.topics.delivery.times'.tr,
        'help.topics.delivery.issues'.tr,
      ],
    ),
  ];

  // FAQ (getter : les textes suivent la langue courante). `category` est
  // une clé de traduction, qui sert aussi d'identifiant de catégorie.
  List<FaqItem> get allFaqs => [
    // Commandes
    FaqItem(
      category: 'help.categories.orders',
      question: 'help.faqs.place_order.question'.tr,
      answer: 'help.faqs.place_order.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.orders',
      question: 'help.faqs.track_order.question'.tr,
      answer: 'help.faqs.track_order.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.orders',
      question: 'help.faqs.cancel_order.question'.tr,
      answer: 'help.faqs.cancel_order.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.orders',
      question: 'help.faqs.damaged_product.question'.tr,
      answer: 'help.faqs.damaged_product.answer'.tr,
    ),

    // Paiements
    FaqItem(
      category: 'help.categories.payments',
      question: 'help.faqs.payment_methods.question'.tr,
      answer: 'help.faqs.payment_methods.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.payments',
      question: 'help.faqs.payment_security.question'.tr,
      answer: 'help.faqs.payment_security.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.payments',
      question: 'help.faqs.cash_on_delivery.question'.tr,
      answer: 'help.faqs.cash_on_delivery.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.payments',
      question: 'help.faqs.refund_time.question'.tr,
      answer: 'help.faqs.refund_time.answer'.tr,
    ),

    // Compte
    FaqItem(
      category: 'help.categories.account',
      question: 'help.faqs.create_account.question'.tr,
      answer: 'help.faqs.create_account.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.account',
      question: 'help.faqs.forgot_password.question'.tr,
      answer: 'help.faqs.forgot_password.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.account',
      question: 'help.faqs.edit_info.question'.tr,
      answer: 'help.faqs.edit_info.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.account',
      question: 'help.faqs.delete_account.question'.tr,
      answer: 'help.faqs.delete_account.answer'.tr,
    ),

    // Livraison
    FaqItem(
      category: 'help.categories.delivery',
      question: 'help.faqs.delivery_zones.question'.tr,
      answer: 'help.faqs.delivery_zones.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.delivery',
      question: 'help.faqs.delivery_fees.question'.tr,
      answer: 'help.faqs.delivery_fees.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.delivery',
      question: 'help.faqs.delivery_time.question'.tr,
      answer: 'help.faqs.delivery_time.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.delivery',
      question: 'help.faqs.change_address.question'.tr,
      answer: 'help.faqs.change_address.answer'.tr,
    ),

    // Vendeurs
    FaqItem(
      category: 'help.categories.vendors',
      question: 'help.faqs.become_vendor.question'.tr,
      answer: 'help.faqs.become_vendor.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.vendors',
      question: 'help.faqs.vendor_fees.question'.tr,
      answer: 'help.faqs.vendor_fees.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.vendors',
      question: 'help.faqs.add_product.question'.tr,
      answer: 'help.faqs.add_product.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.vendors',
      question: 'help.faqs.manage_stock.question'.tr,
      answer: 'help.faqs.manage_stock.answer'.tr,
    ),

    // Général
    FaqItem(
      category: 'help.categories.general',
      question: 'help.faqs.what_is_asso.question'.tr,
      answer: 'help.faqs.what_is_asso.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.general',
      question: 'help.faqs.contact_support.question'.tr,
      answer: 'help.faqs.contact_support.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.general',
      question: 'help.faqs.app_free.question'.tr,
      answer: 'help.faqs.app_free.answer'.tr,
    ),
    FaqItem(
      category: 'help.categories.general',
      question: 'help.faqs.report_issue.question'.tr,
      answer: 'help.faqs.report_issue.answer'.tr,
    ),
  ];

  // FAQ filtrées
  RxList<FaqItem> get filteredFaqs {
    if (searchQuery.value.isEmpty) {
      return allFaqs.obs;
    }

    final query = searchQuery.value.toLowerCase();
    return allFaqs
        .where(
          (faq) =>
              faq.question.toLowerCase().contains(query) ||
              faq.answer.toLowerCase().contains(query) ||
              faq.category.tr.toLowerCase().contains(query),
        )
        .toList()
        .obs;
  }

  // Catégories FAQ
  List<String> get faqCategories {
    return allFaqs.map((faq) => faq.category).toSet().toList();
  }

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Effacer la recherche
  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  /// Contacter par email
  Future<void> contactByEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@asso-corporation.com',
      query: 'subject=Demande de support',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        Get.snackbar(
          'common.error'.tr,
          'help.errors.email_client'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'common.error'.tr,
        'help.errors.generic'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  /// Contacter par téléphone
  Future<void> contactByPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+237658895572');

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        Get.snackbar(
          'common.error'.tr,
          'help.errors.dialer'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'common.error'.tr,
        'help.errors.generic'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  /// Contacter par WhatsApp
  Future<void> contactByWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/237658895572?text=Bonjour, j\'ai besoin d\'aide concernant',
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'common.error'.tr,
          'help.errors.whatsapp'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'common.error'.tr,
        'help.errors.generic'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  /// Ouvrir un sujet d'aide
  void openTopic(SupportTopic topic) {
    // Feuille standard : un sujet aux nombreuses questions débordait de
    // l'écran, sans croix pour la refermer ; le contact reste épinglé en bas.
    AppSheet.show(
      AppSheet(
        title: topic.title,
        subtitle: topic.description,
        footer: AppButton(
          label: 'help.contact_support'.tr,
          onPressed: () {
            Get.back();
            contactByEmail();
          },
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...topic.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppDesign.space3),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: AppThemeSystem.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppDesign.space3),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportTopic {
  final IconData icon;
  final String title;
  final String description;
  final List<String> items;

  SupportTopic({
    required this.icon,
    required this.title,
    required this.description,
    required this.items,
  });
}

class FaqItem {
  final String category;
  final String question;
  final String answer;

  FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}
