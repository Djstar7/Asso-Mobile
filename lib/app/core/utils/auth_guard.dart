import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/providers/storage_service.dart';
import 'app_theme_system.dart';

/// Helper class pour gérer l'authentification et afficher les alertes
class AuthGuard {
  /// Vérifie si l'utilisateur est connecté
  static bool get isAuthenticated => StorageService.isAuthenticated;

  /// Vérifie si l'utilisateur est en mode invité
  static bool get isGuest => !isAuthenticated;

  /// Exécute une action si l'utilisateur est connecté, sinon affiche un dialog
  static void requireAuth(
    BuildContext context, {
    required VoidCallback onAuthenticated,
    String? featureName,
    bool useDialog = true,
  }) {
    if (isAuthenticated) {
      onAuthenticated();
    } else {
      if (useDialog) {
        AppDialogs.showLoginRequiredDialog(
          context,
          featureName: featureName,
        );
      } else {
        AppDialogs.showLoginRequiredSnackbar(
          featureName: featureName,
        );
      }
    }
  }

  /// Vérifie si l'utilisateur peut accéder à une fonctionnalité
  /// Retourne true si authentifié, false et affiche une alerte sinon
  static bool checkAuthWithAlert(
    BuildContext context, {
    String? featureName,
    bool useDialog = true,
  }) {
    if (isAuthenticated) {
      return true;
    }

    if (useDialog) {
      AppDialogs.showLoginRequiredDialog(
        context,
        featureName: featureName,
      );
    } else {
      AppDialogs.showLoginRequiredSnackbar(
        featureName: featureName,
      );
    }

    return false;
  }

  /// Vérifie si l'utilisateur peut naviguer vers une route
  /// Retourne true et navigue si authentifié, false et affiche une alerte sinon
  static bool navigateIfAuthenticated(
    BuildContext context,
    String route, {
    dynamic arguments,
    String? featureName,
    bool useDialog = true,
  }) {
    if (isAuthenticated) {
      if (arguments != null) {
        Get.toNamed(route, arguments: arguments);
      } else {
        Get.toNamed(route);
      }
      return true;
    }

    if (useDialog) {
      AppDialogs.showLoginRequiredDialog(
        context,
        featureName: featureName,
      );
    } else {
      AppDialogs.showLoginRequiredSnackbar(
        featureName: featureName,
      );
    }

    return false;
  }

  /// Retourne le nom d'utilisateur ou "Invité"
  static String get displayName {
    final user = StorageService.getUser();
    if (user != null) {
      final name = user.name;
      if (name.isNotEmpty) {
        return name;
      }
      final phone = user.phone;
      if (phone != null && phone.isNotEmpty) {
        return phone;
      }
    }
    return 'core.auth.guest'.tr;
  }

  /// Retourne le numéro de téléphone formaté ou null
  static String? get phoneNumber {
    final user = StorageService.getUser();
    return user?.phone;
  }
}
