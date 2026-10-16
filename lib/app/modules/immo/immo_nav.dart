import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../chatdetail/views/chatdetail_view.dart';
import 'views/immo_cabinet_view.dart';
import 'views/immo_favorites_view.dart';
import 'views/immo_home_view.dart';
import 'views/immo_listing_view.dart';
import 'views/immo_project_view.dart';
import 'views/immo_reservation_view.dart';
import 'views/immo_reserve_view.dart';
import 'views/immo_room_tour_view.dart';

/// Navigation de la rubrique Immobilier.
///
/// La rubrique s'ouvre depuis la tuile « Immobilier » de l'accueil, dans le
/// corps de l'accueil : ses pages s'empilent dans ce navigateur imbriqué, si
/// bien que la barre du bas reste visible de la liste jusqu'au paiement.
class ImmoNav {
  const ImmoNav._();

  static const int id = 41;

  static const String home = '/';
  static const String listing = '/listing';
  static const String tour = '/tour';
  static const String cabinet = '/cabinet';
  static const String project = '/project';
  static const String favorites = '/favorites';
  static const String chat = '/chat';
  static const String reserve = '/reserve';
  static const String reservation = '/reservation';
  static const String reservations = '/reservations';

  static NavigatorState? get _navigator => Get.nestedKey(id)?.currentState;

  /// Page affichée en haut de la pile : la barre du haut de l'accueil suit.
  static final RxString currentRoute = home.obs;

  /// Titre de la barre du haut pour la page affichée.
  static String get title => switch (currentRoute.value) {
        favorites => 'immo.favorites.title'.tr,
        project => 'immo.project.cta'.tr,
        cabinet => 'immo.cabinet.title'.tr,
        reserve => 'immo.detail.reserve'.tr,
        reservation => 'immo.booking.title'.tr,
        reservations => 'immo.booking.list_title'.tr,
        _ => 'immo.title'.tr,
      };

  /// La conversation et la visite ont leur propre barre : celle de
  /// l'accueil s'efface pour ne pas doubler le bouton retour.
  static bool get hidesTopBar => currentRoute.value == chat || currentRoute.value == tour;

  static Future<void> push(String route, {Object? arguments}) async {
    await _navigator?.pushNamed<Object?>(route, arguments: arguments);
  }

  static bool get canPop => _navigator?.canPop() ?? false;

  static Future<bool> maybePop() async => await _navigator?.maybePop() ?? false;

  static void popToRoot() => _navigator?.popUntil((r) => r.isFirst);

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    Widget page;

    switch (settings.name) {
      case listing:
        page = ImmoListingView(listingId: args as int);
      case tour:
        page = ImmoRoomTourView(args: args as ImmoRoomTourArgs);
      case cabinet:
        page = ImmoCabinetView(cabinetId: args as int);
      case project:
        page = ImmoProjectView(hasLand: args as bool?);
      case favorites:
        page = const ImmoFavoritesView();
      case reserve:
        page = ImmoReserveView(args: args as ImmoReserveArgs);
      case reservation:
        page = ImmoReservationView(reservationId: args as int);
      case reservations:
        page = const ImmoReservationsView();
      case chat:
        // La conversation lit ses arguments dans Get.arguments, alimenté
        // d'ordinaire par le navigateur racine.
        Get.routing.args = args;
        page = const ChatdetailPage();
      default:
        page = const ImmoHomeView();
    }

    return GetPageRoute(settings: settings, page: () => page);
  }
}

/// Corps de l'accueil quand la rubrique est ouverte.
class ImmoShell extends StatelessWidget {
  const ImmoShell({super.key, this.initialRoute, this.initialArguments});

  final String? initialRoute;
  final Object? initialArguments;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: Get.nestedKey(ImmoNav.id),
      observers: [_ImmoRouteObserver()],
      onGenerateInitialRoutes: (navigator, _) => [
        ImmoNav.onGenerateRoute(const RouteSettings(name: ImmoNav.home)),
        if (initialRoute != null && initialRoute != ImmoNav.home)
          ImmoNav.onGenerateRoute(RouteSettings(name: initialRoute, arguments: initialArguments)),
      ],
      onGenerateRoute: ImmoNav.onGenerateRoute,
    );
  }
}

class _ImmoRouteObserver extends NavigatorObserver {
  void _sync(Route<dynamic>? top) {
    final name = top?.settings.name;
    // Le changement arrive pendant la construction du navigateur.
    WidgetsBinding.instance.addPostFrameCallback((_) => ImmoNav.currentRoute.value = name ?? ImmoNav.home);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _sync(newRoute);
}
