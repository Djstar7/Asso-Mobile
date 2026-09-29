import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/product_scan_controller.dart';

/// Viseur plein écran : code-barres lu en direct, capture de l'étiquette ou
/// import depuis la galerie.
class ProductScanView extends GetView<ProductScanController> {
  const ProductScanView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final stage = controller.stage.value;
        final camera = controller.camera.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (camera != null && camera.value.isInitialized)
              _CameraFill(controller: camera),
            if (stage == ScanStage.scanning) const _Viewfinder(),
            if (stage == ScanStage.unavailable) _buildUnavailable(context),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  const Spacer(),
                  if (stage == ScanStage.scanning) _buildHint(context),
                  if (stage == ScanStage.scanning) _buildControls(context),
                ],
              ),
            ),
            if (controller.isBusy ||
                (controller.galleryOnly && stage == ScanStage.starting))
              _buildBusyOverlay(context, stage),
          ],
        );
      }),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space2,
        vertical: AppDesign.space2,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: controller.isBusy ? null : Get.back,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(
              'Remplir automatiquement',
              style: context.subtitle1.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(BuildContext context) {
    final barcode = controller.detectedBarcode.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesign.space6),
      child: Column(
        children: [
          if (barcode != null) ...[
            AppBadge(
              label: 'Code-barres lu : $barcode',
              tone: AppBadgeTone.success,
              icon: Icons.check_circle_rounded,
            ),
            const SizedBox(height: AppDesign.space3),
          ],
          Text(
            barcode == null
                ? 'Visez le code-barres, puis photographiez l\'étiquette avec le nom du produit.'
                : 'Photographiez maintenant l\'étiquette avec le nom du produit.',
            textAlign: TextAlign.center,
            style: context.body2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppDesign.space6),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesign.space6,
        0,
        AppDesign.space6,
        AppDesign.space8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundAction(
            icon: Icons.photo_library_outlined,
            label: 'Galerie',
            onTap: controller.pickFromGallery,
          ),
          Semantics(
            button: true,
            label: 'Capturer l\'étiquette',
            child: GestureDetector(
              onTap: controller.capture,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                padding: const EdgeInsets.all(AppDesign.space1),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Équilibre visuel du déclencheur centré.
          const SizedBox(width: 64),
        ],
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesign.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: AppDesign.space4),
            Text(
              controller.unavailableMessage.value,
              textAlign: TextAlign.center,
              style: context.body1.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppDesign.space6),
            AppButton(
              label: 'Importer depuis la galerie',
              icon: Icons.photo_library_outlined,
              onPressed: controller.pickFromGallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusyOverlay(BuildContext context, ScanStage stage) {
    final message = switch (stage) {
      ScanStage.searching => 'Recherche du produit…',
      ScanStage.analysing => 'Lecture de l\'étiquette…',
      _ => 'Ouverture de la galerie…',
    };
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppDesign.accent),
            const SizedBox(height: AppDesign.space4),
            Text(
              message,
              style: context.subtitle1.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu caméra qui remplit l'écran sans déformation (recadré).
class _CameraFill extends StatelessWidget {
  const _CameraFill({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        // previewSize est donné en paysage ; l'écran est en portrait.
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// Cadre de visée, vert dès que le code-barres est lu.
class _Viewfinder extends GetView<ProductScanController> {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Obx(() {
          final found = controller.detectedBarcode.value != null;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: MediaQuery.sizeOf(context).width * 0.78,
            height: MediaQuery.sizeOf(context).width * 0.62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesign.radiusLg),
              border: Border.all(
                color: found ? AppDesign.success : Colors.white,
                width: found ? 4 : 2,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white24,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: label,
              onPressed: onTap,
              icon: Icon(icon, color: Colors.white),
            ),
          ),
          const SizedBox(height: AppDesign.space1),
          Text(
            label,
            style: context.caption.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
