import 'package:asso/app/core/utils/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_design.dart';

/// Système de theming automatique et responsive pour ASSO
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
  static const Color secondaryColor = AppDesign.neutral800; // Noir doux UI
  static const Color tertiaryColor = AppDesign.accentHover;

  // Couleurs neutres
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color blackColor = Color(0xFF000000);
  static const Color backgroundColor = AppDesign.neutral50;
  static const Color darkBackgroundColor = AppDesign.neutralDark900;
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color darkCardColor = AppDesign.neutralDark800;

  // Couleurs grises
  static const Color grey50 = AppDesign.neutral25;
  static const Color grey100 = AppDesign.neutral100;
  static const Color grey200 = AppDesign.neutral200;
  static const Color grey300 = AppDesign.neutral300;
  static const Color grey400 = AppDesign.neutral400;
  static const Color grey500 = AppDesign.neutral500;
  static const Color grey600 = AppDesign.neutral600;
  static const Color grey700 = AppDesign.neutral700;
  static const Color grey800 = AppDesign.neutral800;
  static const Color grey900 = AppDesign.neutral900;

  // Couleurs sémantiques
  static const Color successColor = AppDesign.success;
  static const Color errorColor = AppDesign.danger;
  static const Color warningColor = AppDesign.warning;
  static const Color infoColor = AppDesign.info;

  // Couleurs des providers de paiement
  static const Color kpayColor = Color(0xFFFF6F00); // Orange
  static const Color paypalColor = Color(0xFF0070ba); // Bleu PayPal
  static const Color bankColor =
      AppDesign.success; // Vert virement bancaire (IBAN)

  // ================================
  // BREAKPOINTS RESPONSIVE
  // ================================

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double largeTabletBreakpoint = 1024;
  static const double iPadPro13Breakpoint = 1366; // iPad Pro 13" width
  static const double desktopBreakpoint = iPadPro13Breakpoint;

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
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  // ================================
  // SYSTÈME DE TYPOGRAPHIE RESPONSIVE
  // ================================

  /// Rôles typographiques stables : le système applique lui-même TextScaler.
  static TextStyle _typeStyle(BuildContext context, FontSizeType type) {
    final text = Theme.of(context).textTheme;
    return switch (type) {
      FontSizeType.h1 => text.displayLarge!,
      FontSizeType.h2 => text.displayMedium!,
      FontSizeType.h3 => text.headlineSmall!,
      FontSizeType.h4 => text.titleLarge!,
      FontSizeType.h5 => text.titleMedium!,
      FontSizeType.h6 => text.titleSmall!,
      FontSizeType.subtitle1 => text.titleSmall!,
      FontSizeType.subtitle2 => text.labelLarge!,
      FontSizeType.body1 => text.bodyLarge!,
      FontSizeType.body2 => text.bodyMedium!,
      FontSizeType.caption => text.bodySmall!,
      FontSizeType.overline => text.labelSmall!,
      FontSizeType.button => text.labelLarge!,
    };
  }

  static double getFontSize(BuildContext context, FontSizeType type) =>
      _typeStyle(context, type).fontSize!;

  static TextStyle getTextStyle(
    BuildContext context,
    FontSizeType type, {
    FontWeight? fontWeight,
    Color? color,
    double? height,
    String fontFamily = 'SF-Pro',
  }) => _typeStyle(context, type).copyWith(
    fontWeight: fontWeight,
    color: color ?? AppDesign.textPrimary(context),
    height: height,
    fontFamily: fontFamily,
  );

  // ================================
  // ESPACEMENTS RESPONSIFS
  // ================================

  /// Gouttières stables par classe de largeur, sur la grille de quatre points.
  static double getHorizontalPadding(BuildContext context) =>
      switch (getDeviceType(context)) {
        DeviceType.mobile => AppDesign.space4,
        DeviceType.tablet => AppDesign.space6,
        DeviceType.largeTablet => AppDesign.space8,
        DeviceType.iPadPro13 => AppDesign.space10,
        DeviceType.desktop => AppDesign.space8,
      };

  static double getVerticalPadding(BuildContext context) =>
      isTabletOrLarger(context) ? AppDesign.space6 : AppDesign.space4;

  static double getSectionSpacing(BuildContext context) =>
      isTabletOrLarger(context) ? AppDesign.space8 : AppDesign.space6;

  static double getElementSpacing(BuildContext context) =>
      isTabletOrLarger(context) ? AppDesign.space4 : AppDesign.space3;

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
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Couleur de fond pour les champs de saisie (TextField, TextFormField)
  static Color getInputFieldColor(BuildContext context) =>
      AppDesign.surfaceMuted(context);

  // ================================
  // CONFIGURATIONS DE WIDGETS
  // ================================

  /// Hauteur minimale commune, indépendante de la hauteur de la fenêtre.
  static double getButtonHeight(BuildContext context) => AppDesign.minTapTarget;

  /// Padding du bottom sheet en tenant compte de la barre de navigation native
  /// Utilise viewPadding.bottom pour les barres système + viewInsets.bottom pour le clavier
  ///
  /// Réservé aux feuilles ouvertes avec `showModalBottomSheet`, qui laisse le
  /// clavier recouvrir la feuille. `Get.bottomSheet` (et donc `AppSheet.show`)
  /// remonte déjà la feuille au-dessus du clavier : y ajouter ce padding
  /// compte le clavier deux fois, laisse un grand vide et écrase le contenu.
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

  /// Adaptateur historique vers les rayons du design system.
  static double getBorderRadius(BuildContext context, BorderRadiusType type) =>
      switch (type) {
        BorderRadiusType.small => AppDesign.radiusSm,
        BorderRadiusType.medium => AppDesign.radiusMd,
        BorderRadiusType.large => AppDesign.radiusLg,
        BorderRadiusType.circular => AppDesign.radiusPill,
      };

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
    final surfaceMuted = isDark
        ? AppDesign.neutralDark700
        : AppDesign.neutral100;
    final border = isDark ? AppDesign.neutralDark600 : AppDesign.neutral200;
    final borderStrong = isDark
        ? const Color(0xFF3D3D39)
        : AppDesign.neutral300;
    final textPrimary = isDark ? const Color(0xFFF5F5F3) : AppDesign.neutral900;
    final textSecondary = isDark
        ? const Color(0xFFB0B0AA)
        : AppDesign.neutral600;
    final textTertiary = isDark ? AppDesign.neutral400 : AppDesign.neutral600;

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
        onPrimary: AppDesign.onAccent,
        primaryContainer: AppDesign.accentSubtle,
        onPrimaryContainer: AppDesign.accentText,
        secondary: isDark ? const Color(0xFFD8D8D3) : AppDesign.neutral800,
        onSecondary: isDark ? AppDesign.neutral900 : Colors.white,
        tertiary: AppDesign.accent,
        onTertiary: AppDesign.onAccent,
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

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesign.accent,
          foregroundColor: AppDesign.onAccent,
          disabledBackgroundColor: isDark
              ? AppDesign.neutralDark600
              : AppDesign.neutral200,
          disabledForegroundColor: textTertiary,
          elevation: 0,
          minimumSize: const Size(0, AppDesign.minTapTarget),
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
          foregroundColor: AppDesign.onAccent,
          minimumSize: const Size(0, AppDesign.minTapTarget),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),

      // Une seule flèche de retour, sur Android comme sur iPhone. Les écrans
      // mélangeaient quatre pictogrammes différents ; celui-ci est aussi celui
      // d'`AppBackButton`, si bien qu'un retour implicite d'AppBar et un
      // retour explicite ne se distinguent plus.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) =>
            const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        closeButtonIconBuilder: (context) => const Icon(Icons.close_rounded),
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
        backgroundColor: AppDesign.accent,
        contentTextStyle: TextStyle(
          fontFamily: 'SF-Pro',
          color: AppDesign.onAccent,
          fontSize: 14,
        ),
        actionTextColor: AppDesign.onAccent,
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

      // Texte et icônes contrastés sur le fond orange de marque.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppDesign.accent,
        foregroundColor: AppDesign.onAccent,
        elevation: 2,
        extendedTextStyle: TextStyle(
          fontFamily: 'SF-Pro',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppDesign.onAccent,
        ),
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
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.25,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.25,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: textPrimary, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          height: 1.3,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          height: 1.3,
        ),
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
  bool get isDarkMode =>
      AppThemeSystem.enableDynamicTheming &&
      Theme.of(this).brightness == Brightness.dark;

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
    final defaultTitle = title ?? 'core.login_required.title'.tr;
    final defaultMessage =
        message ??
        (featureName != null
            ? 'core.login_required.dialog_feature'.trParams({
                'feature': featureName,
              })
            : 'core.login_required.dialog_generic'.tr);

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
                        onPressed:
                            onLoginPressed ??
                            () {
                              Get.back();
                              Get.toNamed('/login');
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeSystem.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppThemeSystem.primaryColor.withValues(
                            alpha: 0.4,
                          ),
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
                              'core.login_required.sign_in'.tr,
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
    final defaultMessage =
        message ??
        (featureName != null
            ? 'core.login_required.snackbar_feature'.trParams({
                'feature': featureName,
              })
            : 'core.login_required.snackbar_generic'.tr);

    AppFeedback.show(
      'core.login_required.title'.tr,
      defaultMessage,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.primaryColor,
      colorText: Colors.white,
      icon: const Icon(Icons.lock_person_rounded, color: Colors.white),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      mainButton: TextButton(
        onPressed:
            onLoginPressed ??
            () {
              Get.back();
              Get.toNamed('/login');
            },
        child: Text(
          'core.login_required.sign_in'.tr,
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
