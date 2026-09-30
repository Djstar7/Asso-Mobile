import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/asso_ads_banner.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/values/constants.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../routes/app_pages.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../tracking/views/tracking_view.dart';
import '../../profile/views/profile_view.dart';
import '../../import/views/import_view.dart';
import '../../search/views/search_view.dart';
import '../../notification/controllers/notification_controller.dart';
import '../../../core/widgets/offline_badge.dart';
import '../../../core/widgets/user_avatar.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // Protection contre l'utilisation d'un controller disposé
    if (!controller.isSafe) {
      return Scaffold(
        backgroundColor: context.ds.canvas,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final scaffold = Scaffold(
      backgroundColor: context.ds.canvas,
      drawer: _buildDrawer(context),
      // La navigation principale passe en bas de l'écran : c'est la zone
      // atteignable au pouce, et chaque destination porte désormais un
      // libellé — une rangée d'icônes seules laissait deviner le contenu.
      bottomNavigationBar: _buildBottomNav(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: TabBarView(
                controller: controller.tabController,
                // Le balayage latéral est désactivé : il entrait en conflit
                // avec les carrousels horizontaux de la page d'accueil.
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  HomeItemView(),
                  SearchTabView(),
                  ImportView(),
                  TrackingView(),
                  ProfileView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Depuis un autre onglet, le retour système ramène à l'Accueil au lieu de
    // fermer l'application d'un coup : c'est ce qu'on attend d'une barre de
    // navigation basse. Seul l'Accueil laisse sortir.
    return Obx(
      () => PopScope(
        canPop: controller.currentTabIndex.value == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          controller.handleTabTap(0);
          if (controller.tabController.index != 0) {
            controller.tabController.animateTo(0);
          }
        },
        child: scaffold,
      ),
    );
  }

  /// Destinations de la navigation basse.
  ///
  /// L'ordre suit le parcours : on découvre (Accueil, Import), on s'exprime
  /// (Ma voix), on suit ses achats (Suivi), on gère son compte.
  /// La messagerie a rejoint la barre du haut.
  /// Destinations de la barre basse, dans l'ordre des onglets.
  ///
  /// « Ma voix » a quitté cette barre pour le menu latéral : c'est une
  /// rubrique qu'on visite, pas un des cinq gestes quotidiens. La recherche
  /// prend sa place, là où l'on s'attend à la trouver dans une place de
  /// marché.
  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'home.nav.home',
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront_rounded,
    ),
    _NavDestination(
      label: 'home.nav.search',
      icon: Icons.search_outlined,
      activeIcon: Icons.search_rounded,
    ),
    _NavDestination(
      label: 'home.nav.wholesale',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
    ),
    _NavDestination(
      label: 'home.nav.tracking',
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping_rounded,
    ),
    _NavDestination(
      label: 'home.nav.account',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  /// Barre de navigation basse.
  Widget _buildBottomNav(BuildContext context) {
    return Obx(() {
      final current = controller.currentTabIndex.value;

      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.ds.surface,
          border: Border(top: BorderSide(color: context.ds.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            // Assez haut pour l'icône, la pastille et le libellé sans les
            // tasser quand la police est agrandie.
            height: 64,
            child: Row(
              children: List.generate(_destinations.length, (index) {
                final destination = _destinations[index];
                final isActive = current == index;

                return Expanded(
                  child: _NavItem(
                    destination: destination,
                    isActive: isActive,
                    onTap: () {
                      controller.handleTabTap(index);
                      // `handleTabTap` peut refuser l'accès (onglet protégé)
                      // et forcer le retour à l'accueil : on suit l'index
                      // réellement retenu par le contrôleur.
                      final target = controller.currentTabIndex.value;
                      if (controller.tabController.index != target) {
                        controller.tabController.animateTo(target);
                      }
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      );
    });
  }

  /// En-tête : identité, actions, puis recherche.
  ///
  /// La barre de recherche n'est affichée que sur l'accueil et l'import ;
  /// sur les autres onglets elle ne correspondait à rien de cherchable.
  Widget _buildTopBar(BuildContext context) {
    return Obx(() {
      final tab = controller.currentTabIndex.value;
      // Raccourci de recherche gardé sur l'accueil seulement. L'onglet
      // Recherche porte déjà son propre champ, et le catalogue grossiste a
      // le sien, filtré par pays.
      final showSearch = tab == 0;

      return Container(
        decoration: BoxDecoration(
          color: context.ds.surface,
          border: Border(bottom: BorderSide(color: context.ds.border)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppDesign.space2,
          0,
          AppDesign.space2,
          showSearch ? AppDesign.space3 : 0,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  Builder(
                    builder: (scaffoldContext) => AppIconButton(
                      icon: Icons.menu_rounded,
                      tooltip: 'home.tooltip.menu'.tr,
                      onPressed: () =>
                          Scaffold.of(scaffoldContext).openDrawer(),
                    ),
                  ),
                  Expanded(
                    // Sur l'accueil, on s'adresse à la personne plutôt que
                    // de répéter le nom de l'application, déjà porté par
                    // l'icône du téléphone.
                    child: tab == 0
                        ? _buildGreeting(context)
                        : Text(
                            _destinations[tab].label.tr,
                            style: context.textStyle(
                              FontSizeType.h6,
                              fontWeight: FontWeight.w700,
                              color: context.ds.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  const OfflineBadge(),
                  // La messagerie a quitté la navigation basse : elle se
                  // consulte ponctuellement, comme les favoris et les
                  // notifications.
                  GetX<ChatController>(
                    builder: (chatController) => AppIconButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      tooltip: 'home.tooltip.messages'.tr,
                      badgeCount: chatController.totalUnreadCount,
                      onPressed: () => AuthGuard.navigateIfAuthenticated(
                        context,
                        '/chat',
                        featureName: 'home.feature.messaging'.tr,
                        useDialog: false,
                      ),
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.favorite_border_rounded,
                    tooltip: 'home.tooltip.favorites'.tr,
                    badgeCount: controller.favoritesCount.value,
                    onPressed: () => AuthGuard.navigateIfAuthenticated(
                      context,
                      '/favorites',
                      featureName: 'home.feature.your_favorites'.tr,
                      useDialog: false,
                    ),
                  ),
                  GetX<NotificationController>(
                    builder: (notifController) => AppIconButton(
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'home.tooltip.notifications'.tr,
                      badgeCount: notifController.unreadCount.value,
                      onPressed: () => AuthGuard.navigateIfAuthenticated(
                        context,
                        '/notification',
                        featureName: 'home.feature.notifications'.tr,
                        useDialog: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showSearch)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppDesign.space2),
                child: _buildSearchEntry(context),
              ),
          ],
        ),
      );
    });
  }

  /// Salutation de l'accueil.
  ///
  /// Affiche le prénom quand il est connu, « Invité » sinon. Le nom de
  /// l'application n'y figure plus : on sait sur quelle application on est,
  /// et cette ligne sert mieux à situer la session en cours.
  Widget _buildGreeting(BuildContext context) {
    return Obx(() {
      final fullName = controller.userName.value.trim();
      final firstName = fullName.isEmpty
          ? ''
          : fullName.split(RegExp(r'\s+')).first;
      final isGuest = AuthGuard.isGuest || firstName.isEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'home.header.welcome'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.overline,
              color: context.ds.textTertiary,
            ),
          ),
          Text(
            isGuest ? 'home.header.guest'.tr : firstName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.subtitle1,
              fontWeight: FontWeight.w700,
              color: context.ds.textPrimary,
            ),
          ),
        ],
      );
    });
  }

  /// Champ de recherche factice qui ouvre l'écran de recherche dédié.
  Widget _buildSearchEntry(BuildContext context) {
    return Material(
      color: context.ds.surfaceMuted,
      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      child: InkWell(
        // Bascule sur l'onglet Recherche plutôt que d'empiler un écran :
        // la destination existe désormais dans la barre du bas.
        onTap: controller.goToSearchTab,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        child: Container(
          height: AppDesign.minTapTarget,
          padding: EdgeInsets.symmetric(horizontal: AppDesign.space3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            border: Border.all(color: context.ds.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: context.ds.textTertiary,
              ),
              SizedBox(width: AppDesign.space2),
              Expanded(
                child: Text(
                  'home.search_hint'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.body2,
                    color: context.ds.textTertiary,
                  ),
                ),
              ),
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: context.ds.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: context.ds.surface,
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        children: [
          // En-tête du menu.
          //
          // L'aplat orange pleine largeur écrasait la liste qui le suit ;
          // l'identité passe désormais par l'avatar et l'adresse, et l'accent
          // reste réservé aux éléments sur lesquels on peut agir.
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.ds.surfaceMuted,
              border: Border(bottom: BorderSide(color: context.ds.border)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.ds.gutter,
                  AppDesign.space5,
                  context.ds.gutter,
                  AppDesign.space5,
                ),
                child: Builder(
                  builder: (context) {
                    final user = StorageService.getUser();
                    final isAuthenticated = StorageService.isAuthenticated;
                    final hasAccount =
                        isAuthenticated &&
                        user != null &&
                        user.email.isNotEmpty;

                    return Row(
                      children: [
                        const UserAvatar(size: 48),
                        SizedBox(width: AppDesign.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                hasAccount ? 'home.drawer.my_account'.tr : 'home.drawer.guest_mode'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyle(
                                  FontSizeType.body2,
                                  fontWeight: FontWeight.w600,
                                  color: context.ds.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasAccount
                                    ? user.email
                                    : 'home.drawer.sign_in_to_order'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyle(
                                  FontSizeType.caption,
                                  color: context.ds.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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
                _buildSectionHeader(context, 'home.drawer.section_account'.tr),
                // « Ma voix » a quitté la barre du bas : le fil communautaire
                // se consulte ponctuellement, il ne fait pas partie des cinq
                // gestes quotidiens.
                _buildDrawerItem(
                  context: context,
                  icon: Icons.forum_rounded,
                  title: 'home.drawer.my_voice'.tr,
                  onTap: () {
                    Get.back();
                    AuthGuard.navigateIfAuthenticated(
                      context,
                      Routes.MY_VOICE,
                      featureName: 'home.feature.my_voice'.tr,
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.favorite_rounded,
                  title: 'home.drawer.my_preferences'.tr,
                  onTap: () {
                    Get.back();
                    Get.toNamed(
                      Routes.PREFERENCES,
                      arguments: {'isEditing': true},
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.shopping_bag_rounded,
                  title: 'home.drawer.my_orders'.tr,
                  onTap: () {
                    Get.back();
                    AuthGuard.navigateIfAuthenticated(
                      context,
                      '/shipment',
                      featureName: 'home.feature.your_orders'.tr,
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
                _buildSectionHeader(context, 'home.drawer.section_modes'.tr),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.flight_takeoff_rounded,
                  title: 'home.drawer.diaspora_mode'.tr,
                  badge: 'home.drawer.badge_new'.tr,
                  onTap: () {
                    Get.back();
                    if (AuthGuard.isGuest) {
                      AppDialogs.showLoginRequiredDialog(
                        context,
                        featureName: 'home.feature.diaspora_mode'.tr,
                      );
                    } else {
                      Get.toNamed('/diaspo');
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.delivery_dining_rounded,
                  title: 'home.drawer.delivery_mode'.tr,
                  onTap: () {
                    Get.back();
                    AuthGuard.navigateIfAuthenticated(
                      context,
                      '/delivery-check',
                      featureName: 'home.feature.delivery_mode'.tr,
                    );
                  },
                ),
                // Mode Vendeur : même ligne que les autres, avec un état actif
                // quand le compte est déjà vendeur.
                Builder(
                  builder: (context) {
                    final user = StorageService.getUser();
                    final isVendor = user?.isVendor ?? false;

                    return _buildDrawerItem(
                      context: context,
                      icon: Icons.storefront_rounded,
                      title: 'home.drawer.vendor_mode'.tr,
                      isActive: isVendor,
                      badge: isVendor ? null : 'home.drawer.badge_become'.tr,
                      onTap: () {
                        Get.back();
                        if (AuthGuard.isGuest) {
                          AppDialogs.showLoginRequiredDialog(
                            context,
                            featureName: 'home.feature.vendor_mode'.tr,
                          );
                          return;
                        }
                        Get.toNamed(isVendor ? '/vendor-dashboard' : '/vendor-config');
                      },
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
                _buildSectionHeader(context, 'home.drawer.settings'.tr),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_rounded,
                  title: 'home.drawer.settings'.tr,
                  onTap: () {
                    Get.back();
                    AuthGuard.navigateIfAuthenticated(
                      context,
                      '/settings',
                      featureName: 'home.feature.settings'.tr,
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.share_rounded,
                  title: 'home.drawer.invite_friend'.tr,
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'home.drawer.share_title'.tr,
                      'home.drawer.share_message'.tr,
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
                // Mêmes destinations que les entrées homonymes des paramètres.
                _buildSectionHeader(context, 'home.drawer.help_support'.tr),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.help_outline_rounded,
                  title: 'home.drawer.help_support'.tr,
                  onTap: () {
                    Get.back();
                    Get.toNamed(Routes.HELP);
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.quiz_rounded,
                  title: 'home.drawer.faq'.tr,
                  onTap: () {
                    Get.back();
                    Get.toNamed(Routes.FAQ);
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.gavel_rounded,
                  title: 'home.drawer.terms_policies'.tr,
                  onTap: () {
                    Get.back();
                    Get.toNamed(Routes.LEGAL);
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: 'home.drawer.about'.tr,
                  onTap: () {
                    Get.back();
                    Get.toNamed(Routes.ABOUT);
                  },
                ),

                SizedBox(height: AppThemeSystem.getElementSpacing(context)),
              ],
            ),
          ),

          // Footer avec déconnexion / connexion
          Container(
            padding: EdgeInsets.all(
              AppThemeSystem.getHorizontalPadding(context),
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.borderColor, width: 1),
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
                          'home.logout.title'.tr,
                          style: context.textStyle(
                            FontSizeType.h5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          'home.logout.confirm'.tr,
                          style: context.textStyle(FontSizeType.body2),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: Text(
                              'home.logout.cancel'.tr,
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
                              Get.offAllNamed(Routes.LOGIN);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeSystem.errorColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              'home.logout.title'.tr,
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
                    horizontal:
                        AppThemeSystem.getHorizontalPadding(context) * 0.75,
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
                        AuthGuard.isGuest
                            ? Icons.login_rounded
                            : Icons.logout_rounded,
                        color: AuthGuard.isGuest
                            ? AppThemeSystem.primaryColor
                            : AppThemeSystem.errorColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AuthGuard.isGuest ? 'home.logout.sign_in'.tr : 'home.logout.title'.tr,
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

  /// Ligne du menu latéral.
  ///
  /// L'icône reste neutre : une pastille orange sur chaque ligne remettait de
  /// l'accent sur toute la colonne, ce que l'en-tête cherchait justement à
  /// éviter. L'orange est réservé à ce qui est actif ou nouveau.
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? badge,
    bool isActive = false,
  }) {
    final ds = context.ds;
    final tint = isActive ? AppDesign.accent : ds.icon;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesign.space2,
        vertical: 1,
      ),
      child: Material(
        color: isActive ? AppDesign.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDesign.radiusSm),
          child: Container(
            // Hauteur minimale confortable au pouce.
            constraints: const BoxConstraints(minHeight: AppDesign.minTapTarget),
            padding: EdgeInsets.symmetric(
              horizontal: AppDesign.space3,
              vertical: AppDesign.space2,
            ),
            child: Row(
              children: [
                Icon(icon, color: tint, size: 22),
                SizedBox(width: AppDesign.space3),
                Expanded(
                  child: Text(
                    title,
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? AppDesign.accentText : ds.textPrimary,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  SizedBox(width: AppDesign.space2),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDesign.space2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppDesign.accent,
                      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
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
                ] else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: ds.textTertiary,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeItemView extends GetView<HomeController> {
  const HomeItemView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Afficher le shimmer complet uniquement pendant le chargement initial
      if (controller.isInitialLoading.value) {
        return _buildLoadingState(context);
      }

      return RefreshIndicator(
        onRefresh: controller.refreshProducts,
        color: AppThemeSystem.primaryColor,
        child: CustomScrollView(
          slivers: [
            // Carousel de bannières
            SliverToBoxAdapter(child: _buildBannerCarousel(context)),

            // DIASPO EXCHANGE Promo Card
            SliverToBoxAdapter(child: _buildQuickAccess(context)),

            // Catégories horizontales
            SliverToBoxAdapter(child: _buildCategories(context)),

            // Passcolis : un bandeau fin plutôt qu'une rubrique en fin de
            // page, où presque personne ne descendait.
            SliverToBoxAdapter(child: _buildPasscolisBanner(context)),

            // Afficher les sections "Proche de vous" et "Récemment postés" seulement si "Tous" est sélectionné
            // Asso Ads — annonces en tête d'accueil, juste sous le carrousel.
            // Les vendeurs paient pour être vus : un emplacement en bas de
            // page ne vaut pas son prix.
            if (controller.sponsoredProducts.isNotEmpty)
              SliverToBoxAdapter(child: _buildSponsoredSection(context)),

            if (controller.selectedCategory.value == 'Tous') ...[
              // Vérifier si on est en train de charger ou s'il y a des produits
              if (controller.isLoadingNearby.value ||
                  controller.isLoadingRecent.value ||
                  controller.nearbyProducts.isNotEmpty ||
                  controller.recentProducts.isNotEmpty) ...[
                // Section "Proche de vous" - afficher seulement s'il y a des produits ou en chargement
                if (controller.isLoadingNearby.value ||
                    controller.nearbyProducts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      context,
                      'home.sections.nearby'.tr,
                      Icons.location_on_rounded,
                      onSeeAll: controller.nearbyProducts.isNotEmpty
                          ? controller.onSeeAllNearby
                          : null,
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
                          : _buildHorizontalProductList(
                              context,
                              controller.nearbyProducts,
                            ),
                    ),
                  ),
                ],

                // Section "Récemment postés" - afficher seulement s'il y a des produits ou en chargement
                if (controller.isLoadingRecent.value ||
                    controller.recentProducts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      context,
                      'home.sections.recent'.tr,
                      Icons.schedule_rounded,
                      onSeeAll: controller.recentProducts.isNotEmpty
                          ? controller.onSeeAllRecent
                          : null,
                    ),
                  ),

                  // Grille de produits récents
                  controller.isLoadingRecent.value
                      ? SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemeSystem.getHorizontalPadding(
                              context,
                            ),
                          ),
                          sliver: SliverGrid(
                            gridDelegate: ProductCard.gridDelegate(context),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  ShimmerWidgets.productCardShimmer(context),
                              childCount: 6,
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemeSystem.getHorizontalPadding(
                              context,
                            ),
                          ),
                          sliver: SliverGrid(
                            gridDelegate: ProductCard.gridDelegate(context),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = controller.recentProducts[index];
                              return _FadeInProduct(
                                delay: Duration(milliseconds: index * 50),
                                child: _buildProductCard(context, product),
                              );
                            }, childCount: controller.recentProducts.length),
                          ),
                        ),

                  // Sortie de l'accueil : les six derniers produits vus, on
                  // passe la main au catalogue complet.
                  if (controller.recentProducts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildDiscoverMoreButton(context),
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
                  _categoryLabel(controller.selectedCategory.value),
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
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: AppThemeSystem.grey400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'home.empty_category'.tr,
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
                  : _buildProductSlivers(context),

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
              child: SizedBox(
                height: AppThemeSystem.getVerticalPadding(context) * 2,
              ),
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
        SliverToBoxAdapter(child: ShimmerWidgets.categoriesShimmer(context)),

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
          child: SizedBox(
            height: AppThemeSystem.getVerticalPadding(context) * 2,
          ),
        ),
      ],
    );
  }

  Widget _buildCategories(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppDesign.space2),
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
        itemCount: controller.categories.length,
        separatorBuilder: (_, __) => SizedBox(width: AppDesign.space2),
        itemBuilder: (context, index) {
          final category = controller.categories[index];

          Map<String, dynamic>? categoryData;
          if (index > 0) {
            categoryData = controller.apiCategories.firstWhereOrNull(
              (cat) => cat['name'] == category,
            );
          }

          return Obx(() {
            final isSelected = controller.selectedCategory.value == category;

            // Le filtre actif se signale par un fond teinté et un texte
            // accentué plutôt que par un aplat de couleur pleine : la rangée
            // reste lisible et ne capte plus tout le regard.
            final background = isSelected
                ? AppDesign.accentSubtle
                : context.ds.surface;
            final foreground = isSelected
                ? AppDesign.accentText
                : context.ds.textSecondary;
            final borderColor = isSelected
                ? AppDesign.accentBorder
                : context.ds.border;

            return Material(
              color: background,
              borderRadius: BorderRadius.circular(AppDesign.radiusPill),
              child: InkWell(
                onTap: () => controller.selectCategory(category),
                borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: AppDesign.space4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index == 0)
                        Padding(
                          padding: EdgeInsets.only(right: AppDesign.space1 + 2),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 15,
                            color: foreground,
                          ),
                        )
                      else if (categoryData?['svg_icon'] != null)
                        Padding(
                          padding: EdgeInsets.only(right: AppDesign.space1 + 2),
                          child: _buildCategorySvgIcon(
                            categoryData!['svg_icon'],
                            isSelected,
                            context,
                          ),
                        ),
                      Text(
                        _categoryLabel(category),
                        style: context.textStyle(
                          FontSizeType.caption,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  /// Build category SVG icon
  Widget _buildCategorySvgIcon(
    String svgIcon,
    bool isSelected,
    BuildContext context,
  ) {
    // Cette icône est posée sur le chip, dont le fond passe à accentSubtle
    // quand il est actif : d'où accentText plutôt que l'accent plein.
    final color = isSelected ? AppDesign.accentText : context.ds.textSecondary;
    try {
      return SvgPicture.string(
        svgIcon,
        width: 15,
        height: 15,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } catch (e) {
      return Icon(Icons.category_rounded, size: 15, color: color);
    }
  }

  /// DIASPO EXCHANGE Promo Card
  Widget _buildDiaspoPromoCard(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space2,
        context.ds.gutter,
        AppDesign.space2,
      ),
      // Anciennement un aplat bleu en dégradé qui rivalisait avec la marque.
      // La carte reprend la surface standard : c'est le libellé et le badge
      // qui signalent la nouveauté, pas la couleur de fond.
      child: AppCard(
        onTap: () {
          if (AuthGuard.isGuest) {
            AppDialogs.showLoginRequiredDialog(
              context,
              featureName: 'home.feature.diaspora_mode'.tr,
            );
          } else {
            Get.toNamed('/diaspo');
          }
        },
        padding: EdgeInsets.all(AppDesign.space4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppDesign.accentSubtle,
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              ),
              child: const Icon(
                Icons.flight_takeoff_rounded,
                color: AppDesign.accentText,
                size: 22,
              ),
            ),
            SizedBox(width: AppDesign.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'home.diaspo.title'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyle(
                            FontSizeType.body2,
                            fontWeight: FontWeight.w600,
                            color: context.ds.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: AppDesign.space2),
                      AppBadge(
                        label: 'home.diaspo.badge_new'.tr,
                        tone: AppBadgeTone.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'home.diaspo.subtitle'.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: context.ds.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppDesign.space2),
            Icon(
              Icons.chevron_right_rounded,
              color: context.ds.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Accès rapides, sous la bannière.
  ///
  /// La carte « Diaspo Exchange » occupait seule une ligne entière pour un
  /// service parmi d'autres. Quatre raccourcis tiennent dans la même hauteur
  /// et donnent une vue d'ensemble de ce que propose l'application.
  Widget _buildQuickAccess(BuildContext context) {
    final entries = <_QuickLink>[
      _QuickLink(
        label: 'home.quick.diaspo'.tr,
        icon: Icons.flight_takeoff_rounded,
        isNew: true,
        // Trajets encore réservables : le chiffre dit qu'il y a de la place
        // à acheter maintenant, pas combien d'annonces existent en tout.
        count: controller.openPasscolisCount,
        onTap: () => AuthGuard.navigateIfAuthenticated(
          context,
          Routes.DIASPO,
          featureName: 'home.feature.diaspora_mode'.tr,
          useDialog: true,
        ),
      ),
      _QuickLink(
        label: 'home.quick.wholesale'.tr,
        icon: Icons.inventory_2_rounded,
        onTap: () {
          controller.handleTabTap(2);
          controller.tabController.animateTo(controller.currentTabIndex.value);
        },
      ),
      _QuickLink(
        label: 'home.quick.orders'.tr,
        icon: Icons.receipt_long_rounded,
        onTap: () => AuthGuard.navigateIfAuthenticated(
          context,
          Routes.MY_ORDER,
          featureName: 'home.feature.your_orders'.tr,
          useDialog: true,
        ),
      ),
      _QuickLink(
        label: 'home.tooltip.favorites'.tr,
        icon: Icons.favorite_rounded,
        count: controller.favoritesCount.value,
        onTap: () => AuthGuard.navigateIfAuthenticated(
          context,
          Routes.FAVORITES,
          featureName: 'home.feature.your_favorites'.tr,
          useDialog: true,
        ),
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space4,
        context.ds.gutter,
        AppDesign.space2,
      ),
      child: Row(
        children: [
          for (final entry in entries) ...[
            Expanded(child: _QuickLinkTile(link: entry)),
            if (entry != entries.last) SizedBox(width: AppDesign.space2),
          ],
        ],
      ),
    );
  }

  Widget _buildBannerCarousel(BuildContext context) {
    final deviceType = AppThemeSystem.getDeviceType(context);

    final bannerData = [
      {
        'title': 'home.banner.welcome_title'.tr,
        'subtitle': 'home.banner.welcome_subtitle'.tr,
      },
      {
        'title': 'home.banner.delivery_title'.tr,
        'subtitle': 'home.banner.delivery_subtitle'.tr,
      },
      {
        'title': 'home.banner.prices_title'.tr,
        'subtitle': 'home.banner.prices_subtitle'.tr,
      },
    ];

    // Use API banners or fallback to local assets
    final bannerCount = controller.banners.isNotEmpty
        ? controller.banners.length
        : controller.fallbackBanners.length;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      height: deviceType == DeviceType.mobile ? 240 : 280,
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

                final apiBanner = controller.banners.isNotEmpty
                    ? controller.banners[index]
                    : null;
                final title = apiBanner?['title']?.toString() ?? data['title']!;
                final subtitle =
                    apiBanner?['subtitle']?.toString() ?? data['subtitle']!;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppDesign.radiusLg),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      // La bannière entière est cliquable, pas seulement le
                      // bouton : c'est la cible la plus large de l'écran, et
                      // le « Découvrir » n'était qu'un décor sans action.
                      onTap: controller.goToSearchTab,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildBannerImage(context, index),

                          // Voile sombre, plus haut et plus dense que le
                          // précédent : le sous-titre se perdait sur les
                          // photos claires.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppDesign.neutral900.withValues(alpha: 0.35),
                                  AppDesign.neutral900.withValues(alpha: 0.85),
                                ],
                                stops: const [0.25, 0.6, 1.0],
                              ),
                            ),
                          ),

                          Positioned(
                            left: AppDesign.space5,
                            right: AppDesign.space5,
                            bottom: AppDesign.space5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textStyle(
                                    FontSizeType.h4,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: AppDesign.space1 + 2),
                                // Le sous-titre existait dans les données mais
                                // n'était jamais rendu : la bannière ne disait
                                // que « Bienvenue sur Asso ».
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textStyle(
                                    FontSizeType.caption,
                                    color: Colors.white.withValues(alpha: 0.92),
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(height: AppDesign.space4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppDesign.space4,
                                        vertical: AppDesign.space2 + 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          AppDesign.radiusPill,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'home.banner.discover'.tr,
                                            style: context.textStyle(
                                              FontSizeType.caption,
                                              fontWeight: FontWeight.w700,
                                              color: AppDesign.neutral900,
                                            ),
                                          ),
                                          SizedBox(width: AppDesign.space1),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 15,
                                            color: AppDesign.neutral900,
                                          ),
                                        ],
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
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                bannerCount,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: controller.currentBannerIndex.value == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: controller.currentBannerIndex.value == index
                        ? AppThemeSystem.primaryColor
                        : AppThemeSystem.grey400,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerImage(BuildContext context, int index) {
    if (controller.banners.isNotEmpty &&
        controller.banners[index]['image'] != null) {
      // Bannière pleine largeur : décodée à la largeur de l'écran.
      final width = MediaQuery.sizeOf(context).width;
      return AppNetworkImage(
        url: controller.banners[index]['image'].toString(),
        decodeSize: Size(width, width * 9 / 16),
        errorBuilder: (_) => Image.asset(
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
  ///
  /// [decodeSize] : taille logique de la case, pour décoder la photo à la
  /// taille affichée (par défaut, une carte de la grille produits).
  Widget _buildProductImage(
    BuildContext context,
    Map<String, dynamic> product, {
    BoxFit fit = BoxFit.cover,
    Size? decodeSize,
  }) {
    final primaryImage = product['primary_image'];
    final images = product['images'] as List?;

    String? imageUrl;
    if (primaryImage != null && primaryImage.toString().isNotEmpty) {
      imageUrl = primaryImage.toString();
    } else if (images != null && images.isNotEmpty) {
      imageUrl = images[0] is Map ? images[0]['url'] : images[0].toString();
    }

    if (imageUrl != null && imageUrl.startsWith('http')) {
      final cardWidth = ProductCard.widthInGrid(context);
      return AppNetworkImage(
        url: imageUrl,
        fit: fit,
        decodeSize:
            decodeSize ??
            Size(cardWidth, cardWidth / ProductCard.imageAspectRatio),
        placeholder: (_) => const SizedBox.expand(),
        showProgress: true,
        errorBuilder: (_) => _buildPlaceholderImage(),
      );
    }

    // Fallback: try as local asset
    final localImage = product['image'];
    if (localImage != null && localImage.toString().isNotEmpty) {
      return Image.asset(
        localImage.toString(),
        fit: fit,
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

  /// Libellé affiché d'une catégorie : « Tous » et les catégories de repli
  /// restent des valeurs internes, traduites seulement à l'affichage.
  String _categoryLabel(String category) {
    switch (category) {
      case 'Tous':
        return 'home.categories.all'.tr;
      case 'Vêtements':
        return 'home.categories.clothing'.tr;
      case 'Électronique':
        return 'home.categories.electronics'.tr;
      case 'Accessoires':
        return 'home.categories.accessories'.tr;
      default:
        return category;
    }
  }

  /// Format price for display (with currency conversion)
  String _formatPrice(Map<String, dynamic> product) {
    final price = product['price_xaf'] ?? product['price'];

    if (price != null) {
      double priceValue = 0.0;
      if (price is num) {
        priceValue = price.toDouble();
      } else if (price is String) {
        priceValue = double.tryParse(price) ?? 0.0;
      }

      // Utiliser CurrencyService pour la conversion
      try {
        if (Get.isRegistered<CurrencyService>()) {
          return CurrencyService.to.formatPrice(priceValue);
        }
      } catch (e) {
        print('Error using CurrencyService in _formatPrice: $e');
      }

      // Fallback: affichage sans conversion
      return '${priceValue.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]} ')} FCFA';
    }

    return 'home.price_undefined'.tr;
  }

  /// Get product location
  String _getLocation(Map<String, dynamic> product) {
    return product['location']?.toString() ??
        product['shop']?['address']?.toString() ??
        '';
  }

  /// Check if shop is certified (handles bool, int, string)
  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    IconData icon, {
    VoidCallback? onSeeAll,
  }) {
    return AppSectionHeader(
      title: title,
      actionLabel: onSeeAll != null ? 'home.sections.see_all'.tr : null,
      onAction: onSeeAll,
    );
  }

  Widget _buildHorizontalProductList(
    BuildContext context,
    List<Map<String, dynamic>> products,
  ) {
    if (products.isEmpty) {
      return SizedBox(height: AppDesign.space4);
    }

    // La largeur des vignettes suit celle de la grille : on retrouve le même
    // objet visuel que l'on scrolle horizontalement ou verticalement.
    final cardWidth = ProductCard.widthInGrid(context);

    return SizedBox(
      height: ProductCard.totalHeight(context, cardWidth),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
        itemCount: products.length,
        separatorBuilder: (_, __) => SizedBox(width: AppDesign.space3),
        itemBuilder: (context, index) {
          final product = products[index];
          return _FadeInProduct(
            delay: Duration(milliseconds: index * 50),
            child: SizedBox(
              width: cardWidth,
              child: _buildProductCard(context, product),
            ),
          );
        },
      ),
    );
  }

  /// « Découvrir plus » : bascule sur l'onglet Recherche.
  ///
  /// L'accueil ne montre qu'une sélection ; c'est la recherche qui porte le
  /// catalogue entier, ses filtres et sa pagination.
  Widget _buildDiscoverMoreButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space4,
        context.ds.gutter,
        AppDesign.space2,
      ),
      child: AppButton(
        label: 'home.discover_more'.tr,
        icon: Icons.search_rounded,
        variant: AppButtonVariant.secondary,
        onPressed: controller.goToSearchTab,
      ),
    );
  }

  /// Bandeau Passcolis : envoyer un colis par un voyageur.
  ///
  /// Remplace la rubrique qui occupait le bas de page. Placé juste sous les
  /// catégories, il est vu sans qu'on ait à faire défiler tout le catalogue,
  /// et sa hauteur réduite ne repousse pas les produits.
  Widget _buildPasscolisBanner(BuildContext context) {
    // Rien à annoncer tant qu'aucun trajet n'est ouvert : un bandeau qui
    // promet des kilos sans en avoir déçoit au premier tap.
    if (controller.isLoadingPasscolis.value ||
        controller.openPasscolisCount == 0) {
      return const SizedBox.shrink();
    }

    return _PasscolisBanner(
      openCount: controller.openPasscolisCount,
      onTap: controller.onSeeAllPasscolis,
    );
  }

  /// Asso Ads — bloc d'annonces en tête d'accueil.
  ///
  /// La première annonce prend le format bandeau (16/9, pleine largeur) : c'est
  /// l'emplacement qui se remarque. Les suivantes défilent horizontalement en
  /// cartes, pour ne pas repousser le contenu éditorial trop bas.
  Widget _buildSponsoredSection(BuildContext context) {
    final ads = controller.sponsoredProducts;
    final first = ads.first;
    final rest = ads.length > 1
        ? ads.sublist(1)
        : const <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.ds.gutter,
            AppDesign.space4,
            context.ds.gutter,
            0,
          ),
          child: Row(
            children: [
              Icon(Icons.campaign, size: 16, color: AppDesign.info),
              const SizedBox(width: 6),
              Text(
                'home.ads.title'.tr,
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: FontWeight.w700,
                  color: AppDesign.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'home.ads.subtitle'.tr,
                  style: context.textStyle(
                    FontSizeType.overline,
                    color: context.ds.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildAdsBanner(context, first),
        if (rest.isNotEmpty) ...[
          SizedBox(
            height: ProductCard.totalHeight(
              context,
              ProductCard.widthInGrid(context),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
              itemCount: rest.length,
              separatorBuilder: (context, index) =>
                  SizedBox(width: AppDesign.space3),
              itemBuilder: (context, index) => SizedBox(
                width: ProductCard.widthInGrid(context),
                child: _buildProductCard(context, rest[index]),
              ),
            ),
          ),
          SizedBox(height: AppDesign.space3),
        ],
      ],
    );
  }

  /// Grille principale, coupée par les bandeaux Asso Ads.
  ///
  /// Un `SliverGrid` ne peut pas héberger une cellule pleine largeur : on
  /// découpe donc la liste en tronçons de grille séparés par des bandeaux.
  /// Les produits sponsorisés déjà servis en carte dans la grille ne sont pas
  /// repris en bandeau — deux formats pour la même annonce sur un seul écran
  /// donneraient l'impression d'un fil saturé de publicité.
  Widget _buildProductSlivers(BuildContext context) {
    final products = controller.products;
    final padding = EdgeInsets.symmetric(
      horizontal: AppThemeSystem.getHorizontalPadding(context),
    );

    // Bandeau après cette rangée de la grille (index de produit).
    const bannerAfter = 8;

    // Les annonces de la première page sont déjà servies en tête d'écran
    // (section Asso Ads) et retirées de `products` : seules celles des pages
    // suivantes, chargées à la pagination, s'intercalent ici.
    final sponsored = products.firstWhereOrNull(
      (p) => p['is_sponsored'] == true,
    );

    // Pas assez de produits pour couper le flux, ou aucune annonce à passer :
    // une seule grille continue.
    if (sponsored == null || products.length <= bannerAfter + 2) {
      return SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: ProductCard.gridDelegate(context),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _FadeInProduct(
              delay: Duration(milliseconds: index * 50),
              child: _buildProductCard(context, products[index]),
            ),
            childCount: products.length,
          ),
        ),
      );
    }

    final head = products.sublist(0, bannerAfter);
    final tail = products.sublist(bannerAfter);

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            gridDelegate: ProductCard.gridDelegate(context),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _FadeInProduct(
                delay: Duration(milliseconds: index * 50),
                child: _buildProductCard(context, head[index]),
              ),
              childCount: head.length,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildAdsBanner(context, sponsored)),
        SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            gridDelegate: ProductCard.gridDelegate(context),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildProductCard(context, tail[index]),
              childCount: tail.length,
            ),
          ),
        ),
      ],
    );
  }

  /// Bandeau Asso Ads pleine largeur, intercalé dans le défilement.
  Widget _buildAdsBanner(BuildContext context, Map<String, dynamic> product) {
    return AssoAdsBanner(
      name: product['name']?.toString() ?? 'product.fallback_name'.tr,
      price: _formatPrice(product),
      shopName: product['shop']?['name']?.toString(),
      location: _getLocation(product),
      imageBuilder: (context) {
        // Visuel 16/9 sur toute la largeur utile.
        final width = MediaQuery.sizeOf(context).width;
        return _buildProductImage(
          context,
          product,
          decodeSize: Size(width, width * 9 / 16),
        );
      },
      onTap: () =>
          Get.toNamed('/product', arguments: {...product, 'from_ad': true}),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final productId = product['id'] is int
        ? product['id'] as int
        : int.tryParse('${product['id']}') ?? 0;

    // Asso Ads : emplacement acheté par le vendeur, signalé comme tel.
    final isSponsored = product['is_sponsored'] == true;

    return ProductCard(
      name: product['name']?.toString() ?? 'product.fallback_name'.tr,
      price: _formatPrice(product),
      location: _getLocation(product),
      isFavorite: product['is_favorite'] == true,
      isCertified: ProductCard.isShopCertified(product),
      isSponsored: isSponsored,
      imageBuilder: (context) => _buildProductImage(context, product),
      // `from_ad` permet au serveur de mesurer l'efficacité de la campagne.
      onTap: () => Get.toNamed(
        '/product',
        arguments: isSponsored ? {...product, 'from_ad': true} : product,
      ),
      onFavoriteTap: productId > 0
          ? () => controller.toggleFavorite(productId)
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: Icons.storefront_outlined,
      title: 'home.empty.title'.tr,
      message:
          'home.empty.message'.tr,
      actionLabel: 'home.empty.refresh'.tr,
      onAction: controller.refreshProducts,
    );
  }
}

/// Bandeau Passcolis : fin, animé, une seule promesse.
///
/// L'animation reste discrète — un avion qui glisse lentement en fond et une
/// lueur qui balaie le bandeau. Assez pour attirer l'œil dans un flux de
/// cartes statiques, pas au point de gêner la lecture du reste de la page.
class _PasscolisBanner extends StatefulWidget {
  const _PasscolisBanner({required this.openCount, required this.onTap});

  /// Trajets encore réservables, annoncés dans le sous-titre.
  final int openCount;
  final VoidCallback onTap;

  @override
  State<_PasscolisBanner> createState() => _PasscolisBannerState();
}

class _PasscolisBannerState extends State<_PasscolisBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Cycle lent : le bandeau doit vivre, pas clignoter.
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space1,
        context.ds.gutter,
        AppDesign.space2,
      ),
      child: Material(
        color: AppDesign.accentSubtle,
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          // La hauteur suit les deux lignes de texte au lieu d'être fixée :
          // un bandeau plus haut que son contenu laissait une bande vide
          // sous le sous-titre.
          child: IntrinsicHeight(
            child: Stack(
              children: [
                // Décor animé, derrière le texte.
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      painter: _PasscolisBannerPainter(_controller.value),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDesign.space3,
                    vertical: AppDesign.space2,
                  ),
                  child: Row(
                    children: [
                      // L'avion avance et recule doucement : c'est le seul
                      // élément mobile que l'œil suit vraiment.
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final t = _controller.value;
                          final drift = (t < 0.5 ? t : 1 - t) * 8;
                          return Transform.translate(
                            offset: Offset(drift, -drift * 0.4),
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.flight_takeoff_rounded,
                          size: 26,
                          color: AppDesign.accentText,
                        ),
                      ),
                      SizedBox(width: AppDesign.space3),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'home.diaspo.banner_title'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyle(
                                FontSizeType.body2,
                                fontWeight: FontWeight.w700,
                                color: AppDesign.accentText,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              (widget.openCount > 1
                                      ? 'home.diaspo.open_trips_other'
                                      : 'home.diaspo.open_trips_one')
                                  .trParams({'count': '${widget.openCount}'}),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyle(
                                FontSizeType.overline,
                                color: AppDesign.accentText.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: AppDesign.space2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppDesign.accentText,
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
  }
}

/// Décor du bandeau : une traînée en pointillés et une lueur qui le balaie.
class _PasscolisBannerPainter extends CustomPainter {
  _PasscolisBannerPainter(this.progress);

  /// Avancement du cycle, de 0 à 1.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Traînée de l'avion : des tirets qui filent vers la droite, décalés au
    // fil du cycle pour donner le sens du déplacement.
    // Trait décoratif, très dilué : l'accent plein suffit, accentText est
    // réservé au texte posé sur accentSubtle.
    final dash = Paint()
      ..color = AppDesign.accent.withValues(alpha: 0.22)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashWidth = 9.0;
    const gap = 7.0;
    final shift = progress * (dashWidth + gap);
    final y = size.height * 0.34;

    for (var x = -dashWidth + shift; x < size.width; x += dashWidth + gap) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), dash);
    }

    // Lueur diagonale qui traverse le bandeau une fois par cycle.
    final sweepX = size.width * (progress * 1.6 - 0.3);
    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(sweepX - 40, 0, 80, size.height));

    canvas.drawRect(Rect.fromLTWH(sweepX - 40, 0, 80, size.height), glow);
  }

  @override
  bool shouldRepaint(_PasscolisBannerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FadeInProduct extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeInProduct({required this.child, this.delay = Duration.zero});

  /// Décalage maximal de l'apparition en cascade.
  ///
  /// Les appelants décalent de 50 ms par position : sans plafond, la tuile
  /// n° 400 restait invisible 20 s, et comme la grille recrée ses tuiles au
  /// défilement, une longue session finissait sur un mur vide (noir en mode
  /// sombre). La cascade n'a de sens que pour le premier écran.
  static const Duration maxDelay = Duration(milliseconds: 300);

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

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delay = widget.delay > _FadeInProduct.maxDelay
        ? _FadeInProduct.maxDelay
        : widget.delay;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      // Minuteur annulé à la destruction : une tuile sortie de l'écran ne
      // reste pas en mémoire le temps de son délai.
      _delayTimer = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  Timer? _delayTimer;

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

/// Destination de la barre de navigation principale.
class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Raccourci de la rangée d'accès rapides de l'accueil.
class _QuickLink {
  const _QuickLink({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isNew = false,
    this.count = 0,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isNew;

  /// Porté en pastille sur l'icône. Zéro n'affiche rien : une pastille « 0 »
  /// occupe la place d'une information sans en être une.
  final int count;
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({required this.link});

  final _QuickLink link;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ds.surface,
      borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      child: InkWell(
        onTap: link.onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: AppDesign.space3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesign.radiusMd),
            border: Border.all(color: context.ds.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(link.icon, size: 22, color: AppDesign.accent),
                  // Le compte prime sur la pastille « nouveau » : un chiffre
                  // dit déjà qu'il se passe quelque chose, et les deux
                  // superposés deviendraient illisibles.
                  if (link.count > 0)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppDesign.accent,
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusPill,
                          ),
                          border: Border.all(color: context.ds.surface),
                        ),
                        child: Text(
                          link.count > 99 ? '99+' : '${link.count}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    )
                  else if (link.isNew)
                    Positioned(
                      right: -5,
                      top: -3,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppDesign.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppDesign.space2),
              Text(
                link.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyle(
                  FontSizeType.overline,
                  fontWeight: FontWeight.w600,
                  color: context.ds.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Destination de la barre de navigation basse.
///
/// L'onglet actif se signale par une pastille teintée derrière son icône, et
/// non par la seule couleur du trait : sur un écran lumineux, un simple
/// changement de teinte se repère mal, surtout entre deux icônes voisines.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isActive,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Un seul orange dans toute l'application : l'icône comme le libellé
    // prennent l'accent de marque. accentText, plus sombre, faisait paraître
    // l'onglet actif d'une autre couleur que les raccourcis juste au-dessus ;
    // la pastille accentSubtle est assez claire pour que l'accent y reste
    // lisible.
    final color = isActive ? AppDesign.accent : context.ds.textTertiary;

    return InkWell(
      onTap: onTap,
      // Pas d'effet d'encre rectangulaire sur toute la colonne : il
      // débordait de la pastille et donnait un retour visuel approximatif.
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: AppDesign.space4,
              vertical: AppDesign.space1 + 1,
            ),
            decoration: BoxDecoration(
              color: isActive ? AppDesign.accentSubtle : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            ),
            child: Icon(
              isActive ? destination.activeIcon : destination.icon,
              size: 22,
              color: color,
            ),
          ),
          SizedBox(height: AppDesign.space1 - 1),
          // Le libellé passe par l'échelle typographique : en `TextStyle` brut
          // il ignorait les réglages d'accessibilité de l'appareil.
          Text(
            destination.label.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.overline,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
