/// Asso Ads — modèles du sponsoring d'article.
library;

import '../providers/currency_service.dart';

/// Un forfait de sponsoring proposé au vendeur.
///
/// [reachUsers] est un quota de vues garanti, pas une estimation : la campagne
/// s'arrête quand il est atteint, ou à l'échéance, au premier des deux.
class BoostPackage {
  final int id;
  final String name;
  final String? description;
  /// Prix en XAF (pivot). L'affichage passe par [formattedPrice], qui le
  /// convertit dans la devise choisie par l'utilisateur.
  final double price;
  final int durationDays;
  final String formattedDuration;
  final int reachUsers;
  final String formattedReach;
  final bool isPopular;

  const BoostPackage({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.durationDays,
    required this.formattedDuration,
    required this.reachUsers,
    required this.formattedReach,
    required this.isPopular,
  });

  factory BoostPackage.fromJson(Map<String, dynamic> json) {
    return BoostPackage(
      id: _int(json['id']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      price: _double(json['price']),
      durationDays: _int(json['duration_days']),
      formattedDuration: json['formatted_duration']?.toString() ?? '',
      reachUsers: _int(json['reach_users']),
      formattedReach: json['formatted_reach']?.toString() ?? '',
      isPopular: json['is_popular'] == true,
    );
  }

  /// Prix affiché dans la devise de l'utilisateur.
  ///
  /// Le backend renvoie un `formatted_price` toujours libellé en FCFA :
  /// l'utiliser afficherait « 1 000 FCFA » à quelqu'un qui a choisi l'euro.
  /// On repart donc du montant pivot et on le convertit ici.
  String get formattedPrice => CurrencyService.formatFromPivot(price);

  /// Prix par personne touchée, pour comparer deux forfaits d'un coup d'œil.
  double get pricePerPerson => reachUsers > 0 ? price / reachUsers : 0;
}

/// Un point de la courbe de diffusion.
class BoostDailyPoint {
  final String date;
  final int impressions;
  final int clicks;

  const BoostDailyPoint({
    required this.date,
    required this.impressions,
    required this.clicks,
  });

  factory BoostDailyPoint.fromJson(Map<String, dynamic> json) {
    return BoostDailyPoint(
      date: json['date']?.toString() ?? '',
      impressions: _int(json['impressions']),
      clicks: _int(json['clicks']),
    );
  }
}

/// Une campagne de sponsoring et son suivi.
class BoostCampaign {
  final int id;
  final int productId;
  final String productName;
  final String? productImage;
  final String? packageName;

  final String status;
  final String statusLabel;
  final bool isRunning;
  final double amountXaf;

  final DateTime? startsAt;
  final DateTime? endsAt;
  final int remainingDays;

  /// Portée achetée et délivrée.
  final int impressionsQuota;
  final int impressionsServed;
  final int impressionsRemaining;
  final double progressPercent;

  /// Ce que la portée a produit.
  final int reached;      // personnes touchées (annonce affichée)
  final int viewers;      // ont ouvert la fiche produit
  final int interactions; // ont pris contact
  final int clicks;       // ouvertures depuis l'annonce
  final double clickThroughRate;
  final double viewRate;

  final List<BoostDailyPoint> series;

  const BoostCampaign({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    this.packageName,
    required this.status,
    required this.statusLabel,
    required this.isRunning,
    required this.amountXaf,
    this.startsAt,
    this.endsAt,
    required this.remainingDays,
    required this.impressionsQuota,
    required this.impressionsServed,
    required this.impressionsRemaining,
    required this.progressPercent,
    required this.reached,
    required this.viewers,
    required this.interactions,
    required this.clicks,
    required this.clickThroughRate,
    required this.viewRate,
    required this.series,
  });

  factory BoostCampaign.fromJson(Map<String, dynamic> json) {
    final product = (json['product'] as Map?)?.cast<String, dynamic>() ?? {};

    return BoostCampaign(
      id: _int(json['id']),
      productId: _int(product['id']),
      productName: product['name']?.toString() ?? 'Article',
      productImage: product['image']?.toString(),
      packageName: json['package_name']?.toString(),
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? '',
      isRunning: json['is_running'] == true,
      amountXaf: _double(json['amount_xaf']),
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
      remainingDays: _int(json['remaining_days']),
      impressionsQuota: _int(json['impressions_quota']),
      impressionsServed: _int(json['impressions_served']),
      impressionsRemaining: _int(json['impressions_remaining']),
      progressPercent: _double(json['progress_percent']),
      reached: _int(json['reached']),
      viewers: _int(json['viewers']),
      interactions: _int(json['interactions']),
      clicks: _int(json['clicks']),
      clickThroughRate: _double(json['click_through_rate']),
      viewRate: _double(json['view_rate']),
      series: ((json['series'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BoostDailyPoint.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  /// Montant payé, dans la devise de l'utilisateur.
  String get formattedAmount => CurrencyService.formatFromPivot(amountXaf);

  /// Progression bornée à [0,1] pour les barres de progression.
  double get progressFraction => (progressPercent / 100).clamp(0.0, 1.0);
}

int _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

double _double(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
