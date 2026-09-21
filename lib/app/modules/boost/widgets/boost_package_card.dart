import 'package:flutter/material.dart';

import '../../../core/utils/app_design.dart';
import '../../../data/models/boost_models.dart';

/// Une formule de sponsoring : audience achetée, durée, prix.
class BoostPackageCard extends StatelessWidget {
  final BoostPackage package;
  final bool selected;
  final VoidCallback onTap;

  const BoostPackageCard({
    super.key,
    required this.package,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppDesign.accentSubtle : AppDesign.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppDesign.accent : AppDesign.border(context),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            // Marqueur de sélection
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppDesign.accent : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppDesign.accent
                      : AppDesign.borderStrong(context),
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          package.name,
                          style: TextStyle(
                            color: AppDesign.textPrimary(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (package.isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppDesign.accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Populaire',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: AppDesign.textSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        package.formattedReach,
                        style: TextStyle(
                          color: AppDesign.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppDesign.textSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        package.formattedDuration,
                        style: TextStyle(
                          color: AppDesign.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),
            Text(
              package.formattedPrice,
              style: TextStyle(
                color: selected
                    ? AppDesign.accentText
                    : AppDesign.textPrimary(context),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
