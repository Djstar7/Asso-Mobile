import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';

/// Écran d'attente bloquant affiché pendant la déconnexion.
///
/// Modal plutôt qu'un état du bouton : `AuthService.logout()` supprime le
/// `ProfileController` en cours de route, et une vue qui l'observerait se
/// reconstruirait sans lui. Le dialogue ne dépend d'aucun controller et
/// disparaît avec le reste de la pile lors de `Get.offAllNamed`.
class LogoutLoadingDialog extends StatelessWidget {
  const LogoutLoadingDialog({super.key});

  static void show() {
    Get.dialog(const LogoutLoadingDialog(), barrierDismissible: false);
  }

  @override
  Widget build(BuildContext context) {
    // Retour Android neutralisé : quitter l'attente laisserait l'utilisateur
    // sur un profil dont la session est déjà en train d'être effacée.
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: context.ds.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesign.space6,
            vertical: AppDesign.space8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppDesign.accent),
                ),
              ),
              const SizedBox(height: AppDesign.space5),
              Text(
                'Déconnexion en cours…',
                style: context.textStyle(
                  FontSizeType.body1,
                  fontWeight: FontWeight.w600,
                  color: context.ds.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesign.space1),
              Text(
                'Veuillez patienter',
                style: context.textStyle(
                  FontSizeType.body2,
                  color: context.ds.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
