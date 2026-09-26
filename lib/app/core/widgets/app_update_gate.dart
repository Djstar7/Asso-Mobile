import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:upgrader/upgrader.dart';

import '../../routes/app_pages.dart';

/// Prévient l'utilisateur qu'une version plus récente est publiée sur les
/// stores, et l'y renvoie pour l'installer.
///
/// Le correctif Dart passe par Shorebird et n'a pas besoin de ce passage : ce
/// garde-fou ne sert qu'aux vraies releases (dépendance ajoutée, code natif,
/// montée de version), les seules que Shorebird ne peut pas pousser.
///
/// La version publiée est lue directement sur l'App Store et le Play Store à
/// partir de l'identifiant de l'application, sans réglage côté serveur.
class AppUpdateGate extends StatelessWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  /// Délai avant de reproposer la mise à jour à qui a répondu « plus tard ».
  static const _rappel = Duration(days: 3);

  /// Une seule instance pour toute la vie de l'application.
  ///
  /// Ce widget est reconstruit avec l'application (thème, langue, retour au
  /// premier plan…) : en recréer une à chaque fois laissait derrière chaque
  /// reconstruction un vérificateur et son flux jamais fermés.
  static final Upgrader _upgrader = _AppUpgrader(
    durationUntilAlertAgain: _rappel,
    messages: UpgraderMessages(code: 'fr'),
    // En débogage la version installée ne correspond pas à celle publiée :
    // sans cela, la fenêtre s'ouvrirait à chaque démarrage.
    debugDisplayAlways: false,
  );

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      upgrader: _upgrader,
      // Ce widget enveloppe le navigateur, il n'est pas dessous : sans sa
      // clé, la fenêtre cherchait un Navigator au-dessus d'elle et échouait.
      navigatorKey: Get.key,
      // « Ignorer » masquerait la version à vie, y compris une mise à jour
      // importante : seul « plus tard » est proposé.
      showIgnore: false,
      showLater: true,
      showReleaseNotes: true,
      child: child,
    );
  }
}

/// Vérificateur qui se tait tant que l'écran de démarrage est affiché.
///
/// Le démarrage se termine par `Get.offAllNamed`, qui emporte toute la pile,
/// fenêtre de mise à jour comprise : ouverte sur le splash, elle disparaissait
/// d'elle-même. Elle sera proposée au prochain retour au premier plan.
class _AppUpgrader extends Upgrader {
  _AppUpgrader({
    super.durationUntilAlertAgain,
    super.messages,
    super.debugDisplayAlways,
  });

  @override
  bool shouldDisplayUpgrade() {
    final route = Get.currentRoute;
    if (route.isEmpty || route == '/' || route == Routes.SPLASH) return false;
    return super.shouldDisplayUpgrade();
  }
}
