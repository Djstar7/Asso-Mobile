import 'dart:developer' as developer;

import 'package:get/get.dart';

import '../../../data/providers/api_provider.dart';

/// Document légal (CGU, CGV, confidentialité…) rédigé dans le back-office.
class LegalDocument {
  final String slug;
  final String title;

  /// Version web publique, pour « Ouvrir dans le navigateur ».
  final String url;
  final DateTime? updatedAt;

  /// HTML de l'éditeur du back-office ; absent des listes, chargé à la
  /// lecture.
  final String? content;

  const LegalDocument({
    required this.slug,
    required this.title,
    this.url = '',
    this.updatedAt,
    this.content,
  });

  static LegalDocument? fromJson(dynamic json) {
    if (json is! Map) return null;
    final slug = json['slug']?.toString() ?? '';
    if (slug.isEmpty) return null;
    return LegalDocument(
      slug: slug,
      title: json['title']?.toString() ?? 'legal.document_fallback'.tr,
      url: json['url']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      content: json['content']?.toString(),
    );
  }

  static List<LegalDocument> listFrom(dynamic json) => json is List
      ? json.map(LegalDocument.fromJson).whereType<LegalDocument>().toList()
      : const [];

  /// Charge le document complet (avec son contenu) ; null si indisponible.
  static Future<LegalDocument?> fetch(String slug) async {
    try {
      final response = await ApiProvider.get('/v1/legal-pages/$slug');
      if (!response.success) return null;
      return LegalDocument.fromJson(response.data?['data']);
    } catch (e) {
      developer.log('Legal page fetch failed', name: 'LegalDocument', error: e);
      return null;
    }
  }
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
