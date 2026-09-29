import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/legal_controller.dart';
import 'legal_document_view.dart';

/// « Conditions & politiques » : tous les documents légaux actifs.
class LegalView extends GetView<LegalController> {
  const LegalView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Conditions & politiques',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.documents.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppThemeSystem.primaryColor,
              ),
            ),
          );
        }
        if (controller.documents.isEmpty) {
          return AppEmptyState(
            icon: controller.hasError.value
                ? Icons.wifi_off_rounded
                : Icons.description_outlined,
            title: controller.hasError.value
                ? 'Chargement impossible'
                : 'Aucun document disponible',
            message: controller.hasError.value
                ? 'Vérifiez votre connexion puis réessayez.'
                : null,
            actionLabel: 'Réessayer',
            onAction: controller.fetchDocuments,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.fetchDocuments,
          child: ListView(
            padding: EdgeInsets.all(context.horizontalPadding),
            children: [LegalDocumentsCard(documents: controller.documents)],
          ),
        );
      }),
    );
  }
}

/// Carte listant des documents légaux ; réutilisée par « À propos ».
class LegalDocumentsCard extends StatelessWidget {
  const LegalDocumentsCard({
    super.key,
    required this.documents,
    this.trailing = const [],
  });

  final List<LegalDocument> documents;

  /// Lignes ajoutées après les documents (ex. licences open source).
  final List<Widget> trailing;

  static IconData iconFor(String slug) {
    if (slug.contains('confidential') || slug.contains('privacy')) {
      return Icons.privacy_tip_outlined;
    }
    if (slug.contains('vente') || slug.contains('cgv')) {
      return Icons.receipt_long_outlined;
    }
    if (slug.contains('mention')) return Icons.gavel_outlined;
    if (slug.contains('cookie')) return Icons.cookie_outlined;
    return Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final document in documents)
        LegalTile(
          icon: iconFor(document.slug),
          title: document.title,
          onTap: () => LegalDocumentView.open(document),
        ),
      ...trailing,
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(color: context.borderColor, height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class LegalTile extends StatelessWidget {
  const LegalTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppThemeSystem.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: context.body2.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: context.caption),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
