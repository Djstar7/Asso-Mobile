import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_design.dart';
import '../utils/app_navigation.dart';
import '../utils/app_theme_system.dart';
import 'app_ui.dart';

/// Feuille modale standard : poignée, en-tête avec sa sortie, contenu qui
/// défile, action principale toujours visible.
///
/// Trois défauts revenaient d'une feuille à l'autre :
/// - la feuille montait jusque sous la barre d'état et couvrait tout
///   l'écran, sans autre sortie qu'un glissement vers le bas que personne
///   ne devine ;
/// - le clavier était compté deux fois (la route GetX remonte déjà la
///   feuille), ce qui laissait un grand vide et écrasait le formulaire ;
/// - le bouton de validation, au bout du contenu, passait sous le clavier.
///
/// Ici la hauteur s'arrête sous la barre d'état, la croix est toujours là,
/// et [footer] reste épinglé juste au-dessus du clavier.
///
/// Toujours ouvrir avec [AppSheet.show] : c'est la route qui place la feuille
/// au-dessus du clavier, la feuille elle-même ne doit pas le refaire.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.footer,
    this.onBack,
    this.showClose = true,
    this.onClose,
    this.color,
    this.bodyPadding,
    this.scrollController,
    this.scrollable = true,
  });

  /// Contenu de la feuille.
  final Widget child;

  final String? title;

  /// Précision sous le titre (produit concerné, montant…).
  final String? subtitle;

  /// Action principale, épinglée sous le contenu. Elle reste visible quand
  /// le clavier est ouvert ou que le contenu est long.
  final Widget? footer;

  /// Retour à l'étape précédente d'un parcours en plusieurs feuilles.
  /// Absent, aucune flèche n'est affichée.
  final VoidCallback? onBack;

  /// Croix de fermeture en haut à droite.
  final bool showClose;

  /// Fermeture personnalisée. Absente, la feuille se referme sans résultat.
  final VoidCallback? onClose;

  /// Fond de la feuille. Par défaut la surface ; le fond d'écran convient
  /// mieux quand le contenu est fait de cartes.
  final Color? color;

  final EdgeInsetsGeometry? bodyPadding;

  final ScrollController? scrollController;

  /// false quand l'enfant gère lui-même son défilement (liste longue) : il
  /// doit alors pouvoir se contracter, la feuille lui donne la place restante.
  final bool scrollable;

  /// Ouvre [sheet] (en principe une [AppSheet]) au-dessus de l'écran courant.
  static Future<T?> show<T>(
    Widget sheet, {
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    // Le clavier de l'écran d'en dessous masquerait la feuille dès son
    // ouverture.
    AppNavigation.dismissKeyboard();
    return Get.bottomSheet<T>(
      sheet,
      isScrollControlled: true,
      // La feuille dessine elle-même son fond et ses coins.
      backgroundColor: Colors.transparent,
      // Garde la hauteur de la barre d'état lisible dans la feuille, pour
      // l'arrêter juste en dessous.
      ignoreSafeArea: false,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final hasHeader = title != null || onBack != null || showClose;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Une bande d'écran reste visible au-dessus de la feuille : on voit
        // d'où l'on vient et qu'elle se referme.
        final maxHeight = math.max(
          0.0,
          constraints.maxHeight - topInset - AppDesign.space6,
        );

        final padding = bodyPadding ??
            EdgeInsets.fromLTRB(
              context.ds.gutter,
              hasHeader ? 0 : AppDesign.space2,
              context.ds.gutter,
              AppDesign.space4,
            );

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: color ?? context.ds.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDesign.radiusXl),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                if (hasHeader)
                  _SheetHeader(
                    title: title,
                    subtitle: subtitle,
                    onBack: onBack,
                    showClose: showClose,
                    onClose: onClose,
                  ),
                Flexible(
                  child: scrollable
                      ? SingleChildScrollView(
                          controller: scrollController,
                          // Faire défiler pour relire ne doit pas obliger à
                          // retoucher le champ : le clavier suit le doigt.
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: padding,
                          child: child,
                        )
                      : Padding(padding: padding, child: child),
                ),
                if (footer != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.ds.border),
                      ),
                    ),
                    // `SafeArea` suit la barre système quand le clavier est
                    // fermé, et s'efface quand il est ouvert.
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.ds.gutter,
                          AppDesign.space3,
                          context.ds.gutter,
                          AppDesign.space3,
                        ),
                        child: footer,
                      ),
                    ),
                  )
                else
                  const SafeArea(top: false, child: SizedBox.shrink()),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Poignée : signale qu'on peut aussi glisser la feuille vers le bas.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(
          top: AppDesign.space2,
          bottom: AppDesign.space1,
        ),
        decoration: BoxDecoration(
          color: context.ds.borderStrong,
          borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.showClose,
    required this.onClose,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showClose;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        onBack != null ? AppDesign.space1 : context.ds.gutter,
        0,
        AppDesign.space1,
        AppDesign.space2,
      ),
      child: Row(
        children: [
          if (onBack != null)
            AppIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              size: 20,
              tooltip: 'common.back'.tr,
              onPressed: onBack,
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.h5,
                      fontWeight: FontWeight.w700,
                      color: context.ds.textPrimary,
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: context.ds.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showClose)
            AppIconButton(
              icon: Icons.close_rounded,
              tooltip: 'common.close'.tr,
              onPressed: onClose ?? () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }
}
