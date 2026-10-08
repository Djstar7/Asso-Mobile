import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';

/// Version anglaise facultative d'un texte saisi par le vendeur (produit,
/// boutique). Le français reste le texte principal : sans anglais, les
/// clients anglophones voient le français.
///
/// Les champs partent au serveur sous `translations[en][<champ>]`.
class EnglishVersionSection extends StatefulWidget {
  const EnglishVersionSection({
    super.key,
    required this.nameController,
    required this.descriptionController,
    this.nameHint,
    this.descriptionHint,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? nameHint;
  final String? descriptionHint;

  /// Champs multipart à envoyer. En création, rien si tout est vide ; en
  /// modification ([clearEmpty]), un champ vide efface la traduction.
  static Map<String, String> fields(
    TextEditingController name,
    TextEditingController description, {
    bool clearEmpty = false,
  }) {
    final values = {
      'name': name.text.trim(),
      'description': description.text.trim(),
    };
    return {
      for (final entry in values.entries)
        if (clearEmpty || entry.value.isNotEmpty)
          'translations[en][${entry.key}]': entry.value,
    };
  }

  /// Lit `translations.en.<champ>` renvoyé par l'API vendeur.
  static String readTranslation(dynamic translations, String field) {
    if (translations is! Map) return '';
    final english = translations['en'];
    if (english is! Map) return '';
    return english[field]?.toString() ?? '';
  }

  @override
  State<EnglishVersionSection> createState() => _EnglishVersionSectionState();
}

class _EnglishVersionSectionState extends State<EnglishVersionSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Ouverte d'emblée quand une traduction existe déjà.
    _expanded = _hasText;
    widget.nameController.addListener(_onTextChanged);
    widget.descriptionController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_onTextChanged);
    widget.descriptionController.removeListener(_onTextChanged);
    super.dispose();
  }

  bool get _hasText =>
      widget.nameController.text.trim().isNotEmpty ||
      widget.descriptionController.text.trim().isNotEmpty;

  void _onTextChanged() {
    // Pré-remplissage asynchrone (modification, brouillon) : on déplie.
    if (!_expanded && _hasText && mounted) setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      borderSide: BorderSide(color: theme.dividerColor),
    );
    InputDecoration decoration(String label, String? hint) => InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(
              color: AppThemeSystem.primaryColor,
              width: 2,
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppDesign.space3),
              child: Row(
                children: [
                  const Icon(Icons.translate_rounded, size: 20),
                  const SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'core.english_version.title'.tr,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'core.english_version.subtitle'.tr,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDesign.space3,
                0,
                AppDesign.space3,
                AppDesign.space3,
              ),
              child: Column(
                children: [
                  TextField(
                    key: const Key('english_name_field'),
                    controller: widget.nameController,
                    decoration: decoration(
                      'core.english_version.name_label'.tr,
                      widget.nameHint,
                    ),
                  ),
                  const SizedBox(height: AppDesign.space3),
                  TextField(
                    key: const Key('english_description_field'),
                    controller: widget.descriptionController,
                    maxLines: 4,
                    decoration: decoration(
                      'core.english_version.description_label'.tr,
                      widget.descriptionHint,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
