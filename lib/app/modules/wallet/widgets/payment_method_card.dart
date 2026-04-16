import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:asso/app/core/utils/responsive.dart';
import 'package:flutter/material.dart';

/// Card pour afficher les méthodes de paiement avec image en background
class PaymentMethodCard extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color? overlayColor;

  const PaymentMethodCard({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.description,
    required this.onTap,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    // Déterminer l'opacité en fonction du thème
    final isDark = AppThemeSystem.isDarkMode(context);
    final overlayStartOpacity = isDark ? 0.5 : 0.4;
    final overlayEndOpacity = isDark ? 0.75 : 0.7;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Responsive.radiusLG),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.radiusLG),
          child: Stack(
            children: [
              // Image de fond
              Positioned.fill(
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            overlayColor ?? Colors.blue.shade700,
                            overlayColor?.withValues(alpha: 0.8) ?? Colors.blue.shade900,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Overlay gradient semi-transparent pour la lisibilité (adapté au thème)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: overlayStartOpacity),
                        Colors.black.withValues(alpha: overlayEndOpacity),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              // Contenu
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
