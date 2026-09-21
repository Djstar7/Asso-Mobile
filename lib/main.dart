import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'app/routes/app_pages.dart';
import 'app/core/utils/app_theme_system.dart';
import 'app/core/widgets/app_update_gate.dart';
import 'app/core/controllers/app_config_controller.dart';
import 'app/data/services/websocket_service.dart';
import 'app/data/services/firebase_messaging_service.dart';
import 'app/data/providers/diaspo_service.dart';
import 'app/data/providers/currency_service.dart';
import 'app/data/services/deep_link_service.dart';
import 'app/modules/notification/controllers/notification_controller.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  print('');
  print('========================================');
  print('🚀 APP STARTING');
  print('========================================');

  WidgetsFlutterBinding.ensureInitialized();
  print('✅ Flutter binding initialized');

  await GetStorage.init();
  print('✅ GetStorage initialized');

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
  await appConfigController.loadSettings(); // Attendre le chargement des settings
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
      // Enveloppe les routes plutôt que l'application : la fenêtre de mise à
      // jour a ainsi un Navigator au-dessus d'elle, et ne s'ouvre pas par
      // dessus l'écran de démarrage.
      builder: (context, child) => AppUpdateGate(child: child ?? const SizedBox.shrink()),
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
