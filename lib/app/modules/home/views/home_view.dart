import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
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
import '../../myVoice/views/my_voice_view.dart';
import '../../notification/controllers/notification_controller.dart';
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

    return Scaffold(
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
                  ImportView(),
                  MyVoiceView(),
                  TrackingView(),
                  ProfileView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Destinations de la navigation basse.
  ///
  /// L'ordre suit le parcours : on découvre (Accueil, Import), on s'exprime
  /// (Ma voix), on suit ses achats (Suivi), on gère son compte.
  /// La messagerie a rejoint la barre du haut.
  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'Accueil',
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront_rounded,
    ),
    _NavDestination(
      label: 'Import',
      icon: Icons.travel_explore_outlined,
      activeIcon: Icons.travel_explore_rounded,
    ),
    _NavDestination(
      label: 'Ma voix',
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
    ),
    _NavDestination(
      label: 'Suivi',
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping_rounded,
    ),
    _NavDestination(
      label: 'Compte',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  /// Barre de navigation basse.
  Widget _buildBottomNav(BuildContext context) {
    return Obx(() {
      final current = controller.currentTabIndex.value;

      return Container(
        decoration: BoxDecoration(
          color: context.ds.surface,
          border: Border(top: BorderSide(color: context.ds.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_destinations.length, (index) {
                final destination = _destinations[index];
                final isActive = current == index;

                return Expanded(
                  child: InkWell(
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? destination.activeIcon : destination.icon,
                          size: 22,
                          color: isActive
                              ? AppDesign.accent
                              : context.ds.textTertiary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'SF-Pro',
                            fontSize: 10,
                            height: 1.1,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive
                                ? AppDesign.accent
                                : context.ds.textTertiary,
                          ),
                        ),
                      ],
                    ),
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
      final showSearch = tab == 0 || tab == 2;

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
                      tooltip: 'Menu',
                      onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                    ),
                  ),
                  Expanded(
                    // Sur l'accueil, on s'adresse à la personne plutôt que
                    // de répéter le nom de l'application, déjà porté par
                    // l'icône du téléphone.
                    child: tab == 0
                        ? _buildGreeting(context)
                        : Text(
                            _destinations[tab].label,
                            style: context.textStyle(
                              FontSizeType.h6,
                              fontWeight: FontWeight.w700,
                              color: context.ds.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  // La messagerie a quitté la navigation basse : elle se
                  // consulte ponctuellement, comme les favoris et les
                  // notifications.
                  GetX<ChatController>(
                    builder: (chatController) => AppIconButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      tooltip: 'Messages',
                      badgeCount: chatController.totalUnreadCount,
                      onPressed: () => AuthGuard.navigateIfAuthenticated(
                        context,
                        '/chat',
                        featureName: 'la messagerie',
                        useDialog: false,
                      ),
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.favorite_border_rounded,
                    tooltip: 'Favoris',
                    onPressed: () => AuthGuard.navigateIfAuthenticated(
                      context,
                      '/favorites',
                      featureName: 'vos favoris',
                      useDialog: false,
                    ),
                  ),
                  GetX<NotificationController>(
                    builder: (notifController) => AppIconButton(
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'Notifications',
                      badgeCount: notifController.unreadCount.value,
                      onPressed: () => AuthGuard.navigateIfAuthenticated(
                        context,
                        '/notification',
                        featureName: 'les notifications',
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
      final firstName =
          fullName.isEmpty ? '' : fullName.split(RegExp(r'\s+')).first;
      final isGuest = AuthGuard.isGuest || firstName.isEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bienvenue',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.overline,
              color: context.ds.textTertiary,
            ),
          ),
          Text(
            isGuest ? 'Invité' : firstName,
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
        onTap: () => Get.toNamed('/search'),
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
              Icon(Icons.search_rounded, size: 20, color: context.ds.textTertiary),
              SizedBox(width: AppDesign.space2),
              Expanded(
                child: Text(
                  'Rechercher un produit, une boutique…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.body2,
                    color: context.ds.textTertiary,
                  ),
                ),
              ),
              Icon(Icons.tune_rounded, size: 18, color: context.ds.textTertiary),
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
                        isAuthenticated && user != null && user.email.isNotEmpty;

                    return Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppDesign.accentSubtle,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppDesign.accentText,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: AppDesign.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                hasAccount ? 'Mon compte' : 'Mode invité',
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
                                    : 'Connectez-vous pour commander',
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
                _buildSectionHeader(context, 'Mon Compte'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.favorite_rounded,
                  title: 'Mes préférences',
                  onTap: () {
                    Get.back();
                    Get.toNamed(Routes.PREFERENCES, arguments: {'isEditing': true});
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
                  icon: Icons.flight_takeoff_rounded,
                  title: 'Mode Diaspora',
                  badge: 'Nouveau',
                  onTap: () {
                    Get.back();
                    if (AuthGuard.isGuest) {
                      AppDialogs.showLoginRequiredDialog(
                        context,
                        featureName: 'le mode Diaspora',
                      );
                    } else {
                      Get.toNamed('/diaspo');
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.delivery_dining_rounded,
                  title: 'Mode Livreur',
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
                    AuthGuard.navigateIfAuthenticated(
                      context,
                      '/settings',
                      featureName: 'les paramètres',
                    );
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
                              Get.offAllNamed(Routes.LOGIN);
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
                    color: AppDesign.accent,
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
            SliverToBoxAdapter(
              child: _buildBannerCarousel(context),
            ),

            // DIASPO EXCHANGE Promo Card
            SliverToBoxAdapter(
              child: _buildDiaspoPromoCard(context),
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
                            gridDelegate: ProductCard.gridDelegate(context),
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
                            gridDelegate: ProductCard.gridDelegate(context),
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
                            gridDelegate: ProductCard.gridDelegate(context),
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
            final background =
                isSelected ? AppDesign.accentSubtle : context.ds.surface;
            final foreground =
                isSelected ? AppDesign.accentText : context.ds.textSecondary;
            final borderColor =
                isSelected ? AppDesign.accentBorder : context.ds.border;

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
                          child: Icon(Icons.grid_view_rounded,
                              size: 15, color: foreground),
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
                        category,
                        style: context.textStyle(
                          FontSizeType.caption,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
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
  Widget _buildCategorySvgIcon(String svgIcon, bool isSelected, BuildContext context) {
    final color =
        isSelected ? AppDesign.accentText : context.ds.textSecondary;
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
              featureName: 'le mode Diaspora',
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
                          'Diaspo Exchange',
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
                      const AppBadge(label: 'NOUVEAU', tone: AppBadgeTone.accent),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Achetez ou vendez des kilos de bagage',
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
            Icon(Icons.chevron_right_rounded,
                color: context.ds.textTertiary, size: 20),
          ],
        ),
      ),
    );
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

                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: AppThemeSystem.getHorizontalPadding(context),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image - API or local
                        _buildBannerImage(index),

                        // Gradient overlay - améliore la lisibilité du texte
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),

                        // Content - minimal
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                controller.banners.isNotEmpty
                                    ? (controller.banners[index]['title'] ?? data['title']!)
                                    : data['title']!,
                                style: context.textStyle(
                                  deviceType == DeviceType.mobile ? FontSizeType.h4 : FontSizeType.h3,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Découvrir',
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    fontWeight: FontWeight.w600,
                                    color: AppThemeSystem.primaryColor,
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
          const SizedBox(height: 12),
          Obx(() => Row(
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

    return 'Prix non défini';
  }

  /// Get product location
  String _getLocation(Map<String, dynamic> product) {
    return product['location']?.toString() ?? product['shop']?['address']?.toString() ?? '';
  }

  /// Check if shop is certified (handles bool, int, string)
  Widget _buildSectionTitle(BuildContext context, String title, IconData icon, {VoidCallback? onSeeAll}) {
    return AppSectionHeader(
      title: title,
      actionLabel: onSeeAll != null ? 'Voir tout' : null,
      onAction: onSeeAll,
    );
  }

  Widget _buildHorizontalProductList(BuildContext context, List<Map<String, dynamic>> products) {
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

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final productId = product['id'] is int
        ? product['id'] as int
        : int.tryParse('${product['id']}') ?? 0;

    return ProductCard(
      name: product['name']?.toString() ?? 'Produit',
      price: _formatPrice(product),
      location: _getLocation(product),
      isFavorite: product['is_favorite'] == true,
      isCertified: ProductCard.isShopCertified(product),
      imageBuilder: (context) => _buildProductImage(product),
      onTap: () => Get.toNamed('/product', arguments: product),
      onFavoriteTap:
          productId > 0 ? () => controller.toggleFavorite(productId) : null,
    );
  }

  /// Bouton "Voir plus" stylé
  Widget _buildSeeMoreButton(BuildContext context, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space5,
        context.ds.gutter,
        AppDesign.space2,
      ),
      child: AppButton(
        label: 'Voir plus de produits',
        onPressed: onTap,
        variant: AppButtonVariant.secondary,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: Icons.storefront_outlined,
      title: 'Aucun produit disponible',
      message:
          "Il n'y a pas encore de produits dans votre région. Revenez bientôt ou explorez une autre catégorie.",
      actionLabel: 'Actualiser',
      onAction: controller.refreshProducts,
    );
  }
}

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
