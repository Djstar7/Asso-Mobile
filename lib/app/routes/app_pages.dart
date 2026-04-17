import 'package:asso/app/modules/invoices/views/invoices_view.dart';
import 'package:get/get.dart';

import '../modules/about/bindings/about_binding.dart';
import '../modules/about/views/about_view.dart';
import '../modules/chat/bindings/chat_binding.dart';
import '../modules/chat/views/chat_view.dart';
import '../modules/chatdetail/bindings/chatdetail_binding.dart';
import '../modules/chatdetail/views/chatdetail_view.dart';
import '../modules/completeProfile/bindings/complete_profile_binding.dart';
import '../modules/completeProfile/views/complete_profile_view.dart';
import '../modules/deliveryCheck/bindings/delivery_check_binding.dart';
import '../modules/deliveryCheck/views/delivery_check_view.dart';
import '../modules/deliveryDashboard/bindings/delivery_dashboard_binding.dart';
import '../modules/deliveryDashboard/views/delivery_dashboard_view.dart';
import '../modules/faq/bindings/faq_binding.dart';
import '../modules/faq/views/faq_view.dart';
import '../modules/favorites/bindings/favorites_binding.dart';
import '../modules/favorites/views/favorites_view.dart';
import '../modules/help/bindings/help_binding.dart';
import '../modules/help/views/help_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/myOrder/bindings/my_order_binding.dart';
import '../modules/myOrder/views/my_order_view.dart';
import '../modules/notification/bindings/notification_binding.dart';
import '../modules/notification/views/notification_view.dart';
import '../modules/onboarding/bindings/onboarding_binding.dart';
import '../modules/onboarding/views/onboarding_view.dart';
import '../modules/orderManagement/bindings/order_management_binding.dart';
import '../modules/orderManagement/views/order_management_view.dart';
import '../modules/otp/bindings/otp_binding.dart';
import '../modules/otp/views/otp_view.dart';
import '../modules/post/bindings/post_binding.dart';
import '../modules/post/views/post_view.dart';
import '../modules/preferences/bindings/preferences_binding.dart';
import '../modules/preferences/views/preferences_view.dart';
import '../modules/product/bindings/product_binding.dart';
import '../modules/product/views/product_view.dart';
import '../modules/profile/bindings/profile_binding.dart';
import '../modules/profile/views/profile_view.dart';
import '../modules/register/bindings/register_binding.dart';
import '../modules/register/views/register_view.dart';
import '../modules/search/bindings/search_binding.dart';
import '../modules/search/views/search_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/shipConfig/bindings/ship_config_binding.dart';
import '../modules/shipConfig/views/ship_config_view.dart';
import '../modules/shipment/bindings/shipment_binding.dart';
import '../modules/shipment/views/shipment_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/storeManagement/bindings/store_management_binding.dart';
import '../modules/storeManagement/views/store_management_view.dart';
import '../modules/tracking/bindings/tracking_binding.dart';
import '../modules/tracking/views/tracking_view.dart';
import '../modules/vendorConfig/bindings/vendor_config_binding.dart';
import '../modules/vendorConfig/views/vendor_config_view.dart';
import '../modules/vendorDashboard/bindings/vendor_dashboard_binding.dart';
import '../modules/vendorDashboard/views/vendor_dashboard_view.dart';
import '../modules/wallet/bindings/wallet_binding.dart';
import '../modules/wallet/views/wallet_view.dart';
import '../modules/wallet/views/ussd_waiting_view.dart';
import '../modules/wallet/views/wallet_history_view.dart';
import '../modules/welcomer/bindings/welcomer_binding.dart';
import '../modules/welcomer/views/welcomer_view.dart';
import '../modules/packageSubscription/bindings/package_subscription_binding.dart';
import '../modules/packageSubscription/views/package_subscription_view.dart';
import '../modules/certificationPackages/bindings/certification_packages_binding.dart';
import '../modules/certificationPackages/views/certification_packages_view.dart';
import '../modules/addProduct/bindings/add_product_binding.dart';
import '../modules/addProduct/views/add_product_view.dart';
import '../modules/productManagement/bindings/product_management_binding.dart';
import '../modules/productManagement/views/product_management_view.dart';
import '../modules/inventoryList/bindings/inventory_list_binding.dart';
import '../modules/inventoryList/views/inventory_list_view.dart';
import '../modules/invoices/bindings/invoices_binding.dart';
import '../modules/vendorDetails/bindings/vendor_details_binding.dart';
import '../modules/vendorDetails/views/vendor_details_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: _Paths.ONBOARDING,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: _Paths.WELCOMER,
      page: () => const WelcomerView(),
      binding: WelcomerBinding(),
    ),
    GetPage(
      name: _Paths.REGISTER,
      page: () => const RegisterView(),
      binding: RegisterBinding(),
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: _Paths.SEARCH,
      page: () => const SearchView(),
      binding: SearchBinding(),
    ),
    GetPage(
      name: _Paths.CHAT,
      page: () => const ChatView(),
      binding: ChatBinding(),
    ),
    GetPage(
      name: _Paths.CHATDETAIL,
      page: () => const ChatdetailView(),
      binding: ChatdetailBinding(),
    ),
    GetPage(
      name: _Paths.NOTIFICATION,
      page: () => const NotificationView(),
      binding: NotificationBinding(),
    ),
    GetPage(
      name: _Paths.PROFILE,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
    ),
    GetPage(
      name: _Paths.TRACKING,
      page: () => const TrackingView(),
      binding: TrackingBinding(),
    ),
    GetPage(
      name: _Paths.PRODUCT,
      page: () => const ProductView(),
      binding: ProductBinding(),
    ),
    GetPage(
      name: _Paths.FAVORITES,
      page: () => const FavoritesView(),
      binding: FavoritesBinding(),
    ),
    GetPage(
      name: _Paths.SETTINGS,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: _Paths.SHIPMENT,
      page: () => const ShipmentView(),
      binding: ShipmentBinding(),
    ),
    GetPage(
      name: _Paths.PREFERENCES,
      page: () => const PreferencesView(),
      binding: PreferencesBinding(),
    ),
    GetPage(
      name: _Paths.POST,
      page: () => const PostView(),
      binding: PostBinding(),
    ),
    GetPage(
      name: _Paths.COMPLETE_PROFILE,
      page: () => const CompleteProfileView(),
      binding: CompleteProfileBinding(),
    ),
    GetPage(
      name: _Paths.OTP,
      page: () => const OtpView(),
      binding: OtpBinding(),
    ),
    GetPage(
      name: _Paths.DELIVERY_DASHBOARD,
      page: () => const DeliveryDashboardView(),
      binding: DeliveryDashboardBinding(),
    ),
    GetPage(
      name: _Paths.VENDOR_DASHBOARD,
      page: () => const VendorDashboardView(),
      binding: VendorDashboardBinding(),
    ),
    GetPage(
      name: _Paths.WALLET,
      page: () => const WalletView(),
      binding: WalletBinding(),
    ),
    GetPage(
      name: _Paths.VENDOR_CONFIG,
      page: () => const VendorConfigView(),
      binding: VendorConfigBinding(),
    ),
    GetPage(
      name: _Paths.ORDER_MANAGEMENT,
      page: () => const OrderManagementView(),
      binding: OrderManagementBinding(),
    ),
    GetPage(
      name: _Paths.STORE_MANAGEMENT,
      page: () => const StoreManagementView(),
      binding: StoreManagementBinding(),
    ),
    GetPage(
      name: _Paths.SHIP_CONFIG,
      page: () => const ShipConfigView(),
      binding: ShipConfigBinding(),
    ),
    GetPage(
      name: _Paths.DELIVERY_CHECK,
      page: () => const DeliveryCheckView(),
      binding: DeliveryCheckBinding(),
    ),
    GetPage(
      name: _Paths.MY_ORDER,
      page: () => const MyOrderView(),
      binding: MyOrderBinding(),
    ),
    GetPage(
      name: _Paths.HELP,
      page: () => const HelpView(),
      binding: HelpBinding(),
    ),
    GetPage(
      name: _Paths.FAQ,
      page: () => const FaqView(),
      binding: FaqBinding(),
    ),
    GetPage(
      name: _Paths.ABOUT,
      page: () => const AboutView(),
      binding: AboutBinding(),
    ),
    GetPage(
      name: _Paths.PACKAGE_SUBSCRIPTION,
      page: () => const PackageSubscriptionView(),
      binding: PackageSubscriptionBinding(),
    ),
    GetPage(
      name: _Paths.CERTIFICATION_PACKAGES,
      page: () => const CertificationPackagesView(),
      binding: CertificationPackagesBinding(),
    ),
    GetPage(
      name: _Paths.PRODUCT_MANAGEMENT,
      page: () => const ProductManagementView(),
      binding: ProductManagementBinding(),
    ),
    GetPage(
      name: _Paths.ADD_PRODUCT,
      page: () => const AddProductView(),
      binding: AddProductBinding(),
    ),
    GetPage(
      name: _Paths.USSD_WAITING,
      page: () => const UssdWaitingView(),
      binding: WalletBinding(),
    ),
    GetPage(
      name: _Paths.WALLET_HISTORY,
      page: () => const WalletHistoryView(),
      binding: WalletBinding(),
    ),
    GetPage(
      name: _Paths.INVENTORY_LIST,
      page: () => const InventoryListView(),
      binding: InventoryListBinding(),
    ),
    GetPage(
      name: _Paths.INVOICES,
      page: () => const InvoicesView(),
      binding: InvoicesBinding(),
    ),
    GetPage(
      name: _Paths.VENDOR_DETAILS,
      page: () => const VendorDetailsView(),
      binding: VendorDetailsBinding(),
    ),
  ];
}
