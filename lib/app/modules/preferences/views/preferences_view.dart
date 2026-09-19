import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/app_design.dart';
import '../controllers/preferences_controller.dart'
    show PreferencesController, CategoryItem, SubcategoryItem;

class PreferencesView extends GetView<PreferencesController> {
  const PreferencesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header avec bouton Skip
            _buildHeader(context),

            // Contenu scrollable
            Expanded(
              child: Obx(() {
                // Show loading indicator while fetching preferences
                if (controller.isLoading.value) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppThemeSystem.primaryColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Chargement de vos préférences...',
                          style: context.textStyle(
                            FontSizeType.body2,
                            color: context.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppThemeSystem.getHorizontalPadding(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: AppThemeSystem.getElementSpacing(context)),

                      // Titre principal
                      Text(
                        'Vos centres d\'intérêt',
                        style: context.textStyle(
                          FontSizeType.h2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        'Sélectionnez les catégories qui vous intéressent pour personnaliser votre expérience',
                        style: context.textStyle(
                          FontSizeType.body2,
                          color: context.secondaryTextColor,
                        ),
                      ),

                    SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

                    // Liste des catégories
                    Obx(() => Column(
                          children: controller.categories.map((category) {
                            final isExpanded =
                                controller.expandedCategories.contains(category.id);
                            final selectionCount =
                                controller.getCategorySelectionCount(category.id);
                            final isSelected =
                                controller.isCategorySelected(category.id);

                            return _buildCategoryCard(
                              context,
                              category: category,
                              isExpanded: isExpanded,
                              isSelected: isSelected,
                              selectionCount: selectionCount,
                            );
                          }).toList(),
                        )),

                      SizedBox(height: AppThemeSystem.getSectionSpacing(context) * 1.5),
                    ],
                  ),
                );
              }),
            ),

            // Bouton fixe en bas
            _buildBottomButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo ou titre app
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: context.borderRadius(BorderRadiusType.small),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppThemeSystem.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Préférences',
                style: context.textStyle(
                  FontSizeType.h5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Bouton Skip
          TextButton(
            onPressed: controller.skipPreferences,
            child: Text(
              'PASSER',
              style: context.textStyle(
                FontSizeType.button,
                color: context.secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required CategoryItem category,
    required bool isExpanded,
    required bool isSelected,
    required int selectionCount,
  }) {
    return Container(
      margin: EdgeInsets.only(
        bottom: AppThemeSystem.getElementSpacing(context),
      ),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(
          color: isSelected ? AppDesign.accentBorder : context.ds.border,
        ),
      ),
      child: Column(
        children: [
          // Header de la catégorie
          InkWell(
            onTap: () => controller.toggleCategory(category.id),
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            child: Padding(
              padding: EdgeInsets.all(
                AppThemeSystem.getHorizontalPadding(context) * 0.75,
              ),
              child: Row(
                children: [
                  // SVG Icon
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                          : context.backgroundColor,
                      borderRadius: context.borderRadius(BorderRadiusType.small),
                    ),
                    child: SvgPicture.asset(
                      category.svgPath,
                      colorFilter: ColorFilter.mode(
                        isSelected
                            ? AppThemeSystem.primaryColor
                            : context.secondaryTextColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),

                  SizedBox(width: 12),

                  // Nom de la catégorie
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: context.textStyle(
                            FontSizeType.body1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (selectionCount > 0)
                          Text(
                            '$selectionCount sélectionné${selectionCount > 1 ? 's' : ''}',
                            style: context.textStyle(
                              FontSizeType.caption,
                              color: AppThemeSystem.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Icône expand/collapse
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.secondaryTextColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sous-catégories (collapsable)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: EdgeInsets.fromLTRB(
                AppThemeSystem.getHorizontalPadding(context) * 0.75,
                0,
                AppThemeSystem.getHorizontalPadding(context) * 0.75,
                AppThemeSystem.getHorizontalPadding(context) * 0.75,
              ),
              child: Column(
                children: [
                  Divider(
                    color: context.borderColor,
                    height: 1,
                  ),
                  SizedBox(height: 12),
                  Obx(() => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: category.subcategories.map((subcategory) {
                          final isSubSelected = controller.selectedSubcategories
                              .contains(subcategory.id);
                          return _buildSubcategoryChip(
                            context,
                            subcategory: subcategory,
                            isSelected: isSubSelected,
                            onTap: () =>
                                controller.toggleSubcategory(subcategory.id),
                          );
                        }).toList(),
                      )),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryChip(
    BuildContext context, {
    required SubcategoryItem subcategory,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: AppDesign.space3 + 2,
          vertical: AppDesign.space2 + 1,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppDesign.accentSubtle : context.ds.surfaceMuted,
          borderRadius: BorderRadius.circular(AppDesign.radiusPill),
          border: Border.all(
            color: isSelected ? AppDesign.accentBorder : context.ds.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(
                Icons.check_rounded,
                size: 14,
                color: AppDesign.accentText,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              subcategory.name,
              style: context.textStyle(
                FontSizeType.caption,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppDesign.accentText
                    : context.ds.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
        vertical: AppThemeSystem.getVerticalPadding(context) * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        border: Border(
          top: BorderSide(
            color: context.borderColor,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compteur de sélections
            Obx(() {
              final count = controller.selectedSubcategories.length;
              if (count == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                        borderRadius: context.borderRadius(BorderRadiusType.small),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppThemeSystem.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$count catégorie${count > 1 ? 's' : ''} sélectionnée${count > 1 ? 's' : ''}',
                            style: context.textStyle(
                              FontSizeType.caption,
                              color: AppThemeSystem.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Bouton Continuer
            SizedBox(
              width: double.infinity,
              height: AppThemeSystem.getButtonHeight(context),
              child: ElevatedButton(
                onPressed: controller.saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: context.borderRadius(BorderRadiusType.medium),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continuer',
                      style: context.textStyle(
                        FontSizeType.button,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
