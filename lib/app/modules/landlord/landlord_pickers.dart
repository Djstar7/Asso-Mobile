import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/image_source_sheet.dart';

/// Choix d'une photo (appareil ou galerie) et d'une vidéo, partagés par la
/// vérification du bailleur et la visite pièce par pièce.
class LandlordPickers {
  const LandlordPickers._();

  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> photo(BuildContext context) async {
    final source = await showImageSourceSheet(context);
    if (source == null) return null;

    return _picker.pickImage(source: source, imageQuality: 82, maxWidth: 2200);
  }

  static Future<List<XFile>> photos() => _picker.pickMultiImage(imageQuality: 82, maxWidth: 2200, limit: 12);

  static Future<XFile?> video(BuildContext context) async {
    final source = await showImageSourceSheet(
      context,
      title: 'core.video_source.add_video'.tr,
      cameraSubtitle: 'core.video_source.record'.tr,
      gallerySubtitle: 'core.video_source.choose_existing'.tr,
    );
    if (source == null) return null;

    return _picker.pickVideo(source: source, maxDuration: const Duration(minutes: 2));
  }
}
