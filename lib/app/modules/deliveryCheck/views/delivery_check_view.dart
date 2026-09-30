import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/delivery_check_controller.dart';

/// Écran de vérification pour le mode livreur
/// Affiche un loader pendant la vérification et redirige automatiquement
class DeliveryCheckView extends GetView<DeliveryCheckController> {
  const DeliveryCheckView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // Sortie visible si la vérification traîne (réseau lent) : l'iPhone
      // n'a pas de bouton système pour quitter cet écran d'attente.
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Le logo reste centré sur l'écran entier, comme avant la barre.
      extendBodyBehindAppBar: true,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo de l'entreprise ou logo par défaut
            Obx(
              () => Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: controller.companyLogo.value != null
                    ? CachedNetworkImage(
                        imageUrl: controller.companyLogo.value!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox(
                          width: 80,
                          height: 80,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Image.asset(
                          'assets/images/logo.png',
                          width: 80,
                          height: 80,
                        ),
                      )
                    : Image.asset(
                        'assets/images/logo.png',
                        width: 80,
                        height: 80,
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Nom de l'entreprise (si disponible)
            Obx(
              () => controller.companyName.value.isNotEmpty
                  ? Column(
                      children: [
                        Text(
                          controller.companyName.value,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                      ],
                    )
                  : const SizedBox(height: 8),
            ),

            // Indicateur de chargement
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(height: 24),

            // Message de statut
            Obx(
              () => Text(
                controller.statusMessage.value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),

            // Message secondaire
            Text(
              'delivery_check.please_wait'.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
