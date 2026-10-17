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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tab(int index) {
      final item = tabs[index];
      final isSelected = index == selectedIndex;
      final color = isSelected
          ? Colors.white
          : AppThemeSystem.getSecondaryTextColor(context);

      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppThemeSystem.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 17, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.grey800 : AppThemeSystem.grey100,
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
      child: Row(
        children: [for (var i = 0; i < tabs.length; i++) tab(i)],
      ),
    );
  }
}
