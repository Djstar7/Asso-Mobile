import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/onboarding_controller.dart';

/// Présentation en trois écrans, affichée au premier lancement.
///
/// Chaque page tient dans la hauteur disponible sans défilement : le contenu
/// est réparti par `Expanded` plutôt que centré sur des espacements fixes,
/// qui débordaient sur les écrans courts.
class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  // Getter : les textes suivent la langue courante.
  static List<_OnboardingPage> get _pages => [
    _OnboardingPage(
      icon: Icons.storefront_outlined,
      title: 'onboarding.market_title'.tr,
      description:
          'onboarding.market_description'.tr,
    ),
    _OnboardingPage(
      icon: Icons.local_shipping_outlined,
      title: 'onboarding.delivery_title'.tr,
      description:
          'onboarding.delivery_description'.tr,
    ),
    _OnboardingPage(
      icon: Icons.shield_outlined,
      title: 'onboarding.payments_title'.tr,
      description:
          'onboarding.payments_description'.tr,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ds.canvas,
      body: SafeArea(
        child: AppContentWidth(
          maxWidth: 560,
          child: Column(
            children: [
              // En-tête : le bouton « Passer » reste accessible en permanence.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppDesign.space2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: controller.skipOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: context.ds.textSecondary,
                      ),
                      child: Text(
                        'onboarding.skip'.tr,
                        style: context.textStyle(
                          FontSizeType.body2,
                          fontWeight: FontWeight.w600,
                          color: context.ds.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: controller.pageController,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) =>
                      _buildPage(context, _pages[index]),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.ds.gutter,
                  AppDesign.space4,
                  context.ds.gutter,
                  AppDesign.space6,
                ),
                child: Column(
                  children: [
                    Obx(
                      () => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          controller.totalPages,
                          (index) => _buildDot(context, index),
                        ),
                      ),
                    ),
                    SizedBox(height: AppDesign.space6),
                    Obx(
                      () => AppButton(
                        label: controller.currentPage.value ==
                                controller.totalPages - 1
                            ? 'onboarding.start'.tr
                            : 'common.continue'.tr,
                        onPressed: controller.nextPage,
                        size: AppButtonSize.large,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, _OnboardingPage page) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
      child: Column(
        children: [
          const Spacer(flex: 4),
          // Un cadre neutre avec une icône sobre, à la place de l'ancien
          // pavé orange en dégradé qui saturait l'écran.
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: context.ds.surface,
              borderRadius: BorderRadius.circular(AppDesign.radiusXl),
              border: Border.all(color: context.ds.border),
            ),
            child: Icon(page.icon, size: 38, color: AppDesign.accent),
          ),
          SizedBox(height: AppDesign.space8),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.h4,
              fontWeight: FontWeight.w700,
              color: context.ds.textPrimary,
              height: 1.25,
            ),
          ),
          SizedBox(height: AppDesign.space3),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.body2,
              color: context.ds.textSecondary,
              height: 1.6,
            ),
          ),
          const Spacer(flex: 5),
        ],
      ),
    );
  }

  Widget _buildDot(BuildContext context, int index) {
    final isActive = controller.currentPage.value == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      height: 6,
      width: isActive ? 22 : 6,
      decoration: BoxDecoration(
        color: isActive ? AppDesign.accent : context.ds.borderStrong,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      ),
    );
  }
}

/// Contenu d'une page d'introduction.
class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
