import 'dart:developer' as developer;

import 'package:get/get.dart';

import '../../../data/providers/api_provider.dart';

/// Document légal (CGU, CGV, confidentialité…) rédigé dans le back-office.
class LegalDocument {
  final String slug;
  final String title;
  final String url;

  const LegalDocument({
    required this.slug,
    required this.title,
    required this.url,
  });

  static LegalDocument? fromJson(dynamic json) {
    if (json is! Map) return null;
    final url = json['url']?.toString() ?? '';
    if (url.isEmpty) return null;
    return LegalDocument(
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Document',
      url: url,
    );
  }

  static List<LegalDocument> listFrom(dynamic json) => json is List
      ? json.map(LegalDocument.fromJson).whereType<LegalDocument>().toList()
      : const [];
}

/// Liste des documents légaux, commune au menu Aide & Support, aux
/// paramètres et à « À propos ».
class LegalController extends GetxController {
  final documents = <LegalDocument>[].obs;
  final isLoading = false.obs;
  final hasError = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final response = await ApiProvider.get('/v1/legal-pages');
      if (response.success) {
        documents.assignAll(LegalDocument.listFrom(response.data?['data']));
      } else {
        hasError.value = true;
      }
    } catch (e) {
      developer.log(
        'Legal pages fetch failed',
        name: 'LegalController',
        error: e,
      );
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }
}
