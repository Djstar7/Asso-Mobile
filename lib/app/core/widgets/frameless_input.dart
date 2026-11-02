import 'package:flutter/material.dart';

/// Champ posé dans un conteneur qui dessine déjà le cadre. `border` seul ne
/// suffit pas : le thème impose aussi son fond et ses contours par état, ce
/// qui dessinerait un second cadre dans le premier.
extension FramelessInput on InputDecoration {
  InputDecoration get frameless => copyWith(
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}
