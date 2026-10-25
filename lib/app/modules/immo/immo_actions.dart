import 'package:asso/app/core/utils/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/auth_guard.dart';
import '../../core/utils/string_utils.dart';
import '../../data/models/real_estate_models.dart';
import '../../data/providers/real_estate_service.dart';
import 'controllers/immo_home_controller.dart';
import 'immo_nav.dart';

/// Actions partagées par les pages de la rubrique.
class ImmoActions {
  const ImmoActions._();

  /// « Contacter ASSO » : la conversation s'ouvre dans la rubrique, avec
  /// l'annonce en tête, et la barre du bas reste visible.
  static void contactAsso(BuildContext context, RealEstateListing listing) {
    AuthGuard.requireAuth(
      context,
      featureName: 'immo.feature.contact'.tr,
      onAuthenticated: () async {
        final res = await RealEstateService.contact(listing.id);
        final conversation = res.data?['conversation'];
        if (!res.success || conversation is! Map) {
          AppFeedback.show('immo.contact.error_title'.tr, res.message, snackPosition: SnackPosition.BOTTOM);
          return;
        }
        final name = (conversation['other_user'] as Map?)?['name']?.toString() ?? 'immo.contact.asso'.tr;

        ImmoNav.push(ImmoNav.chat, arguments: {
          'id': conversation['id'].toString(),
          'name': name,
          'avatar': StringUtils.getInitials(name),
          'isOnline': false,
          'is_support': true,
          'default_message': 'immo.contact.default_message'.trParams({
            'title': listing.title,
            'reference': listing.reference,
          }),
        });
      },
    );
  }

  /// Favori depuis la fiche : la carte de la liste suit.
  static Future<bool> toggleFavorite(BuildContext context, RealEstateListing listing) async {
    if (!AuthGuard.isAuthenticated) {
      AuthGuard.requireAuth(context, featureName: 'immo.feature.favorites'.tr, onAuthenticated: () {});
      return listing.isFavorite;
    }
    final next = !listing.isFavorite;
    final ok = await RealEstateService.setFavorite(listing.id, next);
    if (!ok) return listing.isFavorite;

    listing.isFavorite = next;
    if (Get.isRegistered<ImmoHomeController>()) {
      Get.find<ImmoHomeController>().syncFavorite(listing.id, next);
    }

    return next;
  }
}
