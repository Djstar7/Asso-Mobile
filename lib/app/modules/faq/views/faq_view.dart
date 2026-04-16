import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/faq_controller.dart';

class FaqView extends GetView<FaqController> {
  const FaqView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.primaryTextColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Questions Fréquentes',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(context),

          SizedBox(height: context.elementSpacing),

          // Liste des FAQs
          Expanded(
            child: Obx(() {
              if (controller.filteredCategories.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.separated(
                padding: EdgeInsets.all(context.horizontalPadding),
                itemCount: controller.filteredCategories.length,
                separatorBuilder: (context, index) => SizedBox(height: context.sectionSpacing),
                itemBuilder: (context, index) {
                  final category = controller.filteredCategories[index];
                  return _buildCategorySection(context, category);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: TextField(
        onChanged: (value) => controller.searchQuery.value = value,
        decoration: InputDecoration(
          hintText: 'Rechercher une question...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.searchQuery.value = '';
                  },
                )
              : const SizedBox.shrink()),
          filled: true,
          fillColor: context.inputFieldColor,
          border: OutlineInputBorder(
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            borderSide: BorderSide(color: context.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            borderSide: BorderSide(color: context.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            borderSide: const BorderSide(color: AppThemeSystem.primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: context.secondaryTextColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat trouvé',
            style: context.h6.copyWith(color: context.secondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez avec d\'autres mots-clés',
            style: context.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, FaqCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de la catégorie
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.title,
                style: context.h6.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppThemeSystem.primaryColor,
                ),
              ),
            ],
          ),
        ),

        // Liste des FAQs
        ...category.faqs.map((faq) => _buildFaqItem(context, faq)),
      ],
    );
  }

  Widget _buildFaqItem(BuildContext context, Faq faq) {
    return Obx(() {
      final isExpanded = controller.expandedIndex.value == faq.id;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(
            color: isExpanded ? AppThemeSystem.primaryColor : context.borderColor,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          child: Column(
            children: [
              // Question
              InkWell(
                onTap: () => controller.toggleExpansion(faq.id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? AppThemeSystem.primaryColor
                              : AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.help_outline,
                          size: 18,
                          color: isExpanded ? Colors.white : AppThemeSystem.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          faq.question,
                          style: context.body1.copyWith(
                            fontWeight: isExpanded ? FontWeight.bold : FontWeight.w600,
                            color: isExpanded
                                ? AppThemeSystem.primaryColor
                                : context.primaryTextColor,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: isExpanded
                            ? AppThemeSystem.primaryColor
                            : context.secondaryTextColor,
                      ),
                    ],
                  ),
                ),
              ),

              // Réponse (avec animation)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          top: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.05),
                          border: Border(
                            top: BorderSide(
                              color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppThemeSystem.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                faq.answer,
                                style: context.body2.copyWith(
                                  height: 1.5,
                                  color: context.primaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    });
  }
}
