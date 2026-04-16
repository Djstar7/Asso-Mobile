import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final deviceType = AppThemeSystem.getDeviceType(context);

    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
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

                // Menu principal
                Obx(() {
                  final isVendor = controller.isVendor;

                  return _buildMenuSection(
                    context,
                    'Mon compte',
                    [
                      _MenuItem(
                        icon: isVendor ? Icons.inventory_rounded : Icons.store_rounded,
                        title: isVendor ? 'Mes produits' : 'Devenir Vendeur',
                        subtitle: isVendor ? 'Gérer mes annonces' : 'Vendez vos produits',
                        onTap: isVendor ? controller.goToMyProducts : controller.goToBecomeVendor,
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
                    ],
                  );
                }),

                SizedBox(height: AppThemeSystem.getElementSpacing(context)),

                // Support & Paramètres
                _buildMenuSection(
                  context,
                  'Support & Paramètres',
                  [
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
                  ],
                ),

                SizedBox(height: AppThemeSystem.getSectionSpacing(context)),

                // Bouton déconnexion
                _buildLogoutButton(context, deviceType),

                // Espacement pour la barre de navigation native du téléphone
                SizedBox(height: MediaQuery.of(context).viewPadding.bottom + AppThemeSystem.getVerticalPadding(context)),
              ],
            ),
          );
      }),
    );
  }

  Widget _buildProfileHeader(BuildContext context, bool isDark, DeviceType deviceType) {
    final profile = controller.userProfile;

    return Container(
      padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeSystem.primaryColor,
            AppThemeSystem.tertiaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mon Profil',
                style: context.textStyle(
                  FontSizeType.h5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                ),
                onPressed: controller.editProfile,
              ),
            ],
          ),
          SizedBox(height: AppThemeSystem.getElementSpacing(context)),
          // Avatar
          Stack(
            children: [
              Container(
                width: deviceType == DeviceType.mobile ? 100 : 120,
                height: deviceType == DeviceType.mobile ? 100 : 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.3),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    profile['avatar'],
                    style: context.textStyle(
                      FontSizeType.h2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppThemeSystem.getElementSpacing(context)),
          Text(
            profile['name'],
            style: context.textStyle(
              deviceType == DeviceType.mobile ? FontSizeType.h4 : FontSizeType.h3,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: AppThemeSystem.getElementSpacing(context) * 0.5),
          Text(
            profile['email'],
            style: context.textStyle(
              deviceType == DeviceType.mobile ? FontSizeType.body2 : FontSizeType.body1,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: AppThemeSystem.getElementSpacing(context) * 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              SizedBox(width: 4),
              Text(
                profile['location'],
                style: context.textStyle(
                  FontSizeType.caption,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          SizedBox(height: AppThemeSystem.getElementSpacing(context) * 0.75),
          Text(
            profile['memberSince'],
            style: context.textStyle(
              deviceType == DeviceType.mobile ? FontSizeType.caption : FontSizeType.body2,
              color: Colors.white.withValues(alpha: 0.8),
            ),
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
    final deviceType = AppThemeSystem.getDeviceType(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppThemeSystem.getHorizontalPadding(context)),
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
            padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
            child: Text(
              title,
              style: context.textStyle(
                deviceType == DeviceType.mobile ? FontSizeType.body2 : FontSizeType.body1,
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
                      bottom: isLast ? Radius.circular(AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium)) : Radius.zero,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppThemeSystem.getHorizontalPadding(context),
                        vertical: AppThemeSystem.getElementSpacing(context),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(AppThemeSystem.getElementSpacing(context) * 0.8),
                            decoration: BoxDecoration(
                              color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                              borderRadius: context.borderRadius(BorderRadiusType.small),
                            ),
                            child: Icon(
                              item.icon,
                              color: AppThemeSystem.primaryColor,
                              size: deviceType == DeviceType.mobile ? 24 : 28,
                            ),
                          ),
                          SizedBox(width: AppThemeSystem.getElementSpacing(context)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: context.textStyle(
                                    deviceType == DeviceType.mobile ? FontSizeType.body1 : FontSizeType.subtitle1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.subtitle != null) ...[
                                  SizedBox(height: AppThemeSystem.getElementSpacing(context) * 0.25),
                                  Text(
                                    item.subtitle!,
                                    style: context.textStyle(
                                      deviceType == DeviceType.mobile ? FontSizeType.caption : FontSizeType.body2,
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
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 72,
                  ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, DeviceType deviceType) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppThemeSystem.getHorizontalPadding(context)),
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
              deviceType == DeviceType.mobile ? FontSizeType.body1 : FontSizeType.subtitle1,
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
