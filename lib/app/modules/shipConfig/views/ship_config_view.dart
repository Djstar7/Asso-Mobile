import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/ship_config_controller.dart';

class ShipConfigView extends GetView<ShipConfigController> {
  const ShipConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: context.primaryTextColor,
            ),
            onPressed: () {
              // Vérifier si on peut retourner en arrière
              if (Navigator.of(context).canPop()) {
                Get.back();
              } else {
                // Si pas de page précédente, retourner à Home
                Get.offAllNamed('/home');
              }
            },
          ),
        title: Text(
          'Devenir Livreur',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: context.sectionSpacing),

            // Illustration
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delivery_dining,
                size: 100,
                color: AppThemeSystem.primaryColor,
              ),
            ),

            SizedBox(height: context.sectionSpacing),

            // Titre
            Text(
              'Devenez Livreur Partenaire',
              style: context.h3.copyWith(
                fontWeight: FontWeight.bold,
                color: context.primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: context.elementSpacing),

            // Description
            Text(
              'Synchronisez votre profil avec votre entreprise de livraison pour commencer à recevoir des demandes.',
              style: context.body1.copyWith(
                color: context.secondaryTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: context.sectionSpacing),

            // Carte d'information sur le code de synchronisation
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                          borderRadius: context.borderRadius(BorderRadiusType.small),
                        ),
                        child: Icon(
                          Icons.sync_alt,
                          color: AppThemeSystem.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Code de synchronisation',
                          style: context.h6.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Entrez le code reçu de votre entreprise de livraison',
                    style: context.body2.copyWith(
                      color: context.secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller.syncCodeController,
                    textAlign: TextAlign.center,
                    style: context.body1.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2.0,
                      fontSize: 18,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 14,
                    decoration: InputDecoration(
                      hintText: 'XXXX-XXXX-XXXX',
                      hintStyle: context.body2.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                        color: AppThemeSystem.grey400,
                      ),
                      filled: true,
                      fillColor: AppThemeSystem.grey100,
                      border: OutlineInputBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.small),
                        borderSide: BorderSide(color: AppThemeSystem.grey300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.small),
                        borderSide: BorderSide(color: AppThemeSystem.grey300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.small),
                        borderSide: BorderSide(
                          color: AppThemeSystem.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: context.sectionSpacing),

            // Bouton principal - Synchroniser le profil
            SizedBox(
              width: double.infinity,
              child: Obx(() => ElevatedButton.icon(
                    onPressed: controller.isSyncing.value
                        ? null
                        : controller.syncProfileToDelivery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: AppThemeSystem.grey300,
                      shape: RoundedRectangleBorder(
                        borderRadius: context.borderRadius(BorderRadiusType.medium),
                      ),
                    ),
                    icon: controller.isSyncing.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.sync, size: 22),
                    label: Text(
                      controller.isSyncing.value
                          ? 'Synchronisation en cours...'
                          : 'Activer mon profil livreur',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
