import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_design.dart';
import '../../core/utils/app_design.dart';

/// Système de theming automatique et responsive pour Estuaire Emploi
/// Gère automatiquement les thèmes sombre/clair et toutes les tailles d'écran
class AppThemeSystem {
  // ================================
  // CONFIGURATION DU SYSTÈME DE THÈME
  // ================================

  /// Active/désactive le système de thème dynamique (dark/light)
  /// Si false, seul le thème light sera appliqué
  /// Si true, le thème s'adapte au mode natif de l'appareil
  static bool enableDynamicTheming = false;

  // ================================
  // COULEURS DU DESIGN SYSTEM
  // ================================

  /// Conservée pour compatibilité : alias de l'accent unique `AppDesign.accent`.
  static const Color primaryColor = AppDesign.accent;
  static const Color secondaryColor = Color(0xFF2B2B2B); // Noir doux UI
  static const Color tertiaryColor = AppDesign.accentHover;

  // Couleurs neutres
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color blackColor = Color(0xFF000000);
  static const Color backgroundColor = Color(0xFFF6F6F6);
  static const Color darkBackgroundColor = Color(0xFF0D1117);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color darkCardColor = Color(0xFF151B23);

  // Couleurs grises
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // Couleurs sémantiques
  static const Color successColor = AppDesign.success;
  static const Color errorColor = AppDesign.danger;
  static const Color warningColor = AppDesign.warning;
  static const Color infoColor = AppDesign.info;

  // Couleurs des providers de paiement
  static const Color kpayColor = Color(0xFFFF6F00); // Orange
  static const Color paypalColor = Color(0xFF0070ba); // Bleu PayPal
  static const Color bankColor = AppDesign.success; // Vert virement bancaire (IBAN)

  // ================================
  // BREAKPOINTS RESPONSIVE
  // ================================

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double largeTabletBreakpoint = 1024;
  static const double iPadPro13Breakpoint = 1366; // iPad Pro 13" width
  static const double desktopBreakpoint = 1200;

