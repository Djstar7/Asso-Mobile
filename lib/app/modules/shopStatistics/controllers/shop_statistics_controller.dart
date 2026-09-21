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
        StatsMetric.visits => 'Visites',
        StatsMetric.productViews => 'Produits consultés',
        StatsMetric.orders => 'Commandes',
        StatsMetric.revenue => 'Chiffre d\'affaires',
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
  static const periods = <String, String>{
    '7d': '7 jours',
    '30d': '30 jours',
    '90d': '90 jours',
    '365d': '12 mois',
    'all': 'Tout',
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

  @override
  void onInit() {
    super.onInit();
    final initial = Get.arguments is Map ? Get.arguments['period'] : null;
    if (initial is String && periods.containsKey(initial)) period.value = initial;

    if (Get.isRegistered<CurrencyService>()) {
      ever(CurrencyService.to.userCurrencyRx, (_) => currencyRevision.value++);
    }

    load();
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
        _notify('Export impossible', 'Le rapport n\'a pas pu être généré.',
            isError: true);
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Statistiques ${periods[period.value] ?? ''}',
      );
    } catch (_) {
      _notify('Export impossible', 'Vérifiez votre connexion et réessayez.',
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
            : 'Impossible de charger les statistiques';
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
      errorMessage.value = 'Impossible de charger les statistiques';
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
