import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';

/// Déplacements communs à toute l'application.
///
/// Le retour passe par le même chemin que le bouton système (`maybePop`) :
/// une garde de sortie posée sur un écran — brouillon non enregistré,
/// paiement en attente — s'applique ainsi aux deux gestes, sans être
/// recodée dans chaque bouton.
class AppNavigation {
  const AppNavigation._();

  /// Revient à l'écran précédent.
  ///
  /// Sans écran précédent (ouverture depuis un lien partagé, une
  /// notification, ou après un `offAllNamed`), on ramène à l'accueil : un
  /// retour qui ne fait rien laisse l'utilisateur sans issue, et l'iPhone
  /// n'a aucun bouton système pour s'en sortir.
  static Future<void> back(BuildContext context) async {
    dismissKeyboard();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
      return;
    }
    Get.offAllNamed(Routes.HOME);
  }

  /// Ferme la route du dessus (feuille, dialogue, page) en renvoyant
  /// [result].
  ///
  /// À préférer à `Get.back()` dans un parcours : quand un snackbar est
  /// affiché, `Get.back()` se contente de le fermer et laisse la route en
  /// place. Après un « Stock limité » ou un « Solde insuffisant », le bouton
  /// de validation ne refermait donc plus rien et l'utilisateur restait
  /// bloqué.
  static void pop<T>([T? result]) {
    final navigator = Get.key.currentState;
    if (navigator != null && navigator.canPop()) navigator.pop<T>(result);
  }

  /// Ferme la route qui contient [context] en renvoyant [result], à la fin
  /// d'une attente (enregistrement, paiement…).
  ///
  /// Referme d'abord les feuilles et dialogues ouverts par-dessus : un
  /// simple pop leur renvoyait le résultat, d'un type qu'ils n'attendent
  /// pas. Et ne fait rien si la route est déjà en train de se fermer (retour
  /// pressé pendant l'attente) : le pop visait alors l'écran en dessous.
  static void closeRoute<T>(BuildContext context, [T? result]) {
    if (!context.mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r == route || r.isFirst);
    if (route.isCurrent) navigator.pop<T>(result);
  }

  /// Vrai quand l'écran est affiché comme onglet de l'accueil plutôt que
  /// poussé comme page à part. Il n'a alors pas de retour à proposer : la
  /// barre du bas fait office de navigation.
  static bool isHomeTab(BuildContext context) =>
      ModalRoute.of(context)?.settings.name == Routes.HOME;

  /// Attend que l'application ait quitté l'écran de démarrage.
  ///
  /// Une notification touchée ou un lien ouvert à froid arrive pendant le
  /// splash, qui se termine par `Get.offAllNamed` : l'écran poussé trop tôt
  /// était aussitôt emporté, ou poussé sur un navigateur pas encore monté.
  /// Borné à [timeout] ; renvoie faux s'il expire.
  static Future<bool> whenAppReady({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!isAppReady) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return true;
  }

  /// Vrai quand le navigateur est monté et que le splash est passé.
  static bool get isAppReady {
    if (Get.key.currentState == null) return false;
    final route = Get.currentRoute;
    return route.isNotEmpty && route != Routes.SPLASH;
  }

  /// Referme le clavier sans rien valider.
  static void dismissKeyboard() =>
      FocusManager.instance.primaryFocus?.unfocus();
}
