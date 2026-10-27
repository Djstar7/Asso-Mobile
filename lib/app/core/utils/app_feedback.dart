import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_design.dart';

/// Présentation commune des retours non bloquants des parcours métier.
class AppFeedback {
  const AppFeedback._();

  static SnackbarController? _active;
  static String? _activeTitle;
  static String? _activeMessage;

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
    // A request may report the same failure through both its caller and
    // its form handler. Reuse the visible notification instead of queuing it.
    if (_active != null && _activeTitle == title && _activeMessage == message) {
      return _active!;
    }
    final controller = Get.snackbar(
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
    _active = controller;
    _activeTitle = title;
    _activeMessage = message;
    controller.future.then((_) {
      if (identical(_active, controller)) {
        _active = null;
        _activeTitle = null;
        _activeMessage = null;
      }
    });
    return controller;
  }
}
