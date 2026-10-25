import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_design.dart';

/// Présentation commune des retours non bloquants des parcours métier.
class AppFeedback {
  const AppFeedback._();

  static void show(
    String title,
    String message, {
    Color? backgroundColor,
    Color? colorText,
    SnackPosition snackPosition = SnackPosition.BOTTOM,
    Duration duration = const Duration(seconds: 4),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: snackPosition,
      duration: duration,
      margin: const EdgeInsets.all(AppDesign.space4),
      borderRadius: AppDesign.radiusMd,
      backgroundColor: backgroundColor ?? AppDesign.neutral900,
      colorText: colorText ?? AppDesign.neutral0,
      maxWidth: 560,
    );
  }
}
