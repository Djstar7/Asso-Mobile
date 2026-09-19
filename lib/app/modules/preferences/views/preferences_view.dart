import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/preferences_controller.dart'
    show PreferencesController, CategoryItem, SubcategoryItem;

/// Centres d'intérêt, proposés une fois au premier lancement.
///
/// L'écran d'origine n'était qu'une pile d'accordéons fermés : rien
/// n'indiquait ce qu'il y avait derrière, ni ce qui avait déjà été choisi.
/// Chaque carte montre désormais ses premières sous-catégories directement,
/// et l'en-tête rappelle en continu le nombre de sélections.
class PreferencesView extends GetView<PreferencesController> {
  const PreferencesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ds.canvas,
      body: SafeArea(
        bottom: false,
        child: AppContentWidth(
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const _LoadingState();
                  }
                  return const _CategoryList();
                }),
              ),
              const _BottomBar(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titre de l'écran et sortie sans choisir.
class _Header extends GetView<PreferencesController> {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space4,
        context.ds.gutter,
        AppDesign.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Vos centres d\'intérêt',
                  style: context.textStyle(
                    FontSizeType.h4,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: AppDesign.space2),
              // « Passer » en casse normale : les capitales criaient une
              // action qui doit rester secondaire.
              TextButton(
                onPressed: controller.skipPreferences,
                style: TextButton.styleFrom(
                  foregroundColor: context.ds.textSecondary,
                  padding: EdgeInsets.symmetric(horizontal: AppDesign.space2),
                ),
                child: Text(
                  'Passer',
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w600,
                    color: context.ds.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDesign.space1),
          Text(
            'Nous mettrons en avant ces produits sur votre accueil. '
            'Vous pourrez changer d\'avis à tout moment.',
            style: context.textStyle(
              FontSizeType.caption,
              color: context.ds.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: AppDesign.space4),
          Text(
            'Chargement de vos préférences…',
            style: context.textStyle(
              FontSizeType.caption,
              color: context.ds.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends GetView<PreferencesController> {
  const _CategoryList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        0,
        context.ds.gutter,
        AppDesign.space6,
      ),
      itemCount: controller.categories.length,
      separatorBuilder: (_, _) => SizedBox(height: AppDesign.space3),
      itemBuilder: (context, index) =>
          _CategoryCard(category: controller.categories[index]),
    );
  }
}

/// Une catégorie et ses sous-catégories.
///
/// Les sous-catégories sont visibles d'emblée — c'est ce qu'on demande à
/// l'utilisateur de choisir. Au-delà de [_visibleChips], le reste se déplie
/// à la demande pour que la liste reste parcourable.
class _CategoryCard extends GetView<PreferencesController> {
  const _CategoryCard({required this.category});

  final CategoryItem category;

  /// Nombre de sous-catégories montrées avant « Plus ».
  static const int _visibleChips = 3;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expanded = controller.expandedCategories.contains(category.id);
      final count = controller.getCategorySelectionCount(category.id);
      final selected = count > 0;

      final visible = expanded
          ? category.subcategories
          : category.subcategories.take(_visibleChips).toList();
      final hidden = category.subcategories.length - visible.length;

      return Container(
        decoration: BoxDecoration(
          color: context.ds.surface,
          borderRadius: BorderRadius.circular(AppDesign.radiusMd),
          border: Border.all(
            color: selected ? AppDesign.accentBorder : context.ds.border,
            // Une carte retenue se repère au premier coup d'œil, sans avoir
            // à lire le compteur.
            width: selected ? 1.5 : 1,
          ),
        ),
        padding: EdgeInsets.all(AppDesign.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CategoryIcon(category: category, selected: selected),
                SizedBox(width: AppDesign.space3),
                Expanded(
                  child: Text(
                    category.name,
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: FontWeight.w600,
                      color: context.ds.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDesign.space2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppDesign.accentSubtle,
                      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                    ),
                    child: Text(
                      '$count',
                      style: context.textStyle(
                        FontSizeType.overline,
                        fontWeight: FontWeight.w700,
                        color: AppDesign.accentText,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppDesign.space3),
            Wrap(
              spacing: AppDesign.space2,
              runSpacing: AppDesign.space2,
              children: [
                for (final sub in visible)
                  _SubcategoryChip(
                    subcategory: sub,
                    selected: controller.selectedSubcategories.contains(sub.id),
                    onTap: () => controller.toggleSubcategory(sub.id),
                  ),
                if (hidden > 0 || expanded)
                  _MoreChip(
                    label: expanded ? 'Moins' : '+$hidden',
                    expanded: expanded,
                    onTap: () => controller.toggleCategory(category.id),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category, required this.selected});

  final CategoryItem category;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      padding: EdgeInsets.all(AppDesign.space2),
      decoration: BoxDecoration(
        color: selected ? AppDesign.accentSubtle : context.ds.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      ),
      child: SvgPicture.asset(
        category.svgPath,
        colorFilter: ColorFilter.mode(
          selected ? AppDesign.accent : context.ds.textSecondary,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

/// Une sous-catégorie sélectionnable.
class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({
    required this.subcategory,
    required this.selected,
    required this.onTap,
  });

  final SubcategoryItem subcategory;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: AppDesign.space3,
            vertical: AppDesign.space2,
          ),
          decoration: BoxDecoration(
            color: selected ? AppDesign.accent : context.ds.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            border: Border.all(
              color: selected ? AppDesign.accent : context.ds.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                subcategory.name,
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.ds.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Déplie ou replie le reste des sous-catégories.
class _MoreChip extends StatelessWidget {
  const _MoreChip({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        // Sans contour ni fond : une pastille identique aux autres se
        // lirait comme une sous-catégorie de plus, alors qu'elle déplie.
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesign.space2,
            vertical: AppDesign.space2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: FontWeight.w600,
                  color: AppDesign.accent,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppDesign.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action principale, maintenue visible au-dessus de la liste.
class _BottomBar extends GetView<PreferencesController> {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.ds.surface,
        border: Border(top: BorderSide(color: context.ds.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space3,
        context.ds.gutter,
        AppDesign.space3,
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final count = controller.selectedSubcategories.length;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count == 0
                    ? 'Choisissez au moins un centre d\'intérêt'
                    : '$count sélectionné${count > 1 ? 's' : ''}',
                style: context.textStyle(
                  FontSizeType.overline,
                  color: count == 0
                      ? context.ds.textTertiary
                      : AppDesign.accentText,
                  fontWeight: count == 0 ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
              SizedBox(height: AppDesign.space2),
              AppButton(
                label: 'Continuer',
                size: AppButtonSize.large,
                icon: Icons.arrow_forward_rounded,
                // Désactivé plutôt qu'actif-puis-refusé : l'attente se lit
                // avant d'appuyer, au lieu d'être signalée par une erreur.
                onPressed: count == 0 ? null : controller.saveAndContinue,
              ),
            ],
          );
        }),
      ),
    );
  }
}
