import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';

import '../../../core/widgets/currency_switcher.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/shop_statistics_controller.dart';

/// Écran « Statistiques de ma boutique » (P8).
class ShopStatisticsView extends GetView<ShopStatisticsController> {
  const ShopStatisticsView({super.key});

  static NumberFormat get _count => NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Scaffold(
      backgroundColor: ds.canvas,
      appBar: AppBar(
        backgroundColor: ds.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'shop_statistics.title'.tr,
          style: context.h5.copyWith(
            fontWeight: FontWeight.w700,
            color: ds.textPrimary,
          ),
        ),
        actions: [
          // Le choix de devise pilote tout l'écran : les montants sont
          // convertis à l'affichage, aucun rechargement n'est nécessaire.
          const CurrencySwitcher(compact: true),
          SizedBox(width: AppDesign.space1),
          Obx(() => IconButton(
                icon: controller.isExporting.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppDesign.accent,
                        ),
                      )
                    : Icon(Icons.ios_share_rounded,
                        color: ds.textSecondary, size: 20),
                tooltip: 'shop_statistics.export.title'.tr,
                onPressed: controller.isExporting.value
                    ? null
                    : () => _openExportSheet(context),
              )),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ds.textSecondary, size: 20),
            tooltip: 'shop_statistics.refresh'.tr,
            onPressed: controller.load,
          ),
          SizedBox(width: AppDesign.space1),
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

  /// Choix du format d'export, puis partage du fichier téléchargé.
  void _openExportSheet(BuildContext context) {
    final ds = context.ds;

    Get.bottomSheet<void>(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppDesign.space3),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ds.borderStrong,
                borderRadius: BorderRadius.circular(AppDesign.radiusPill),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDesign.space5,
                AppDesign.space5,
                AppDesign.space5,
                AppDesign.space2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'shop_statistics.export.title'.tr,
                    style: context.h6.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ds.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppDesign.space1),
                  Obx(() => Text(
                        'shop_statistics.export.period'.trParams({
                          'period': ShopStatisticsController.periods[controller.period.value] ?? '',
                        }),
                        style: context.body2.copyWith(color: ds.textSecondary),
                      )),
                ],
              ),
            ),
            _ExportOption(
              icon: Icons.picture_as_pdf_outlined,
              title: 'shop_statistics.export.pdf_title'.tr,
              subtitle: 'shop_statistics.export.pdf_subtitle'.tr,
              onTap: () {
                Get.back();
                controller.exportReport('pdf');
              },
            ),
            Divider(height: 1, color: ds.border, indent: AppDesign.space5),
            _ExportOption(
              icon: Icons.table_chart_outlined,
              title: 'shop_statistics.export.csv_title'.tr,
              subtitle: 'shop_statistics.export.csv_subtitle'.tr,
              onTap: () {
                Get.back();
                controller.exportReport('csv');
              },
            ),
            SizedBox(height: AppDesign.space4),
          ],
        ),
      ),
      backgroundColor: ds.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDesign.radiusXl)),
      ),
    );
  }

  Widget _buildKpis(BuildContext context) {
    final t = controller.totals;
    final cards = <Widget>[
      _KpiCard(
        icon: Icons.storefront_outlined,
        label: 'shop_statistics.kpi.shop_visits'.tr,
        value: _count.format(controller.intOf(t, 'visits')),
        trendKey: 'visits',
      ),
      _KpiCard(
        icon: Icons.people_outline,
        label: 'shop_statistics.kpi.unique_visitors'.tr,
        value: _count.format(controller.intOf(t, 'unique_visitors')),
        trendKey: 'unique_visitors',
      ),
      _KpiCard(
        icon: Icons.visibility_outlined,
        label: 'shop_statistics.metric.product_views'.tr,
        value: _count.format(controller.intOf(t, 'product_views')),
        trendKey: 'product_views',
      ),
      _KpiCard(
        icon: Icons.chat_bubble_outline,
        label: 'shop_statistics.kpi.contacts'.tr,
        value: _count.format(controller.intOf(t, 'contacts')),
        trendKey: 'contacts',
      ),
      _KpiCard(
        icon: Icons.shopping_cart_outlined,
        label: 'shop_statistics.metric.orders'.tr,
        value: _count.format(controller.intOf(t, 'orders')),
        trendKey: 'orders',
        hint: 'shop_statistics.kpi.pending'.trParams({'count': '${controller.intOf(t, 'pending_orders')}'}),
      ),
      _KpiCard(
        icon: Icons.check_circle_outline,
        label: 'shop_statistics.kpi.validated_sales'.tr,
        value: _count.format(controller.intOf(t, 'validated_orders')),
        trendKey: 'validated_orders',
        hint: 'shop_statistics.kpi.items'.trParams({'count': _count.format(controller.intOf(t, 'items_sold'))}),
      ),
      _KpiCard(
        icon: Icons.payments_outlined,
        label: 'shop_statistics.metric.revenue'.tr,
        value: controller.formatPrice(controller.doubleOf(t, 'revenue')),
        trendKey: 'revenue',
        hint: 'shop_statistics.kpi.average_basket'.trParams({
          'amount': controller.formatPrice(controller.doubleOf(t, 'average_basket')),
        }),
      ),
      _KpiCard(
        icon: Icons.percent,
        label: 'shop_statistics.kpi.conversion_rate'.tr,
        value: '${controller.doubleOf(t, 'conversion_rate').toStringAsFixed(1)} %',
        hint: 'shop_statistics.kpi.conversion_hint'.tr,
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
  final String? trendKey;
  final String? hint;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
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
                padding: EdgeInsets.all(AppDesign.space2 - 1),
                decoration: BoxDecoration(
                  color: context.ds.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDesign.radiusXs),
                ),
                child: Icon(icon, color: context.ds.textSecondary, size: 17),
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

  /// Badge d'évolution.
  ///
  /// C'est le seul endroit coloré de la carte : la teinte y porte une
  /// information (hausse, baisse, stabilité) et non une décoration.
  Widget _trendBadge(double? trend) {
    if (trend == null) {
      return AppBadge(label: 'shop_statistics.trend.new'.tr, tone: AppBadgeTone.info);
    }
    if (trend > 0) {
      return AppBadge(
        label: '+${trend.toStringAsFixed(0)} %',
        tone: AppBadgeTone.success,
      );
    }
    if (trend < 0) {
      return AppBadge(
        label: '${trend.toStringAsFixed(0)} %',
        tone: AppBadgeTone.danger,
      );
    }
    return AppBadge(label: 'shop_statistics.trend.stable'.tr);
  }
}

class _EvolutionCard extends GetView<ShopStatisticsController> {
  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.bar_chart,
      title: 'shop_statistics.evolution.title'.tr,
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
              height: 200,
              child: values.every((v) => v == 0)
                  ? Center(
                      child: Text(
                        'shop_statistics.evolution.empty'.tr,
                        style: context.body2.copyWith(color: context.secondaryTextColor),
                      ),
                    )
                  : _EvolutionChart(
                      points: points.toList(),
                      values: metric == StatsMetric.revenue
                          ? values
                              .map(controller.toDisplayCurrency)
                              .toList()
                          : values,
                      isCurve: metric == StatsMetric.revenue,
                      monthly: monthly,
                      formatter: (v) => metric == StatsMetric.revenue
                          ? '${v.toStringAsFixed(0)} ${controller.currencyCode}'
                          : v.toStringAsFixed(0),
                    ),
            ),
          ],
        );
      }),
    );
  }

}

