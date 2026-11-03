import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/storage_service.dart';
import '../../../routes/app_pages.dart';

/// Écran courant, tenu à jour pour la barre latérale : `Get.currentRoute` n'est
/// pas observable.
class VendorWebRouteObserver extends NavigatorObserver {
  static final current = ''.obs;

  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (route is PageRoute && name != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => current.value = name);
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _update(newRoute);
}

/// Adapte l'application, pensée pour le téléphone, à un grand écran : barre
/// latérale de navigation et colonne de contenu à largeur lisible.
class VendorWebShell extends StatelessWidget {
  const VendorWebShell({super.key, required this.child});

  final Widget child;

  static const double _railBreakpoint = 900;
  static const double _contentMaxWidth = 1100;

  static const List<_Destination> _destinations = [
    _Destination(
      Routes.VENDOR_DASHBOARD,
      Icons.dashboard_outlined,
      'vendor_web.nav.dashboard',
    ),
    _Destination(
      Routes.PRODUCT_MANAGEMENT,
      Icons.inventory_2_outlined,
      'vendor_web.nav.products',
    ),
    _Destination(
      Routes.ADD_PRODUCT,
      Icons.add_box_outlined,
      'vendor_web.nav.add_product',
    ),
    _Destination(
      Routes.ORDER_MANAGEMENT,
      Icons.receipt_long_outlined,
      'vendor_web.nav.orders',
    ),
    _Destination(
      Routes.STORE_MANAGEMENT,
      Icons.storefront_outlined,
      'vendor_web.nav.shop',
    ),
    _Destination(
      Routes.SHOP_STATISTICS,
      Icons.insights_outlined,
      'vendor_web.nav.statistics',
    ),
  ];

  /// Le tableau de bord reste à la base de la pile : le retour y ramène.
  void _open(String route) {
    if (route == Routes.VENDOR_DASHBOARD) {
      Get.offAllNamed(route);
    } else {
      Get.offNamedUntil(
        route,
        (r) => r.settings.name == Routes.VENDOR_DASHBOARD,
      );
    }
  }

  Future<void> _signOut() async {
    // Révoque le jeton côté serveur ; la session locale part dans tous les cas.
    try {
      await ApiProvider.post('/v1/auth/logout');
    } finally {
      await StorageService.clearAuthSession();
      Get.offAllNamed(Routes.LOGIN);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _railBreakpoint;

        return Obx(() {
          final route = VendorWebRouteObserver.current.value;
          final showRail = wide && route.isNotEmpty && route != Routes.LOGIN;
          if (!showRail) return child;

          final selected = _destinations.indexWhere((d) => d.route == route);
          const railWidth = 88.0;
          final media = MediaQuery.of(context);
          final contentWidth = (constraints.maxWidth - railWidth).clamp(
            0.0,
            _contentMaxWidth,
          );

          return Material(
            child: Row(
              children: [
                NavigationRail(
                  minWidth: railWidth,
                  selectedIndex: selected < 0 ? null : selected,
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: AppDesign.accent.withValues(alpha: 0.15),
                  onDestinationSelected: (i) => _open(_destinations[i].route),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.labelKey.tr),
                      ),
                  ],
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDesign.space3,
                        ),
                        // Libellé plutôt qu'infobulle : cette barre est au-dessus
                        // du navigateur, où il n'y a pas d'Overlay pour l'afficher.
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusLg,
                          ),
                          onTap: _signOut,
                          child: Padding(
                            padding: const EdgeInsets.all(AppDesign.space2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.logout_rounded),
                                const SizedBox(height: AppDesign.space1),
                                Text(
                                  'vendor_web.nav.sign_out'.tr,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: contentWidth - 1,
                      // Les écrans lisent la largeur dans MediaQuery : sans
                      // cette correction, ils se croiraient en pleine largeur.
                      child: MediaQuery(
                        data: media.copyWith(
                          size: Size(contentWidth - 1, media.size.height),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

class _Destination {
  const _Destination(this.route, this.icon, this.labelKey);

  final String route;
  final IconData icon;
  final String labelKey;
}
