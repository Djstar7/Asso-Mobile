import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/delivery_info.dart';
import '../utils/app_theme_system.dart';

typedef PriceFormatter = String Function(double amount);

/// Ligne « libellé ……… valeur » utilisée dans tous les détails de livraison.
class DeliveryInfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  const DeliveryInfoLine(
    this.label,
    this.value, {
    super.key,
    this.strong = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: context.caption.copyWith(
                fontWeight: strong ? FontWeight.w700 : null,
                color: strong ? context.primaryTextColor : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.textStyle(
                strong ? FontSizeType.body1 : FontSizeType.body2,
                fontWeight: strong ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? (strong ? AppThemeSystem.primaryColor : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petite puce (catégorie Urbain / Interurbain / International…).
class DeliveryChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const DeliveryChip(this.label, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.caption,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color deliveryCategoryColor(String serviceType) {
  switch (serviceType) {
    case 'intercity':
      return AppThemeSystem.infoColor;
    case 'international':
      return Colors.purple;
    default:
      return AppThemeSystem.successColor;
  }
}

/// Détail complet du prix : poids, tranche, kg supplémentaires, HT, TVA,
/// commission ASSO, total, grille de la route et conditions.
class DeliveryBreakdownView extends StatelessWidget {
  final DeliveryBreakdown? breakdown;
  final List<DeliveryPriceGridRow> priceGrid;
  final String? conditions;
  final double? weightKg;
  final double? fallbackTotal;
  final PriceFormatter formatPrice;

  const DeliveryBreakdownView({
    super.key,
    required this.breakdown,
    required this.formatPrice,
    this.priceGrid = const [],
    this.conditions,
    this.weightKg,
    this.fallbackTotal,
  });

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    final weight = b?.weightKg ?? weightKg;
    final extraPerKg = b?.extraPerKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (weight != null) DeliveryInfoLine('Poids total du colis', formatKg(weight)),
        if (b != null) ...[
          if (b.rangeLabel != null)
            DeliveryInfoLine(
              'Tranche appliquée',
              b.rangePrice != null
                  ? '${b.rangeLabel} — ${formatPrice(b.rangePrice!)}'
                  : b.rangeLabel!,
            ),
          if (b.extraKg > 0)
            DeliveryInfoLine(
              'Kg supplémentaires',
              '${formatKg(b.extraKg)} × ${formatPrice(extraPerKg ?? 0)} = ${formatPrice(b.extraPrice)}',
            ),
          // Transport + livraison à domicile : les deux volets du prix.
          if (b.legs.length > 1)
            for (final leg in b.legs)
              DeliveryInfoLine(leg.label, formatPrice(leg.price)),
          if (b.carrierPriceHt != null)
            DeliveryInfoLine(
              b.pricesExcludeVat
                  ? 'Prix transporteur HT'
                  : 'Prix transporteur',
              formatPrice(b.carrierPriceHt!),
            ),
          if (b.pricesExcludeVat || b.vatAmount > 0)
            DeliveryInfoLine(
              'TVA ${formatRate(b.vatRate)}',
              formatPrice(b.vatAmount),
            ),
          if (b.carrierPrice != null && b.vatAmount > 0)
            DeliveryInfoLine('Prix transporteur TTC', formatPrice(b.carrierPrice!)),
          if (b.assoCommission > 0)
            DeliveryInfoLine('Commission ASSO', formatPrice(b.assoCommission)),
        ],
        if ((b?.total ?? fallbackTotal) != null) ...[
          const Divider(height: 14),
          DeliveryInfoLine(
            'Total livraison',
            formatPrice(b?.total ?? fallbackTotal!),
            strong: true,
          ),
        ],
        if (priceGrid.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Grille tarifaire',
            style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in priceGrid)
                  DeliveryInfoLine(
                    row.label,
                    formatPrice(row.price),
                    valueColor: b?.rangeLabel == row.label
                        ? AppThemeSystem.primaryColor
                        : null,
                  ),
                if (extraPerKg != null && extraPerKg > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'puis ${formatPrice(extraPerKg)} / kg supplémentaire',
                      style: context.caption,
                    ),
                  ),
                if (b?.pricesExcludeVat == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Tarifs hors taxes, TVA ${formatRate(b?.vatRate)} en sus.',
                      style: context.caption,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (conditions != null && conditions!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Conditions du transporteur',
            style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(conditions!.trim(), style: context.caption),
        ],
      ],
    );
  }
}

/// Bloc d'identité du service : partenaire, catégorie, mode, trajet, délai.
class DeliveryServiceLines extends StatelessWidget {
  final String? companyName;
  final String? serviceTypeLabel;
  final String? serviceModeLabel;
  final String? routeLabel;
  final String? leadTime;

  const DeliveryServiceLines({
    super.key,
    this.companyName,
    this.serviceTypeLabel,
    this.serviceModeLabel,
    this.routeLabel,
    this.leadTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (companyName != null) DeliveryInfoLine('Partenaire', companyName!),
        if (serviceTypeLabel != null) DeliveryInfoLine('Catégorie', serviceTypeLabel!),
        if (serviceModeLabel != null) DeliveryInfoLine('Mode', serviceModeLabel!),
        if (routeLabel != null) DeliveryInfoLine('Trajet', routeLabel!),
        if (leadTime != null) DeliveryInfoLine('Délai', leadTime!),
      ],
    );
  }
}

/// Encadré d'information (retrait en agence, poids manquant…).
class DeliveryNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const DeliveryNotice(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.color = AppThemeSystem.infoColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.textStyle(
                FontSizeType.caption,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Transporteur + numéro de suivi copiable + lien de suivi externe.
class CarrierTrackingCard extends StatelessWidget {
  final String? companyName;
  final String? trackingNumber;
  final String? trackingUrl;

  const CarrierTrackingCard({
    super.key,
    this.companyName,
    this.trackingNumber,
    this.trackingUrl,
  });

  Future<void> _openUrl() async {
    final uri = Uri.tryParse(trackingUrl ?? '');
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception();
    } catch (_) {
      Get.snackbar(
        'Erreur',
        'Impossible d’ouvrir le site du transporteur.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final number = trackingNumber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeSystem.infoColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeSystem.infoColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded,
                  size: 18, color: AppThemeSystem.infoColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Transporteur${companyName != null ? ' : $companyName' : ''}',
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (number == null)
            Text(
              'Le numéro de suivi sera disponible dès que le vendeur aura remis le colis au transporteur.',
              style: context.caption,
            )
          else
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: number));
                Get.snackbar(
                  'Copié',
                  'Numéro de suivi copié',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text('N° de suivi : ', style: context.caption),
                    Expanded(
                      child: SelectableText(
                        number,
                        style: context.textStyle(
                          FontSizeType.body1,
                          fontWeight: FontWeight.bold,
                        ).copyWith(letterSpacing: 1),
                      ),
                    ),
                    const Icon(Icons.copy_rounded, size: 18),
                  ],
                ),
              ),
            ),
          if (trackingUrl != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openUrl,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Suivre chez le transporteur'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeSystem.infoColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chronologie datée des étapes de livraison.
class DeliveryTimelineView extends StatelessWidget {
  final List<DeliveryTimelineStep> steps;

  const DeliveryTimelineView({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR');
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        final cancelled = step.step == 'cancelled';
        final color = cancelled
            ? AppThemeSystem.errorColor
            : AppThemeSystem.primaryColor;
        final details = [
          if (step.location != null) step.location!,
          if (step.note != null) step.note!,
        ];

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isLast ? color : color.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cancelled ? Icons.close : Icons.check,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: color.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label,
                        style: context.textStyle(
                          FontSizeType.body2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (step.occurredAt != null) ...[
                        const SizedBox(height: 2),
                        Text(fmt.format(step.occurredAt!), style: context.caption),
                      ],
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(details.join(' — '), style: context.caption),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Carte « Livraison » d'une commande : service, suivi transporteur, détail
/// du prix. Utilisée côté acheteur et côté vendeur.
class OrderDeliveryDetails extends StatelessWidget {
  final DeliveryInfo delivery;
  final PriceFormatter formatPrice;
  final double? deliveryFee;
  final bool showTimeline;

  const OrderDeliveryDetails({
    super.key,
    required this.delivery,
    required this.formatPrice,
    this.deliveryFee,
    this.showTimeline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeliveryServiceLines(
          companyName: delivery.companyName,
          serviceTypeLabel: delivery.serviceTypeLabel,
          serviceModeLabel: delivery.serviceModeLabel,
          routeLabel: delivery.routeLabel,
          leadTime: delivery.leadTime,
        ),
        if (delivery.trackingStatusLabel != null)
          DeliveryInfoLine('Statut', delivery.trackingStatusLabel!),
        if (delivery.isCarrier) ...[
          const SizedBox(height: 8),
          CarrierTrackingCard(
            companyName: delivery.companyName,
            trackingNumber: delivery.carrierTrackingNumber,
            trackingUrl: delivery.carrierTrackingUrl,
          ),
        ],
        if (showTimeline && delivery.timeline.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Suivi',
            style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DeliveryTimelineView(steps: delivery.timeline),
        ],
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              'Détail du prix de livraison',
              style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600),
            ),
            children: [
              DeliveryBreakdownView(
                breakdown: delivery.breakdown,
                priceGrid: delivery.priceGrid,
                conditions: delivery.conditions,
                weightKg: delivery.weightKg,
                fallbackTotal: deliveryFee,
                formatPrice: formatPrice,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Feuille « Détails » d'un devis de livraison, avant de valider la commande.
Future<void> showDeliveryQuoteDetails(
  BuildContext context,
  DeliveryPartnerQuote quote, {
  required PriceFormatter formatPrice,
  double? weightKg,
  VoidCallback? onChoose,
}) {
  return Get.bottomSheet(
    Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: AppThemeSystem.getBackgroundColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppThemeSystem.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      quote.companyName,
                      style: context.textStyle(FontSizeType.h5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        DeliveryChip(
                          quote.categoryLabel,
                          color: deliveryCategoryColor(quote.serviceType),
                        ),
                        DeliveryChip(
                          quote.isAgencyToAgency ? 'Agence → agence' : 'À domicile',
                          color: AppThemeSystem.grey700,
                          icon: quote.isAgencyToAgency
                              ? Icons.store_mall_directory_outlined
                              : Icons.home_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DeliveryServiceLines(
                      serviceTypeLabel: quote.serviceTypeLabel,
                      serviceModeLabel: quote.serviceModeLabel,
                      routeLabel: quote.routeOrZone,
                      leadTime: quote.leadTime,
                    ),
                    if (quote.maxWeightKg != null)
                      DeliveryInfoLine('Poids maximum', formatKg(quote.maxWeightKg)),
                    if (quote.pickupNotice != null) ...[
                      const SizedBox(height: 8),
                      DeliveryNotice(
                        quote.pickupNotice!,
                        icon: Icons.store_mall_directory_outlined,
                      ),
                    ],
                    const Divider(height: 24),
                    DeliveryBreakdownView(
                      breakdown: quote.breakdown,
                      priceGrid: quote.priceGrid,
                      conditions: quote.conditions,
                      weightKg: weightKg,
                      fallbackTotal: quote.price,
                      formatPrice: formatPrice,
                    ),
                  ],
                ),
              ),
            ),
            if (onChoose != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      onChoose();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Choisir ce partenaire — ${formatPrice(quote.price)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}
