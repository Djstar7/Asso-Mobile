import 'package:flutter/widgets.dart';

import '../../routes/app_pages.dart';

/// Borne la profondeur de la pile de navigation.
///
/// Fiche produit → boutique → produit → conversation → produit… : chaque
/// rebond empile une page, et aucune n'est jamais refermée. Or une page
/// recouverte reste construite, avec ses photos décodées en mémoire : après
/// une longue session de navigation, le système finissait par tuer
/// l'application.
///
/// Au-delà de [maxPages] pages, la plus ancienne des pages « de rebond » est
/// retirée, sans animation, loin sous l'écran affiché. Le retour ramène donc
/// un peu plus tôt vers l'accueil, qui lui n'est jamais retiré.
///
/// Seules les pages qui possèdent leur propre contrôleur sont retirables
/// (voir `ScopedControllerPage`) : en retirer une ne touche pas à l'état des
/// autres, même quand elles portent le même nom de route.
class RouteStackGuard extends NavigatorObserver {
  RouteStackGuard({this.maxPages = 10});

  final int maxPages;

  /// Pages qu'on peut retirer du bas de la pile sans rien casser.
  static const Set<String> trimmable = {
    Routes.PRODUCT,
    Routes.VENDOR_DETAILS,
    Routes.CHATDETAIL,
    Routes.DIASPO_DETAIL,
    Routes.SEARCH,
  };

  final List<Route<dynamic>> _stack = [];
  bool _trimScheduled = false;

  @visibleForTesting
  int get pageCount => _stack.whereType<PageRoute<dynamic>>().length;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _scheduleTrim();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) {
      _stack[index] = newRoute;
    } else {
      if (oldRoute != null) _stack.remove(oldRoute);
      if (newRoute != null) _stack.add(newRoute);
    }
  }

  /// Le navigateur est verrouillé pendant qu'il notifie ses observateurs : le
  /// retrait attend la fin de l'image.
  void _scheduleTrim() {
    if (_trimScheduled || pageCount <= maxPages) return;
    _trimScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trimScheduled = false;
      _trim();
    });
  }

  void _trim() {
    final navigator = this.navigator;
    if (navigator == null) return;

    while (pageCount > maxPages) {
      final victim = _oldestTrimmable();
      if (victim == null) return;
      _stack.remove(victim);
      if (victim.isActive) navigator.removeRoute(victim);
    }
  }

  /// La plus ancienne page retirable, jamais la première (l'accueil) ni
  /// celle affichée, et seulement si aucune feuille ou dialogue ne lui est
  /// rattaché juste au-dessus.
  Route<dynamic>? _oldestTrimmable() {
    for (var i = 1; i < _stack.length - 1; i++) {
      final route = _stack[i];
      if (route is! PageRoute || route.isCurrent) continue;
      if (!trimmable.contains(route.settings.name)) continue;
      if (_stack[i + 1] is! PageRoute) continue;
      return route;
    }
    return null;
  }
}
