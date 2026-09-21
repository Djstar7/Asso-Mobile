import 'package:flutter/material.dart';

import '../../../core/utils/app_design.dart';
import '../../../data/models/boost_models.dart';

/// Résumé d'une campagne : progression du quota et portée délivrée.
class BoostCampaignCard extends StatelessWidget {
  final BoostCampaign campaign;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const BoostCampaignCard({
    super.key,
    required this.campaign,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppDesign.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesign.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: AppDesign.surfaceMuted(context),
                    child: campaign.productImage != null &&
                            campaign.productImage!.isNotEmpty
                        ? Image.network(
                            campaign.productImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Icon(
                              Icons.inventory_2_outlined,
                              size: 20,
                              color: AppDesign.icon(context),
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: AppDesign.icon(context),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppDesign.textPrimary(context),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _statusChip(context),
                    ],
                  ),
                ),
                if (onCancel != null)
                  IconButton(
                    onPressed: onCancel,
                    icon: Icon(
                      Icons.stop_circle_outlined,
                      size: 20,
                      color: AppDesign.textTertiary(context),
                    ),
                    tooltip: 'Arrêter',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Progression du quota acheté
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: campaign.progressFraction,
                minHeight: 6,
                backgroundColor: AppDesign.surfaceMuted(context),
                valueColor: AlwaysStoppedAnimation(
                  campaign.isRunning ? AppDesign.accent : AppDesign.neutral400,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_n(campaign.impressionsServed)} / ${_n(campaign.impressionsQuota)} personnes touchées',
                    style: TextStyle(
                      color: AppDesign.textSecondary(context),
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (campaign.isRunning)
                  Text(
                    campaign.remainingDays > 0
                        ? '${campaign.remainingDays} j restant${campaign.remainingDays > 1 ? 's' : ''}'
                        : 'Dernier jour',
                    style: TextStyle(
                      color: AppDesign.textTertiary(context),
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context) {
    final running = campaign.isRunning;
    final color = running ? AppDesign.success : AppDesign.neutral500;
    final background =
        running ? AppDesign.successSubtle : AppDesign.surfaceMuted(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        campaign.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _n(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }

    return buffer.toString();
  }
}
