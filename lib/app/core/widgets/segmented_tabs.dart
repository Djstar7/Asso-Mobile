import 'package:flutter/material.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';

/// Un onglet du sélecteur segmenté : libellé et icône.
class SegmentedTab {
  const SegmentedTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Sélecteur segmenté entre deux (ou quelques) vues d'une même page :
/// « Produits / PassColis » en recherche, « Mes commandes / Suivi » au suivi.
///
/// Un segmenté plutôt qu'un `TabBar` : les vues ne se font pas défiler
/// horizontalement l'une vers l'autre, et l'état sélectionné reste lisible
/// sans dépendre d'un indicateur fin.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<SegmentedTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(int index) {
      final item = tabs[index];
      final selected = index == selectedIndex;
      final color = selected ? Colors.white : context.ds.textSecondary;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? AppDesign.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            child: InkWell(
              onTap: () => onChanged(index),
              borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDesign.minTapTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDesign.space2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 18, color: color),
                      const SizedBox(width: AppDesign.space2),
                      Flexible(
                        child: Text(
                          item.label,
                          textAlign: TextAlign.center,
                          style: context.textStyle(
                            FontSizeType.body2,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.ds.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
      child: Row(children: [for (var i = 0; i < tabs.length; i++) tab(i)]),
    );
  }
}
