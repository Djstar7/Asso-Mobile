import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/legal_controller.dart';
import 'legal_view.dart';

/// Lecture d'un document légal dans l'application : le contenu rédigé dans
/// le back-office, chargé par l'API et affiché aux couleurs de l'app.
class LegalDocumentView extends StatefulWidget {
  const LegalDocumentView({super.key, required this.document});

  final LegalDocument document;

  static void open(LegalDocument document) {
    Get.to(
      () => LegalDocumentView(document: document),
      preventDuplicates: false,
    );
  }

  @override
  State<LegalDocumentView> createState() => _LegalDocumentViewState();
}

class _LegalDocumentViewState extends State<LegalDocumentView> {
  late LegalDocument _document = widget.document;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final document = await LegalDocument.fetch(widget.document.slug);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (document != null && (document.content ?? '').trim().isNotEmpty) {
        _document = document;
      } else {
        // Un rafraîchissement raté garde le texte déjà affiché.
        _hasError = _document.content == null;
      }
    });
  }

  /// Un lien vers un autre document légal reste dans l'app ; le reste
  /// (mailto:, sites externes) part vers l'application adaptée.
  Future<bool> _onTapUrl(String url) async {
    final target = Uri.tryParse(url);
    if (target == null) return false;
    final segments = target.pathSegments;
    if (segments.length == 2 && segments.first == 'legal') {
      LegalDocumentView.open(LegalDocument(
        slug: segments.last,
        title: 'legal.document_fallback'.tr,
      ));
      return true;
    }
    return launchUrl(target, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          _document.title,
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_document.url.isNotEmpty)
            IconButton(
              tooltip: 'legal.open_in_browser'.tr,
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => launchUrl(
                Uri.parse(_document.url),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _document.content == null) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            AppThemeSystem.primaryColor,
          ),
        ),
      );
    }
    if (_hasError) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'legal.document_unavailable'.tr,
        message: 'legal.check_connection'.tr,
        actionLabel: 'common.retry'.tr,
        onAction: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppThemeSystem.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.horizontalPadding,
          8,
          context.horizontalPadding,
          32,
        ),
        children: [
          AppContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildContent(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final updatedAt = _document.updatedAt;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeSystem.primaryColor,
            AppThemeSystem.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: context.borderRadius(BorderRadiusType.medium),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LegalDocumentsCard.iconFor(_document.slug),
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _document.title,
                  style: context.h6.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (updatedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'legal.updated_at'.trParams({
                      'date': DateFormat.yMMMMd(Get.locale?.toLanguageTag())
                          .format(updatedAt.toLocal()),
                    }),
                    style: context.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final primary = AppThemeSystem.primaryColor;
    final text = context.primaryTextColor;
    final muted = context.secondaryTextColor;
    final border = context.borderColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: border),
      ),
      child: HtmlWidget(
        _document.content ?? '',
        textStyle: context.body2.copyWith(color: text, height: 1.6),
        onTapUrl: _onTapUrl,
        customStylesBuilder: (element) {
          final classes = element.classes;
          final styles = <String, String>{
            // Alignements et retraits posés par l'éditeur Quill.
            if (classes.contains('ql-align-center')) 'text-align': 'center',
            if (classes.contains('ql-align-right')) 'text-align': 'right',
            if (classes.contains('ql-align-justify')) 'text-align': 'justify',
            for (final c in classes)
              if (c.startsWith('ql-indent-'))
                'padding-left': '${(int.tryParse(c.substring(10)) ?? 0) * 2}em',
          };
          switch (element.localName) {
            case 'h1':
            case 'h2':
              styles.addAll({
                'color': _css(primary),
                'font-size': '1.2em',
                'font-weight': 'bold',
                'margin': '1.2em 0 0.4em',
              });
            case 'h3':
            case 'h4':
              styles.addAll({
                'font-size': '1.05em',
                'font-weight': '600',
                'margin': '1em 0 0.3em',
              });
            case 'p':
              styles['margin'] = '0.5em 0';
            case 'a':
              styles.addAll({
                'color': _css(primary),
                'text-decoration': 'underline',
              });
            case 'blockquote':
              styles.addAll({
                'color': _css(muted),
                'border-left': '3px solid ${_css(primary)}',
                'padding-left': '12px',
                'margin': '0.8em 0',
              });
            case 'ul':
            case 'ol':
              styles['padding-left'] = '1.4em';
            case 'li':
              styles['margin'] = '0.2em 0';
          }
          return styles.isEmpty ? null : styles;
        },
      ),
    );
  }

  static String _css(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}
