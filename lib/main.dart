import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'app/routes/app_pages.dart';
import 'app/core/utils/app_binding.dart';
import 'app/core/utils/app_theme_system.dart';
import 'app/core/utils/route_stack_guard.dart';
import 'app/core/widgets/app_ui.dart';
import 'app/core/widgets/app_update_gate.dart';
import 'app/core/controllers/app_config_controller.dart';
import 'app/data/services/app_lifecycle_service.dart';
import 'app/data/services/connectivity_service.dart';
import 'app/data/services/offline_product_sync_service.dart';
import 'app/data/providers/offline_store.dart';
import 'app/data/services/websocket_service.dart';
import 'app/data/services/firebase_messaging_service.dart';
import 'app/data/providers/diaspo_service.dart';
import 'app/data/providers/currency_service.dart';
import 'app/data/services/deep_link_service.dart';
import 'app/modules/notification/controllers/notification_controller.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() {
  // En production, les `print` de débogage sont coupés : plus de 1 500
  // appels, dont certains à chaque trame WebSocket ou à chaque réponse
  // d'API, qui coûtaient du temps à l'interface et écrivaient jetons et
  // numéros de téléphone dans les journaux du téléphone. En débogage, rien
  // ne change.
  runZoned(
    _bootstrap,
    zoneSpecification: kReleaseMode
        ? ZoneSpecification(print: (self, parent, zone, line) {})
        : null,
  );
}

Future<void> _bootstrap() async {
  print('');
  print('========================================');
  print('🚀 APP STARTING');
  print('========================================');

  // Binding de Flutter avec un plafond de décodage des images (mémoire).
  AppBinding.ensureInitialized();
  print('✅ Flutter binding initialized');

  await GetStorage.init();
  print('✅ GetStorage initialized');

  // Plafonne le cache d'images et libère la mémoire quand le système le
  // demande : avant tout écran, pour que le plafond s'applique dès le départ.
  Get.put(AppLifecycleService(), permanent: true);

  // Mode hors ligne vendeur : base Hive locale et joignabilité du serveur,
  // sondée avant le premier écran pour ne pas attendre un réseau absent.
  await OfflineStore.init();
  final connectivity =
      await Get.putAsync(() => ConnectivityService().init(), permanent: true);
  Get.put(OfflineProductSyncService(), permanent: true);
  print('✅ Offline store ready (online: ${connectivity.isOnline.value})');

  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase initialized');

  // Initialiser Firebase Messaging Service
  await Get.putAsync(() => FirebaseMessagingService().init(), permanent: true);
  print('✅ FirebaseMessagingService initialized');

  // Initialiser le NotificationController pour gérer les notifications FCM
  Get.put(NotificationController(), permanent: true);
  print('✅ NotificationController initialized');

  // Initialiser le WebSocketService comme service global
  Get.put(WebSocketService(), permanent: true);
  print('✅ WebSocketService initialized');

  // Initialiser le DiaspoService comme service global
  Get.put(DiaspoService(), permanent: true);
  print('✅ DiaspoService initialized');

  // Initialiser le CurrencyService pour la conversion automatique des devises
  Get.put(CurrencyService(), permanent: true);
  print('✅ CurrencyService initialized');

  // Liens partagés : le service est enregistré ici, mais n'écoute qu'une fois
  // le routeur monté (voir SplashController), pour qu'un lien de démarrage à
  // froid ne vise pas un navigateur inexistant.
  Get.put(DeepLinkService(), permanent: true);

  // Initialiser AppConfigController pour charger les paramètres de l'app
  final appConfigController = Get.put(AppConfigController(), permanent: true);
  if (connectivity.isOnline.value) {
    await appConfigController.loadSettings(); // Attendre le chargement des settings
  } else {
    // Hors ligne : l'application s'ouvre sur ses valeurs par défaut, les
    // réglages seront relus quand le serveur répondra.
    unawaited(appConfigController.loadSettings());
  }
  print('✅ AppConfigController initialized and settings loaded');

  // Initialiser les données de formatage de dates pour les locales
  await initializeDateFormatting('fr_FR', null);

  // Les durées relatives (« il y a 3 heures ») sont enregistrées une fois
  // pour toute l'application : la locale était déclarée dans une seule vue,
  // les autres retombaient donc sur l'anglais.
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setDefaultLocale('fr');
  print('✅ Date formatting initialized');

  print('🎯 Initial route: ${AppPages.INITIAL}');
  print('========================================');
  print('');

  runApp(
    GetMaterialApp(
      title: "Asso",
      debugShowCheckedModeBanner: false,
      theme: AppThemeSystem.getLightTheme(),
      darkTheme: AppThemeSystem.getDarkTheme(),
      themeMode: AppThemeSystem.enableDynamicTheming ? ThemeMode.system : ThemeMode.light,
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      unknownRoute: AppPages.unknownRoute,
      // Borne la pile : produit → boutique → produit… ne s'empile plus
      // indéfiniment en mémoire.
      navigatorObservers: [RouteStackGuard()],
      // Enveloppe le navigateur : la fenêtre de mise à jour s'y ouvre via
      // `Get.key`, et se tait tant que l'écran de démarrage est affiché.
      //
      // Le toucher hors d'un champ referme le clavier partout, feuilles et
      // dialogues compris : ils vivent sous ce navigateur.
      builder: (context, child) => AppKeyboardDismisser(
        child: AppUpdateGate(child: child ?? const SizedBox.shrink()),
      ),
      // Support de la localisation française
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
    ),
  );
}
