import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';

/// Adresses proposées sous la barre de recherche d'une carte.
///
/// Occupe la hauteur libre entre [top] et le haut du clavier, jamais plus :
/// la liste reste lisible pendant la saisie et défile si elle dépasse. Le
/// clavier se referme dès qu'on la fait défiler, pour découvrir la suite.
///
/// À poser en DERNIER dans la [Stack] de la carte, pour qu'aucun panneau ne
/// la recouvre, et sous un [Scaffold] en `resizeToAvoidBottomInset: false` :
/// le clavier passe alors par-dessus la carte au lieu de la comprimer et de
/// faire remonter le panneau du bas sur les résultats.
class MapSearchResults extends StatelessWidget {
  const MapSearchResults({
    super.key,
    required this.top,
    required this.isSearching,
    required this.results,
    required this.onSelected,
    this.failed = false,
    this.left = AppDesign.space4,
    this.right = AppDesign.space4,
  });

  final double top;
  final double left;
  final double right;
  final bool isSearching;

  /// Aucun service de recherche n'a répondu : on le dit, plutôt que de
  /// laisser croire que l'adresse n'existe pas.
  final bool failed;

  /// Résultats Nominatim : chaque entrée porte au moins `display_name`.
  final List<Map<String, dynamic>> results;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = keyboard > 0
        ? keyboard
        : MediaQuery.paddingOf(context).bottom;

    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom + AppDesign.space3,
      child: Align(
        alignment: Alignment.topCenter,
        child: AddressSuggestionList(
          isSearching: isSearching,
          failed: failed,
          results: results,
          onSelected: onSelected,
        ),
      ),
    );
  }
}

/// Carte des adresses proposées pendant une recherche : état de la recherche,
/// ou liste des résultats.
///
/// Sert au-dessus d'une carte (dans [MapSearchResults]) comme sous un champ
/// de formulaire ; [scrollable] à faux la déroule en entier, pour un parent
/// qui défile déjà.
class AddressSuggestionList extends StatelessWidget {
  const AddressSuggestionList({
    super.key,
    required this.isSearching,
    required this.results,
    required this.onSelected,
    this.failed = false,
    this.scrollable = true,
  });

  final bool isSearching;
  final bool failed;
  final List<Map<String, dynamic>> results;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ds.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: isSearching
          ? _status(
              context,
              leading: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppDesign.accent),
                ),
              ),
              text: 'core.map_search.searching'.tr,
            )
          : failed
          ? _status(
              context,
              leading: Icon(
                Icons.wifi_off_rounded,
                size: 20,
                color: context.ds.textTertiary,
              ),
              text: 'core.map_search.unavailable'.tr,
            )
          : results.isEmpty
          ? _status(
              context,
              leading: Icon(
                Icons.search_off_rounded,
                size: 20,
                color: context.ds.textTertiary,
              ),
              text: 'core.map_search.no_results'.tr,
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: scrollable ? null : const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppDesign.space1),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: results.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, indent: 56, color: context.ds.border),
              itemBuilder: (context, index) => _item(context, results[index]),
            ),
    );
  }

  /// Nominatim renvoie « Lieu, quartier, ville, région, pays » : le lieu
  /// passe en titre, le reste en sous-titre, pour distinguer d'un coup d'œil
  /// deux résultats qui commencent pareil.
  Widget _item(BuildContext context, Map<String, dynamic> result) {
    final parts = (result['display_name']?.toString() ?? '')
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final title = parts.isEmpty ? 'core.map_search.address'.tr : parts.first;
    final subtitle = parts.length > 1 ? parts.skip(1).join(', ') : null;

    return ListTile(
      onTap: () => onSelected(result),
      leading: Icon(Icons.location_on_outlined, color: AppDesign.accent),
      minLeadingWidth: 24,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyle(
          FontSizeType.body2,
          fontWeight: FontWeight.w600,
          color: context.ds.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.caption,
                color: context.ds.textSecondary,
              ),
            ),
    );
  }

  Widget _status(
    BuildContext context, {
    required Widget leading,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppDesign.space3),
          Expanded(
            child: Text(
              text,
              style: context.textStyle(
                FontSizeType.body2,
                color: context.ds.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
