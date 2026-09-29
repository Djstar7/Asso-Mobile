import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/app_design.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/statistics_service.dart';

/// Indicateur affichable dans le graphique d'évolution.
enum StatsMetric { visits, productViews, orders, revenue }

extension StatsMetricX on StatsMetric {
  String get label => switch (this) {
        StatsMetric.visits => 'shop_statistics.metric.visits'.tr,
        StatsMetric.productViews => 'shop_statistics.metric.product_views'.tr,
        StatsMetric.orders => 'shop_statistics.metric.orders'.tr,
        StatsMetric.revenue => 'shop_statistics.metric.revenue'.tr,
      };

  String get apiKey => switch (this) {
        StatsMetric.visits => 'visits',
        StatsMetric.productViews => 'product_views',
        StatsMetric.orders => 'orders',
        StatsMetric.revenue => 'revenue',
      };
}

/// Statistiques de la boutique du vendeur (P8) : audience, commandes, ventes, CA.
class ShopStatisticsController extends GetxController {
  /// Libellés traduits à chaque lecture (suivent la langue courante).
  static Map<String, String> get periods => <String, String>{
    '7d': 'shop_statistics.period.days_7'.tr,
    '30d': 'shop_statistics.period.days_30'.tr,
    '90d': 'shop_statistics.period.days_90'.tr,
    '365d': 'shop_statistics.period.months_12'.tr,
    'all': 'shop_statistics.period.all'.tr,
  };

  final period = '30d'.obs;
  final metric = StatsMetric.visits.obs;
  final isLoading = true.obs;
  final errorMessage = RxnString();

  final totals = <String, dynamic>{}.obs;
  final trends = Rxn<Map<String, dynamic>>();
  final allTime = <String, dynamic>{}.obs;
  final series = <Map<String, dynamic>>[].obs;
  final topProducts = <Map<String, dynamic>>[].obs;
  final granularity = 'day'.obs;

  /// Export en cours : évite deux téléchargements simultanés.
  final isExporting = false.obs;

  /// Sentinelle réactive suivant la devise choisie dans le tableau de bord.
  ///
  /// Les montants sont convertis à l'affichage : changer de devise doit
  /// redessiner l'écran sans rappeler l'API, les chiffres serveur restant en
  /// XOF.
  final currencyRevision = 0.obs;
  Worker? _currencyWorker;

  @override
  void onInit() {
    super.onInit();
    final initial = Get.arguments is Map ? Get.arguments['period'] : null;
    if (initial is String && periods.containsKey(initial)) period.value = initial;

    if (Get.isRegistered<CurrencyService>()) {
      // Écoute d'un service permanent : sans `dispose`, l'écouteur gardait
      // ce contrôleur en mémoire bien après la fermeture de l'écran.
      _currencyWorker = ever(
        CurrencyService.to.userCurrencyRx,
        (_) => currencyRevision.value++,
      );
    }

    load();
  }

  @override
  void onClose() {
    _currencyWorker?.dispose();
    super.onClose();
  }

  /// Télécharge le rapport de la période puis ouvre le partage système.
  Future<void> exportReport(String format) async {
    if (isExporting.value) return;
    isExporting.value = true;
    try {
      final file = await StatisticsService.downloadReport(
        period: period.value,
        format: format,
      );

      if (file == null) {
        _notify('shop_statistics.export.failed_title'.tr, 'shop_statistics.export.not_generated'.tr,
            isError: true);
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'shop_statistics.export.subject'.trParams({'period': periods[period.value] ?? ''}),
      );
    } catch (_) {
      _notify('shop_statistics.export.failed_title'.tr, 'shop_statistics.export.check_connection'.tr,
          isError: true);
    } finally {
      isExporting.value = false;
    }
  }

  void _notify(String title, String message, {bool isError = false}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? AppDesign.danger : AppDesign.success,
      colorText: AppDesign.neutral0,
      margin: const EdgeInsets.all(AppDesign.space4),
      borderRadius: AppDesign.radiusMd,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> changePeriod(String value) async {
    if (value == period.value) return;
    period.value = value;
    await load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final response = await StatisticsService.getVendorStatistics(period: period.value);
      final data = response.data?['data'];
      if (!response.success || data is! Map) {
        errorMessage.value = response.message.isNotEmpty
            ? response.message
            : 'shop_statistics.load_failed'.tr;
        return;
      }

      totals.assignAll(Map<String, dynamic>.from(data['totals'] ?? {}));
      trends.value = data['trends'] is Map ? Map<String, dynamic>.from(data['trends']) : null;
      allTime.assignAll(Map<String, dynamic>.from(data['all_time'] ?? {}));
      series.assignAll(
        (data['series'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      topProducts.assignAll(
        (data['top_products'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      granularity.value = data['period']?['granularity']?.toString() ?? 'day';
    } catch (_) {
      errorMessage.value = 'shop_statistics.load_failed'.tr;
    } finally {
      isLoading.value = false;
    }
  }

  int intOf(Map source, String key) => (source[key] as num?)?.toInt() ?? 0;

  double doubleOf(Map source, String key) => (source[key] as num?)?.toDouble() ?? 0;

  /// Variation en % par rapport à la période précédente ; null = nouveau.
  double? trendOf(String key) {
    final t = trends.value;
    if (t == null || !t.containsKey(key)) return 0;
    return (t[key] as num?)?.toDouble();
  }

  bool get hasTrends => trends.value != null;

  String formatPrice(double amountXaf) {
    // Lecture volontaire : abonne les Obx au changement de devise.
    currencyRevision.value;
    if (!Get.isRegistered<CurrencyService>()) {
      return '${amountXaf.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(amountXaf);
  }

  /// Montant converti dans la devise d'affichage, pour les axes du graphique.
  double toDisplayCurrency(double amountXaf) {
    currencyRevision.value;
    if (!Get.isRegistered<CurrencyService>()) return amountXaf;
    return CurrencyService.to.convertFromXOF(amountXaf);
  }

  String get currencyCode =>
      Get.isRegistered<CurrencyService>() ? CurrencyService.to.currencyCode : 'XOF';
}
