import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:asso/app/core/utils/app_theme_system.dart';

/// The same theme, locale and text scaling contract used by the app.
Widget themedApp(
  Widget home, {
  double textScale = 1,
  ThemeMode mode = ThemeMode.light,
}) => GetMaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppThemeSystem.getLightTheme(),
  darkTheme: AppThemeSystem.getDarkTheme(),
  themeMode: mode,
  locale: const Locale('fr', 'FR'),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);
