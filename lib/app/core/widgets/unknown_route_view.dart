import 'package:flutter/material.dart';

import '../utils/app_navigation.dart';
import '../utils/app_theme_system.dart';
import 'app_ui.dart';

/// Écran affiché quand l'application vise une route qui n'existe pas (lien
/// ancien, notification d'une version précédente…).
///
/// Sans lui, GetX levait une erreur à la navigation et rien ne s'ouvrait.
/// Le retour ramène à l'accueil s'il n'y a rien dessous.
class UnknownRouteView extends StatelessWidget {
  const UnknownRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppThemeSystem.getBackgroundColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      body: AppEmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Page introuvable',
        message: 'Cette page n’existe plus ou le lien est incomplet.',
        actionLabel: 'Retour',
        onAction: () => AppNavigation.back(context),
      ),
    );
  }
}
