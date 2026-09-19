import 'package:flutter/material.dart';
import 'app_theme_system.dart';

/// Design tokens ASSO — socle visuel unique de l'application.
///
/// Principe directeur : **une seule couleur d'accent** (l'orange de marque).
/// Les couleurs vives restantes sont strictement sémantiques (succès, alerte,
/// erreur, information) et ne servent jamais de décoration. Tout le reste
/// s'exprime en neutres, en typographie et en espacement.
///
/// Les valeurs sont dérivées de [AppThemeSystem] pour rester responsive :
/// on ne code jamais une taille en dur dans une vue, on passe par ces tokens.
class AppDesign {
  const AppDesign._();

  // ================================
  // PALETTE — NEUTRES
  // ================================
  // Échelle neutre légèrement chaude, accordée à l'orange de marque.
  // Elle porte l'essentiel de l'interface : fonds, cartes, bordures, textes.

  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral25 = Color(0xFFFCFCFB);
  static const Color neutral50 = Color(0xFFF2F2F0);
  static const Color neutral100 = Color(0xFFEAEAE7);
  static const Color neutral200 = Color(0xFFE6E6E3);
  static const Color neutral300 = Color(0xFFD5D5D1);
  static const Color neutral400 = Color(0xFFA8A8A3);
  static const Color neutral500 = Color(0xFF80807B);
  static const Color neutral600 = Color(0xFF5F5F5A);
  static const Color neutral700 = Color(0xFF474743);
  static const Color neutral800 = Color(0xFF2E2E2B);
  static const Color neutral900 = Color(0xFF1A1A18);

  // Neutres du mode sombre.
  static const Color neutralDark900 = Color(0xFF121211);
  static const Color neutralDark800 = Color(0xFF1B1B1A);
  static const Color neutralDark700 = Color(0xFF242423);
  static const Color neutralDark600 = Color(0xFF32322F);

  // ================================
  // PALETTE — ACCENT DE MARQUE
  // ================================
  // L'orange ASSO, décliné. `accent` est la seule couleur autorisée pour
  // guider l'action principale ; les autres nuances servent de fonds discrets.

  static const Color accent = Color(0xFFE87722); // Orange marque, assombri
  static const Color accentHover = Color(0xFFD06714);
  static const Color accentPressed = Color(0xFFB4570E);
  static const Color accentSubtle = Color(0xFFFDF3EA); // Fond de badge/chip
  static const Color accentBorder = Color(0xFFF6D9C0);
  static const Color accentText = Color(0xFF9C4A0A); // Texte sur accentSubtle

  // ================================
  // PALETTE — SÉMANTIQUE
  // ================================
  // Réservée au sens. Jamais décorative. Chaque couleur a un fond discret
  // (`*Subtle`) et un ton texte lisible (`*Text`) pour composer des badges.

  static const Color success = Color(0xFF1F7A4D);
  static const Color successSubtle = Color(0xFFEAF5EF);
  static const Color successText = Color(0xFF15603B);

  static const Color warning = Color(0xFF9A6700);
  static const Color warningSubtle = Color(0xFFFBF3E2);
  static const Color warningText = Color(0xFF7A5200);

  static const Color danger = Color(0xFFB3261E);
  static const Color dangerSubtle = Color(0xFFFCEEED);
  static const Color dangerText = Color(0xFF8C1D18);

  static const Color info = Color(0xFF2B5F8A);
  static const Color infoSubtle = Color(0xFFEDF3F8);
  static const Color infoText = Color(0xFF1F4A6D);

  // ================================
  // ESPACEMENT — ÉCHELLE 4PT
  // ================================
  // Une échelle unique évite les valeurs arbitraires (10, 13, 22...) qui
  // font qu'une interface « ne tombe pas juste ».

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;

  // ================================
  // RAYONS
  // ================================

  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  // ================================
  // COULEURS RÉSOLUES SELON LE THÈME
  // ================================

  static bool _isDark(BuildContext context) => AppThemeSystem.isDarkMode(context);

  /// Fond général de l'écran.
  static Color canvas(BuildContext context) =>
      _isDark(context) ? neutralDark900 : neutral50;

  /// Fond d'une carte ou d'une surface posée sur [canvas].
  static Color surface(BuildContext context) =>
      _isDark(context) ? neutralDark800 : neutral0;