  /// Détermine le type d'appareil basé sur la largeur d'écran
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return DeviceType.mobile;
    if (width < tabletBreakpoint) return DeviceType.tablet;
    if (width < largeTabletBreakpoint) return DeviceType.largeTablet;
    if (width < iPadPro13Breakpoint) return DeviceType.iPadPro13;
    return DeviceType.desktop;
  }

  /// Vérifie si l'appareil est en mode portrait
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Vérifie si l'appareil est une tablette ou plus grand
  static bool isTabletOrLarger(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  // ================================
  // SYSTÈME DE TYPOGRAPHIE RESPONSIVE
  // ================================

  /// Tailles de police responsives basées sur le type d'appareil
  static double getFontSize(BuildContext context, FontSizeType type) {
    final deviceType = getDeviceType(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Facteur de scaling adaptatif basé sur le type d'appareil
    double scaleFactor;
    if (deviceType == DeviceType.iPadPro13) {
      // Pour iPad Pro 13", on utilise un facteur plus généreux
      final heightFactor = (screenHeight / 1024).clamp(1.1, 1.4);
      final widthFactor = (screenWidth / 1366).clamp(1.1, 1.3);
      scaleFactor = (heightFactor + widthFactor) / 2;
    } else if (deviceType == DeviceType.largeTablet) {
      final heightFactor = (screenHeight / 1024).clamp(1.0, 1.3);
      final widthFactor = (screenWidth / 1024).clamp(1.0, 1.2);
      scaleFactor = (heightFactor + widthFactor) / 2;
    } else if (deviceType == DeviceType.tablet) {
      scaleFactor = (screenHeight / 800).clamp(0.95, 1.25);
    } else {
      scaleFactor = (screenHeight / 800).clamp(0.8, 1.2);
    }

    switch (type) {
      case FontSizeType.h1:
        switch (deviceType) {
          case DeviceType.mobile:
            return (32 * scaleFactor);
          case DeviceType.tablet:
            return (36 * scaleFactor);
          case DeviceType.largeTablet:
            return (42 * scaleFactor);
          case DeviceType.iPadPro13:
            return (48 * scaleFactor); // Plus grand pour iPad Pro 13"
          case DeviceType.desktop:
            return (40 * scaleFactor);
        }
      case FontSizeType.h2:
        switch (deviceType) {
          case DeviceType.mobile:
            return (28 * scaleFactor);
          case DeviceType.tablet:
            return (32 * scaleFactor);
          case DeviceType.largeTablet:
            return (36 * scaleFactor);
          case DeviceType.iPadPro13:
            return (40 * scaleFactor);
          case DeviceType.desktop:
            return (36 * scaleFactor);
        }
      case FontSizeType.h3:
        switch (deviceType) {
          case DeviceType.mobile:
            return (24 * scaleFactor);
          case DeviceType.tablet:
            return (28 * scaleFactor);
          case DeviceType.largeTablet:
            return (32 * scaleFactor);
          case DeviceType.iPadPro13:
            return (36 * scaleFactor);
          case DeviceType.desktop:
            return (32 * scaleFactor);
        }
      case FontSizeType.h4:
        switch (deviceType) {
          case DeviceType.mobile:
            return (20 * scaleFactor);
          case DeviceType.tablet:
            return (24 * scaleFactor);
          case DeviceType.largeTablet:
            return (28 * scaleFactor);
          case DeviceType.iPadPro13:
            return (32 * scaleFactor);
          case DeviceType.desktop:
            return (28 * scaleFactor);
        }
      case FontSizeType.h5:
        switch (deviceType) {
          case DeviceType.mobile:
            return (18 * scaleFactor);
          case DeviceType.tablet:
            return (20 * scaleFactor);
          case DeviceType.largeTablet:
            return (24 * scaleFactor);
          case DeviceType.iPadPro13:
            return (28 * scaleFactor);
          case DeviceType.desktop:
            return (24 * scaleFactor);
        }
      case FontSizeType.h6:
        switch (deviceType) {
          case DeviceType.mobile:
            return (16 * scaleFactor);
          case DeviceType.tablet:
            return (18 * scaleFactor);
          case DeviceType.largeTablet:
            return (20 * scaleFactor);
          case DeviceType.iPadPro13:
            return (24 * scaleFactor);
          case DeviceType.desktop:
            return (20 * scaleFactor);
        }
      case FontSizeType.subtitle1:
        switch (deviceType) {
          case DeviceType.mobile:
            return (16 * scaleFactor);
          case DeviceType.tablet:
            return (18 * scaleFactor);
          case DeviceType.largeTablet:
            return (20 * scaleFactor);
          case DeviceType.iPadPro13:
            return (22 * scaleFactor);
          case DeviceType.desktop:
            return (20 * scaleFactor);
        }
      case FontSizeType.subtitle2:
        switch (deviceType) {
          case DeviceType.mobile:
            return (14 * scaleFactor);
          case DeviceType.tablet:
            return (16 * scaleFactor);
          case DeviceType.largeTablet:
            return (18 * scaleFactor);
          case DeviceType.iPadPro13:
            return (20 * scaleFactor);
          case DeviceType.desktop:
            return (18 * scaleFactor);
        }
      case FontSizeType.body1:
        switch (deviceType) {
          case DeviceType.mobile:
            return (16 * scaleFactor);
          case DeviceType.tablet:
            return (17 * scaleFactor);
          case DeviceType.largeTablet:
            return (18 * scaleFactor);
          case DeviceType.iPadPro13:
            return (20 * scaleFactor);
          case DeviceType.desktop:
            return (18 * scaleFactor);
        }
      case FontSizeType.body2:
        switch (deviceType) {
          case DeviceType.mobile:
            return (14 * scaleFactor);
          case DeviceType.tablet:
            return (15 * scaleFactor);
          case DeviceType.largeTablet:
            return (16 * scaleFactor);
          case DeviceType.iPadPro13:
            return (18 * scaleFactor);
          case DeviceType.desktop:
            return (16 * scaleFactor);
        }
      case FontSizeType.caption:
        switch (deviceType) {
          case DeviceType.mobile:
            return (12 * scaleFactor);
          case DeviceType.tablet:
            return (13 * scaleFactor);
          case DeviceType.largeTablet:
            return (14 * scaleFactor);
          case DeviceType.iPadPro13:
            return (16 * scaleFactor);
          case DeviceType.desktop:
            return (14 * scaleFactor);
        }
      case FontSizeType.overline:
        switch (deviceType) {
          case DeviceType.mobile:
            return (10 * scaleFactor);
          case DeviceType.tablet:
            return (11 * scaleFactor);
          case DeviceType.largeTablet:
            return (12 * scaleFactor);
          case DeviceType.iPadPro13:
            return (14 * scaleFactor);
          case DeviceType.desktop:
            return (12 * scaleFactor);
        }
      case FontSizeType.button:
        switch (deviceType) {
          case DeviceType.mobile:
            return (14 * scaleFactor);
          case DeviceType.tablet:
            return (15 * scaleFactor);
          case DeviceType.largeTablet:
            return (16 * scaleFactor);
          case DeviceType.iPadPro13:
            return (18 * scaleFactor);
          case DeviceType.desktop:
            return (16 * scaleFactor);
        }
    }
  }

  // ================================
  // STYLES DE TEXTE AUTOMATIQUES
  // ================================

  /// Génère un TextStyle basé sur le thème actuel et le type de device
  static TextStyle getTextStyle(
    BuildContext context,
    FontSizeType type, {
    FontWeight? fontWeight,
    Color? color,
    double? height,
    String fontFamily = 'SF-Pro',
  }) {
    final theme = Theme.of(context);
    final isDark = enableDynamicTheming && theme.brightness == Brightness.dark;
    final fontSize = getFontSize(context, type);

    // Couleur automatique basée sur le thème
    Color textColor = color ?? (isDark ? whiteColor : blackColor);

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: textColor,
      height: height,
      fontFamily: fontFamily,
    );
  }

  // ================================
  // ESPACEMENTS RESPONSIFS
  // ================================

  /// Espacement horizontal responsive
  static double getHorizontalPadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    final screenWidth = MediaQuery.of(context).size.width;
    double scaleFactor;

    if (deviceType == DeviceType.iPadPro13) {
      scaleFactor = (screenWidth / 1366).clamp(
        1.1,
        1.4,
      ); // Facteur plus généreux pour iPad Pro 13"
    } else if (deviceType == DeviceType.largeTablet) {
      scaleFactor = (screenWidth / 1024).clamp(1.0, 1.25);
    } else if (deviceType == DeviceType.tablet) {
      scaleFactor = (screenWidth / 768).clamp(0.95, 1.2);
    } else {
      scaleFactor = (screenWidth / 375).clamp(0.9, 1.3);
    }

    switch (deviceType) {
      case DeviceType.mobile:
        return (16 * scaleFactor);
      case DeviceType.tablet:
        return (24 * scaleFactor);
      case DeviceType.largeTablet:
        return (32 * scaleFactor);
      case DeviceType.iPadPro13:
        return (40 * scaleFactor);
      case DeviceType.desktop:
        return (32 * scaleFactor);
    }
  }

  /// Espacement vertical responsive
  static double getVerticalPadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    final screenHeight = MediaQuery.of(context).size.height;
    double scaleFactor;

    if (deviceType == DeviceType.iPadPro13) {
      scaleFactor = (screenHeight / 1024).clamp(1.1, 1.4);
    } else if (deviceType == DeviceType.largeTablet) {
      scaleFactor = (screenHeight / 1024).clamp(1.0, 1.25);
    } else if (deviceType == DeviceType.tablet) {
      scaleFactor = (screenHeight / 800).clamp(0.95, 1.2);
    } else {
      scaleFactor = (screenHeight / 800).clamp(0.8, 1.2);
    }

    switch (deviceType) {
      case DeviceType.mobile:
        return (16 * scaleFactor);
      case DeviceType.tablet:
        return (20 * scaleFactor);
      case DeviceType.largeTablet:
        return (24 * scaleFactor);
      case DeviceType.iPadPro13:
        return (28 * scaleFactor);
      case DeviceType.desktop:
        return (24 * scaleFactor);
    }
  }

  /// Espacement entre sections
  static double getSectionSpacing(BuildContext context) {
    final deviceType = getDeviceType(context);
    final screenHeight = MediaQuery.of(context).size.height;
    double scaleFactor;

    if (deviceType == DeviceType.iPadPro13) {
      scaleFactor = (screenHeight / 1024).clamp(1.1, 1.4);
    } else if (deviceType == DeviceType.largeTablet) {
      scaleFactor = (screenHeight / 1024).clamp(1.0, 1.25);
    } else if (deviceType == DeviceType.tablet) {
      scaleFactor = (screenHeight / 800).clamp(0.95, 1.2);
    } else {
      scaleFactor = (screenHeight / 800).clamp(0.8, 1.2);
    }

    switch (deviceType) {
      case DeviceType.mobile:
        return (24 * scaleFactor);
      case DeviceType.tablet:
        return (32 * scaleFactor);
      case DeviceType.largeTablet:
        return (40 * scaleFactor);
      case DeviceType.iPadPro13:
        return (48 * scaleFactor);
      case DeviceType.desktop:
        return (40 * scaleFactor);
    }
  }

  /// Espacement entre éléments
  static double getElementSpacing(BuildContext context) {
    final deviceType = getDeviceType(context);
    final screenHeight = MediaQuery.of(context).size.height;
    double scaleFactor;

    if (deviceType == DeviceType.iPadPro13) {
      scaleFactor = (screenHeight / 1024).clamp(1.1, 1.4);
    } else if (deviceType == DeviceType.largeTablet) {
      scaleFactor = (screenHeight / 1024).clamp(1.0, 1.25);
    } else if (deviceType == DeviceType.tablet) {
      scaleFactor = (screenHeight / 800).clamp(0.95, 1.2);
    } else {
      scaleFactor = (screenHeight / 800).clamp(0.8, 1.2);
    }

    switch (deviceType) {
      case DeviceType.mobile:
        return (12 * scaleFactor);
      case DeviceType.tablet:
        return (16 * scaleFactor);
      case DeviceType.largeTablet:
        return (20 * scaleFactor);
      case DeviceType.iPadPro13:
        return (24 * scaleFactor);
      case DeviceType.desktop:
        return (20 * scaleFactor);
    }
  }

  // ================================
  // COULEURS AUTOMATIQUES PAR THÈME
  // ================================

  // Ces accesseurs historiques délèguent désormais aux tokens d'`AppDesign`.
  // C'est ce qui permet aux vues encore écrites avec `AppThemeSystem` /
  // `context.surfaceColor` de suivre la nouvelle charte sans être réécrites :
  // il n'existe plus qu'une seule source de vérité pour les couleurs.

  /// Couleur de surface basée sur le thème
  static Color getSurfaceColor(BuildContext context) =>
      AppDesign.surface(context);

  /// Couleur de background basée sur le thème
  static Color getBackgroundColor(BuildContext context) =>
      AppDesign.canvas(context);

  /// Couleur de texte primaire basée sur le thème
  static Color getPrimaryTextColor(BuildContext context) =>
      AppDesign.textPrimary(context);

  /// Couleur de texte secondaire basée sur le thème
  static Color getSecondaryTextColor(BuildContext context) =>
      AppDesign.textSecondary(context);

  /// Couleur de bordure basée sur le thème
  static Color getBorderColor(BuildContext context) =>
      AppDesign.border(context);

  /// Vérifie si le mode sombre est activé (méthode statique pour éviter les conflits d'extensions)
  static bool isDarkMode(BuildContext context) {
    return enableDynamicTheming && Theme.of(context).brightness == Brightness.dark;
  }

  /// Couleur de fond pour les champs de saisie (TextField, TextFormField)
  static Color getInputFieldColor(BuildContext context) =>
      AppDesign.surfaceMuted(context);

  // ================================
  // CONFIGURATIONS DE WIDGETS
  // ================================

  /// Hauteur de bouton responsive
  static double getButtonHeight(BuildContext context) {
    final deviceType = getDeviceType(context);
    final screenHeight = MediaQuery.of(context).size.height;
    double scaleFactor;

    if (deviceType == DeviceType.iPadPro13) {
      scaleFactor = (screenHeight / 1024).clamp(1.0, 1.2);
    } else if (deviceType == DeviceType.largeTablet) {
      scaleFactor = (screenHeight / 1024).clamp(0.9, 1.1);
    } else if (deviceType == DeviceType.tablet) {
      scaleFactor = (screenHeight / 800).clamp(0.85, 1.05);
    } else {
      scaleFactor = (screenHeight / 800).clamp(0.8, 1.2);
    }

    switch (deviceType) {
      case DeviceType.mobile:
        return (48 * scaleFactor);
      case DeviceType.tablet:
        return (44 * scaleFactor).clamp(40, 50);
      case DeviceType.largeTablet:
        return (48 * scaleFactor).clamp(44, 54);
      case DeviceType.iPadPro13:
        return (52 * scaleFactor).clamp(48, 58);
      case DeviceType.desktop:
        return (56 * scaleFactor);
    }
  }

  /// Padding du bottom sheet en tenant compte de la barre de navigation native
  /// Utilise viewPadding.bottom pour les barres système + viewInsets.bottom pour le clavier
  static double getBottomSheetPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    // viewInsets.bottom = hauteur du clavier (quand visible)
    // viewPadding.bottom = hauteur de la barre de navigation native
    // padding.bottom = viewPadding.bottom - viewInsets.bottom (quand clavier ouvert)

    // On utilise la combinaison pour gérer les deux cas:
    // - Clavier fermé: on a le padding de la barre de navigation
    // - Clavier ouvert: on a le padding du clavier
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.viewPadding.bottom;

    // Si le clavier est ouvert, on prend le max entre le clavier et la barre de navigation
    // Sinon, on prend juste la barre de navigation + un padding additionnel
    if (bottomInset > 0) {
      // Clavier ouvert: prendre le maximum
      return bottomInset + getHorizontalPadding(context) * 0.5;
    } else {
      // Clavier fermé: ajouter la barre de navigation + un padding
      return bottomPadding + getHorizontalPadding(context);
    }
  }

  /// Hauteur de conteneur de stats adaptée pour éviter les overflows
  static double getStatsContainerHeight(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return 85;
      case DeviceType.tablet:
        return 100; // Réduit davantage pour éviter les overflows
      case DeviceType.largeTablet:
        return 110;
      case DeviceType.iPadPro13:
        return 120;
      case DeviceType.desktop:
        return 120;
    }
  }

  /// Espacement vertical adaptatif pour éviter les overflows
  static double getAdaptiveSpacing(
    BuildContext context, {
    double baseSpacing = 8,
  }) {
    final deviceType = getDeviceType(context);
    final screenHeight = MediaQuery.of(context).size.height;

    double factor;
    switch (deviceType) {
      case DeviceType.mobile:
        factor = (screenHeight / 800).clamp(0.8, 1.2);
        break;
      case DeviceType.tablet:
        factor = (screenHeight / 1024).clamp(
          0.5,
          0.8,
        ); // Réduit encore plus pour tablettes
        break;
      case DeviceType.largeTablet:
        factor = (screenHeight / 1024).clamp(0.7, 1.0);
        break;
      case DeviceType.iPadPro13:
        factor = (screenHeight / 1366).clamp(0.8, 1.2);
        break;
      case DeviceType.desktop:
        factor = 1.0;
        break;
    }

    final result = baseSpacing * factor;
    final maxValue = baseSpacing * 1.5;
    return result.clamp(2.0, maxValue < 2.0 ? baseSpacing : maxValue);
  }

  /// Border radius responsive
  static double getBorderRadius(BuildContext context, BorderRadiusType type) {
    final deviceType = getDeviceType(context);
    final screenWidth = MediaQuery.of(context).size.width;
    double scaleFactor;

    if (deviceType == DeviceType.iPadPro13) {
      scaleFactor = (screenWidth / 1366).clamp(1.1, 1.4);
    } else if (deviceType == DeviceType.largeTablet) {
      scaleFactor = (screenWidth / 1024).clamp(1.0, 1.3);
    } else if (deviceType == DeviceType.tablet) {
      scaleFactor = (screenWidth / 768).clamp(0.95, 1.25);
    } else {
      scaleFactor = (screenWidth / 375).clamp(0.9, 1.3);
    }

    switch (type) {
      case BorderRadiusType.small:
        switch (deviceType) {
          case DeviceType.mobile:
            return (4 * scaleFactor);
          case DeviceType.tablet:
            return (6 * scaleFactor);
          case DeviceType.largeTablet:
            return (7 * scaleFactor);
          case DeviceType.iPadPro13:
            return (8 * scaleFactor);
          case DeviceType.desktop:
            return (8 * scaleFactor);
        }
      case BorderRadiusType.medium:
        switch (deviceType) {
          case DeviceType.mobile:
            return (8 * scaleFactor);
          case DeviceType.tablet:
            return (10 * scaleFactor);
          case DeviceType.largeTablet:
            return (11 * scaleFactor);
          case DeviceType.iPadPro13:
            return (14 * scaleFactor);
          case DeviceType.desktop:
            return (12 * scaleFactor);
        }
      case BorderRadiusType.large:
        switch (deviceType) {
          case DeviceType.mobile:
            return (16 * scaleFactor);
          case DeviceType.tablet:
            return (18 * scaleFactor);
          case DeviceType.largeTablet:
            return (19 * scaleFactor);
          case DeviceType.iPadPro13:
            return (22 * scaleFactor);
          case DeviceType.desktop:
            return (20 * scaleFactor);
        }
      case BorderRadiusType.circular:
        return (50 * scaleFactor);
    }
  }

  /// Élévation d'ombre responsive
  static double getElevation(BuildContext context, ElevationType type) {
    final deviceType = getDeviceType(context);

    switch (type) {
      case ElevationType.none:
        return 0;
      case ElevationType.low:
        switch (deviceType) {
          case DeviceType.mobile:
            return 2;
          case DeviceType.tablet:
            return 3;
          case DeviceType.largeTablet:
            return 3;
          case DeviceType.iPadPro13:
            return 4;
          case DeviceType.desktop:
            return 4;
        }
      case ElevationType.medium:
        switch (deviceType) {
          case DeviceType.mobile:
            return 4;
          case DeviceType.tablet:
            return 6;
          case DeviceType.largeTablet:
            return 7;
          case DeviceType.iPadPro13:
            return 8;
          case DeviceType.desktop:
            return 8;
        }
      case ElevationType.high:
        switch (deviceType) {
          case DeviceType.mobile:
            return 8;
          case DeviceType.tablet:
            return 12;
          case DeviceType.largeTablet:
            return 14;
          case DeviceType.iPadPro13:
            return 16;
          case DeviceType.desktop:
            return 16;
        }
    }
  }

  // ================================
  // THÈMES
  // ================================
  //
  // Les thèmes sont construits sur les tokens d'`AppDesign` : une seule
  // couleur d'accent (l'orange de marque), des neutres pour tout le reste.
  // Configurer ici évite d'avoir à styliser chaque widget Material
  // individuellement dans les vues.

  /// Construit le thème commun, décliné en clair ou sombre.
  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final canvas = isDark ? AppDesign.neutralDark900 : AppDesign.neutral50;
    final surface = isDark ? AppDesign.neutralDark800 : AppDesign.neutral0;
    final surfaceMuted = isDark ? AppDesign.neutralDark700 : AppDesign.neutral100;
    final border = isDark ? AppDesign.neutralDark600 : AppDesign.neutral200;
    final borderStrong =
        isDark ? const Color(0xFF3D3D39) : AppDesign.neutral300;
    final textPrimary =
        isDark ? const Color(0xFFF5F5F3) : AppDesign.neutral900;
    final textSecondary =
        isDark ? const Color(0xFFB0B0AA) : AppDesign.neutral600;
    final textTertiary =
        isDark ? const Color(0xFF85857F) : AppDesign.neutral500;

    final radiusSm = BorderRadius.circular(AppDesign.radiusSm);

    OutlineInputBorder outline(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: radiusSm,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: AppDesign.accent,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      fontFamily: 'SF-Pro',
      splashFactory: InkSparkle.splashFactory,

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppDesign.accent,
        onPrimary: Colors.white,
        primaryContainer: AppDesign.accentSubtle,
        onPrimaryContainer: AppDesign.accentText,
        secondary: isDark ? const Color(0xFFD8D8D3) : AppDesign.neutral800,
        onSecondary: isDark ? AppDesign.neutral900 : Colors.white,
        tertiary: AppDesign.accent,
        onTertiary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerLowest: canvas,
        surfaceContainerLow: surface,
        surfaceContainer: surfaceMuted,
        surfaceContainerHigh: surfaceMuted,
        surfaceContainerHighest: surfaceMuted,
        onSurfaceVariant: textSecondary,
        outline: borderStrong,
        outlineVariant: border,
        error: AppDesign.danger,
        onError: Colors.white,
        errorContainer: AppDesign.dangerSubtle,
        onErrorContainer: AppDesign.dangerText,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'SF-Pro',
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),

      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusMd),
          side: BorderSide(color: border),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesign.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark ? AppDesign.neutralDark600 : AppDesign.neutral200,
          disabledForegroundColor: textTertiary,
          elevation: 0,
          minimumSize: const Size(double.infinity, AppDesign.minTapTarget),
          textStyle: const TextStyle(
            fontFamily: 'SF-Pro',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, AppDesign.minTapTarget),
          side: BorderSide(color: borderStrong),
          textStyle: const TextStyle(
            fontFamily: 'SF-Pro',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppDesign.accent,
          minimumSize: const Size(0, AppDesign.minTapTarget),
          textStyle: const TextStyle(
            fontFamily: 'SF-Pro',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppDesign.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, AppDesign.minTapTarget),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDesign.space4,
          vertical: AppDesign.space3 + 2,
        ),
        hintStyle: TextStyle(color: textTertiary, fontFamily: 'SF-Pro'),
        labelStyle: TextStyle(color: textSecondary, fontFamily: 'SF-Pro'),
        floatingLabelStyle: const TextStyle(
          color: AppDesign.accent,
          fontFamily: 'SF-Pro',
        ),
        prefixIconColor: textTertiary,
        suffixIconColor: textTertiary,
        border: outline(borderStrong),
        enabledBorder: outline(borderStrong),
        focusedBorder: outline(AppDesign.accent, width: 1.5),
        errorBorder: outline(AppDesign.danger),
        focusedErrorBorder: outline(AppDesign.danger, width: 1.5),
        disabledBorder: outline(border),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        selectedColor: AppDesign.accentSubtle,
        side: BorderSide(color: border),
        labelStyle: TextStyle(
          color: textSecondary,
          fontFamily: 'SF-Pro',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDesign.radiusXl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'SF-Pro',
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'SF-Pro',
          color: textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppDesign.neutral100 : AppDesign.neutral900,
        contentTextStyle: TextStyle(
          fontFamily: 'SF-Pro',
          color: isDark ? AppDesign.neutral900 : Colors.white,
          fontSize: 14,
        ),
        actionTextColor: AppDesign.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppDesign.accent,
        unselectedLabelColor: textSecondary,
        indicatorColor: AppDesign.accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: border,
        labelStyle: const TextStyle(
          fontFamily: 'SF-Pro',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'SF-Pro',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppDesign.accent,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'SF-Pro',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'SF-Pro',
          fontSize: 11,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : (isDark ? AppDesign.neutral400 : AppDesign.neutral0),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppDesign.accent
              : (isDark ? AppDesign.neutralDark600 : AppDesign.neutral300),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppDesign.accent
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusXs - 2),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppDesign.accent
              : borderStrong,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppDesign.accent,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppDesign.accent,
        selectionColor: AppDesign.accent.withValues(alpha: 0.25),
        selectionHandleColor: AppDesign.accent,
      ),

      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(color: textPrimary),
      ),
    );
  }

  static ThemeData getLightTheme() => _buildTheme(brightness: Brightness.light);

  static ThemeData getDarkTheme() => _buildTheme(brightness: Brightness.dark);
}

