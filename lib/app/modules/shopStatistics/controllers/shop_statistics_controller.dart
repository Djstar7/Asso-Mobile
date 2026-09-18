import 'package:get/get.dart';
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

  @override
  void onInit() {
    super.onInit();
    final initial = Get.arguments is Map ? Get.arguments['period'] : null;
    if (initial is String && periods.containsKey(initial)) period.value = initial;
    load();
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
    if (!Get.isRegistered<CurrencyService>()) {
      return '${amountXaf.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(amountXaf);
  }
}
