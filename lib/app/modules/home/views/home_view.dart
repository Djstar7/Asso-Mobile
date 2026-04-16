import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/values/constants.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../routes/app_pages.dart';
import '../../chat/views/chat_view.dart';
import '../../tracking/views/tracking_view.dart';
import '../../profile/views/profile_view.dart';
import '../../wallet/views/wallet_view.dart';
import '../../notification/controllers/notification_controller.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    print('');
    print('========================================');
    print('🎨 HOME VIEW: build() CALLED');
    print('========================================');
    print('  └─ Controller found: ${Get.isRegistered<HomeController>()}');
    if (Get.isRegistered<HomeController>()) {
      print('  └─ Controller hashCode: ${controller.hashCode}');
      print('  └─ TabController exists: ${controller.tabController != null}');
      if (controller.tabController != null) {
        print('  └─ TabController hashCode: ${controller.tabController.hashCode}');
      }
    }
    print('========================================');
    print('');

    final isDark = AppThemeSystem.isDarkMode(context);
    final deviceType = AppThemeSystem.getDeviceType(context);

    // Protection contre l'utilisation d'un controller disposé
    if (!controller.isSafe) {
      return Scaffold(
        backgroundColor: AppThemeSystem.getBackgroundColor(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // Supprimé key pour éviter le problème de GlobalKey duplicate
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      drawer: _buildDrawer(context),
      body: NestedScrollView(
        controller: controller.nestedScrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: false,
              pinned: true,
              snap: false,
              stretch: false,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              backgroundColor: isDark
                  ? AppThemeSystem.darkCardColor
                  : Colors.white,
              toolbarHeight: deviceType == DeviceType.mobile ? 64 : 72,
              titleSpacing: 0,
              forceElevated: true,
              primary: true,
              flexibleSpace: SafeArea(
                child: Container(
                  height: deviceType == DeviceType.mobile ? 64 : 72,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppThemeSystem.getHorizontalPadding(context),
                  ),
                  child: Row(
                    children: [
                      // Hamburger menu button (left side)
                      Builder(
                        builder: (BuildContext scaffoldContext) {
                          return IconButton(
                            icon: Icon(
                              Icons.menu_rounded,
                              color: AppThemeSystem.getPrimaryTextColor(context),
                              size: deviceType == DeviceType.mobile ? 24 : 28,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth: deviceType == DeviceType.mobile ? 40 : 48,
                              minHeight: deviceType == DeviceType.mobile ? 40 : 48,
                            ),
                            onPressed: () {
                              Scaffold.of(scaffoldContext).openDrawer();
                            },
                          );
                        },
                      ),

                      // User profile section
                      Expanded(
                        child: Row(
                          children: [
                            SizedBox(width: AppThemeSystem.getElementSpacing(context) * 0.3),
                            Container(
                              width: deviceType == DeviceType.mobile ? 36 : 40,
                              height: deviceType == DeviceType.mobile ? 36 : 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppThemeSystem.primaryColor,
                                    AppThemeSystem.tertiaryColor,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                  width: deviceType == DeviceType.mobile ? 36 : 40,
                                  height: deviceType == DeviceType.mobile ? 36 : 40,
                                ),
                              ),
                            ),
                            SizedBox(width: AppThemeSystem.getElementSpacing(context) * 0.4),
                            Flexible(
                              child: Text(
                                'ASSO',
                                style: context.textStyle(
                                  deviceType == DeviceType.mobile
                                    ? FontSizeType.body2
                                    : FontSizeType.body1,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action icons (right side)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search icon
                          _buildCompactIconButton(
                            context: context,
                            icon: Icon(
                              Icons.search_rounded,
                              color: AppThemeSystem.getPrimaryTextColor(context),
                            ),
                            onPressed: () {
                              Get.toNamed('/search');
                            },
                          ),

                          // Camera icon for image search - hide on very small screens
                          if (MediaQuery.of(context).size.width > 360)
                            _buildCompactIconButton(
                              context: context,
                              icon: Icon(
                                Icons.camera_alt_rounded,
                                color: AppThemeSystem.getPrimaryTextColor(context),
                              ),
                              onPressed: () {
                                Get.snackbar(
                                  'Recherche par image',
                                  'Prenez une photo pour rechercher des produits similaires',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              },
                            ),

                          // Wishlist icon
                          _buildCompactIconButton(
                            context: context,
                            icon: Icon(
                              Icons.favorite_border_rounded,
                              color: AppThemeSystem.getPrimaryTextColor(context),
                            ),
                            onPressed: () {
                              AuthGuard.navigateIfAuthenticated(
                                context,
                                '/favorites',
                                featureName: 'vos favoris',
                                useDialog: false,
                              );
                            },
                          ),

                          // Notifications icon with badge
                          GetX<NotificationController>(
                            builder: (notifController) {
                              final count = notifController.unreadCount.value;
                              return _buildCompactIconButtonWithBadge(
                                context: context,
                                icon: Icon(
                                  Icons.notifications_outlined,
                                  color: AppThemeSystem.getPrimaryTextColor(context),
                                ),
                                badgeCount: count > 0 ? count.toString() : null,
                                onPressed: () {
                                  AuthGuard.navigateIfAuthenticated(
                                    context,
                                    '/notification',
                                    featureName: 'les notifications',
                                    useDialog: false,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(
                  deviceType == DeviceType.mobile ? 72 : 80,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppThemeSystem.darkCardColor
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? AppThemeSystem.grey800.withValues(alpha: 0.6)
                            : AppThemeSystem.grey200,
                        width: 1,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppThemeSystem.getHorizontalPadding(context) * 0.5,
                  ),
                  child: controller.isSafe
                      ? TabBar(
                          controller: controller.tabController,
                          onTap: controller.handleTabTap,
                          indicatorColor: AppThemeSystem.primaryColor,
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: AppThemeSystem.primaryColor,
                          unselectedLabelColor: isDark
                              ? AppThemeSystem.grey400
                              : AppThemeSystem.grey600,
                          labelStyle: context.textStyle(FontSizeType.caption).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: deviceType == DeviceType.mobile ? 11 : 13,
                          ),
                          unselectedLabelStyle: context.textStyle(FontSizeType.caption).copyWith(
                            fontWeight: FontWeight.normal,
                            fontSize: deviceType == DeviceType.mobile ? 11 : 13,
                          ),
                          tabs: [
                            // Accueil
                            Tab(
                              height: deviceType == DeviceType.mobile ? 64 : 72,
                              icon: Icon(Icons.home_rounded, size: deviceType == DeviceType.mobile ? 24 : 28),
                              text: controller.tabNames[0],
                            ),
                            // Messages
                            Tab(
                              height: deviceType == DeviceType.mobile ? 64 : 72,
                              icon: Icon(Icons.chat_bubble_outline_rounded, size: deviceType == DeviceType.mobile ? 24 : 28),
                              text: controller.tabNames[1],
                            ),
                            // Portefeuille
                            Tab(
                              height: deviceType == DeviceType.mobile ? 64 : 72,
                              icon: Icon(Icons.account_balance_wallet_rounded, size: deviceType == DeviceType.mobile ? 24 : 28),
                              text: controller.tabNames[2],
                            ),
                            // Tracking
                            Tab(
                              height: deviceType == DeviceType.mobile ? 64 : 72,
                              icon: Icon(Icons.local_shipping_outlined, size: deviceType == DeviceType.mobile ? 24 : 28),
                              text: controller.tabNames[3],
                            ),
                            // Profile
                            Tab(
                              height: deviceType == DeviceType.mobile ? 64 : 72,
                              icon: Icon(Icons.person_outline_rounded, size: deviceType == DeviceType.mobile ? 24 : 28),
                              text: controller.tabNames[4],
                            ),
                          ],
                        )
                      : SizedBox(
                          height: deviceType == DeviceType.mobile ? 72 : 80,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                ),
              ),
            ),
          ];
        },
        body: controller.isSafe
            ? TabBarView(
                controller: controller.tabController,
                children: const [
                  HomeItemView(),
                  ChatView(),
                  WalletView(),
                  TrackingView(),
                  ProfileView(),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        children: [
          // Header du drawer avec dégradé
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppThemeSystem.primaryColor,
                  AppThemeSystem.tertiaryColor,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppThemeSystem.getHorizontalPadding(context),
                  vertical: AppThemeSystem.getVerticalPadding(context) * 1.5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar avec bordure
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: AppThemeSystem.primaryColor,
                        size: 36,
                      ),
                    ),

                    SizedBox(height: AppThemeSystem.getElementSpacing(context)),

                    // User info from storage
                    Builder(
                      builder: (context) {
                        final user = StorageService.getUser();
                        final isAuthenticated = StorageService.isAuthenticated;

                        if (isAuthenticated && user != null && user.phone != null) {
                          // Extract country code and phone number
                          String phone = user.phone!;
                          String countryCode = '+237';
                          String phoneNumber = phone;

                          if (phone.startsWith('+')) {
                            final parts = phone.substring(1).split(RegExp(r'(?<=^\d{3})'));
                            if (parts.length > 1) {
                              countryCode = '+${parts[0]}';
                              phoneNumber = parts.sublist(1).join();
                            }
                          }

                          return Row(
                            children: [
                              // Flag Cameroun
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: context.borderRadius(BorderRadiusType.small),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '🇨🇲',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      countryCode,
                                      style: context.textStyle(
                                        FontSizeType.caption,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  phoneNumber,
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Guest mode
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: context.borderRadius(BorderRadiusType.small),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Mode invité',
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Menu items avec scroll
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                vertical: AppThemeSystem.getVerticalPadding(context) * 0.5,
              ),
              children: [
                // SECTION: MON COMPTE
                _buildSectionHeader(context, 'Mon Compte'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.favorite_rounded,
                  title: 'Mes préférences',
                  onTap: () {
                    Get.back();
                    AuthGuard.navigateIfAuthenticated(
                      context,
                      Routes.PREFERENCES,
                      featureName: 'vos préférences',
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.shopping_bag_rounded,
                  title: 'Mes commandes',
                  onTap: () {
                    Get.back();
                    AuthGuard.navigateIfAuthenticated(
                      context,
                      '/shipment',
                      featureName: 'vos commandes',
                    );
                  },
                ),
                SizedBox(height: AppThemeSystem.getElementSpacing(context)),
                Divider(
                  color: context.borderColor,
                  height: 1,
                  indent: AppThemeSystem.getHorizontalPadding(context),
                  endIndent: AppThemeSystem.getHorizontalPadding(context),
                ),

                // SECTION: MODES
                _buildSectionHeader(context, 'Modes'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.delivery_dining_rounded,
                  title: 'Mode Livreur',
                  badge: 'Nouveau',
                  onTap: () {
                    Get.back();
                    AuthGuard.navigateIfAuthenticated(
                      context,
                      '/delivery-check',
                      featureName: 'le mode livreur',
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    final user = StorageService.getUser();
                    final isVendor = user?.isVendor ?? false;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppThemeSystem.getHorizontalPadding(context) * 0.5,
                        vertical: 2,
                      ),
                      child: InkWell(
                        onTap: () {
                          Get.back();
                          // Vérifier l'authentification avant d'accéder au mode vendeur
                          if (AuthGuard.isGuest) {
                            AppDialogs.showLoginRequiredDialog(
                              context,
                              featureName: 'le mode vendeur',
                            );
                          } else {
                            controller.handleVendorModeNavigation();
                          }
                        },
                        borderRadius: context.borderRadius(BorderRadiusType.small),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemeSystem.getHorizontalPadding(context) * 0.5,
                            vertical: AppThemeSystem.getVerticalPadding(context) * 0.5,
                          ),
                          child: Row(
                            children: [
                              // Icône
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: context.borderRadius(BorderRadiusType.small),
                                ),
                                child: Icon(
                                  Icons.store_rounded,
                                  color: AppThemeSystem.primaryColor,
                                  size: 20,
                                ),
                              ),

                              SizedBox(width: 12),

                              // Titre
                              Expanded(
                                child: Text(
                                  'Mode Vendeur',
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              // Badge vendeur actif
                              if (isVendor) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppThemeSystem.successColor.withValues(alpha: 0.15),
                                    borderRadius: context.borderRadius(BorderRadiusType.small),
                                    border: Border.all(
                                      color: AppThemeSystem.successColor.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: AppThemeSystem.successColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Actif',
                                        style: context.textStyle(
                                          FontSizeType.overline,
                                          color: AppThemeSystem.successColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],

                              // Chevron
                              Icon(
                                Icons.chevron_right_rounded,
                                color: context.secondaryTextColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: AppThemeSystem.getElementSpacing(context)),
                Divider(
                  color: context.borderColor,
                  height: 1,
                  indent: AppThemeSystem.getHorizontalPadding(context),
                  endIndent: AppThemeSystem.getHorizontalPadding(context),
                ),

                // SECTION: PARAMÈTRES
                _buildSectionHeader(context, 'Paramètres'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_rounded,
                  title: 'Paramètres',
                  onTap: () {
                    Get.back();
                    Get.toNamed('/settings');
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.share_rounded,
                  title: 'Inviter un ami(e)',
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'Partager',
                      'Partagez Asso avec vos amis et gagnez des récompenses!',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 3),
                      backgroundColor: AppThemeSystem.primaryColor,
                      colorText: Colors.white,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                  },
                ),

                SizedBox(height: AppThemeSystem.getElementSpacing(context)),
                Divider(
                  color: context.borderColor,
                  height: 1,
                  indent: AppThemeSystem.getHorizontalPadding(context),
                  endIndent: AppThemeSystem.getHorizontalPadding(context),
                ),

                // SECTION: AIDE & SUPPORT
                _buildSectionHeader(context, 'Aide & Support'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.help_outline_rounded,
                  title: 'Aide & Support',
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'Support',
                      'Contactez-nous à support@asso.cm ou appelez le 1234',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 3),
                      backgroundColor: AppThemeSystem.infoColor,
                      colorText: Colors.white,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.quiz_rounded,
                  title: 'FAQ',
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'FAQ',
                      'Questions fréquemment posées - En cours de développement',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 2),
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: 'À Propos',
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'À Propos',
                      'Asso v1.0.0 - Votre marketplace au Cameroun',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 2),
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                  },
                ),

                SizedBox(height: AppThemeSystem.getElementSpacing(context)),
              ],
            ),
          ),

          // Footer avec déconnexion / connexion
          Container(
            padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: context.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: InkWell(
                onTap: () {
                  Get.back();
                  if (AuthGuard.isGuest) {
                    // Invité - rediriger vers la page de connexion
                    Get.toNamed('/login');
                  } else {
                    // Utilisateur connecté - afficher dialog de confirmation de déconnexion
                    Get.dialog(
                      AlertDialog(
                        title: Text(
                          'Déconnexion',
                          style: context.textStyle(
                            FontSizeType.h5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          'Êtes-vous sûr de vouloir vous déconnecter ?',
                          style: context.textStyle(FontSizeType.body2),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: Text(
                              'Annuler',
                              style: context.textStyle(
                                FontSizeType.button,
                                color: context.secondaryTextColor,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Get.back();
                              await AuthService.logout();
                              Get.offAllNamed('/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeSystem.errorColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              'Déconnexion',
                              style: context.textStyle(
                                FontSizeType.button,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppThemeSystem.getHorizontalPadding(context) * 0.75,
                    vertical: AppThemeSystem.getVerticalPadding(context) * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: AuthGuard.isGuest
                        ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                        : AppThemeSystem.errorColor.withValues(alpha: 0.1),
                    borderRadius: context.borderRadius(BorderRadiusType.medium),
                    border: Border.all(
                      color: AuthGuard.isGuest
                          ? AppThemeSystem.primaryColor.withValues(alpha: 0.3)
                          : AppThemeSystem.errorColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AuthGuard.isGuest ? Icons.login_rounded : Icons.logout_rounded,
                        color: AuthGuard.isGuest
                            ? AppThemeSystem.primaryColor
                            : AppThemeSystem.errorColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AuthGuard.isGuest ? 'Se connecter' : 'Déconnexion',
                        style: context.textStyle(
                          FontSizeType.body1,
                          color: AuthGuard.isGuest
                              ? AppThemeSystem.primaryColor
                              : AppThemeSystem.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppThemeSystem.getHorizontalPadding(context),
        AppThemeSystem.getVerticalPadding(context) * 0.75,
        AppThemeSystem.getHorizontalPadding(context),
        AppThemeSystem.getVerticalPadding(context) * 0.25,
      ),
      child: Text(
        title.toUpperCase(),
        style: context.textStyle(
          FontSizeType.caption,
          color: context.secondaryTextColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context) * 0.5,
        vertical: 2,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: context.borderRadius(BorderRadiusType.small),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppThemeSystem.getHorizontalPadding(context) * 0.5,
            vertical: AppThemeSystem.getVerticalPadding(context) * 0.5,
          ),
          child: Row(
            children: [
              // Icône
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: context.borderRadius(BorderRadiusType.small),
                ),
                child: Icon(
                  icon,
                  color: AppThemeSystem.primaryColor,
                  size: 20,
                ),
              ),

              SizedBox(width: 12),

              // Titre
              Expanded(
                child: Text(
                  title,
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Badge (optionnel)
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppThemeSystem.primaryColor,
                        AppThemeSystem.tertiaryColor,
                      ],
                    ),
                    borderRadius: context.borderRadius(BorderRadiusType.small),
                  ),
                  child: Text(
                    badge,
                    style: context.textStyle(
                      FontSizeType.overline,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],

              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                color: context.secondaryTextColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactIconButton({
    required BuildContext context,
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    final deviceType = AppThemeSystem.getDeviceType(context);
    return IconButton(
      icon: icon,
      onPressed: onPressed,
      iconSize: deviceType == DeviceType.mobile ? 20 : 24,
      padding: EdgeInsets.all(deviceType == DeviceType.mobile ? 4 : 6),
      constraints: BoxConstraints(
        minWidth: deviceType == DeviceType.mobile ? 32 : 40,
        minHeight: deviceType == DeviceType.mobile ? 32 : 40,
      ),
    );
  }

  Widget _buildCompactIconButtonWithBadge({
    required BuildContext context,
    required Widget icon,
    String? badgeCount,
    required VoidCallback onPressed,
  }) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final deviceType = AppThemeSystem.getDeviceType(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: icon,
          onPressed: onPressed,
          iconSize: deviceType == DeviceType.mobile ? 20 : 24,
          padding: EdgeInsets.all(deviceType == DeviceType.mobile ? 4 : 6),
          constraints: BoxConstraints(
            minWidth: deviceType == DeviceType.mobile ? 32 : 40,
            minHeight: deviceType == DeviceType.mobile ? 32 : 40,
          ),
        ),
        // Badge (affiché seulement si badgeCount != null)
        if (badgeCount != null)
          Positioned(
            right: deviceType == DeviceType.mobile ? 4 : 6,
            top: deviceType == DeviceType.mobile ? 4 : 6,
            child: Container(
              padding: EdgeInsets.all(deviceType == DeviceType.mobile ? 2 : 3),
              decoration: BoxDecoration(
                color: AppThemeSystem.errorColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppThemeSystem.darkCardColor
                      : Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                minWidth: deviceType == DeviceType.mobile ? 14 : 16,
                minHeight: deviceType == DeviceType.mobile ? 14 : 16,
              ),
              child: Center(
                child: Text(
                  badgeCount,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: deviceType == DeviceType.mobile ? 8 : 9,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}


class HomeItemView extends GetView<HomeController> {
  const HomeItemView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingNearby.value && controller.isLoadingRecent.value) {
        return _buildLoadingState(context);
      }

      return RefreshIndicator(
        onRefresh: controller.refreshProducts,
        color: AppThemeSystem.primaryColor,
        child: CustomScrollView(
          slivers: [
            // Carousel de bannières
            SliverToBoxAdapter(
              child: _buildBannerCarousel(context),
            ),

            // Catégories horizontales
            SliverToBoxAdapter(
              child: _buildCategories(context),
            ),

            // Afficher les sections "Proche de vous" et "Récemment postés" seulement si "Tous" est sélectionné
            if (controller.selectedCategory.value == 'Tous') ...[
              // Vérifier si on est en train de charger ou s'il y a des produits
              if (controller.isLoadingNearby.value || controller.isLoadingRecent.value ||
                  controller.nearbyProducts.isNotEmpty || controller.recentProducts.isNotEmpty) ...[

                // Section "Proche de vous" - afficher seulement s'il y a des produits ou en chargement
                if (controller.isLoadingNearby.value || controller.nearbyProducts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      context,
                      'Proche de vous',
                      Icons.location_on_rounded,
                      onSeeAll: controller.nearbyProducts.isNotEmpty ? controller.onSeeAllNearby : null,
                    ),
                  ),

                  // Liste horizontale de produits proches
                  SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: AppConstants.shimmerFadeTransitionDuration,
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: controller.isLoadingNearby.value
                          ? ShimmerWidgets.horizontalProductListShimmer(context)
                          : _buildHorizontalProductList(context, controller.nearbyProducts),
                    ),
                  ),
                ],

                // Section "Récemment postés" - afficher seulement s'il y a des produits ou en chargement
                if (controller.isLoadingRecent.value || controller.recentProducts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      context,
                      'Récemment postés',
                      Icons.schedule_rounded,
                    ),
                  ),

                  // Grille de produits récents
                  controller.isLoadingRecent.value
                      ? SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemeSystem.getHorizontalPadding(context),
                          ),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  AppThemeSystem.getDeviceType(context) == DeviceType.mobile ? 2 : 3,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => ShimmerWidgets.productCardShimmer(context),
                              childCount: 6,
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemeSystem.getHorizontalPadding(context),
                          ),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  AppThemeSystem.getDeviceType(context) == DeviceType.mobile ? 2 : 3,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final product = controller.recentProducts[index];
                                return _FadeInProduct(
                                  delay: Duration(milliseconds: index * 50),
                                  child: _buildProductCard(context, product),
                                );
                              },
                              childCount: controller.recentProducts.length,
                            ),
                          ),
                        ),

                  // Bouton "Voir plus" stylé
                  if (controller.recentProducts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildSeeMoreButton(context, controller.onSeeAllRecent),
                    ),
                ],
              ] else ...[
                // État vide professionnel - affiché seulement quand il n'y a aucun produit
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context),
                ),
              ],
            ],

            // Afficher les produits filtrés par catégorie
            if (controller.selectedCategory.value != 'Tous') ...[
              // Section titre avec la catégorie sélectionnée
              SliverToBoxAdapter(
                child: _buildSectionTitle(
                  context,
                  controller.selectedCategory.value,
                  Icons.category_rounded,
                ),
              ),

              // Grille de produits filtrés
              controller.isLoadingProducts.value
                  ? ShimmerWidgets.productGridShimmer(context, itemCount: 6)
                  : controller.products.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined,
                                      size: 64, color: AppThemeSystem.grey400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucun produit dans cette catégorie',
                                    style: context.textStyle(
                                      FontSizeType.body1,
                                      color: AppThemeSystem.grey600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemeSystem.getHorizontalPadding(context),
                          ),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  AppThemeSystem.getDeviceType(context) == DeviceType.mobile ? 2 : 3,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final product = controller.products[index];
                                return _FadeInProduct(
                                  delay: Duration(milliseconds: index * 50),
                                  child: _buildProductCard(context, product),
                                );
                              },
                              childCount: controller.products.length,
                            ),
                          ),
                        ),

              // Indicateur de chargement pour la pagination
              if (controller.isLoadingMore.value)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ),
                ),
            ],

            // Espacement en bas
            SliverToBoxAdapter(
              child: SizedBox(height: AppThemeSystem.getVerticalPadding(context) * 2),
            ),
          ],
        ),
      );
    });
  }

  /// Build shimmer loading state for initial load
  Widget _buildLoadingState(BuildContext context) {
    final deviceType = AppThemeSystem.getDeviceType(context);

    return CustomScrollView(
      slivers: [
        // Banner shimmer
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 16, bottom: 12),
            height: deviceType == DeviceType.mobile ? 220 : 260,
            child: ShimmerWidgets.bannerShimmer(context),
          ),
        ),

        // Categories shimmer
        SliverToBoxAdapter(
          child: ShimmerWidgets.categoriesShimmer(context),
        ),

        // Section title placeholder
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppThemeSystem.getHorizontalPadding(context),
              right: AppThemeSystem.getHorizontalPadding(context),
              top: 8,
              bottom: 12,
            ),
            child: Container(
              width: 150,
              height: 24,
              decoration: BoxDecoration(
                color: AppThemeSystem.grey200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        // Horizontal products shimmer
        SliverToBoxAdapter(
          child: ShimmerWidgets.horizontalProductListShimmer(context),
        ),

        // Section title placeholder
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppThemeSystem.getHorizontalPadding(context),
              right: AppThemeSystem.getHorizontalPadding(context),
              top: 8,
              bottom: 12,
            ),
            child: Container(
              width: 150,
              height: 24,
              decoration: BoxDecoration(
                color: AppThemeSystem.grey200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        // Grid products shimmer
        ShimmerWidgets.productGridShimmer(context, itemCount: 6),

        // Espacement en bas
        SliverToBoxAdapter(
          child: SizedBox(height: AppThemeSystem.getVerticalPadding(context) * 2),
        ),
      ],
    );
  }

  Widget _buildCategories(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppThemeSystem.getHorizontalPadding(context),
        ),
        itemCount: controller.categories.length,
        itemBuilder: (context, index) {
          final category = controller.categories[index];

          // Find the full category object for SVG icon
          Map<String, dynamic>? categoryData;
          if (index > 0) { // Skip "Tous" at index 0
            categoryData = controller.apiCategories.firstWhereOrNull(
              (cat) => cat['name'] == category,
            );
          }

          return Obx(() {
            final isSelected = controller.selectedCategory.value == category;

            return GestureDetector(
              onTap: () => controller.selectCategory(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppThemeSystem.primaryColor,
                            AppThemeSystem.primaryColor.withValues(alpha: 0.8),
                          ],
                        )
                      : null,
                  color: isSelected ? null : AppThemeSystem.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppThemeSystem.primaryColor
                        : AppThemeSystem.getBorderColor(context),
                    width: isSelected ? 0 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Display category icon
                    if (index == 0)
                      // "Tous" category - use default icon
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 18,
                          color: isSelected
                              ? Colors.white
                              : AppThemeSystem.getPrimaryTextColor(context),
                        ),
                      )
                    else if (categoryData?['svg_icon'] != null)
                      // Category with SVG icon
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildCategorySvgIcon(
                          categoryData!['svg_icon'],
                          isSelected,
                          context,
                        ),
                      ),
                    Text(
                      category,
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppThemeSystem.getPrimaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  /// Build category SVG icon
  Widget _buildCategorySvgIcon(String svgIcon, bool isSelected, BuildContext context) {
    try {
      return SvgPicture.string(
        svgIcon,
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(
          isSelected
              ? Colors.white
              : AppThemeSystem.getPrimaryTextColor(context),
          BlendMode.srcIn,
        ),
      );
    } catch (e) {
      // Fallback to default icon if SVG parsing fails
      return Icon(
        Icons.category_rounded,
        size: 18,
        color: isSelected
            ? Colors.white
            : AppThemeSystem.getPrimaryTextColor(context),
      );
    }
  }

  Widget _buildBannerCarousel(BuildContext context) {
    final deviceType = AppThemeSystem.getDeviceType(context);

    final bannerData = [
      {'title': 'Bienvenue sur Asso', 'subtitle': 'Découvrez les meilleures offres près de chez vous'},
      {'title': 'Livraison Rapide', 'subtitle': 'Recevez vos commandes en moins de 24h'},
      {'title': 'Prix Imbattables', 'subtitle': 'Les meilleurs prix du marché camerounais'},
    ];

    // Use API banners or fallback to local assets
    final bannerCount = controller.banners.isNotEmpty
        ? controller.banners.length
        : controller.fallbackBanners.length;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      height: deviceType == DeviceType.mobile ? 220 : 260,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: controller.bannerController,
              itemCount: bannerCount,
              onPageChanged: (index) {
                controller.currentBannerIndex.value = index;
              },
              itemBuilder: (context, index) {
                final data = bannerData[index % bannerData.length];

                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: AppThemeSystem.getHorizontalPadding(context),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeSystem.primaryColor.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image - API or local
                        _buildBannerImage(index),

                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),

                        // Content
                        Positioned(
                          left: AppThemeSystem.getHorizontalPadding(context),
                          right: AppThemeSystem.getHorizontalPadding(context),
                          bottom: AppThemeSystem.getVerticalPadding(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                controller.banners.isNotEmpty
                                    ? (controller.banners[index]['title'] ?? data['title']!)
                                    : data['title']!,
                                style: context.textStyle(
                                  deviceType == DeviceType.mobile ? FontSizeType.h3 : FontSizeType.h2,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                data['subtitle']!,
                                style: context.textStyle(
                                  deviceType == DeviceType.mobile ? FontSizeType.body2 : FontSizeType.body1,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppThemeSystem.primaryColor, AppThemeSystem.tertiaryColor],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Découvrir',
                                  style: context.textStyle(
                                    FontSizeType.button,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Obx(() => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  bannerCount,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: controller.currentBannerIndex.value == index ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: controller.currentBannerIndex.value == index
                          ? AppThemeSystem.primaryColor
                          : AppThemeSystem.grey300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBannerImage(int index) {
    if (controller.banners.isNotEmpty && controller.banners[index]['image'] != null) {
      return Image.network(
        controller.banners[index]['image'],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          controller.fallbackBanners[index % controller.fallbackBanners.length],
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      controller.fallbackBanners[index % controller.fallbackBanners.length],
      fit: BoxFit.cover,
    );
  }

  /// Build product image widget (network or asset fallback)
  Widget _buildProductImage(Map<String, dynamic> product, {BoxFit fit = BoxFit.cover}) {
    final primaryImage = product['primary_image'];
    final images = product['images'] as List?;

    String? imageUrl;
    if (primaryImage != null && primaryImage.toString().isNotEmpty) {
      imageUrl = primaryImage.toString();
    } else if (images != null && images.isNotEmpty) {
      imageUrl = images[0] is Map ? images[0]['url'] : images[0].toString();
    }

    if (imageUrl != null && imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: AppThemeSystem.primaryColor,
            ),
          );
        },
      );
    }

    // Fallback: try as local asset
    final localImage = product['image'];
    if (localImage != null && localImage.toString().isNotEmpty) {
      return Image.asset(localImage.toString(), fit: fit,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppThemeSystem.grey200,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: Colors.grey),
      ),
    );
  }

  /// Format price for display
  String _formatPrice(Map<String, dynamic> product) {
    final formattedPrice = product['formatted_price'];
    if (formattedPrice != null) return formattedPrice.toString();

    final price = product['price'];
    if (price != null) {
      if (price is num) {
        return '${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]} ')} FCFA';
      }
      return '$price FCFA';
    }
    return 'Prix non défini';
  }

  /// Get product location
  String _getLocation(Map<String, dynamic> product) {
    return product['location']?.toString() ?? product['shop']?['address']?.toString() ?? '';
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppThemeSystem.getHorizontalPadding(context),
        right: AppThemeSystem.getHorizontalPadding(context),
        top: 8,
        bottom: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppThemeSystem.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: context.textStyle(FontSizeType.h4, fontWeight: FontWeight.bold)),
            ],
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Row(
                children: [
                  Text(
                    'Voir plus',
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppThemeSystem.primaryColor),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalProductList(BuildContext context, List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return const SizedBox(height: 16);
    }

    return Container(
      height: 280,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppThemeSystem.getHorizontalPadding(context),
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _FadeInProduct(
            delay: Duration(milliseconds: index * 50),
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 16),
              child: GestureDetector(
              onTap: () => Get.toNamed('/product', arguments: product),
              child: Container(
                decoration: BoxDecoration(
                  color: AppThemeSystem.getSurfaceColor(context),
                  borderRadius: context.borderRadius(BorderRadiusType.medium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium)),
                              topRight: Radius.circular(AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium)),
                            ),
                            child: SizedBox.expand(child: _buildProductImage(product)),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                final productId = product['id'] is int
                                    ? product['id']
                                    : int.tryParse(product['id'].toString()) ?? 0;
                                if (productId > 0) {
                                  controller.toggleFavorite(productId);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
                                  ],
                                ),
                                child: Icon(
                                  product['is_favorite'] == true
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 16,
                                  color: product['is_favorite'] == true
                                      ? AppThemeSystem.errorColor
                                      : AppThemeSystem.grey600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'Produit',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatPrice(product),
                            style: context.textStyle(
                              FontSizeType.subtitle2,
                              fontWeight: FontWeight.bold,
                              color: AppThemeSystem.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_getLocation(product).isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: AppThemeSystem.grey600),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _getLocation(product),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () => Get.toNamed('/product', arguments: product),
      child: Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppThemeSystem.getBorderColor(context).withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: SizedBox.expand(child: _buildProductImage(product)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        final productId = product['id'] is int
                            ? product['id']
                            : int.tryParse(product['id'].toString()) ?? 0;
                        if (productId > 0) {
                          controller.toggleFavorite(productId);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
                          ],
                        ),
                        child: Icon(
                          product['is_favorite'] == true
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: product['is_favorite'] == true
                              ? AppThemeSystem.errorColor
                              : AppThemeSystem.grey700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Produit',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatPrice(product),
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Vendor name with verified badge
                  if (product['shop'] != null && product['shop']['name'] != null)
                    Row(
                      children: [
                        Icon(Icons.store_outlined, size: 14, color: AppThemeSystem.grey600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product['shop']['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey700),
                          ),
                        ),
                        const SizedBox(width: 4),
                        VerifiedBadge(
                          isCertified: product['shop']['is_certified'] ?? false,
                          size: 14,
                        ),
                      ],
                    ),
                  if (product['shop'] != null && product['shop']['name'] != null)
                    const SizedBox(height: 8),
                  if (_getLocation(product).isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: AppThemeSystem.grey600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getLocation(product),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bouton "Voir plus" stylé
  Widget _buildSeeMoreButton(BuildContext context, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
        vertical: AppThemeSystem.getVerticalPadding(context),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                AppThemeSystem.tertiaryColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppThemeSystem.primaryColor,
                      AppThemeSystem.tertiaryColor,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Voir tous les produits',
                style: context.textStyle(
                  FontSizeType.body1,
                  fontWeight: FontWeight.w700,
                  color: AppThemeSystem.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppThemeSystem.primaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// État vide professionnel
  Widget _buildEmptyState(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final deviceType = AppThemeSystem.getDeviceType(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context) * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône avec dégradé
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    AppThemeSystem.tertiaryColor.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: deviceType == DeviceType.mobile ? 80 : 100,
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.6),
              ),
            ),

            SizedBox(height: AppThemeSystem.getVerticalPadding(context) * 1.5),

            // Titre
            Text(
              'Aucun produit disponible',
              style: context.textStyle(
                deviceType == DeviceType.mobile ? FontSizeType.h4 : FontSizeType.h3,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.getPrimaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppThemeSystem.getElementSpacing(context)),

            // Message
            Text(
              'Il n\'y a pas encore de produits disponibles dans votre région.',
              style: context.textStyle(
                FontSizeType.body1,
                color: isDark ? AppThemeSystem.grey400 : AppThemeSystem.grey600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade-in animation widget for smooth product appearance
class _FadeInProduct extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeInProduct({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_FadeInProduct> createState() => _FadeInProductState();
}

class _FadeInProductState extends State<_FadeInProduct>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.shimmerFadeTransitionDuration,
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
