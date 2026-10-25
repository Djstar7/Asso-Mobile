import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_design.dart';

/// Présentation commune des retours non bloquants des parcours métier.
class AppFeedback {
  const AppFeedback._();

  static SnackbarController show(
    String title,
    String message, {
    Color? backgroundColor,
    Color? colorText,
    SnackPosition snackPosition = SnackPosition.BOTTOM,
    Duration duration = const Duration(seconds: 4),
    EdgeInsets margin = const EdgeInsets.all(AppDesign.space4),
    double borderRadius = AppDesign.radiusMd,
    Widget? icon,
    TextButton? mainButton,
    List<BoxShadow>? boxShadows,
    double maxWidth = 560,
  }) {
    return Get.snackbar(
      title,
      message,
      snackPosition: snackPosition,
      duration: duration,
      margin: margin,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor ?? AppDesign.accent,
      colorText: colorText ?? AppDesign.onAccent,
      icon: icon,
      mainButton: mainButton,
      boxShadows: boxShadows,
      maxWidth: maxWidth,
    );
  }
}
