import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/media_helper.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/english_version_section.dart';
import '../../../core/widgets/free_delivery_widgets.dart';
import '../../../core/widgets/image_source_sheet.dart';
import '../../../core/widgets/offline_badge.dart';
import '../controllers/add_product_controller.dart';
import '../controllers/product_draft_store.dart';
import '../controllers/product_video_upload.dart';
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
                ? 'add_product.view.edit_title'.tr
                : 'add_product.view.add_title'.tr,
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
                  'add_product.view.loading'.tr,
                  style: context.h6.copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: context.elementSpacing * 0.5),
                Text(
                  'add_product.view.loading_subtitle'.tr,
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
          'add_product.draft.keep_title'.tr,
          style: context.subtitle1.copyWith(
            fontWeight: FontWeight.w700,
            color: ds.textPrimary,
          ),
        ),
        content: Text(
          'add_product.draft.keep_message'.tr,
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
            child: Text('add_product.draft.delete'.tr),
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
              'add_product.draft.keep'.tr,
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
                    'add_product.draft.resume_title'.tr,
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
              'add_product.draft.resume_label'.trParams({
                'label': draft.label,
                'age': _draftAge(draft),
              }),
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
                        'add_product.draft.restart'.tr,
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
                        'add_product.draft.resume'.tr,
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
    if (elapsed.inMinutes < 1) return 'add_product.draft.age_now'.tr;
    if (elapsed.inMinutes < 60) {
      return 'add_product.draft.age_minutes'
          .trParams({'n': '${elapsed.inMinutes}'});
    }
    if (elapsed.inHours < 24) {
      return 'add_product.draft.age_hours'.trParams({'n': '${elapsed.inHours}'});
    }
    return 'add_product.draft.age_days'.trParams({'n': '${elapsed.inDays}'});
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
          title: 'add_product.view.photos_title'.tr,
          subtitle: 'add_product.view.photos_subtitle'.tr,
        ),
        _buildImagesSection(context),
        SizedBox(height: AppDesign.space6),
        _buildVideoSection(context),
      ],
    );
  }

  /// Vidéo de présentation (facultative) : lue en boucle et muette sur les
  /// cartes, avec le son sur la fiche produit.
  Widget _buildVideoSection(BuildContext context) {
    final ds = context.ds;
    final video = controller.video;

    return Obx(() {
      final phase = video.phase.value;
      final existing = video.existing.value;
      final file = video.picked.value;

      Widget status;
      switch (phase) {
        case ProductVideoPhase.uploading:
          status = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'add_product.video.uploading'.trParams({
                  'percent': '${(video.progress.value * 100).round()}',
                }),
                style: context.body2.copyWith(color: ds.textSecondary),
              ),
              SizedBox(height: AppDesign.space2),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                child: LinearProgressIndicator(
                  value: video.progress.value,
                  minHeight: 6,
                  color: AppDesign.accent,
                  backgroundColor: ds.surfaceMuted,
                ),
              ),
            ],
          );
        case ProductVideoPhase.processing:
          status = _videoStatusLine(
            context,
            Icons.hourglass_top_rounded,
            'add_product.video.processing'.tr,
            ds.textSecondary,
          );
        case ProductVideoPhase.ready:
          status = _videoStatusLine(
            context,
            Icons.check_circle_rounded,
            existing?.durationLabel == null
                ? 'add_product.video.ready'.tr
                : 'add_product.video.ready_duration'.trParams({
                    'duration': existing!.durationLabel!,
                  }),
            AppDesign.success,
          );
        case ProductVideoPhase.failed:
          status = _videoStatusLine(
            context,
            Icons.error_outline_rounded,
            (video.errorKey.value ?? 'add_product.video.upload_failed')
                .trParams(video.errorParams.value ?? const {}),
            AppDesign.danger,
          );
        case ProductVideoPhase.none:
          status = const SizedBox.shrink();
      }

      final hasVideo = phase != ProductVideoPhase.none &&
          (file != null || existing != null || phase == ProductVideoPhase.processing);

      return AppCard(
        padding: EdgeInsets.all(AppDesign.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.videocam_outlined, color: AppDesign.accent),
                SizedBox(width: AppDesign.space2),
                Expanded(
                  child: Text(
                    'add_product.video.title'.tr,
                    style: context.subtitle2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ds.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDesign.space1),
            Text(
              'add_product.video.subtitle'.trParams({
                'max': '${ProductVideoUpload.maxSizeMb}',
              }),
              style: context.caption.copyWith(color: ds.textTertiary),
            ),
            if (hasVideo || phase == ProductVideoPhase.failed) ...[
              SizedBox(height: AppDesign.space4),
              if (existing?.posterUrl != null && file == null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesign.radiusMd),
                  child: SizedBox(
                    height: 120,
                    child: AspectRatio(
                      aspectRatio: existing!.aspectRatio,
                      child: Image.network(
                        existing.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            ColoredBox(color: ds.surfaceMuted),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppDesign.space3),
              ],
              if (file != null) ...[
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.body2.copyWith(color: ds.textPrimary),
                ),
                SizedBox(height: AppDesign.space2),
              ],
              status,
            ],
            SizedBox(height: AppDesign.space4),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: hasVideo
                        ? 'add_product.video.replace'.tr
                        : 'add_product.video.add'.tr,
                    icon: Icons.video_library_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: phase == ProductVideoPhase.uploading
                        ? null
                        : () => _showVideoSourceSheet(context),
                  ),
                ),
                if (hasVideo || phase == ProductVideoPhase.failed) ...[
                  SizedBox(width: AppDesign.space3),
                  Expanded(
                    child: AppButton(
                      label: phase == ProductVideoPhase.uploading
                          ? 'add_product.cancel'.tr
                          : 'add_product.video.remove'.tr,
                      icon: Icons.delete_outline_rounded,
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.small,
                      onPressed: video.remove,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _videoStatusLine(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        SizedBox(width: AppDesign.space2),
        Expanded(
          child: Text(label, style: context.body2.copyWith(color: color)),
        ),
      ],
    );
  }

  Future<void> _showVideoSourceSheet(BuildContext context) async {
    final source = await showImageSourceSheet(
      context,
      title: 'add_product.video.source_title'.tr,
      cameraSubtitle: 'add_product.video.source_camera'.tr,
      gallerySubtitle: 'add_product.video.source_gallery'.tr,
    );
    if (source != null) controller.pickVideo(source);
  }

  Widget _buildIdentityStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIntro(
          context,
          title: 'add_product.steps.description'.tr,
          subtitle: 'add_product.view.identity_subtitle'.tr,
        ),
        _buildNameSection(context),
        SizedBox(height: AppDesign.space6),
        _buildCategorySelector(context),
        SizedBox(height: AppDesign.space6),
        _buildSubcategorySelector(context),
        SizedBox(height: AppDesign.space6),
        _buildDescriptionSection(context),
        SizedBox(height: AppDesign.space6),
        EnglishVersionSection(
          nameController: controller.nameEnController,
          descriptionController: controller.descriptionEnController,
          nameHint: 'add_product.view.name_en_hint'.tr,
          descriptionHint: 'add_product.view.description_en_hint'.tr,
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
          title: 'add_product.steps.price_stock'.tr,
          subtitle: 'add_product.view.pricing_subtitle'.tr,
        ),
        _buildPriceSection(context),
        SizedBox(height: AppDesign.space6),
        _buildStockSection(context),
        SizedBox(height: AppDesign.space6),
        _buildWeightSection(context),
        SizedBox(height: AppDesign.space6),
        _buildDeliveryDelaySection(context),
        SizedBox(height: AppDesign.space6),
        _buildFreeDeliverySection(context),
        SizedBox(height: AppDesign.space6),
        _buildDepositSection(context),
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
            title: 'add_product.view.kind_title'.tr,
            subtitle: 'add_product.view.kind_subtitle'.tr,
          ),

          _buildKindCard(
            context,
            selected: !isVariable,
            icon: Icons.inventory_2_outlined,
            title: 'add_product.view.simple_product'.tr,
            subtitle: 'add_product.view.simple_subtitle'.tr,
            example: 'add_product.view.simple_example'.tr,
            onTap: () => controller.setProductKind(variable: false),
          ),
          SizedBox(height: AppDesign.space3),
          _buildKindCard(
            context,
            selected: isVariable,
            icon: Icons.style_outlined,
            title: 'add_product.view.variable_product'.tr,
            subtitle: 'add_product.view.variable_subtitle'.tr,
            example: 'add_product.view.variable_example'.tr,
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
                        'add_product.view.your_variants'.tr,
                        style: context.subtitle1.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.ds.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppDesign.space1),
                      Text(
                        'add_product.view.your_variants_subtitle'.tr,
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
            title: 'add_product.steps.review'.tr,
            subtitle: 'add_product.view.review_subtitle'.tr,
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
                                    ? 'add_product.view.no_name'.tr
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
                                (controller.productImages.length > 1
                                        ? 'add_product.view.photo_count_plural'
                                        : 'add_product.view.photo_count')
                                    .trParams({
                                  'count': '${controller.productImages.length}',
                                }),
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
                  'add_product.view.category'.tr,
                  controller.selectedSubcategory.value ??
                      'add_product.view.not_set_f'.tr,
                  onEdit: () => controller.goToStep(1),
                ),
                _buildReviewRow(
                  context,
                  hasVariants
                      ? 'add_product.view.base_price'.tr
                      : 'add_product.view.price'.tr,
                  price > 0
                      ? controller.formatPrice(price)
                      : 'add_product.view.not_set_m'.tr,
                  onEdit: () => controller.goToStep(2),
                ),
                _buildReviewRow(
                  context,
                  'add_product.view.total_stock'.tr,
                  controller.stockController.text.trim().isEmpty
                      ? '0'
                      : controller.stockController.text.trim(),
                  onEdit: () => controller.goToStep(2),
                ),
                _buildReviewRow(
                  context,
                  'add_product.delivery_delay.title'.tr,
                  controller.deliveryDelay == null
                      ? 'add_product.delivery_delay.auto'.tr
                      : 'product.delivery_delay.range'.trParams({
                          'min': '${controller.deliveryDelay!.min}',
                          'max': '${controller.deliveryDelay!.max}',
                        }),
                  onEdit: () => controller.goToStep(2),
                ),
                _buildReviewRow(
                  context,
                  'add_product.view.type'.tr,
                  controller.isVariableProduct.value
                      ? (combos.length > 1
                              ? 'add_product.view.variable_count_plural'
                              : 'add_product.view.variable_count')
                          .trParams({'count': '${combos.length}'})
                      : 'add_product.view.simple_product'.tr,
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
                      'add_product.view.total_stock_hint'.tr,
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
                          'add_product.view.back'.tr,
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
                                      ? 'add_product.view.save'.tr
                                      : controller.isOffline
                                          // Backend injoignable : la fiche
                                          // part en file, pas en ligne.
                                          ? 'add_product.view.save_offline'.tr
                                          : 'add_product.view.publish'.tr)
                                  : 'add_product.view.continue'.tr,
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
                      isEmpty
                          ? 'add_product.view.add_photos'.tr
                          : 'add_product.view.add_another_photo'.tr,
                      style: context.subtitle2.copyWith(
                        color: AppDesign.accentText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isEmpty) ...[
                      SizedBox(height: AppDesign.space1),
                      Text(
                        'add_product.view.image_required'.tr,
                        style: context.body2.copyWith(color: ds.textSecondary),
                      ),
                      SizedBox(height: AppDesign.space1),
                      Text(
                        'add_product.view.camera_or_gallery'.tr,
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
                    (total > 1
                            ? 'add_product.view.photo_count_plural'
                            : 'add_product.view.photo_count')
                        .trParams({'count': '$total'}),
                    style: context.subtitle2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ds.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'add_product.view.tap_to_choose_main'.tr,
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
                  'add_product.view.main'.tr,
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
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Text(
                  'add_product.view.pinch_to_zoom'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
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
        Text(
          'add_product.view.name_label'.tr,
          style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: context.elementSpacing),
        TextField(
          controller: controller.nameController,
          decoration: InputDecoration(
            hintText: 'add_product.view.name_hint'.tr,
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

  /// Sélecteur de catégorie avec bottom sheet
  Widget _buildCategorySelector(BuildContext context) {
    return Obx(() {
      final category = controller.selectedCategory.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'add_product.view.category_label'.tr,
            style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
          ),
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
                      category ?? 'add_product.view.select_category_hint'.tr,
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
            'add_product.view.subcategory_label'.tr,
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
                      subcategory ??
                          'add_product.view.select_subcategory_hint'.tr,
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
  Future<void> _showImageSourceBottomSheet(BuildContext context) async {
    final source = await showImageSourceSheet(context);
    if (source == ImageSource.camera) {
      controller.takePhoto();
    } else if (source == ImageSource.gallery) {
      controller.pickImages();
    }
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
                            'add_product.view.select_category'.tr,
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
                        hintText: 'add_product.view.search'.tr,
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
                                ? 'add_product.view.subcategories_of'
                                    .trParams({'category': category})
                                : 'add_product.view.select_subcategory'.tr,
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
                        hintText: 'add_product.view.search'.tr,
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
                              ? 'add_product.view.no_subcategory_found'.tr
                              : 'add_product.view.select_category_first'.tr,
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
              controller.isVariableProduct.value
                  ? 'add_product.view.base_price_label'.tr
                  : 'add_product.view.price_label'.tr,
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 .,]')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'add_product.view.price_hint'.tr,
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
              'add_product.view.receive_exact_price'.tr,
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
                  'add_product.view.buyer_price'.trParams({
                    'price': controller.formatInSelectedCurrency(buyer),
                  }),
                  style: context.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeSystem.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'add_product.view.seller_receives'.trParams({
                    'price': controller.formatInSelectedCurrency(seller),
                  }),
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
                            'add_product.view.select_currency'.tr,
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
                        hintText: 'add_product.view.search_currency'.tr,
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
                          'add_product.view.no_currency_found'.tr,
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
        Text(
          'add_product.view.description_label'.tr,
          style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: context.elementSpacing),
        TextField(
          controller: controller.descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'add_product.view.description_hint'.tr,
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
        title: 'add_product.free_delivery.title'.tr,
        subtitle: [
          value
              ? 'add_product.free_delivery.on'.tr
              : 'add_product.free_delivery.off'.tr,
          if (followsShop && shop) 'add_product.free_delivery.shop_setting'.tr,
          if (!followsShop && shop) 'add_product.free_delivery.excluded'.tr,
        ].join(' '),
        value: value,
        onChanged: controller.setFreeDelivery,
      );
    });
  }

  /// Commande avec acompte : le client paie une part du prix à la commande et
  /// le solde après la livraison, une fois la marchandise vérifiée avec ASSO.
  Widget _buildDepositSection(BuildContext context) {
    return Obx(() {
      // Une prestation ne se commande pas sur acompte.
      if (controller.articleType.value == 'service') {
        return const SizedBox.shrink();
      }
      controller.formRevision.value; // réagit à la saisie du % et du prix
      final enabled = controller.depositEnabled.value;
      final price = AddProductController.parsePrice(controller.priceController.text);
      final rate = controller.depositRate;
      final showPreview =
          enabled && controller.depositRateValid && price != null && price > 0;
      final deposit = showPreview ? (price * rate! / 100).roundToDouble() : 0.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FreeDeliveryToggle(
            title: 'add_product.deposit.title'.tr,
            subtitle: 'add_product.deposit.subtitle'.tr,
            value: enabled,
            onChanged: (value) => controller.depositEnabled.value = value,
          ),
          if (enabled) ...[
            SizedBox(height: context.elementSpacing),
            TextField(
              controller: controller.depositRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'add_product.deposit.rate_label'.tr,
                suffixText: '%',
                errorText:
                    controller.depositRateController.text.trim().isNotEmpty &&
                        !controller.depositRateValid
                    ? 'add_product.deposit.rate_error'.tr
                    : null,
              ),
            ),
            if (showPreview) ...[
              SizedBox(height: context.elementSpacing),
              Text(
                'add_product.deposit.preview'.trParams({
                  'deposit': deposit.toStringAsFixed(0),
                  'balance': (price - deposit).toStringAsFixed(0),
                }),
                style: context.caption,
              ),
            ],
            SizedBox(height: context.elementSpacing),
            Text('add_product.deposit.notice'.tr, style: context.caption),
          ],
        ],
      );
    });
  }

  /// Section Poids du produit : poids réel en kg, obligatoire pour un article.
  /// Délai de livraison annoncé au client (jours ouvrables, 1 minimum,
  /// sans maximum). Vide = « Auto » : délai de la catégorie, réglé par ASSO.
  Widget _buildDeliveryDelaySection(BuildContext context) {
    Widget field({
      required String label,
      required TextEditingController textController,
      required ValueChanged<String> onChanged,
    }) {
      return TextField(
        controller: textController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'add_product.delivery_delay.auto'.tr,
          suffixText: 'add_product.delivery_delay.unit'.tr,
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
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'add_product.delivery_delay.title'.tr,
          style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: context.elementSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: field(
                label: 'add_product.delivery_delay.min'.tr,
                textController: controller.deliveryDaysMinController,
                onChanged: controller.setDeliveryDaysMin,
              ),
            ),
            SizedBox(width: context.elementSpacing),
            Expanded(
              child: field(
                label: 'add_product.delivery_delay.max'.tr,
                textController: controller.deliveryDaysMaxController,
                onChanged: controller.setDeliveryDaysMax,
              ),
            ),
          ],
        ),
        SizedBox(height: AppDesign.space2),
        Text(
          'add_product.delivery_delay.helper'.tr,
          style: context.caption.copyWith(color: context.secondaryTextColor),
        ),
      ],
    );
  }

  Widget _buildWeightSection(BuildContext context) {
    return Obx(() {
      controller.customWeightValue.value; // réagit à la saisie
      final isArticle = controller.articleType.value == 'article';
      final hasText = controller.weightKgController.text.trim().isNotEmpty;
      final error = hasText ? controller.weightError : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArticle
                ? 'add_product.view.weight_label_required'.tr
                : 'add_product.view.weight_label'.tr,
            style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: context.elementSpacing),
          TextField(
            controller: controller.weightKgController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              hintText: 'add_product.view.weight_hint'.tr,
              helperText: 'add_product.view.weight_helper'.tr,
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
                          'add_product.variants.title'.tr,
                          style: context.subtitle1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          combos.isEmpty
                              ? 'add_product.view.variants_optional'.tr
                              : 'add_product.view.variants_summary'.trParams({
                                  'count': '${combos.length}',
                                  'stock': '${editor.totalStock}',
                                }),
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
          'add_product.view.stock_label'.tr,
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              helperText: fromVariants
                  ? 'add_product.view.stock_auto'.tr
                  : null,
              hintText: 'add_product.view.stock_hint'.tr,
              filled: true,
              fillColor: context.inputFieldColor,
              prefixIcon: const Icon(Icons.inventory_outlined),
              suffixText: 'add_product.view.units'.tr,
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
                'add_product.storage.title'.tr,
                style: context.subtitle1.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: controller.addNewStorage,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: Text('add_product.variants.add'.tr),
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
                      'add_product.storage.no_package'.tr,
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
                        'add_product.storage.active'.tr,
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
                        'add_product.storage.used'.tr,
                        style: context.body2.copyWith(color: ds.textSecondary),
                      ),
                    ),
                    Text(
                      'add_product.storage.gb'
                          .trParams({'value': used.toStringAsFixed(1)}),
                      style: context.body2.copyWith(
                        color: ds.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'add_product.storage.of_total'
                          .trParams({'value': total.toStringAsFixed(0)}),
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
                  'add_product.storage.usage'.trParams({
                    'percent': percentageUsed.toStringAsFixed(0),
                    'available': available.toStringAsFixed(1),
                  }),
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
