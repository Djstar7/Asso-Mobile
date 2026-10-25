import 'package:flutter/material.dart';

/// Palette de marque ASSO, issue de l'orange de référence fourni (#FC9141).
/// Toute couleur d'action passe par ces tokens, y compris les anciens thèmes.
abstract final class AppBrandColors {
  static const primary = Color(0xFFFC9141);
  static const hover = Color(0xFFF7832C);
  static const pressed = Color(0xFFEF751F);
  static const subtle = Color(0xFFFFF2E8);
  static const border = Color(0xFFFFD3B2);
  static const text = Color(0xFF9A4108);

  /// Texte et icônes toujours blancs sur les fonds orange de marque.
  static const onPrimary = Colors.white;
}