  /// Surface légèrement contrastée (champ de saisie, ligne alternée).
  static Color surfaceMuted(BuildContext context) =>
      _isDark(context) ? neutralDark700 : neutral100;

  /// Bordure discrète, celle qui structure sans se voir.
  static Color border(BuildContext context) =>
      _isDark(context) ? neutralDark600 : neutral200;

  /// Bordure plus affirmée (champ au repos, séparateur porteur).
  static Color borderStrong(BuildContext context) =>
      _isDark(context) ? const Color(0xFF3D3D39) : neutral300;

  /// Texte principal.
  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF5F5F3) : neutral900;

  /// Texte secondaire : sous-titres, métadonnées.
  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB0B0AA) : neutral600;

  /// Texte tertiaire : mentions légères, aides à la saisie.
  static Color textTertiary(BuildContext context) =>
      _isDark(context) ? const Color(0xFF85857F) : neutral500;

  /// Couleur d'une icône neutre.
  static Color icon(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB0B0AA) : neutral600;

  // ================================
  // OMBRES
  // ================================
  // Deux niveaux suffisent. L'ombre sert à détacher une surface, pas à
  // décorer : elle reste large, basse en opacité et jamais colorée.

  /// Élévation d'une carte au repos.
  static List<BoxShadow> shadowSm(BuildContext context) {
    if (_isDark(context)) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: neutral900.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Élévation d'un élément flottant (bottom sheet, menu, dialogue).
  static List<BoxShadow> shadowMd(BuildContext context) {
    if (_isDark(context)) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];
    }
    return [
      BoxShadow(
        color: neutral900.withValues(alpha: 0.09),
        blurRadius: 28,
        offset: const Offset(0, 10),
      ),
    ];
  }

  // ================================
  // GABARITS RESPONSIVES
  // ================================

  /// Marge latérale de contenu, alignée sur le système responsive existant.
  static double gutter(BuildContext context) =>
      AppThemeSystem.getHorizontalPadding(context);

  /// Largeur maximale d'une colonne de lecture. Au-delà, on centre le
  /// contenu plutôt que de l'étirer : une ligne trop longue devient illisible
  /// et donne l'impression d'un site non pensé pour les grands écrans.
  static double maxContentWidth(BuildContext context) {
    switch (AppThemeSystem.getDeviceType(context)) {
      case DeviceType.mobile:
        return double.infinity;
      case DeviceType.tablet:
        return 720;
      case DeviceType.largeTablet:
        return 880;
      case DeviceType.iPadPro13:
        return 1040;
      case DeviceType.desktop:
        return 1140;
    }
  }

  /// Nombre de colonnes pour une grille de produits.
  static int productColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 2;
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  /// Hauteur minimale d'une cible tactile (recommandation WCAG / Material).
  static const double minTapTarget = 48;
}

/// Raccourcis de lecture sur le `BuildContext`.
///
/// Ils rendent les vues nettement plus lisibles : `context.ds.surface`
/// plutôt que `AppDesign.surface(context)` répété à chaque ligne.
extension AppDesignContext on BuildContext {
  DesignTokens get ds => DesignTokens(this);
}

/// Vue matérialisée des tokens pour un contexte donné.
class DesignTokens {
  const DesignTokens(this.context);

  final BuildContext context;

  Color get canvas => AppDesign.canvas(context);
  Color get surface => AppDesign.surface(context);
  Color get surfaceMuted => AppDesign.surfaceMuted(context);
  Color get border => AppDesign.border(context);
  Color get borderStrong => AppDesign.borderStrong(context);
  Color get textPrimary => AppDesign.textPrimary(context);
  Color get textSecondary => AppDesign.textSecondary(context);
  Color get textTertiary => AppDesign.textTertiary(context);
  Color get icon => AppDesign.icon(context);

  Color get accent => AppDesign.accent;

  List<BoxShadow> get shadowSm => AppDesign.shadowSm(context);
  List<BoxShadow> get shadowMd => AppDesign.shadowMd(context);

  double get gutter => AppDesign.gutter(context);
  double get maxContentWidth => AppDesign.maxContentWidth(context);
  int get productColumns => AppDesign.productColumns(context);
}