// ================================
// ENUMS POUR LA TYPOLOGIE
// ================================

enum DeviceType { mobile, tablet, largeTablet, iPadPro13, desktop }

enum FontSizeType {
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  subtitle1,
  subtitle2,
  body1,
  body2,
  caption,
  overline,
  button,
}

enum BorderRadiusType { small, medium, large, circular }

enum ElevationType { none, low, medium, high }

// ================================
// EXTENSIONS POUR FACILITER L'USAGE
// ================================

extension AppThemeExtensions on BuildContext {
  /// Accès rapide au système de thème
  AppThemeSystem get appTheme => AppThemeSystem();

  /// Accès rapide aux couleurs du thème
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Vérifie si le thème est sombre
  bool get isDarkMode => AppThemeSystem.enableDynamicTheming && Theme.of(this).brightness == Brightness.dark;

  /// Type d'appareil
  DeviceType get deviceType => AppThemeSystem.getDeviceType(this);

  /// Vérifie si c'est une tablette ou plus
  bool get isTabletOrLarger => AppThemeSystem.isTabletOrLarger(this);

  /// Espacement horizontal
  double get horizontalPadding => AppThemeSystem.getHorizontalPadding(this);

  /// Espacement vertical
  double get verticalPadding => AppThemeSystem.getVerticalPadding(this);

