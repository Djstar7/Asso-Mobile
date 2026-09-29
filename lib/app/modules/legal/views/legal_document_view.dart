import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/legal_controller.dart';

/// Lecture d'un document légal dans l'application : la page web publique
/// du back-office, sans son titre (déjà dans la barre).
class LegalDocumentView extends StatefulWidget {
  const LegalDocumentView({super.key, required this.document});

  final LegalDocument document;

  static void open(LegalDocument document) {
    Get.to(() => LegalDocumentView(document: document));
  }

  @override
  State<LegalDocumentView> createState() => _LegalDocumentViewState();
}

class _LegalDocumentViewState extends State<LegalDocumentView> {
  late final WebViewController _controller;
  late final Uri _uri;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final base = Uri.parse(widget.document.url);
    _uri = base.replace(queryParameters: {...base.queryParameters, 'app': '1'});
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _update(loading: true, error: false),
          onPageFinished: (_) => _update(loading: false),
          onWebResourceError: (error) {
            // Seule la page elle-même compte : une image absente ne
            // rend pas le document illisible.
            if (error.isForMainFrame ?? true) {
              _update(loading: false, error: true);
            }
          },
          onNavigationRequest: (request) {
            // Les autres documents légaux restent dans l'écran ; le reste
            // (mailto:, sites externes) part vers l'application adaptée.
            final target = Uri.tryParse(request.url);
            if (target != null && target.host == _uri.host) {
              return NavigationDecision.navigate;
            }
            if (target != null) {
              launchUrl(target, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(_uri);
  }

  void _update({required bool loading, bool? error}) {
    if (!mounted) return;
    setState(() {
      _isLoading = loading;
      if (error != null) _hasError = error;
    });
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
          widget.document.title,
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Ouvrir dans le navigateur',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => launchUrl(
              Uri.parse(widget.document.url),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_hasError)
            AppEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Document indisponible',
              message: 'Vérifiez votre connexion puis réessayez.',
              actionLabel: 'Réessayer',
              onAction: () {
                _update(loading: true, error: false);
                _controller.loadRequest(_uri);
              },
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading && !_hasError)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppThemeSystem.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
