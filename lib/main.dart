import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'app/routes/app_pages.dart';
import 'app/core/utils/app_theme_system.dart';
import 'app/core/controllers/app_config_controller.dart';
import 'app/data/services/websocket_service.dart';
import 'app/data/services/firebase_messaging_service.dart';
import 'app/modules/notification/controllers/notification_controller.dart';

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

  // Initialiser AppConfigController pour charger les paramètres de l'app
  final appConfigController = Get.put(AppConfigController(), permanent: true);
  await appConfigController.loadSettings(); // Attendre le chargement des settings
  print('✅ AppConfigController initialized and settings loaded');

  // Initialiser les données de formatage de dates pour les locales
  await initializeDateFormatting('fr_FR', null);
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
