import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Police des captures de référence : Roboto du SDK Flutter, celle de
/// l'application sur Android. Sans elle, les tests écrivent en rectangles.
Future<void> loadGoldenFonts() async {
  final fonts =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final weight in ['Light', 'Regular', 'Medium', 'Bold', 'Black']) {
    final bytes = File('$fonts/Roboto-$weight.ttf').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();
}

/// Les boutons et barres du thème ne nomment aucune police : le téléphone prend
/// celle du système, les tests leur police à rectangles. On y nomme Roboto.
ThemeData withGoldenFont(ThemeData theme) {
  ButtonStyle? named(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) =>
          style.textStyle?.resolve(states)?.copyWith(fontFamily: 'Roboto'),
    ),
  );

  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: named(theme.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: named(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: named(theme.textButtonTheme.style),
    ),
  );
}
