import 'package:flutter/material.dart';

import 'app_design.dart';
import 'app_theme_system.dart';

class Responsive {
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // Breakpoints
  static bool isMobile(BuildContext context) =>
      width(context) < AppThemeSystem.mobileBreakpoint;
  static bool isTablet(BuildContext context) =>
      width(context) >= AppThemeSystem.mobileBreakpoint &&
      width(context) < AppThemeSystem.desktopBreakpoint;
  static bool isDesktop(BuildContext context) =>
      width(context) >= AppThemeSystem.desktopBreakpoint;

  // Spacing
  static double sp(BuildContext context, double value) {
    return (width(context) / 375) * value; // 375 is base mobile width
  }

  // Font sizes responsive
  static double fontSize(BuildContext context, double size) {
    return sp(context, size);
  }

  // Padding & Margin
  static const double paddingXS = 4;
  static const double paddingSM = 8;
  static const double paddingMD = 16;
  static const double paddingLG = 24;
  static const double paddingXL = 32;

  // Border radius
  static const double radiusSM = AppDesign.radiusSm;
  static const double radiusMD = AppDesign.radiusMd;
  static const double radiusLG = AppDesign.radiusLg;
  static const double radiusXL = AppDesign.radiusXl;

  // Icon sizes
  static const double iconSM = 16;
  static const double iconMD = 24;
  static const double iconLG = 32;
  static const double iconXL = 48;

  // Responsive value
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }
}

// Extension for easier access
extension ResponsiveExtension on BuildContext {
  double get width => Responsive.width(this);
  double get height => Responsive.height(this);
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
}
