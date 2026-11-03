import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/app_config_controller.dart';
import '../values/constants.dart';

/// Partage des liens publics d'un produit ou d'une boutique.
class ShareLinks {
  const ShareLinks._();

  /// Les boutons n'apparaissent qu'une fois activés depuis le back-office.
  static bool get enabled =>
      Get.isRegistered<AppConfigController>() &&
      Get.find<AppConfigController>().shareLinksEnabled;

  /// Rectangle d'ancrage réclamé par iPad : sans lui, iOS refuse d'afficher la
  /// feuille de partage.
  static Rect? originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  /// Message d'un produit : le nom d'abord, un lien nu n'apprend rien dans une
  /// conversation tant qu'on ne l'a pas ouvert.
  static Future<void> shareProduct({
    required Object id,
    required String name,
    Rect? origin,
  }) => _share(AppConstants.productUrl(id), name, origin);

  static Future<void> shareShop({
    required Object id,
    required String name,
    Rect? origin,
  }) => _share(AppConstants.shopUrl(id), name, origin);

  static Future<void> _share(String url, String title, Rect? origin) {
    final name = title.trim();
    return Share.share(
      name.isEmpty ? url : '$name\n$url',
      subject: name.isEmpty ? null : name,
      sharePositionOrigin: origin,
    );
  }
}
