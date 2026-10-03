import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers/storage_service.dart';
import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import '../utils/media_helper.dart';
import '../utils/media_url.dart';
import 'app_network_image.dart';

/// Pastille d'identité de l'utilisateur connecté.
///
/// Une seule source : l'utilisateur en cache. Dès qu'un profil est
/// enregistré (complétion du profil, passage vendeur, rafraîchissement),
/// toutes les pastilles de l'application — accueil, compte, paramètres,
/// composeur — affichent la nouvelle photo sans recharger leur écran.
///
/// Sans photo, la pastille montre les initiales ; hors session, une
/// silhouette. [localImage] prévisualise une photo choisie mais pas encore
/// envoyée.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 48, this.localImage});

  final double size;
  final XFile? localImage;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Lu pour s'abonner : le cache lui-même n'est pas réactif.
      StorageService.userRevision.value;
      final user = StorageService.getUser();
      final avatar = user?.avatar?.trim() ?? '';
      final fallback = _Fallback(
        size: size,
        initials: _initials('${user?.firstName ?? ''} ${user?.lastName ?? ''}'),
      );

      Widget child;
      if (localImage != null) {
        child = MediaHelper.buildImagePreview(
          localImage!,
          width: size,
          height: size,
        );
      } else if (avatar.isNotEmpty) {
        child = AppNetworkImage(
          url: resolveMediaUrl(avatar),
          decodeSize: Size.square(size),
          width: size,
          height: size,
          placeholder: (_) => fallback,
          errorBuilder: (_) => fallback,
        );
      } else {
        child = fallback;
      }

      return SizedBox.square(dimension: size, child: ClipOval(child: child));
    });
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.size, required this.initials});

  final double size;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppDesign.accentSubtle,
      child: initials.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: size * 0.5,
              color: AppDesign.accentText,
            )
          : Text(
              initials,
              style: context.textStyle(
                size >= 56 ? FontSizeType.h5 : FontSizeType.caption,
                fontWeight: FontWeight.w700,
                color: AppDesign.accentText,
              ),
            ),
    );
  }
}
