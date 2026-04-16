import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/help_controller.dart';

class HelpView extends GetView<HelpController> {
  const HelpView({super.key});

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
          'Aide et Support',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre de recherche
            _buildSearchBar(context),

            SizedBox(height: context.elementSpacing),

            // Section contact rapide
            _buildQuickContactSection(context),

            SizedBox(height: context.sectionSpacing),

            // FAQ Section
            Obx(() {
              if (controller.searchQuery.value.isNotEmpty) {
                return _buildSearchResults(context);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre des FAQ
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.horizontalPadding,
                    ),
                    child: Text(
                      'Questions Fréquentes (FAQ)',
                      style: context.h6.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Liste des FAQ par catégorie
                  _buildFaqSection(context),

                  SizedBox(height: context.sectionSpacing),

                  // Titre des sujets d'aide
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.horizontalPadding,
                    ),
                    child: Text(
                      'Sujets d\'aide',
                      style: context.h6.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ),

                  SizedBox(height: context.elementSpacing),

                  // Grille des sujets d'aide
                  _buildSupportTopicsGrid(context),

                  SizedBox(height: context.sectionSpacing),

                  // Section informations de contact
                  _buildContactInfoSection(context),

                  const SizedBox(height: 32),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickContactSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(context.horizontalPadding),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeSystem.primaryColor,
            AppThemeSystem.primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        boxShadow: [
          BoxShadow(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.headset_mic, color: Colors.white, size: 40),
          const SizedBox(height: 16),
          const Text(
            'Besoin d\'aide ?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Notre équipe est disponible pour vous aider 24h/24 et 7j/7',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: controller.contactByEmail,
                  icon: const Icon(Icons.email, size: 18),
                  label: const Text('Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppThemeSystem.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: controller.contactByPhone,
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Appeler'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppThemeSystem.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTopicsGrid(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.deviceType == DeviceType.mobile ? 2 : 4,
          childAspectRatio: 1.1,
          crossAxisSpacing: context.elementSpacing,
          mainAxisSpacing: context.elementSpacing,
        ),
        itemCount: controller.supportTopics.length,
        itemBuilder: (context, index) {
          final topic = controller.supportTopics[index];
          return _buildTopicCard(context, topic);
        },
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, SupportTopic topic) {
    return InkWell(
      onTap: () => controller.openTopic(topic),
      borderRadius: context.borderRadius(BorderRadiusType.medium),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                topic.icon,
                color: AppThemeSystem.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                topic.title,
                style: context.body1.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                topic.description,
                style: context.caption,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations de contact',
            style: context.body1.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildContactItem(
            context,
            icon: Icons.email,
            title: 'Email',
            value: 'support@asso-corporation.com',
            onTap: controller.contactByEmail,
          ),
          const SizedBox(height: 12),
          _buildContactItem(
            context,
            icon: Icons.phone,
            title: 'Téléphone',
            value: '658895572 / 651826475',
            onTap: controller.contactByPhone,
          ),
          const SizedBox(height: 12),
          _buildContactItem(
            context,
            icon: Icons.chat,
            title: 'WhatsApp',
            value: '658895572 / 651826475',
            onTap: controller.contactByWhatsApp,
            iconColor: const Color(0xFF25D366),
          ),
          const SizedBox(height: 16),
          Divider(color: context.borderColor),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 20,
                color: context.secondaryTextColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Horaires: 24h/24 - 7j/7',
                style: context.body2.copyWith(
                  color: context.secondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppThemeSystem.primaryColor).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppThemeSystem.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.caption),
                  Text(
                    value,
                    style: context.body2.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(context.horizontalPadding),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.inputFieldColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: context.secondaryTextColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher dans l\'aide...',
                hintStyle: context.body2.copyWith(
                  color: AppThemeSystem.grey600,
                ),
                border: InputBorder.none,
              ),
              style: context.body2.copyWith(
                color: AppThemeSystem.blackColor,
              ),
            ),
          ),
          Obx(() {
            if (controller.searchQuery.value.isNotEmpty) {
              return IconButton(
                icon: Icon(
                  Icons.clear,
                  color: context.secondaryTextColor,
                  size: 20,
                ),
                onPressed: controller.clearSearch,
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final results = controller.filteredFaqs;
            if (results.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: context.secondaryTextColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun résultat trouvé',
                        style: context.h6.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Essayez avec d\'autres mots-clés',
                        style: context.body2.copyWith(
                          color: context.secondaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${results.length} résultat(s) trouvé(s)',
                  style: context.body2.copyWith(
                    color: context.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                ...results.map((faq) => _buildFaqCard(context, faq, true)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFaqSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: Column(
        children: controller.faqCategories.map((category) {
          final categoryFaqs = controller.allFaqs
              .where((faq) => faq.category == category)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre de la catégorie
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(category),
                      color: AppThemeSystem.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      category,
                      style: context.body1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // FAQ de la catégorie (afficher seulement 3 premières)
              ...categoryFaqs
                  .take(3)
                  .map((faq) => _buildFaqCard(context, faq, false)),

              // Bouton "Voir plus" si plus de 3 FAQ
              if (categoryFaqs.length > 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () =>
                        _showAllCategoryFaqs(context, category, categoryFaqs),
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      'Voir toutes les ${categoryFaqs.length} questions',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppThemeSystem.primaryColor,
                    ),
                  ),
                ),

              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaqCard(BuildContext context, FaqItem faq, bool showCategory) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.help_outline,
              color: AppThemeSystem.primaryColor,
              size: 20,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showCategory)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    faq.category,
                    style: context.caption.copyWith(
                      color: AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                faq.question,
                style: context.body2.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          children: [
            Text(
              faq.answer,
              style: context.body2.copyWith(
                color: context.secondaryTextColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Commandes':
        return Icons.shopping_cart_outlined;
      case 'Paiements':
        return Icons.payment_outlined;
      case 'Compte':
        return Icons.person_outline;
      case 'Livraison':
        return Icons.local_shipping_outlined;
      case 'Vendeurs':
        return Icons.store_outlined;
      case 'Général':
        return Icons.info_outline;
      default:
        return Icons.help_outline;
    }
  }

  void _showAllCategoryFaqs(
    BuildContext context,
    String category,
    List<FaqItem> faqs,
  ) {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.8,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(category),
                  color: AppThemeSystem.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category,
                    style: context.h6.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: faqs.length,
                itemBuilder: (context, index) {
                  return _buildFaqCard(context, faqs[index], false);
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}
