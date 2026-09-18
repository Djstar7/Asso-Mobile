import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/shop_statistics_controller.dart';

/// Écran « Statistiques de ma boutique » (P8).
class ShopStatisticsView extends GetView<ShopStatisticsController> {
  const ShopStatisticsView({super.key});

  static final _count = NumberFormat.decimalPattern('fr_FR');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Statistiques de ma boutique'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: controller.load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.horizontalPadding),
          children: [
            _PeriodSelector(),
            SizedBox(height: context.elementSpacing),
            Obx(() {
              if (controller.isLoading.value && controller.totals.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (controller.errorMessage.value != null && controller.totals.isEmpty) {
                return _ErrorState(message: controller.errorMessage.value!);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.isLoading.value)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  _buildKpis(context),
                  SizedBox(height: context.sectionSpacing),
                  _EvolutionCard(),
                  SizedBox(height: context.sectionSpacing),
                  _TopProductsCard(),
                  SizedBox(height: context.sectionSpacing),
                  _AllTimeCard(),
                  SizedBox(height: context.sectionSpacing),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildKpis(BuildContext context) {
    final t = controller.totals;
    final cards = <Widget>[
      _KpiCard(
        icon: Icons.storefront_outlined,
        label: 'Visites de la boutique',
        value: _count.format(controller.intOf(t, 'visits')),
        trendKey: 'visits',
        color: AppThemeSystem.infoColor,
      ),
      _KpiCard(
        icon: Icons.people_outline,
        label: 'Visiteurs uniques',
        value: _count.format(controller.intOf(t, 'unique_visitors')),
        trendKey: 'unique_visitors',
        color: Colors.indigo,
      ),
      _KpiCard(
        icon: Icons.visibility_outlined,
        label: 'Produits consultés',
        value: _count.format(controller.intOf(t, 'product_views')),
        trendKey: 'product_views',
        color: Colors.purple,
      ),
      _KpiCard(
        icon: Icons.chat_bubble_outline,
        label: 'Contacts reçus',
        value: _count.format(controller.intOf(t, 'contacts')),
        trendKey: 'contacts',
        color: Colors.teal,
      ),
      _KpiCard(
        icon: Icons.shopping_cart_outlined,
        label: 'Commandes',
        value: _count.format(controller.intOf(t, 'orders')),
        trendKey: 'orders',
        color: AppThemeSystem.warningColor,
        hint: '${controller.intOf(t, 'pending_orders')} en attente',
      ),
      _KpiCard(
        icon: Icons.check_circle_outline,
        label: 'Ventes validées',
        value: _count.format(controller.intOf(t, 'validated_orders')),
        trendKey: 'validated_orders',
        color: AppThemeSystem.successColor,
        hint: '${_count.format(controller.intOf(t, 'items_sold'))} article(s)',
      ),
      _KpiCard(
        icon: Icons.payments_outlined,
        label: 'Chiffre d\'affaires',
        value: controller.formatPrice(controller.doubleOf(t, 'revenue')),
        trendKey: 'revenue',
        color: Colors.green.shade700,
        hint: 'Panier moyen ${controller.formatPrice(controller.doubleOf(t, 'average_basket'))}',
      ),
      _KpiCard(
        icon: Icons.percent,
        label: 'Taux de conversion',
        value: '${controller.doubleOf(t, 'conversion_rate').toStringAsFixed(1)} %',
        color: Colors.pink,
        hint: 'Ventes / visiteurs',
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 600 ? 4 : 2;
      const spacing = 10.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cards.map((c) => SizedBox(width: width, child: c)).toList(),
      );
    });
  }
}

class _PeriodSelector extends GetView<ShopStatisticsController> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Obx(() => Row(
            children: ShopStatisticsController.periods.entries.map((entry) {
              final selected = controller.period.value == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  selectedColor: AppThemeSystem.primaryColor,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : context.primaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => controller.changePeriod(entry.key),
                ),
              );
            }).toList(),
          )),
    );
  }
}