  /// Espacement entre sections
  double get sectionSpacing => AppThemeSystem.getSectionSpacing(this);

  /// Espacement entre éléments
  double get elementSpacing => AppThemeSystem.getElementSpacing(this);

  /// Couleur de surface
  Color get surfaceColor => AppThemeSystem.getSurfaceColor(this);

  /// Couleur de background
  Color get backgroundColor => AppThemeSystem.getBackgroundColor(this);

  /// Couleur de texte primaire
  Color get primaryTextColor => AppThemeSystem.getPrimaryTextColor(this);

  /// Couleur de texte secondaire
  Color get secondaryTextColor => AppThemeSystem.getSecondaryTextColor(this);

  /// Couleur de bordure
  Color get borderColor => AppThemeSystem.getBorderColor(this);

  /// Couleur de fond pour les champs de saisie
  Color get inputFieldColor => AppThemeSystem.getInputFieldColor(this);

  /// Hauteur de bouton
  double get buttonHeight => AppThemeSystem.getButtonHeight(this);

  /// Padding pour les bottom sheets (barre de navigation + clavier)
  double get bottomSheetPadding => AppThemeSystem.getBottomSheetPadding(this);
}

extension TextStyleExtension on BuildContext {
  /// Génère un TextStyle responsive
  TextStyle textStyle(
    FontSizeType type, {
    FontWeight? fontWeight,
    Color? color,
    double? height,
    String fontFamily = 'SF-Pro',
  }) => AppThemeSystem.getTextStyle(
    this,
    type,
    fontWeight: fontWeight,
    color: color,
    height: height,
    fontFamily: fontFamily,
  );

