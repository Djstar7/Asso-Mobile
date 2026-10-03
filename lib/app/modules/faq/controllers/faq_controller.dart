import 'package:get/get.dart';

class FaqController extends GetxController {
  // Catégories de FAQ (getter : les textes suivent la langue courante)
  List<FaqCategory> get faqCategories => [
    FaqCategory(
      title: 'faq.categories.orders_delivery'.tr,
      faqs: [
        Faq(
          question: 'faq.items.place_order.question'.tr,
          answer: 'faq.items.place_order.answer'.tr,
        ),
        Faq(
          question: 'faq.items.track_order.question'.tr,
          answer: 'faq.items.track_order.answer'.tr,
        ),
        Faq(
          question: 'faq.items.cancel_order.question'.tr,
          answer: 'faq.items.cancel_order.answer'.tr,
        ),
        Faq(
          question: 'faq.items.delivery_times.question'.tr,
          answer: 'faq.items.delivery_times.answer'.tr,
        ),
      ],
    ),
    FaqCategory(
      title: 'faq.categories.payments'.tr,
      faqs: [
        Faq(
          question: 'faq.items.payment_methods.question'.tr,
          answer: 'faq.items.payment_methods.answer'.tr,
        ),
        Faq(
          question: 'faq.items.payment_security.question'.tr,
          answer: 'faq.items.payment_security.answer'.tr,
        ),
        Faq(
          question: 'faq.items.get_refund.question'.tr,
          answer: 'faq.items.get_refund.answer'.tr,
        ),
      ],
    ),
    FaqCategory(
      title: 'faq.categories.account_security'.tr,
      faqs: [
        Faq(
          question: 'faq.items.create_account.question'.tr,
          answer: 'faq.items.create_account.answer'.tr,
        ),
        Faq(
          question: 'faq.items.forgot_password.question'.tr,
          answer: 'faq.items.forgot_password.answer'.tr,
        ),
        Faq(
          question: 'faq.items.edit_info.question'.tr,
          answer: 'faq.items.edit_info.answer'.tr,
        ),
        Faq(
          question: 'faq.items.delete_account.question'.tr,
          answer: 'faq.items.delete_account.answer'.tr,
        ),
      ],
    ),
    FaqCategory(
      title: 'faq.categories.returns_refunds'.tr,
      faqs: [
        Faq(
          question: 'faq.items.return_product.question'.tr,
          answer: 'faq.items.return_product.answer'.tr,
        ),
        Faq(
          question: 'faq.items.damaged_product.question'.tr,
          answer: 'faq.items.damaged_product.answer'.tr,
        ),
        Faq(
          question: 'faq.items.refund_time.question'.tr,
          answer: 'faq.items.refund_time.answer'.tr,
        ),
      ],
    ),
  ];

  // Index de l'élément actuellement ouvert (null si aucun)
  final expandedIndex = Rxn<String>();

  /// Basculer l'état d'expansion d'un FAQ
  void toggleExpansion(String id) {
    if (expandedIndex.value == id) {
      expandedIndex.value = null;
    } else {
      expandedIndex.value = id;
    }
  }

  /// Rechercher dans les FAQs
  final searchQuery = ''.obs;
  final filteredCategories = <FaqCategory>[].obs;

  @override
  void onInit() {
    super.onInit();
    filteredCategories.value = faqCategories;

    // Écouter les changements de recherche
    ever(searchQuery, (_) => _filterFaqs());
  }

  void _filterFaqs() {
    if (searchQuery.value.isEmpty) {
      filteredCategories.value = faqCategories;
      return;
    }

    final query = searchQuery.value.toLowerCase();
    final filtered = <FaqCategory>[];

    for (final category in faqCategories) {
      final matchingFaqs = category.faqs.where((faq) =>
          faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query)).toList();

      if (matchingFaqs.isNotEmpty) {
        filtered.add(FaqCategory(
          title: category.title,
          faqs: matchingFaqs,
        ));
      }
    }

    filteredCategories.value = filtered;
  }
}

class FaqCategory {
  final String title;
  final List<Faq> faqs;

  FaqCategory({
    required this.title,
    required this.faqs,
  });
}

class Faq {
  final String question;
  final String answer;

  Faq({
    required this.question,
    required this.answer,
  });

  String get id => question.hashCode.toString();
}