class _KpiCard extends GetView<ShopStatisticsController> {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? trendKey;
  final String? hint;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.trendKey,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (trendKey != null && controller.hasTrends) _trendBadge(controller.trendOf(trendKey!)),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.h5.copyWith(fontWeight: FontWeight.bold, color: context.primaryTextColor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.caption.copyWith(color: context.secondaryTextColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hint != null)
            Text(
              hint!,
              style: context.caption.copyWith(color: context.secondaryTextColor, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _trendBadge(double? trend) {
    final Color c;
    final String text;
    if (trend == null) {
      c = AppThemeSystem.successColor;
      text = 'nouveau';
    } else if (trend > 0) {
      c = AppThemeSystem.successColor;
      text = '+${trend.toStringAsFixed(0)} %';
    } else if (trend < 0) {
      c = AppThemeSystem.errorColor;
      text = '${trend.toStringAsFixed(0)} %';
    } else {
      c = Colors.grey;
      text = '=';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _EvolutionCard extends GetView<ShopStatisticsController> {
  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.bar_chart,
      title: 'Évolution',
      child: Obx(() {
        final metric = controller.metric.value;
        final points = controller.series;
        final values = points.map((p) => (p[metric.apiKey] as num?)?.toDouble() ?? 0).toList();
        final monthly = controller.granularity.value == 'month';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: StatsMetric.values.map((m) {
                final selected = m == metric;
                return ChoiceChip(
                  label: Text(m.label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => controller.metric.value = m,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: values.every((v) => v == 0)
                  ? Center(
                      child: Text(
                        'Aucune donnée sur la période',
                        style: context.body2.copyWith(color: context.secondaryTextColor),
                      ),
                    )
                  : _BarChart(
                      values: values,
                      color: AppThemeSystem.primaryColor,
                      formatter: (v) => metric == StatsMetric.revenue
                          ? controller.formatPrice(v)
                          : v.toStringAsFixed(0),
                    ),
            ),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_label(points.first['date'], monthly), style: context.caption),
                  Text(_label(points.last['date'], monthly), style: context.caption),
                ],
              ),
            ],
          ],
        );
      }),
    );
  }

  String _label(dynamic raw, bool monthly) {
    final parts = raw.toString().split('-');
    if (monthly && parts.length >= 2) return '${parts[1]}/${parts[0]}';
    if (parts.length == 3) return '${parts[2]}/${parts[1]}';
    return raw.toString();
  }
}

/// Histogramme léger sans dépendance ; un appui long affiche la valeur.
class _BarChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final String Function(double) formatter;

  const _BarChart({required this.values, required this.color, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, math.max);
    return LayoutBuilder(builder: (context, constraints) {
      final gap = values.length > 60 ? 1.0 : 3.0;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final ratio = maxValue > 0 ? v / maxValue : 0.0;
          return Expanded(
            child: Tooltip(
              message: formatter(v),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gap / 2),
                child: Container(
                  height: math.max(2, constraints.maxHeight * ratio),
                  decoration: BoxDecoration(
                    color: v > 0 ? color : color.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _TopProductsCard extends GetView<ShopStatisticsController> {
  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.local_fire_department_outlined,
      title: 'Produits les plus consultés',
      child: Obx(() {
        if (controller.topProducts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aucune consultation ni vente sur la période.',
              style: context.body2.copyWith(color: context.secondaryTextColor),
            ),
          );
        }
        return Column(
          children: controller.topProducts.map((p) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                p['name']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.body1.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${controller.intOf(p, 'views')} vue(s) · ${controller.intOf(p, 'items_sold')} vendu(s)',
                style: context.caption,
              ),
              trailing: Text(
                controller.formatPrice(controller.doubleOf(p, 'revenue')),
                style: context.body2.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppThemeSystem.successColor,
                ),
              ),
            );
          }).toList(),
        );
      }),
    );
  }
}

class _AllTimeCard extends GetView<ShopStatisticsController> {
  @override
  Widget build(BuildContext context) {
    final count = ShopStatisticsView._count;
    return _Section(
      icon: Icons.history,
      title: 'Depuis l\'ouverture',
      child: Obx(() {
        final a = controller.allTime;
        final rows = <List<String>>[
          ['Visites', count.format(controller.intOf(a, 'visits'))],
          ['Visites (7 derniers jours)', count.format(controller.intOf(a, 'visits_last_7_days'))],
          ['Produits consultés', count.format(controller.intOf(a, 'product_views'))],
          ['Contacts reçus', count.format(controller.intOf(a, 'contacts'))],
          ['Commandes', count.format(controller.intOf(a, 'orders'))],
          ['Ventes validées', count.format(controller.intOf(a, 'sales_count'))],
          ['Articles vendus', count.format(controller.intOf(a, 'items_sold'))],
          ['Chiffre d\'affaires', controller.formatPrice(controller.doubleOf(a, 'revenue'))],
        ];
        return Column(
          children: rows
              .map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(r[0], style: context.body2.copyWith(color: context.secondaryTextColor)),
                        ),
                        Text(r[1], style: context.body2.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ))
              .toList(),
        );
      }),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Section({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppThemeSystem.primaryColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: context.h6.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: context.elementSpacing),
          child,
        ],
      ),
    );
  }
}

class _ErrorState extends GetView<ShopStatisticsController> {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.insights_outlined, size: 56, color: context.secondaryTextColor),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: context.body1),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