  /// Styles prédéfinis
  TextStyle get h1 => textStyle(FontSizeType.h1, fontWeight: FontWeight.bold);
  TextStyle get h2 => textStyle(FontSizeType.h2, fontWeight: FontWeight.bold);
  TextStyle get h3 => textStyle(FontSizeType.h3, fontWeight: FontWeight.w600);
  TextStyle get h4 => textStyle(FontSizeType.h4, fontWeight: FontWeight.w600);
  TextStyle get h5 => textStyle(FontSizeType.h5, fontWeight: FontWeight.w500);
  TextStyle get h6 => textStyle(FontSizeType.h6, fontWeight: FontWeight.w500);
  TextStyle get subtitle1 =>
      textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w500);
  TextStyle get subtitle2 =>
      textStyle(FontSizeType.subtitle2, fontWeight: FontWeight.w400);
  TextStyle get body1 => textStyle(FontSizeType.body1);
  TextStyle get body2 => textStyle(FontSizeType.body2);
  TextStyle get caption =>
      textStyle(FontSizeType.caption, color: secondaryTextColor);
  TextStyle get overline =>
      textStyle(FontSizeType.overline, fontWeight: FontWeight.w500);
  TextStyle get button =>
      textStyle(FontSizeType.button, fontWeight: FontWeight.w500);
}