/// Graphique d'évolution de la période.
///
/// Courbe pour le chiffre d'affaires (on y lit une tendance), barres pour les
/// volumes (visites, vues, commandes — des quantités qui se comparent d'un
/// point à l'autre). Le libellé de l'axe horizontal est échantillonné : au-delà
/// d'une trentaine de points, tout afficher rendrait l'axe illisible.
class _EvolutionChart extends StatelessWidget {
  const _EvolutionChart({
    required this.points,
    required this.values,
    required this.isCurve,
    required this.monthly,
    required this.formatter,
  });

  final List<Map<String, dynamic>> points;
  final List<double> values;
  final bool isCurve;
  final bool monthly;
  final String Function(double) formatter;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final maxValue = values.fold<double>(0, math.max);
    // Marge haute pour que le sommet ne colle pas au bord du cadre.
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.18;
    final step = (values.length / 5).ceil().clamp(1, values.length);

    final gridData = FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: maxY / 4,
      getDrawingHorizontalLine: (_) => FlLine(color: ds.border, strokeWidth: 1),
    );

    final titlesData = FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: maxY / 4,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value > maxY) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                _compact(value),
                textAlign: TextAlign.right,
                style: context.caption.copyWith(
                  fontSize: 9,
                  color: ds.textTertiary,
                ),
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= points.length) return const SizedBox.shrink();
            if (index % step != 0 && index != points.length - 1) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _axisLabel(points[index]['date'], monthly),
                style: context.caption.copyWith(
                  fontSize: 9,
                  color: ds.textTertiary,
                ),
              ),
            );
          },
        ),
      ),
    );

    if (isCurve) {
      return LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: gridData,
          titlesData: titlesData,
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppDesign.neutral900,
              getTooltipItems: (spots) => spots
                  .map((spot) => LineTooltipItem(
                        '${_axisLabel(points[spot.x.toInt()]['date'], monthly)}\n'
                        '${formatter(spot.y)}',
                        const TextStyle(
                          color: AppDesign.neutral0,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              color: AppDesign.accent,
              barWidth: 2.5,
              dotData: FlDotData(show: values.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                color: AppDesign.accent.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        gridData: gridData,
        titlesData: titlesData,
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppDesign.neutral900,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${_axisLabel(points[group.x]['date'], monthly)}\n'
              '${formatter(rod.toY)}',
              const TextStyle(
                color: AppDesign.neutral0,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: values[i] > 0
                      ? AppDesign.accent
                      : AppDesign.accent.withValues(alpha: 0.15),
                  width: values.length > 40 ? 3 : (values.length > 16 ? 6 : 12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Abrège les grands nombres sur l'axe vertical (12 500 -> « 12,5k »).
  static String _compact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    }
    return value.toStringAsFixed(0);
  }

  static String _axisLabel(dynamic raw, bool monthly) {
    final parts = raw.toString().split('-');
    if (monthly && parts.length >= 2) return '${parts[1]}/${parts[0].substring(2)}';
    if (parts.length == 3) return '${parts[2]}/${parts[1]}';
    return raw.toString();
  }
}

class _TopProductsCard extends GetView<ShopStatisticsController> {
  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.local_fire_department_outlined,
      title: 'shop_statistics.top_products.title'.tr,
      child: Obx(() {
        if (controller.topProducts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'shop_statistics.top_products.empty'.tr,
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
                'shop_statistics.top_products.views_sold'.trParams({
                  'views': '${controller.intOf(p, 'views')}',
                  'sold': '${controller.intOf(p, 'items_sold')}',
                }),
                style: context.caption,
              ),
              trailing: Text(
                controller.formatPrice(controller.doubleOf(p, 'revenue')),
                style: context.body2.copyWith(
                  fontWeight: FontWeight.bold,
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
      title: 'shop_statistics.all_time.title'.tr,
      child: Obx(() {
        final a = controller.allTime;
        final rows = <List<String>>[
          ['shop_statistics.metric.visits'.tr, count.format(controller.intOf(a, 'visits'))],
          ['shop_statistics.all_time.visits_7_days'.tr, count.format(controller.intOf(a, 'visits_last_7_days'))],
          ['shop_statistics.metric.product_views'.tr, count.format(controller.intOf(a, 'product_views'))],
          ['shop_statistics.kpi.contacts'.tr, count.format(controller.intOf(a, 'contacts'))],
          ['shop_statistics.metric.orders'.tr, count.format(controller.intOf(a, 'orders'))],
          ['shop_statistics.kpi.validated_sales'.tr, count.format(controller.intOf(a, 'sales_count'))],
          ['shop_statistics.all_time.items_sold'.tr, count.format(controller.intOf(a, 'items_sold'))],
          ['shop_statistics.metric.revenue'.tr, controller.formatPrice(controller.doubleOf(a, 'revenue'))],
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
            label: Text('shop_statistics.retry'.tr),
          ),
        ],
      ),
    );
  }
}

/// Ligne de choix dans la feuille d'export.
class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDesign.space5,
          vertical: AppDesign.space1,
        ),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ds.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDesign.radiusSm),
          ),
          child: Icon(icon, size: 20, color: ds.textSecondary),
        ),
        title: Text(
          title,
          style: context.body1.copyWith(
            fontWeight: FontWeight.w600,
            color: ds.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: context.caption.copyWith(color: ds.textTertiary),
        ),
        trailing:
            Icon(Icons.chevron_right_rounded, size: 18, color: ds.textTertiary),
        onTap: onTap,
      ),
    );
  }
}
