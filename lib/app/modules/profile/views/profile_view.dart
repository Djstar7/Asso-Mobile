import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/profile_controller.dart';
import '../../../core/widgets/app_ui.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final deviceType = AppThemeSystem.getDeviceType(context);

    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      // Onglet de l'accueil, la barre du haut porte déjà le titre. Ouvert
      // comme page à part, l'écran a besoin de sa propre sortie.
      appBar: AppNavigation.isHomeTab(context)
          ? null
          : AppBar(
              leading: const AppBackButton(),
              title: Text(
                'Compte',
                style: context.h5.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
      body: Obx(() {
        if (controller.userProfile.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }

      return SingleChildScrollView(
        child: Column(
          children: [
            // Header avec profil
            _buildProfileHeader(context, isDark, deviceType),

            SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

            // Menu principal (plus de Obx : aucune variable réactive à observer ici)
            _buildMenuSection(context, 'Mon compte', [
              _MenuItem(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Mon Wallet',
                subtitle: 'Solde, recharge et remboursements',
                onTap: controller.goToWallet,
              ),
              _MenuItem(
                icon: Icons.favorite_outline_rounded,
                title: 'Mes favoris',
                subtitle: 'Articles sauvegardés',
                onTap: controller.goToFavorites,
              ),
              _MenuItem(
                icon: Icons.receipt_long_rounded,
                title: 'Mes commandes',
                subtitle: 'Historique d\'achats',
                onTap: controller.goToOrders,
              ),
            ]),

            SizedBox(height: AppThemeSystem.getElementSpacing(context)),

            // Support & Paramètres
            _buildMenuSection(context, 'Support & Paramètres', [
              _MenuItem(
                icon: Icons.tune_rounded,
                title: 'Préférences',
                subtitle: 'Vos centres d\'intérêt',
                onTap: controller.goToPreferences,
              ),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Aide & Support',
                subtitle: 'FAQ et contact',
                onTap: controller.goToHelp,
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                title: 'Paramètres',
                subtitle: 'Préférences de l\'app',
                onTap: controller.goToSettings,
              ),
            ]),

            SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

            // Bouton déconnexion
            _buildLogoutButton(context, deviceType),

            // Espacement pour la barre de navigation native du téléphone
            SizedBox(
              height:
                  MediaQuery.of(context).viewPadding.bottom +
                  AppThemeSystem.getVerticalPadding(context),
            ),
          ],
        ),
      );}),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    bool isDark,
    DeviceType deviceType,
  ) {
    final profile = controller.userProfile;

    // En-tête compact posé sur une surface neutre.
    //
    // L'aplat orange occupait le tiers haut de l'écran et répétait le titre
    // « Compte » déjà présent dans la barre. La carte d'identité passe en
    // disposition horizontale : même information, trois fois moins de place,
    // et la liste de réglages devient visible sans défiler.
    return Container(
      color: context.ds.surface,
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space5,
        context.ds.gutter,
        AppDesign.space5,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppDesign.accentSubtle,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    profile['avatar']?.toString() ?? '',
                    style: context.textStyle(
                      FontSizeType.h5,
                      fontWeight: FontWeight.w700,
                      color: AppDesign.accentText,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppDesign.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.ds.surface, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(width: AppDesign.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile['name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.subtitle1,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile['email']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.caption,
                    color: context.ds.textSecondary,
                  ),
                ),
                if ((profile['location']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: context.ds.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          profile['location'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyle(
                            FontSizeType.overline,
                            color: context.ds.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: AppDesign.space2),
          AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Modifier le profil',
            onPressed: controller.editProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    String title,
    List<_MenuItem> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final deviceType = AppThemeSystem.getDeviceType(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
      ),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(
              AppThemeSystem.getHorizontalPadding(context),
            ),
            child: Text(
              title,
              style: context.textStyle(
                deviceType == DeviceType.mobile
                    ? FontSizeType.body2
                    : FontSizeType.body1,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.grey600,
              ),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;

            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.vertical(
                      bottom: isLast
                          ? Radius.circular(
                              AppThemeSystem.getBorderRadius(
                                context,
                                BorderRadiusType.medium,
                              ),
                            )
                          : Radius.zero,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppThemeSystem.getHorizontalPadding(
                          context,
                        ),
                        vertical: AppThemeSystem.getElementSpacing(context),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              AppThemeSystem.getElementSpacing(context) * 0.8,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeSystem.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: context.borderRadius(
                                BorderRadiusType.small,
                              ),
                            ),
                            child: Icon(
                              item.icon,
                              color: AppThemeSystem.primaryColor,
                              size: deviceType == DeviceType.mobile ? 24 : 28,
                            ),
                          ),
                          SizedBox(
                            width: AppThemeSystem.getElementSpacing(context),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: context.textStyle(
                                    deviceType == DeviceType.mobile
                                        ? FontSizeType.body1
                                        : FontSizeType.subtitle1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.subtitle != null) ...[
                                  SizedBox(
                                    height:
                                        AppThemeSystem.getElementSpacing(
                                          context,
                                        ) *
                                        0.25,
                                  ),
                                  Text(
                                    item.subtitle!,
                                    style: context.textStyle(
                                      deviceType == DeviceType.mobile
                                          ? FontSizeType.caption
                                          : FontSizeType.body2,
                                      color: AppThemeSystem.grey600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppThemeSystem.grey400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isLast) Divider(height: 1, indent: 72),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, DeviceType deviceType) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppThemeSystem.getButtonHeight(context),
        child: OutlinedButton.icon(
          onPressed: controller.logout,
          icon: Icon(
            Icons.logout_rounded,
            color: AppThemeSystem.errorColor,
            size: deviceType == DeviceType.mobile ? 20 : 24,
          ),
          label: Text(
            'Déconnexion',
            style: context.textStyle(
              deviceType == DeviceType.mobile
                  ? FontSizeType.body1
                  : FontSizeType.subtitle1,
              fontWeight: FontWeight.w600,
              color: AppThemeSystem.errorColor,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              vertical: AppThemeSystem.getElementSpacing(context),
              horizontal: AppThemeSystem.getHorizontalPadding(context),
            ),
            side: BorderSide(
              color: AppThemeSystem.errorColor,
              width: deviceType == DeviceType.mobile ? 1.5 : 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
