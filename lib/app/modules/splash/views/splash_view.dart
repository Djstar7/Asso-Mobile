import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/splash_controller.dart';

/// Écran d'ouverture.
///
/// Il se contente d'afficher l'identité de la marque le temps que
/// l'application décide de sa première route. Les cercles décoratifs et le
/// dégradé d'origine ont été retirés : un écran de lancement gagne à être
/// calme, et ces formes se comportaient mal sur les petits écrans (tailles
/// fixes en pixels, indépendantes de la surface réelle).
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    // Le contrôleur est instancié par le binding ; on le touche ici pour
    // garantir son initialisation avant le premier rendu.
    controller;

    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    // Le logo occupe une fraction de l'écran, borné pour rester raisonnable
    // du petit téléphone à la tablette.
    final logoSize = (shortestSide * 0.28).clamp(96.0, 168.0);

    return Scaffold(
      backgroundColor: context.ds.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                _FadeIn(
                  child: Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      color: context.ds.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.ds.border),
                    ),
                    padding: EdgeInsets.all(logoSize * 0.16),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: AppDesign.space6),
                _FadeIn(
                  delay: const Duration(milliseconds: 150),
                  child: Column(
                    children: [
                      Text(
                        'ASSO',
                        style: context
                            .textStyle(
                              FontSizeType.h3,
                              fontWeight: FontWeight.w700,
                              color: context.ds.textPrimary,
                            )
                            .copyWith(letterSpacing: 4),
                      ),
                      SizedBox(height: AppDesign.space2),
                      Text(
                        'Votre marketplace de confiance',
                        textAlign: TextAlign.center,
                        style: context.textStyle(
                          FontSizeType.body2,
                          color: context.ds.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                _FadeIn(
                  delay: const Duration(milliseconds: 300),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppDesign.accent),
                      backgroundColor: context.ds.border,
                    ),
                  ),
                ),
                SizedBox(height: AppDesign.space10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Apparition en fondu, avec un léger décalage vers le haut.
///
/// `delay` permet d'échelonner l'entrée des blocs pour que l'écran se
/// compose au lieu d'apparaître d'un coup.
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      // Laisse passer la première frame pour que l'animation soit visible.
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    } else {
      Future<void>.delayed(widget.delay, _show);
    }
  }

  void _show() {
    if (mounted) setState(() => _visible = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.08),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
