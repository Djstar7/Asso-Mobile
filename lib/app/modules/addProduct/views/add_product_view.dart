import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/media_helper.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/free_delivery_widgets.dart';
import '../../../core/widgets/offline_badge.dart';
import '../controllers/add_product_controller.dart';
import '../controllers/product_draft_store.dart';
import '../../../core/widgets/product_variant_selector.dart';
import '../../../routes/app_pages.dart';
import 'variant_editor_page.dart';
import '../../../data/models/currency_model.dart';

class AddProductView extends GetView<AddProductController> {
  const AddProductView({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    // Quitter en cours de saisie propose de garder le travail commencé.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleExit(context);
      },
      child: Scaffold(
      backgroundColor: ds.canvas,
      appBar: AppBar(
        backgroundColor: ds.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(onPressed: () => _handleExit(context)),
        title: Obx(
          () => Text(
            controller.isEditMode.value
                ? 'Modifier le produit'
                : 'Ajouter un produit',
            style: context.h5.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        // Hors ligne, la fiche est gardée sur le téléphone à la validation.
        actions: const [OfflineBadge(), SizedBox(width: AppDesign.space2)],
        // actions: [
        //   IconButton(
        //     tooltip: 'Menu principal',
        //     icon: Icon(Icons.home_outlined, color: context.primaryTextColor),
        //     onPressed: () => _confirmGoHome(context),
        //   ),
        // ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animation de chargement
                Container(
                  padding: EdgeInsets.all(context.horizontalPadding * 1.5),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeSystem.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircularProgressIndicator(
                    color: AppThemeSystem.primaryColor,
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: context.sectionSpacing),
                Text(
                  'Chargement des données...',
                  style: context.h6.copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: context.elementSpacing * 0.5),
                Text(
                  'Récupération des catégories et packages',
                  style: context.caption.copyWith(
                    color: context.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          // Formulaire long : faire défiler pour relire referme le clavier,
          // qui masquait sinon les champs suivants et le pied d'étape.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            left: context.horizontalPadding,
            right: context.horizontalPadding,
            top: context.verticalPadding,
            bottom:
                MediaQuery.of(context).viewPadding.bottom +
                context.verticalPadding * 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDraftBanner(context),
              _buildStepBody(context),
            ],
          ),
        );
      }),
      bottomNavigationBar: _buildStepFooter(context),
      ),
    );
  }

