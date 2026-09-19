import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';

/// Ossature commune aux écrans Connexion et Inscription.
///
/// Un bandeau de marque porte une animation d'accueil ; le formulaire repose
/// sur une feuille claire qui remonte par-dessus. Les deux écrans partageant
/// cette ossature, passer de l'un à l'autre ne fait plus sauter la mise en
/// page.
///
/// Le bandeau se réduit dès que le clavier s'ouvre : l'animation est un
/// accueil, elle ne doit pas disputer sa place au champ en cours de saisie.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.animationAsset,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onSkip,
    this.skipLabel = 'Passer',
  });

  /// Animation Lottie affichée dans le bandeau.
  final String animationAsset;

  /// Titre de l'écran, posé en haut de la feuille.
  final String title;

  /// Phrase d'explication sous le titre.
  final String subtitle;

  /// Contenu du formulaire.
  final List<Widget> children;

  /// Entrée sans compte. Absente, le bouton n'est pas affiché.
  final VoidCallback? onSkip;

  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Le bandeau prend une part de la hauteur plutôt qu'une valeur fixe, pour
    // tenir aussi bien sur un petit téléphone que sur une tablette. Replié,
    // il ne garde que de quoi porter le bouton « Passer ».
    final bannerHeight = keyboardOpen
        ? 0.0
        : (screenHeight * 0.30).clamp(180.0, 300.0);

    return Scaffold(
      backgroundColor: AppDesign.accentSubtle,
      body: Stack(
        children: [
          Column(
            children: [
              _Banner(height: bannerHeight, animationAsset: animationAsset),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.ds.canvas,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppDesign.radiusXl),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        context.ds.gutter,
                        AppDesign.space6,
                        context.ds.gutter,
                        AppDesign.space6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: context.textStyle(
                              FontSizeType.h3,
                              fontWeight: FontWeight.w700,
                              color: context.ds.textPrimary,
                            ),
                          ),
                          SizedBox(height: AppDesign.space2),
                          Text(
                            subtitle,
                            style: context.textStyle(
                              FontSizeType.body2,
                              color: context.ds.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: AppDesign.space6),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Posé par-dessus, et non dans le bandeau : celui-ci se replie
          // quand le clavier s'ouvre, et emporterait la sortie avec lui.
          if (onSkip != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + AppDesign.space2,
              right: context.ds.gutter,
              child: _SkipButton(label: skipLabel, onPressed: onSkip!),
            ),
        ],
      ),
    );
  }
}

/// Bandeau de marque, réduit à l'animation d'accueil.
class _Banner extends StatelessWidget {
  const _Banner({required this.height, required this.animationAsset});

  final double height;
  final String animationAsset;

  @override
  Widget build(BuildContext context) {
    final collapsed = height == 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: collapsed ? 0 : height,
      // Le bandeau descend jusque sous la barre d'état : l'animation est
      // coupée par l'encoche si on ne réserve pas cette marge.
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: collapsed
          ? const SizedBox.shrink()
          : ClipRect(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.ds.gutter,
                  vertical: AppDesign.space4,
                ),
                child: Lottie.asset(
                  animationAsset,
                  fit: BoxFit.contain,
                  // Une animation d'accueil qui boucle indéfiniment capte le
                  // regard pendant toute la saisie.
                  repeat: false,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
    );
  }
}

/// Sortie vers la visite sans compte.
///
/// Posée sur le bandeau plutôt qu'en bas de page : elle doit rester trouvable
/// sans faire défiler, mais discrète devant l'action principale.
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ds.canvas.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesign.space3,
            vertical: AppDesign.space2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: FontWeight.w600,
                  color: context.ds.textSecondary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: context.ds.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Séparateur « ou » entre l'action principale et les autres entrées.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'ou'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(height: 1, thickness: 1, color: context.ds.border),
    );

    return Row(
      children: [
        line,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDesign.space3),
          child: Text(
            label,
            style: context.textStyle(
              FontSizeType.caption,
              color: context.ds.textTertiary,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Bascule entre Connexion et Inscription, en bas de formulaire.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: Text.rich(
          TextSpan(
            style: context.textStyle(
              FontSizeType.body2,
              color: context.ds.textSecondary,
            ),
            children: [
              TextSpan(text: '$question '),
              TextSpan(
                text: action,
                style: context.textStyle(
                  FontSizeType.body2,
                  fontWeight: FontWeight.w700,
                  color: AppDesign.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
