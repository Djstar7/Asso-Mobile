import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/core/controllers/app_config_controller.dart';
import 'app/core/i18n/app_translations.dart';
import 'app/core/services/locale_service.dart';
import 'app/core/utils/app_theme_system.dart';
import 'app/core/widgets/app_ui.dart';
import 'app/data/providers/currency_service.dart';
import 'app/data/providers/offline_store.dart';
import 'app/data/providers/storage_service.dart';
import 'app/data/services/connectivity_service.dart';
import 'app/data/services/offline_product_sync_service.dart';
import 'app/modules/addProduct/bindings/add_product_binding.dart';
import 'app/modules/addProduct/views/add_product_view.dart';
import 'app/modules/inventoryList/bindings/inventory_list_binding.dart';
import 'app/modules/inventoryList/views/inventory_list_view.dart';
import 'app/modules/orderManagement/bindings/order_management_binding.dart';
import 'app/modules/orderManagement/views/order_management_view.dart';
import 'app/modules/productManagement/bindings/product_management_binding.dart';
import 'app/modules/productManagement/views/product_management_view.dart';
import 'app/modules/disputes/bindings/disputes_binding.dart';
import 'app/modules/disputes/views/dispute_detail_view.dart';
import 'app/modules/disputes/views/vendor_disputes_view.dart';
import 'app/modules/shopStatistics/bindings/shop_statistics_binding.dart';
import 'app/modules/shopStatistics/views/shop_statistics_view.dart';
import 'app/modules/storeManagement/bindings/store_management_binding.dart';
import 'app/modules/storeManagement/views/store_management_view.dart';
import 'app/modules/vendorDashboard/bindings/vendor_dashboard_binding.dart';
import 'app/modules/vendorDashboard/views/vendor_dashboard_view.dart';
import 'app/modules/vendorWeb/controllers/vendor_web_login_controller.dart';
import 'app/modules/vendorWeb/views/vendor_web_login_view.dart';
import 'app/modules/vendorWeb/views/vendor_web_shell.dart';
import 'app/modules/vendorWeb/views/vendor_web_unavailable_view.dart';
import 'app/routes/app_pages.dart';

/// Espace vendeur web, servi à l'adresse /vendor.
///
/// Compilé avec --dart-define=VENDOR_WEB=true (scripts/build_vendor_web.sh). Seuls
/// les écrans déclarés ici existent : tout le reste aboutit à
/// [VendorWebUnavailableView], et le serveur refuse de toute façon au jeton web
/// les routes hors de sa liste blanche.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetStorage.init();
  await StorageService.initSecureStorage();

  final translations = await AppTranslations.load();
  final localeService = await Get.putAsync(
    () => LocaleService().init(),
    permanent: true,
  );

  await OfflineStore.init();
  await Get.putAsync(() => ConnectivityService().init(), permanent: true);
  Get.put(OfflineProductSyncService(), permanent: true);
  Get.put(CurrencyService(), permanent: true);
  unawaited(Get.put(AppConfigController(), permanent: true).loadSettings());

  runApp(
    GetMaterialApp(
      title: 'ASSO Vendeur',
      debugShowCheckedModeBanner: false,
      theme: AppThemeSystem.getLightTheme(),
      darkTheme: AppThemeSystem.getDarkTheme(),
      themeMode: AppThemeSystem.enableDynamicTheming
          ? ThemeMode.system
          : ThemeMode.light,
      initialRoute: StorageService.isAuthenticated
          ? Routes.VENDOR_DASHBOARD
          : Routes.LOGIN,
      getPages: vendorWebPages,
      unknownRoute: GetPage(
        name: '/indisponible',
        page: () => const VendorWebUnavailableView(),
      ),
      navigatorObservers: [VendorWebRouteObserver()],
      builder: (context, child) => AppKeyboardDismisser(
        child: VendorWebShell(child: child ?? const SizedBox.shrink()),
      ),
      translations: translations,
      fallbackLocale: LocaleService.french,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [LocaleService.french, LocaleService.english],
      locale: localeService.currentLocale,
    ),
  );
}

/// Le périmètre de l'espace web.
final List<GetPage<dynamic>> vendorWebPages = [
  GetPage(
    // La session expirée renvoie ici (ApiProvider), comme dans l'application.
    name: Routes.LOGIN,
    page: () => const VendorWebLoginView(),
    binding: BindingsBuilder(() => Get.lazyPut(VendorWebLoginController.new)),
  ),
  GetPage(
    name: Routes.VENDOR_DASHBOARD,
    page: () => const VendorDashboardView(),
    binding: VendorDashboardBinding(),
  ),
  GetPage(
    // Le retour sans écran précédent vise l'accueil : ici, le tableau de bord.
    name: Routes.HOME,
    page: () => const VendorDashboardView(),
    binding: VendorDashboardBinding(),
  ),
  GetPage(
    name: Routes.PRODUCT_MANAGEMENT,
    page: () => const ProductManagementView(),
    binding: ProductManagementBinding(),
  ),
  GetPage(
    name: Routes.ADD_PRODUCT,
    page: () => const AddProductView(),
    binding: AddProductBinding(),
  ),
  GetPage(
    name: Routes.ORDER_MANAGEMENT,
    page: () => const OrderManagementView(),
    binding: OrderManagementBinding(),
  ),
  GetPage(
    name: Routes.STORE_MANAGEMENT,
    page: () => const StoreManagementView(),
    binding: StoreManagementBinding(),
  ),
  GetPage(
    name: Routes.SHOP_STATISTICS,
    page: () => const ShopStatisticsView(),
    binding: ShopStatisticsBinding(),
  ),
  GetPage(
    name: Routes.VENDOR_DISPUTES,
    page: () => const VendorDisputesView(),
    binding: VendorDisputesBinding(),
  ),
  GetPage(
    name: Routes.DISPUTE_DETAIL,
    page: () => const DisputeDetailView(),
    binding: DisputeDetailBinding(),
  ),
  GetPage(
    name: Routes.INVENTORY_LIST,
    page: () => const InventoryListView(),
    binding: InventoryListBinding(),
  ),
];