  /// Sortie du formulaire : propose de conserver la saisie en brouillon.
  Future<void> _handleExit(BuildContext context) async {
    void leave() {
      if (Navigator.of(context).canPop()) {
        Get.back();
      } else {
        Get.offAllNamed(Routes.VENDOR_DASHBOARD);
      }
    }

    final started = controller.productImages.isNotEmpty ||
        controller.nameController.text.trim().isNotEmpty;

    if (!controller.supportsDraft || !started) {
      leave();
      return;
    }

    final ds = context.ds;
    final keep = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: ds.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        ),
        title: Text(
          'Garder ce brouillon ?',
          style: context.subtitle1.copyWith(
            fontWeight: FontWeight.w700,
            color: ds.textPrimary,
          ),
        ),
        content: Text(
          'Vous pourrez reprendre cette fiche là où vous vous êtes arrêté.',
          style: context.body2.copyWith(color: ds.textSecondary),
        ),
        actionsPadding: EdgeInsets.fromLTRB(
          AppDesign.space4,
          0,
          AppDesign.space4,
          AppDesign.space4,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            style: TextButton.styleFrom(foregroundColor: AppDesign.danger),
            child: const Text('Supprimer'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesign.accent,
              foregroundColor: AppDesign.neutral0,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesign.radiusMd),
              ),
            ),
            child: Text(
              'Garder',
              style: context.button.copyWith(color: AppDesign.neutral0),
            ),
          ),
        ],
      ),
    );

    // Fermeture du dialogue sans choix : on ne quitte pas.
    if (keep == null) return;

    if (keep) {
      controller.saveDraft();
    } else {
      controller.discardDraft();
    }
    leave();
  }

  /// Proposition de reprise d'une fiche laissée en cours.
  Widget _buildDraftBanner(BuildContext context) {
    return Obx(() {
      final draft = controller.pendingDraft.value;
      if (draft == null) return const SizedBox.shrink();

      final ds = context.ds;
      return Container(
        margin: EdgeInsets.only(bottom: AppDesign.space6),
        padding: EdgeInsets.all(AppDesign.space4),
        decoration: BoxDecoration(
          color: ds.surface,
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
          border: Border.all(color: AppDesign.accent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 18, color: AppDesign.accentText),
                SizedBox(width: AppDesign.space2),
                Expanded(
                  child: Text(
                    'Reprendre votre brouillon ?',
                    style: context.subtitle2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ds.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDesign.space2),
            Text(
              '« ${draft.label} » · ${_draftAge(draft)}',
              style: context.body2.copyWith(color: ds.textSecondary),
            ),
            SizedBox(height: AppDesign.space4),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: controller.rejectPendingDraft,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ds.textSecondary,
                        side: BorderSide(color: ds.borderStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDesign.radiusMd),
                        ),
                      ),
                      child: Text(
                        'Recommencer',
                        style: context.body2.copyWith(
                          color: ds.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppDesign.space3),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: controller.acceptPendingDraft,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesign.accent,
                        foregroundColor: AppDesign.neutral0,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDesign.radiusMd),
                        ),
                      ),
                      child: Text(
                        'Reprendre',
                        style: context.body2.copyWith(
                          color: AppDesign.neutral0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  String _draftAge(ProductDraft draft) {
    final elapsed = DateTime.now().difference(draft.savedAt);
    if (elapsed.inMinutes < 1) return "à l'instant";
    if (elapsed.inMinutes < 60) return 'il y a ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'il y a ${elapsed.inHours} h';
    return 'il y a ${elapsed.inDays} j';
  }

  // ==========================================================================
  // PARCOURS EN ÉTAPES
  // ==========================================================================

  /// Contenu de l'étape courante.
  ///
  /// Les sections restent celles du formulaire d'origine : seul leur
  /// regroupement change. Une fiche complète demandait auparavant de parcourir
  /// treize blocs d'affilée avant de découvrir, tout en bas, qu'un forfait de
  /// stockage manquait.
  Widget _buildStepBody(BuildContext context) {
    return Obx(() {
      switch (controller.currentStep.value) {
        case 0:
          return _buildPhotoStep(context);
        case 1:
          return _buildIdentityStep(context);
        case 2:
          return _buildPricingStep(context);
        case 3:
          return _buildVariantsStep(context);
        default:
          return _buildReviewStep(context);
      }
    });
  }

  Widget _buildStepIntro(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final ds = context.ds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.h5.copyWith(
            fontWeight: FontWeight.w700,
            color: ds.textPrimary,
          ),
        ),
        SizedBox(height: AppDesign.space1),
        Text(
          subtitle,
          style: context.body2.copyWith(color: ds.textSecondary),
        ),
        SizedBox(height: AppDesign.space6),
      ],
    );
  }

  Widget _buildPhotoStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIntro(
          context,
          title: 'Photos du produit',
          subtitle:
              'La première image est celle que verront vos clients dans la liste.',
        ),
        Obx(
          () => controller.canScan
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppDesign.space6),
                  child: _buildScanCard(context),
                )
              : const SizedBox.shrink(),
        ),
        _buildImagesSection(context),
      ],
    );
  }

  Widget _buildIdentityStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIntro(
          context,
          title: 'Description',
          subtitle: 'Nommez et classez votre produit pour qu\'on le trouve.',
        ),
        _buildNameSection(context),
        SizedBox(height: AppDesign.space6),
        _buildOptionalTextField(
          context,
          label: 'Marque',
          field: 'brand',
          textController: controller.brandController,
          hint: 'Ex: Nestlé, Samsung…',
          icon: Icons.sell_outlined,
        ),
        SizedBox(height: AppDesign.space6),
        _buildCategorySelector(context),
        SizedBox(height: AppDesign.space6),
        _buildSubcategorySelector(context),
        SizedBox(height: AppDesign.space6),
        _buildDescriptionSection(context),
        SizedBox(height: AppDesign.space6),
        _buildOptionalTextField(
          context,
          label: 'Code-barres',
          field: 'barcode',
          textController: controller.barcodeController,
          hint: '8 à 14 chiffres, sous le code-barres',
          icon: Icons.qr_code_2_rounded,
          digitsOnly: true,
          errorOf: () => controller.barcodeError,
        ),
      ],
    );
  }

  Widget _buildPricingStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIntro(
          context,
          title: 'Prix & stock',
          subtitle:
              'Le poids sert au calcul des frais de livraison.',
        ),
        _buildPriceSection(context),
        SizedBox(height: AppDesign.space6),
        _buildStockSection(context),
        SizedBox(height: AppDesign.space6),
        _buildWeightSection(context),
        SizedBox(height: AppDesign.space6),
        _buildFreeDeliverySection(context),
        SizedBox(height: AppDesign.space6),
        _buildStorageSection(context),
      ],
    );
  }

  Widget _buildVariantsStep(BuildContext context) {
    return Obx(() {
      final isVariable = controller.isVariableProduct.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIntro(
            context,
            title: 'Type de produit',
            subtitle: 'Votre produit se décline-t-il en plusieurs versions ?',
          ),

          _buildKindCard(
            context,
            selected: !isVariable,
            icon: Icons.inventory_2_outlined,
            title: 'Produit simple',
            subtitle: 'Un seul prix, un seul stock.',
            example: 'Un sac de riz, un livre, un accessoire unique',
            onTap: () => controller.setProductKind(variable: false),
          ),
          SizedBox(height: AppDesign.space3),
          _buildKindCard(
            context,
            selected: isVariable,
            icon: Icons.style_outlined,
            title: 'Produit variable',
            subtitle: 'Plusieurs couleurs, tailles ou options.',
            example: 'Un t-shirt en S/M/L, une chaussure en plusieurs pointures',
            onTap: () => controller.setProductKind(variable: true),
          ),

          // L'éditeur n'apparaît que pour un produit réellement décliné.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: isVariable
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: AppDesign.space8),
                      Text(
                        'Vos déclinaisons',
                        style: context.subtitle1.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.ds.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppDesign.space1),
                      Text(
                        'Chaque combinaison a son propre stock et son propre prix.',
                        style: context.body2
                            .copyWith(color: context.ds.textSecondary),
                      ),
                      SizedBox(height: AppDesign.space4),
                      _buildVariantsSection(context),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      );
    });
  }

  /// Carte de choix du type de produit.
  Widget _buildKindCard(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required String example,
    required VoidCallback onTap,
  }) {
    final ds = context.ds;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(AppDesign.space4),
            decoration: BoxDecoration(
              color: ds.surface,
              borderRadius: BorderRadius.circular(AppDesign.radiusLg),
              border: Border.all(
                color: selected ? AppDesign.accent : ds.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SelectionDot(isSelected: selected),
                SizedBox(width: AppDesign.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 18, color: ds.textSecondary),
                          SizedBox(width: AppDesign.space2),
                          Expanded(
                            child: Text(
                              title,
                              style: context.subtitle1.copyWith(
                                fontWeight: FontWeight.w700,
                                color: ds.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppDesign.space1),
                      Text(
                        subtitle,
                        style:
                            context.body2.copyWith(color: ds.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        example,
                        style:
                            context.caption.copyWith(color: ds.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────── Vérification ─────────────

  Widget _buildReviewStep(BuildContext context) {
    final ds = context.ds;

    return Obx(() {
      final hasVariants = controller.isVariableProduct.value &&
          controller.variantEditor.hasVariants;
      final combos = controller.variantEditor.combinations;
      final price = double.tryParse(
            controller.priceController.text.trim().replaceAll(',', '.'),
          ) ??
          0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIntro(
            context,
            title: 'Vérification',
            subtitle: 'Relisez votre fiche avant de la publier.',
          ),

          Container(
            decoration: BoxDecoration(
              color: ds.surface,
              borderRadius: BorderRadius.circular(AppDesign.radiusLg),
              border: Border.all(color: ds.border),
            ),
            child: Column(
              children: [
                if (controller.productImages.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.all(AppDesign.space4),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppDesign.radiusMd),
                          child: MediaHelper.buildImagePreview(
                            controller.productImages[
                                controller.primaryImageIndex.value.clamp(
                              0,
                              controller.productImages.length - 1,
                            )],
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(width: AppDesign.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.nameController.text.trim().isEmpty
                                    ? 'Sans nom'
                                    : controller.nameController.text.trim(),
                                style: context.subtitle1.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: ds.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${controller.productImages.length} photo'
                                '${controller.productImages.length > 1 ? 's' : ''}',
                                style: context.caption
                                    .copyWith(color: ds.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Divider(height: 1, color: ds.border),
                _buildReviewRow(
                  context,
                  'Catégorie',
                  controller.selectedSubcategory.value ?? 'Non renseignée',
                  onEdit: () => controller.goToStep(1),
                ),
                _buildReviewRow(
                  context,
                  hasVariants ? 'Prix de base' : 'Prix',
                  price > 0
                      ? controller.formatPrice(price)
                      : 'Non renseigné',
                  onEdit: () => controller.goToStep(2),
                ),
                _buildReviewRow(
                  context,
                  'Stock total',
                  controller.stockController.text.trim().isEmpty
                      ? '0'
                      : controller.stockController.text.trim(),
                  onEdit: () => controller.goToStep(2),
                ),
                _buildReviewRow(
                  context,
                  'Type',
                  controller.isVariableProduct.value
                      ? 'Variable · ${combos.length} déclinaison'
                          '${combos.length > 1 ? 's' : ''}'
                      : 'Produit simple',
                  onEdit: () => controller.goToStep(3),
                  isLast: true,
                ),
              ],
            ),
          ),

          if (hasVariants) ...[
            SizedBox(height: AppDesign.space4),
            Container(
              padding: EdgeInsets.all(AppDesign.space3),
              decoration: BoxDecoration(
                color: AppDesign.accentSubtle,
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppDesign.accentText),
                  SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Text(
                      'Le stock total est la somme de vos déclinaisons.',
                      style: context.body2
                          .copyWith(color: AppDesign.accentText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildReviewRow(
    BuildContext context,
    String label,
    String value, {
    required VoidCallback onEdit,
    bool isLast = false,
  }) {
    final ds = context.ds;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDesign.space4,
                vertical: AppDesign.space4,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 116,
                    child: Text(
                      label,
                      style:
                          context.body2.copyWith(color: ds.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: context.body2.copyWith(
                        color: ds.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: AppDesign.space2),
                  Icon(Icons.edit_outlined, size: 16, color: ds.textTertiary),
                ],
              ),
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: ds.border),
      ],
    );
  }

  // ───────────── Barre de progression et navigation ─────────────

  Widget _buildStepFooter(BuildContext context) {
    final ds = context.ds;

    return Obx(() {
      final step = controller.currentStep.value;
      final isLast = step == AddProductController.stepCount - 1;
      final blocked = controller.blockingReason(step);
      final isBusy = controller.isLoading.value;

      return Container(
        padding: EdgeInsets.fromLTRB(
          ds.gutter,
          AppDesign.space3,
          ds.gutter,
          MediaQuery.of(context).viewPadding.bottom + AppDesign.space3,
        ),
        decoration: BoxDecoration(
          color: ds.surface,
          border: Border(top: BorderSide(color: ds.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStepIndicator(context, step),
            SizedBox(height: AppDesign.space3),

            // Ce qui manque est dit ici, pas découvert au moment d'envoyer.
            if (blocked != null) ...[
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: ds.textTertiary),
                  SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Text(
                      blocked,
                      style: context.caption
                          .copyWith(color: ds.textTertiary),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppDesign.space3),
            ],

            Row(
              children: [
                if (step > 0) ...[
                  Expanded(
                    child: SizedBox(
                      height: context.buttonHeight,
                      child: OutlinedButton(
                        onPressed:
                            isBusy ? null : controller.previousStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ds.textPrimary,
                          side: BorderSide(color: ds.borderStrong),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDesign.radiusMd),
                          ),
                        ),
                        child: Text(
                          'Retour',
                          style: context.button.copyWith(
                            color: ds.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppDesign.space3),
                ],
                Expanded(
                  flex: step > 0 ? 2 : 1,
                  child: SizedBox(
                    height: context.buttonHeight,
                    child: ElevatedButton(
                      onPressed: isBusy
                          ? null
                          : isLast
                              ? controller.submitProduct
                              : (controller.canGoNext
                                  ? controller.nextStep
                                  : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesign.accent,
                        foregroundColor: AppDesign.neutral0,
                        disabledBackgroundColor: ds.surfaceMuted,
                        disabledForegroundColor: ds.textTertiary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDesign.radiusMd),
                        ),
                      ),
                      child: isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppDesign.neutral0,
                              ),
                            )
                          : Text(
                              isLast
                                  ? (controller.isEditMode.value
                                      ? 'Enregistrer'
                                      : 'Publier le produit')
                                  : 'Continuer',
                              style: context.button.copyWith(
                                color: controller.canGoNext || isLast
                                    ? AppDesign.neutral0
                                    : ds.textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Fil d'étapes : segments cliquables vers les étapes déjà franchies.
  Widget _buildStepIndicator(BuildContext context, int step) {
    final ds = context.ds;

    return Row(
      children: List.generate(AddProductController.stepCount, (index) {
        final isDone = index < step;
        final isCurrent = index == step;
        final isReachable = index <= controller.furthestStep.value;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == AddProductController.stepCount - 1
                  ? 0
                  : AppDesign.space1,
            ),
            child: Semantics(
              label: AddProductController.stepTitles[index],
              selected: isCurrent,
              child: GestureDetector(
                onTap: isReachable ? () => controller.goToStep(index) : null,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      decoration: BoxDecoration(
                        color: isDone || isCurrent
                            ? AppDesign.accent
                            : ds.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(AppDesign.radiusPill),
                      ),
                    ),
                    SizedBox(height: AppDesign.space1),
                    Text(
                      AddProductController.stepTitles[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption.copyWith(
                        fontSize: 10,
                        color: isCurrent
                            ? AppDesign.accentText
                            : ds.textTertiary,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Sélection des photos : zone de dépôt puis grille des images choisies.
  ///
  /// L'ancienne bande horizontale de 120 px laissait l'écran quasi vide et
  /// obligeait à faire défiler latéralement pour voir ses propres photos.
  Widget _buildImagesSection(BuildContext context) {
    final ds = context.ds;

    return Obx(() {
      final existingCount = controller.existingImages.length;
      final newCount = controller.productImages.length;
      final total = existingCount + newCount;
      final isEmpty = total == 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone de dépôt : pleine largeur et généreuse tant qu'aucune photo
          // n'est choisie, réduite en bandeau une fois la galerie remplie.
          GestureDetector(
            onTap: () => _showImageSourceBottomSheet(context),
            child: DottedBorder(
              color: AppDesign.accent,
              strokeWidth: 1.5,
              dashPattern: const [7, 5],
              borderType: BorderType.RRect,
              radius: Radius.circular(AppDesign.radiusLg),
              child: Container(
                width: double.infinity,
                height: isEmpty ? 220 : 96,
                decoration: BoxDecoration(
                  color: AppDesign.accentSubtle,
                  borderRadius: BorderRadius.circular(AppDesign.radiusLg),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isEmpty ? 16 : 10),
                      decoration: const BoxDecoration(
                        color: AppDesign.neutral0,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: isEmpty ? 30 : 20,
                        color: AppDesign.accent,
                      ),
                    ),
                    SizedBox(height: AppDesign.space3),
                    Text(
                      isEmpty ? 'Ajouter des photos' : 'Ajouter une autre photo',
                      style: context.subtitle2.copyWith(
                        color: AppDesign.accentText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isEmpty) ...[
                      SizedBox(height: AppDesign.space1),
                      Text(
                        'Au moins une image est requise',
                        style: context.body2.copyWith(color: ds.textSecondary),
                      ),
                      SizedBox(height: AppDesign.space1),
                      Text(
                        'Appareil photo ou galerie',
                        style: context.caption.copyWith(color: ds.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (!isEmpty) ...[
            SizedBox(height: AppDesign.space5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$total photo${total > 1 ? 's' : ''}',
                    style: context.subtitle2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ds.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'Touchez pour choisir la principale',
                  style: context.caption.copyWith(color: ds.textTertiary),
                ),
              ],
            ),
            SizedBox(height: AppDesign.space3),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: total,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppDesign.space3,
                mainAxisSpacing: AppDesign.space3,
              ),
              itemBuilder: (context, index) =>
                  _buildImageThumbnail(context, index),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildImageThumbnail(BuildContext context, int index) {
    return Obx(() {
      final existingCount = controller.existingImages.length;
      final isExisting = index < existingCount;
      final isPrimary = controller.primaryImageIndex.value == index;

      Widget imageWidget;
      if (isExisting) {
        final url = controller.existingImages[index]['url'] as String;
        imageWidget = Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: context.surfaceColor,
              child: Icon(
                Icons.broken_image,
                color: context.secondaryTextColor,
              ),
            );
          },
        );
      } else {
        final newIndex = index - existingCount;
        imageWidget = MediaHelper.buildImagePreview(
          controller.productImages[newIndex],
          fit: BoxFit.cover,
        );
      }

      return Stack(
        children: [
          GestureDetector(
            onTap: () => controller.setPrimaryImage(index),
            child: Container(
              // La largeur est imposée par la grille : la fixer à 100 px
              // débordait de la colonne.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDesign.radiusMd),
                border: Border.all(
                  color: isPrimary ? AppDesign.accent : context.ds.border,
                  width: isPrimary ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDesign.radiusMd - 1),
                child: SizedBox.expand(child: imageWidget),
              ),
            ),
          ),

          if (isPrimary)
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppDesign.accent,
                  borderRadius: BorderRadius.circular(AppDesign.radiusXs),
                ),
                child: Text(
                  'Principale',
                  style: context.caption.copyWith(
                    color: AppDesign.neutral0,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => controller.removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppDesign.neutral900.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: AppDesign.neutral0, size: 13),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _showSelectedImage(context, index),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppDesign.neutral900.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.zoom_in,
                    color: AppDesign.neutral0, size: 13),
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showSelectedImage(BuildContext context, int index) {
    final existingCount = controller.existingImages.length;
    final isExisting = index < existingCount;
    final image = isExisting
        ? Image.network(
            controller.existingImages[index]['url'] as String,
            fit: BoxFit.contain,
          )
        : MediaHelper.buildImagePreview(
            controller.productImages[index - existingCount],
            fit: BoxFit.contain,
          );
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: image),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                ),
              ),
            ),
            const Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Text(
                  'Pincez pour zoomer',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section Nom du produit
  Widget _buildNameSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, 'Nom du produit *', 'name'),
        SizedBox(height: context.elementSpacing),
        TextField(
          controller: controller.nameController,
          decoration: InputDecoration(
            hintText: 'Ex: iPhone 13 Pro Max',
            filled: true,
            fillColor: context.inputFieldColor,
            prefixIcon: const Icon(Icons.inventory_2_outlined),
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
              borderSide: const BorderSide(
                color: AppThemeSystem.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Libellé de champ, avec le badge « À vérifier » tant qu'une valeur
  /// posée par le scan n'a pas été modifiée.
  Widget _fieldLabel(BuildContext context, String label, String field) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Obx(
          () => controller.isPrefilled(field)
              ? const Padding(
                  padding: EdgeInsets.only(left: AppDesign.space2),
                  child: AppBadge(
                    label: 'À vérifier',
                    tone: AppBadgeTone.accent,
                    icon: Icons.auto_awesome_outlined,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Champ texte facultatif (marque, code-barres).
  Widget _buildOptionalTextField(
    BuildContext context, {
    required String label,
    required String field,
    required TextEditingController textController,
    required String hint,
    required IconData icon,
    bool digitsOnly = false,
    String? Function()? errorOf,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, label, field),
        SizedBox(height: context.elementSpacing),
        Obx(() {
          controller.formRevision.value; // réagit à la saisie
          return TextField(
            controller: textController,
            keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
            textCapitalization: digitsOnly
                ? TextCapitalization.none
                : TextCapitalization.words,
            inputFormatters: digitsOnly
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                  ]
                : [LengthLimitingTextInputFormatter(120)],
            decoration: InputDecoration(
              hintText: hint,
              helperText: 'Facultatif',
              errorText: errorOf?.call(),
              filled: true,
              fillColor: context.inputFieldColor,
              prefixIcon: Icon(icon),
              border: border(context.borderColor),
              enabledBorder: border(context.borderColor),
              focusedBorder: border(AppThemeSystem.primaryColor, width: 2),
            ),
          );
        }),
      ],
    );
  }

  /// Accroche du remplissage automatique (photo analysée sur le téléphone).
  Widget _buildScanCard(BuildContext context) {
    final ds = context.ds;
    return AppCard(
      color: AppDesign.accentSubtle,
      elevated: false,
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.document_scanner_outlined,
                color: AppDesign.accentText,
              ),
              const SizedBox(width: AppDesign.space2),
              Expanded(
                child: Text(
                  'Remplir automatiquement',
                  style: context.subtitle1.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppDesign.accentText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.space2),
          Text(
            'Filmez le code-barres puis l\'étiquette : nom, marque, catégorie '
            'et poids se remplissent seuls. Vous vérifiez avant de publier.',
            style: context.body2.copyWith(color: ds.textSecondary),
          ),
          const SizedBox(height: AppDesign.space4),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppButton(
                  label: 'Filmer le produit',
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () => controller.openScanner(),
                ),
              ),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'Galerie',
                  icon: Icons.photo_library_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => controller.openScanner(fromGallery: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sélecteur de catégorie avec bottom sheet
  Widget _buildCategorySelector(BuildContext context) {
    return Obx(() {
      final category = controller.selectedCategory.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(context, 'Catégorie *', 'category'),
          SizedBox(height: context.elementSpacing),
          GestureDetector(
            onTap: () => _showCategoryBottomSheet(context),
            child: Container(
              padding: EdgeInsets.all(context.horizontalPadding),
              decoration: BoxDecoration(
                color: category != null
                    ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                    : context.surfaceColor,
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                border: Border.all(
                  color: category != null
                      ? AppThemeSystem.primaryColor
                      : context.borderColor,
                  width: category != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    color: category != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category ?? 'Sélectionnez une catégorie',
                      style: context.body1.copyWith(
                        color: category != null
                            ? AppThemeSystem.primaryColor
                            : context.secondaryTextColor,
                        fontWeight: category != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: category != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Sélecteur de sous-catégorie avec bottom sheet
  Widget _buildSubcategorySelector(BuildContext context) {
    return Obx(() {
      final subcategory = controller.selectedSubcategory.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sous-catégorie *',
            style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: context.elementSpacing),
          GestureDetector(
            onTap: () => _showSubcategoryBottomSheet(context),
            child: Container(
              padding: EdgeInsets.all(context.horizontalPadding),
              decoration: BoxDecoration(
                color: subcategory != null
                    ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                    : context.surfaceColor,
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                border: Border.all(
                  color: subcategory != null
                      ? AppThemeSystem.primaryColor
                      : context.borderColor,
                  width: subcategory != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    color: subcategory != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subcategory ?? 'Sélectionnez une sous-catégorie',
                      style: context.body1.copyWith(
                        color: subcategory != null
                            ? AppThemeSystem.primaryColor
                            : context.secondaryTextColor,
                        fontWeight: subcategory != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: subcategory != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Bottom sheet pour choisir la source de l'image (caméra ou galerie)
  void _showImageSourceBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: context.horizontalPadding,
            right: context.horizontalPadding,
            top: context.verticalPadding,
            bottom: context.bottomSheetPadding,
          ),
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: context.elementSpacing),

              // Titre
              Text(
                'Ajouter des images',
                style: context.h5.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: context.sectionSpacing),

              // Option Caméra
              _buildImageSourceOption(
                context,
                icon: Icons.camera_alt,
                title: 'Appareil photo',
                subtitle: 'Prendre une photo',
                onTap: () {
                  Navigator.pop(context);
                  controller.takePhoto();
                },
              ),
              SizedBox(height: context.elementSpacing),

              // Option Galerie
              _buildImageSourceOption(
                context,
                icon: Icons.photo_library,
                title: 'Galerie',
                subtitle: 'Sélectionner depuis la galerie',
                onTap: () {
                  Navigator.pop(context);
                  controller.pickImages();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Widget pour une option de source d'image
  Widget _buildImageSourceOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: context.borderRadius(BorderRadiusType.medium),
      child: Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(color: context.borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.elementSpacing),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                borderRadius: context.borderRadius(BorderRadiusType.small),
              ),
              child: Icon(icon, color: AppThemeSystem.primaryColor, size: 28),
            ),
            SizedBox(width: context.elementSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.subtitle1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
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

  /// Bottom sheet pour sélectionner la catégorie
  void _showCategoryBottomSheet(BuildContext context) {
    if (!controller.categoriesAvailable.value) {
      controller.warnCategoriesUnavailable();
      return;
    }
    final searchController = TextEditingController();
    final categories = controller.categoriesData.keys.toList();
    final filteredCategories = categories.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
              ),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(context.horizontalPadding),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      AppThemeSystem.getBorderRadius(
                        context,
                        BorderRadiusType.large,
                      ),
                    ),
                  ),
                  border: Border(
                    bottom: BorderSide(color: context.borderColor),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: context.elementSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sélectionner une catégorie',
                            style: context.h5.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: context.elementSpacing),
                    // Barre de recherche
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: context.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: context.borderRadius(
                            BorderRadiusType.medium,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.horizontalPadding,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          filteredCategories.value = categories;
                        } else {
                          filteredCategories.value = categories
                              .where(
                                (cat) => cat.toLowerCase().contains(
                                  value.toLowerCase(),
                                ),
                              )
                              .toList();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Liste avec padding bottom pour la barre de navigation
              Expanded(
                child: Obx(() {
                  return ListView.separated(
                    // Parcourir la liste referme le clavier de la recherche,
                    // qui en recouvrait la moitié basse.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      left: context.horizontalPadding,
                      right: context.horizontalPadding,
                      top: context.horizontalPadding,
                      bottom: context.bottomSheetPadding,
                    ),
                    itemCount: filteredCategories.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: context.borderColor),
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
                      final isSelected =
                          controller.selectedCategory.value == category;

                      // Le ListTile peint son encre sur le Material le plus
                      // proche : sans cette enveloppe, le fond décoré de la
                      // feuille masquait le retour au toucher.
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            Icons.folder,
                            color: isSelected
                                ? AppThemeSystem.primaryColor
                                : context.secondaryTextColor,
                          ),
                          title: Text(
                            category,
                            style: context.body1.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppThemeSystem.primaryColor
                                  : context.primaryTextColor,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: AppThemeSystem.successColor,
                                )
                              : null,
                          onTap: () {
                            controller.selectedCategory.value = category;
                            controller.selectedSizes.clear();
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bottom sheet pour sélectionner la sous-catégorie
  void _showSubcategoryBottomSheet(BuildContext context) {
    if (!controller.categoriesAvailable.value) {
      controller.warnCategoriesUnavailable();
      return;
    }
    final searchController = TextEditingController();
    final category = controller.selectedCategory.value;

    // Filtrer les sous-catégories selon la catégorie sélectionnée
    final subcategories = category != null
        ? controller.categoriesData[category] ?? []
        : controller.allSubcategories;

    final filteredSubcategories = <Map<String, String>>[].obs;
    filteredSubcategories.value = subcategories;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
              ),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(context.horizontalPadding),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      AppThemeSystem.getBorderRadius(
                        context,
                        BorderRadiusType.large,
                      ),
                    ),
                  ),
                  border: Border(
                    bottom: BorderSide(color: context.borderColor),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: context.elementSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category != null
                                ? 'Sous-catégories de $category'
                                : 'Sélectionner une sous-catégorie',
                            style: context.h5.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: context.elementSpacing),
                    // Barre de recherche
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: context.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: context.borderRadius(
                            BorderRadiusType.medium,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.horizontalPadding,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          filteredSubcategories.value = subcategories;
                        } else {
                          filteredSubcategories.value = subcategories
                              .where(
                                (sub) => sub['name']!.toLowerCase().contains(
                                  value.toLowerCase(),
                                ),
                              )
                              .toList();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Liste avec padding bottom pour la barre de navigation
              Expanded(
                child: Obx(() {
                  if (filteredSubcategories.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.horizontalPadding),
                        child: Text(
                          category != null
                              ? 'Aucune sous-catégorie trouvée'
                              : 'Veuillez sélectionner une catégorie d\'abord',
                          style: context.body1.copyWith(
                            color: context.secondaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    // Parcourir la liste referme le clavier de la recherche,
                    // qui en recouvrait la moitié basse.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      left: context.horizontalPadding,
                      right: context.horizontalPadding,
                      top: context.horizontalPadding,
                      bottom: context.bottomSheetPadding,
                    ),
                    itemCount: filteredSubcategories.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: context.borderColor),
                    itemBuilder: (context, index) {
                      final subcategory = filteredSubcategories[index];
                      final isSelected =
                          controller.selectedSubcategoryId.value ==
                          subcategory['id'];

                      // Le ListTile peint son encre sur le Material le plus
                      // proche : sans cette enveloppe, le fond décoré de la
                      // feuille masquait le retour au toucher.
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            Icons.category,
                            color: isSelected
                                ? AppThemeSystem.primaryColor
                                : context.secondaryTextColor,
                          ),
                          title: Text(
                            subcategory['name']!,
                            style: context.body1.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppThemeSystem.primaryColor
                                  : context.primaryTextColor,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: AppThemeSystem.successColor,
                                )
                              : null,
                          onTap: () {
                            controller.selectedSubcategory.value =
                                subcategory['name'];
                            controller.selectedSubcategoryId.value =
                                subcategory['id'];
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Section Prix
  Widget _buildPriceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avec des déclinaisons, ce prix sert de base : chacune lui applique
        // son propre supplément.
        Obx(() => Text(
              controller.isVariableProduct.value ? 'Prix de base *' : 'Prix *',
              style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
            )),
        SizedBox(height: context.elementSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Obx(
                () => TextField(
                  controller: controller.priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Entrez le prix',
                    filled: true,
                    fillColor: context.inputFieldColor,
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: controller.selectedCurrencySymbol,
                    border: OutlineInputBorder(
                      borderRadius: context.borderRadius(
                        BorderRadiusType.medium,
                      ),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: context.borderRadius(
                        BorderRadiusType.medium,
                      ),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: context.borderRadius(
                        BorderRadiusType.medium,
                      ),
                      borderSide: const BorderSide(
                        color: AppThemeSystem.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: context.elementSpacing),
            _buildCurrencySelector(context),
          ],
        ),
        SizedBox(height: context.elementSpacing / 2),
        // Aperçu : ce que paient les clients (commission ASSO incluse) vs ce que reçoit le vendeur.
        Obx(() {
          final buyer = controller.buyerPricePreview.value;
          final seller = double.tryParse(
            controller.priceController.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
          );
          if (buyer == null || seller == null || buyer <= seller) {
            return Text(
              'Vous recevez exactement le prix que vous saisissez.',
              style: context.caption.copyWith(color: context.secondaryTextColor),
            );
          }
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.08),
              borderRadius: context.borderRadius(BorderRadiusType.small),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prix affiché aux clients : ${controller.formatInSelectedCurrency(buyer)}',
                  style: context.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeSystem.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vous recevez ${controller.formatInSelectedCurrency(seller)} par vente. La commission ASSO est payée par le client.',
                  style: context.caption.copyWith(color: context.secondaryTextColor),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Sélecteur de devise du prix — bottom sheet avec recherche (remplace le dropdown)
  Widget _buildCurrencySelector(BuildContext context) {
    return Obx(() {
      final currencies = controller.availableCurrencies;
      final selectedCode = controller.selectedCurrency.value;
      final selected = currencies.firstWhereOrNull(
        (c) => c.code == selectedCode,
      );

      return GestureDetector(
        onTap: () => _showCurrencyBottomSheet(context),
        child: Container(
          height: 56, // aligné avec la hauteur du TextField du prix
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.inputFieldColor,
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected?.code ?? selectedCode,
                style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: context.secondaryTextColor),
            ],
          ),
        ),
      );
    });
  }

  /// Bottom sheet pour sélectionner la devise, avec recherche (code ou nom)
  void _showCurrencyBottomSheet(BuildContext context) {
    final searchController = TextEditingController();
    final allCurrencies = controller.availableCurrencies.isNotEmpty
        ? controller.availableCurrencies
        : <CurrencyModel>[];
    final filteredCurrencies = <CurrencyModel>[].obs;
    filteredCurrencies.value = allCurrencies;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
              ),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(context.horizontalPadding),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      AppThemeSystem.getBorderRadius(
                        context,
                        BorderRadiusType.large,
                      ),
                    ),
                  ),
                  border: Border(
                    bottom: BorderSide(color: context.borderColor),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: context.elementSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sélectionner une devise',
                            style: context.h5.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: context.elementSpacing),
                    // Barre de recherche
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par code ou nom...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: context.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: context.borderRadius(
                            BorderRadiusType.medium,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.horizontalPadding,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          filteredCurrencies.value = allCurrencies;
                        } else {
                          final query = value.toLowerCase();
                          filteredCurrencies.value = allCurrencies.where((c) {
                            return c.code.toLowerCase().contains(query) ||
                                c.name.toLowerCase().contains(query);
                          }).toList();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Liste des devises
              Expanded(
                child: Obx(() {
                  if (filteredCurrencies.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.horizontalPadding),
                        child: Text(
                          'Aucune devise trouvée',
                          style: context.body1.copyWith(
                            color: context.secondaryTextColor,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    // Parcourir la liste referme le clavier de la recherche,
                    // qui en recouvrait la moitié basse.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      left: context.horizontalPadding,
                      right: context.horizontalPadding,
                      top: context.horizontalPadding,
                      bottom: context.bottomSheetPadding,
                    ),
                    itemCount: filteredCurrencies.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: context.borderColor),
                    itemBuilder: (context, index) {
                      final currency = filteredCurrencies[index];
                      final isSelected =
                          controller.selectedCurrency.value == currency.code;

                      // Le ListTile peint son encre sur le Material le plus
                      // proche : sans cette enveloppe, le fond décoré de la
                      // feuille masquait le retour au toucher.
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? AppThemeSystem.primaryColor.withValues(
                                    alpha: 0.1,
                                  )
                                : context.surfaceColor,
                            child: Text(
                              currency.symbol,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AppThemeSystem.primaryColor
                                    : context.secondaryTextColor,
                              ),
                            ),
                          ),
                          title: Text(
                            currency.code,
                            style: context.body1.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppThemeSystem.primaryColor
                                  : context.primaryTextColor,
                            ),
                          ),
                          subtitle: Text(
                            currency.name,
                            style: context.caption.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: AppThemeSystem.successColor,
                                )
                              : null,
                          onTap: () {
                            controller.selectedCurrency.value = currency.code;
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Section Description
  Widget _buildDescriptionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, 'Description *', 'description'),
        SizedBox(height: context.elementSpacing),
        TextField(
          controller: controller.descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Décrivez votre produit en détail...',
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
              borderSide: const BorderSide(
                color: AppThemeSystem.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Livraison gratuite du produit : suit la boutique, sauf choix contraire.
  Widget _buildFreeDeliverySection(BuildContext context) {
    return Obx(() {
      // Une prestation n'a pas de colis à livrer.
      if (controller.articleType.value == 'service') {
        return const SizedBox.shrink();
      }
      final value = controller.freeDeliveryEffective;
      final shop = controller.shopFreeDelivery.value;
      final followsShop = controller.freeDeliveryOverride.value == null;

      return FreeDeliveryToggle(
        title: 'Livraison gratuite',
        subtitle: [
          value
              ? 'Le client ne paie pas la livraison : son prix est retenu sur la vente.'
              : 'Offrez la livraison de ce produit : son prix sera retenu sur la vente.',
          if (followsShop && shop) 'Réglage de votre boutique.',
          if (!followsShop && shop) 'Exclu de la livraison gratuite de la boutique.',
        ].join(' '),
        value: value,
        onChanged: controller.setFreeDelivery,
      );
    });
  }

  /// Section Poids du produit : poids réel en kg, obligatoire pour un article.
  Widget _buildWeightSection(BuildContext context) {
    return Obx(() {
      controller.customWeightValue.value; // réagit à la saisie
      final isArticle = controller.articleType.value == 'article';
      final hasText = controller.weightKgController.text.trim().isNotEmpty;
      final error = hasText ? controller.weightError : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(
            context,
            isArticle ? 'Poids du produit (kg) *' : 'Poids du produit (kg)',
            'weight',
          ),
          SizedBox(height: context.elementSpacing),
          TextField(
            controller: controller.weightKgController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              hintText: 'Ex: 2,5',
              helperText: 'Poids réel du colis en kg — utilisé pour calculer la livraison',
              helperMaxLines: 2,
              errorText: error,
              filled: true,
              fillColor: context.inputFieldColor,
              prefixIcon: const Icon(Icons.scale_outlined),
              suffixText: 'kg',
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
                borderSide: const BorderSide(
                  color: AppThemeSystem.primaryColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  
  
  
  Future<void> _openVariantEditor(BuildContext context) async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VariantEditorPage(state: controller.variantEditor),
      ),
    );
    controller.syncStockFromVariants();
  }

  /// Section variantes : résumé lisible + accès à l'éditeur dédié.
  Widget _buildVariantsSection(BuildContext context) {
    final editor = controller.variantEditor;
    return Obx(() {
      editor.revision.value;
      final groups = editor.groups
          .where((g) => g.name.trim().isNotEmpty && g.values.isNotEmpty)
          .toList();
      final combos = editor.combinations;

      return InkWell(
        onTap: () => _openVariantEditor(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: combos.isEmpty
                  ? context.borderColor
                  : AppThemeSystem.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppThemeSystem.primaryColor.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.style_outlined,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Couleurs, tailles & options',
                          style: context.subtitle1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          combos.isEmpty
                              ? 'Facultatif · ex. couleur d’un téléphone, pointure d’une chaussure'
                              : '${combos.length} choix · ${editor.totalStock} en stock au total',
                          style: context.caption.copyWith(
                            color: context.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    combos.isEmpty
                        ? Icons.add_circle_outline
                        : Icons.edit_outlined,
                    color: AppThemeSystem.primaryColor,
                  ),
                ],
              ),
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final group in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            group.name,
                            style: context.caption.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: group.values.map((v) {
                              if (group.isColor) {
                                return Tooltip(
                                  message: v.value,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color:
                                          VariantPalette.parseHex(v.hex) ??
                                          VariantPalette.guess(v.value),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black26),
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: context.backgroundColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  v.value,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    });
  }

  /// Section Stock
  Widget _buildStockSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantité en stock *',
          style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: context.elementSpacing),
        Obx(() {
          controller.variantEditor.revision.value;
          final fromVariants = controller.variantEditor.hasVariants;
          return TextField(
            controller: controller.stockController,
            readOnly: fromVariants,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              helperText: fromVariants
                  ? 'Calculée automatiquement à partir des couleurs / tailles'
                  : null,
              hintText: 'Ex: 200',
              filled: true,
              fillColor: context.inputFieldColor,
              prefixIcon: const Icon(Icons.inventory_outlined),
              suffixText: 'unités',
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
                borderSide: const BorderSide(
                  color: AppThemeSystem.primaryColor,
                  width: 2,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Section Espace de stockage
  Widget _buildStorageSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Espace de stockage',
                style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: controller.addNewStorage,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(
                foregroundColor: AppThemeSystem.primaryColor,
              ),
            ),
          ],
        ),
        SizedBox(height: context.elementSpacing),

        Obx(() {
          if (controller.selectedStorage.value == null) {
            return Container(
              padding: EdgeInsets.all(context.horizontalPadding),
              decoration: BoxDecoration(
                color: AppThemeSystem.warningColor.withValues(alpha: 0.1),
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                border: Border.all(
                  color: AppThemeSystem.warningColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppThemeSystem.warningColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aucun package actif. Veuillez souscrire à un package.',
                      style: context.body2.copyWith(
                        color: AppThemeSystem.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final storage = controller.selectedStorage.value!;
          final available = storage['available'] as double;
          final total = storage['total'] as double;
          final used = total - available;
          final percentageUsed = total > 0 ? (used / total * 100) : 0.0;

          final ds = context.ds;
          // La jauge ne vire au vif que lorsqu'elle alerte réellement, et
          // l'unité suit le reste de l'application (Go, pas GB).
          final gaugeColor = percentageUsed > 90
              ? AppDesign.danger
              : percentageUsed > 75
                  ? AppDesign.warning
                  : AppDesign.accent;

          return Container(
            padding: EdgeInsets.all(AppDesign.space4),
            decoration: BoxDecoration(
              color: ds.surface,
              borderRadius: BorderRadius.circular(AppDesign.radiusLg),
              border: Border.all(color: AppDesign.accent),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        storage['name'],
                        style: context.body1.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ds.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDesign.space2,
                        vertical: AppDesign.space1,
                      ),
                      decoration: BoxDecoration(
                        color: AppDesign.successSubtle,
                        borderRadius:
                            BorderRadius.circular(AppDesign.radiusPill),
                      ),
                      child: Text(
                        'Actif',
                        style: context.caption.copyWith(
                          color: AppDesign.successText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppDesign.space4),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        'Espace utilisé',
                        style: context.body2.copyWith(color: ds.textSecondary),
                      ),
                    ),
                    Text(
                      '${used.toStringAsFixed(1)} Go',
                      style: context.body2.copyWith(
                        color: ds.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' / ${total.toStringAsFixed(0)} Go',
                      style: context.body2.copyWith(color: ds.textTertiary),
                    ),
                  ],
                ),
                SizedBox(height: AppDesign.space2),

                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                  child: LinearProgressIndicator(
                    value: (percentageUsed / 100).clamp(0.0, 1.0),
                    backgroundColor: ds.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                    minHeight: 6,
                  ),
                ),
                SizedBox(height: AppDesign.space2),
                Text(
                  '${percentageUsed.toStringAsFixed(0)} % utilisé · '
                  '${available.toStringAsFixed(1)} Go disponibles',
                  style: context.caption.copyWith(color: ds.textTertiary),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Bouton de soumission
  }

/// Indicateur de sélection : cercle neutre au repos, plein en accent une fois
/// choisi.
class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppDesign.accent : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppDesign.accent : ds.borderStrong,
          width: isSelected ? 0 : 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 14, color: AppDesign.neutral0)
          : null,
    );
  }
}
