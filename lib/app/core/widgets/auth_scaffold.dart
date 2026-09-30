import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import 'app_ui.dart';

/// Ossature commune aux écrans Connexion et Inscription.
///
/// Un bandeau de marque porte une animation d'accueil ; le formulaire repose
/// sur une feuille claire qui remonte par-dessus. Les deux écrans partageant
/// cette ossature, passer de l'un à l'autre ne fait plus sauter la mise en
/// page.
///
/// Le bandeau se réduit dès que le clavier s'ouvre : l'animation est un
/// accueil, elle ne doit pas disputer sa place au champ en cours de saisie.
/// Hauteur que le bandeau conserve pendant la saisie.
///
/// Assez pour porter la sortie « Passer » et laisser respirer les coins
/// arrondis de la feuille sous la barre d'état.
const double _collapsedBannerHeight = 44;

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.animationAsset,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onSkip,
    this.skipLabel,
    this.bannerRatio = 0.30,
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

  final String? skipLabel;

  /// Part de la hauteur d'écran occupée par le bandeau.
  ///
  /// Réglable par écran : un formulaire long a besoin d'un bandeau plus
  /// court, sinon son action principale démarre hors de l'écran.
  final double bannerRatio;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topInset = MediaQuery.paddingOf(context).top;

    // Le bandeau prend une part de la hauteur plutôt qu'une valeur fixe, pour
    // tenir aussi bien sur un petit téléphone que sur une tablette.
    //
    // Clavier ouvert, il cède l'animation mais garde une bande : repliée à
    // zéro, la feuille remontait jusque sous la barre d'état et l'écran
    // paraissait sauter d'un cran, coins arrondis rognés et titre collé à
    // l'heure. La bande conservée porte la sortie « Passer » et fait la
    // marge que la barre d'état réclame.
    final bannerHeight = keyboardOpen
        ? _collapsedBannerHeight
        : (screenHeight * bannerRatio).clamp(120.0, 300.0);

    // Ouvert par-dessus un écran (action réservée aux membres depuis une
    // fiche produit…), l'écran propose d'y revenir. « Passer » ramène à
    // l'accueil et faisait perdre ce que l'on était en train de faire.
    final canGoBack = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: AppDesign.accentSubtle,
      body: Column(
        children: [
          // L'animation et la sortie « Passer » vivent dans le même bloc, qui
          // se replie d'un seul tenant. Posée à part, par-dessus la pile, la
          // sortie restait à sa place quand le bandeau se repliait et venait
          // barrer le sous-titre.
          _Banner(
            height: bannerHeight,
            topInset: topInset,
            animationAsset: animationAsset,
            back: canGoBack ? const AppBackButton() : null,
            skip: onSkip == null
                ? null
                : _SkipButton(label: skipLabel ?? 'core.auth.skip'.tr, onPressed: onSkip!),
          ),
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
                  // Le clavier ouvert, on suit le doigt sans fermer la
                  // saisie : refermer le clavier au moindre défilement
                  // obligeait à retoucher le champ pour continuer.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
    );
  }
}

/// Bandeau de marque : l'animation d'accueil et la sortie « Passer ».
///
/// Sa hauteur est pilotée par [AuthScaffold] : pleine au repos, réduite à
/// [_collapsedBannerHeight] pendant la saisie. Il ne descend jamais plus bas,
/// pour que la feuille garde sa marge sous la barre d'état.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.height,
    required this.topInset,
    required this.animationAsset,
    this.back,
    this.skip,
  });

  final double height;

  /// Hauteur de la barre d'état, que le bandeau couvre lui-même.
  final double topInset;

  final String animationAsset;

  /// Retour à l'écran précédent, en haut à gauche. Absent, rien n'est affiché.
  final Widget? back;

  /// Sortie sans compte, posée en haut à droite. Absente, rien n'est affiché.
  final Widget? skip;

  @override
  Widget build(BuildContext context) {
    // Sous ce seuil il ne reste plus de quoi dessiner l'animation sans la
    // déformer : elle cède la place et seule la sortie demeure.
    final showAnimation = height > _collapsedBannerHeight + 24;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: topInset + height,
      // Le bandeau descend jusque sous la barre d'état : l'animation est
      // coupée par l'encoche si on ne réserve pas cette marge.
      padding: EdgeInsets.only(top: topInset),
      child: ClipRect(
        child: Stack(
          children: [
            if (showAnimation)
              Positioned.fill(
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
            // Aligné sur « Passer » : les deux sorties restent à portée
            // quand le bandeau se replie pendant la saisie.
            if (back != null)
              Positioned(top: 0, left: AppDesign.space1, child: back!),
            if (skip != null)
              Positioned(
                top: AppDesign.space2,
                right: context.ds.gutter,
                child: skip!,
              ),
          ],
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