extension BorderRadiusExtension on BuildContext {
  /// Border radius responsive
  BorderRadius borderRadius(BorderRadiusType type) =>
      BorderRadius.circular(AppThemeSystem.getBorderRadius(this, type));
}

extension ElevationExtension on BuildContext {
  /// Élévation responsive
  double elevation(ElevationType type) =>
      AppThemeSystem.getElevation(this, type);
}

// ================================
// DIALOGS SYSTÈME
// ================================

/// Helper class for system dialogs
class AppDialogs {
  /// Affiche un dialog demandant à l'utilisateur de se connecter
  static void showLoginRequiredDialog(
    BuildContext context, {
    String? title,
    String? message,
    String? featureName,
    VoidCallback? onLoginPressed,
  }) {
    final defaultTitle = title ?? 'Connexion requise';
    final defaultMessage = message ??
        (featureName != null
            ? 'Pour accéder à $featureName, vous devez d\'abord vous connecter à votre compte.'
            : 'Cette fonctionnalité nécessite une connexion. Veuillez vous connecter pour continuer.');

    Get.dialog(
      Dialog(
        backgroundColor: AppThemeSystem.getSurfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppThemeSystem.primaryColor,
                      AppThemeSystem.tertiaryColor,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),

              SizedBox(height: AppThemeSystem.getElementSpacing(context) * 1.5),

              // Titre
              Text(
                defaultTitle,
                style: context.textStyle(
                  FontSizeType.h4,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppThemeSystem.getElementSpacing(context)),

              // Message
              Text(
                defaultMessage,
                style: context.textStyle(
                  FontSizeType.body2,
                  color: context.secondaryTextColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

              // Boutons
              Row(
                children: [
                  // Bouton Se connecter
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: AppThemeSystem.getButtonHeight(context),
                      child: ElevatedButton(
                        onPressed: onLoginPressed ??
                            () {
                              Get.back();
                              Get.toNamed('/login');
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeSystem.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor:
                              AppThemeSystem.primaryColor.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppThemeSystem.getBorderRadius(
                                context,
                                BorderRadiusType.medium,
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.login_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Se connecter',
                              style: context.textStyle(
                                FontSizeType.button,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  /// Affiche un snackbar demandant à l'utilisateur de se connecter (version compacte)
  static void showLoginRequiredSnackbar({
    String? message,
    String? featureName,
    VoidCallback? onLoginPressed,
  }) {
    final defaultMessage = message ??
        (featureName != null
            ? 'Connectez-vous pour accéder à $featureName'
            : 'Connexion requise pour cette fonctionnalité');

    Get.snackbar(
      'Connexion requise',
      defaultMessage,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.primaryColor,
      colorText: Colors.white,
      icon: const Icon(
        Icons.lock_person_rounded,
        color: Colors.white,
      ),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      mainButton: TextButton(
        onPressed: onLoginPressed ??
            () {
              Get.back();
              Get.toNamed('/login');
            },
        child: Text(
          'Se connecter',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
