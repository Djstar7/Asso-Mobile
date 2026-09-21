import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';

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

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      upgrader: Upgrader(
        durationUntilAlertAgain: _rappel,
        messages: UpgraderMessages(code: 'fr'),
        // En débogage la version installée ne correspond pas à celle publiée :
        // sans cela, la fenêtre s'ouvrirait à chaque démarrage.
        debugDisplayAlways: false,
      ),
      // « Ignorer » masquerait la version à vie, y compris une mise à jour
      // importante : seul « plus tard » est proposé.
      showIgnore: false,
      showLater: true,
      showReleaseNotes: true,
      child: child,
    );
  }
}
