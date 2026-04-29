import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../utils/app_theme_system.dart';

class MarkdownBottomSheet {
  /// Affiche un BottomSheet avec le contenu d'un fichier markdown
  static void show({
    required BuildContext context,
    required String title,
    required String assetPath,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MarkdownBottomSheetContent(
        title: title,
        assetPath: assetPath,
      ),
    );
  }
}

class _MarkdownBottomSheetContent extends StatefulWidget {
  final String title;
  final String assetPath;

  const _MarkdownBottomSheetContent({
    required this.title,
    required this.assetPath,
  });

  @override
  State<_MarkdownBottomSheetContent> createState() =>
      _MarkdownBottomSheetContentState();
}

class _MarkdownBottomSheetContentState
    extends State<_MarkdownBottomSheetContent> {
  String _markdownContent = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final content = await rootBundle.loadString(widget.assetPath);
      setState(() {
        _markdownContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du chargement du document: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: AppThemeSystem.getBackgroundColor(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppThemeSystem.grey400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemeSystem.getHorizontalPadding(context),
              vertical: AppThemeSystem.getVerticalPadding(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: context.textStyle(
                      FontSizeType.h3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: context.primaryTextColor,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppThemeSystem.primaryColor,
                      ),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(
                            AppThemeSystem.getHorizontalPadding(context),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppThemeSystem.errorColor,
                              ),
                              SizedBox(
                                height:
                                    AppThemeSystem.getElementSpacing(context),
                              ),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: context.textStyle(
                                  FontSizeType.body2,
                                  color: AppThemeSystem.errorColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Markdown(
                        data: _markdownContent,
                        styleSheet: MarkdownStyleSheet(
                          textAlign: WrapAlignment.start,
                          h1: context.textStyle(
                            FontSizeType.h2,
                            fontWeight: FontWeight.bold,
                          ),
                          h2: context.textStyle(
                            FontSizeType.h3,
                            fontWeight: FontWeight.bold,
                          ),
                          h3: context.textStyle(
                            FontSizeType.h4,
                            fontWeight: FontWeight.bold,
                          ),
                          p: context.textStyle(
                            FontSizeType.body1,
                            height: 1.6,
                          ).copyWith(
                            letterSpacing: 0.2,
                          ),
                          pPadding: const EdgeInsets.only(bottom: 12),
                          listBullet: context.textStyle(
                            FontSizeType.body1,
                            color: AppThemeSystem.primaryColor,
                          ),
                          a: TextStyle(
                            color: AppThemeSystem.primaryColor,
                            decoration: TextDecoration.underline,
                            fontSize: AppThemeSystem.getFontSize(
                              context,
                              FontSizeType.body1,
                            ),
                          ),
                          strong: context.textStyle(
                            FontSizeType.body1,
                            fontWeight: FontWeight.bold,
                          ),
                          blockquote: context.textStyle(
                            FontSizeType.body2,
                            color: context.secondaryTextColor,
                          ),
                          code: TextStyle(
                            fontFamily: 'monospace',
                            color: AppThemeSystem.primaryColor,
                            backgroundColor: AppThemeSystem.grey200,
                            fontSize: AppThemeSystem.getFontSize(
                              context,
                              FontSizeType.caption,
                            ),
                          ),
                        ),
                        padding: EdgeInsets.all(
                          AppThemeSystem.getHorizontalPadding(context),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
