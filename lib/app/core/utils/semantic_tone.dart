import 'package:flutter/material.dart';

import 'app_design.dart';
import 'app_theme_system.dart';

/// Couleurs d'un ton sémantique (info, avertissement, succès, accent) :
/// fond pâle + texte foncé en clair, fond translucide + texte éclairci en
/// sombre. Un texte n'est jamais posé sur un fond de la même teinte pleine.
class ToneColors {
  final Color background;
  final Color border;
  final Color foreground;

  const ToneColors._(this.background, this.border, this.foreground);

  factory ToneColors.of(
    BuildContext context, {
    required Color solid,
    required Color subtle,
    required Color text,
  }) {
    if (AppThemeSystem.isDarkMode(context)) {
      return ToneColors._(
        solid.withValues(alpha: 0.16),
        solid.withValues(alpha: 0.35),
        Color.lerp(solid, Colors.white, 0.45)!,
      );
    }
    return ToneColors._(subtle, solid.withValues(alpha: 0.22), text);
  }

  static ToneColors accent(BuildContext context) => ToneColors.of(
    context,
    solid: AppDesign.accent,
    subtle: AppDesign.accentSubtle,
    text: AppDesign.accentText,
  );
  static ToneColors info(BuildContext context) => ToneColors.of(
    context,
    solid: AppDesign.info,
    subtle: AppDesign.infoSubtle,
    text: AppDesign.infoText,
  );
  static ToneColors warning(BuildContext context) => ToneColors.of(
    context,
    solid: AppDesign.warning,
    subtle: AppDesign.warningSubtle,
    text: AppDesign.warningText,
  );
  static ToneColors success(BuildContext context) => ToneColors.of(
    context,
    solid: AppDesign.success,
    subtle: AppDesign.successSubtle,
    text: AppDesign.successText,
  );
  static ToneColors danger(BuildContext context) => ToneColors.of(
    context,
    solid: AppDesign.danger,
    subtle: AppDesign.dangerSubtle,
    text: AppDesign.dangerText,
  );
}
