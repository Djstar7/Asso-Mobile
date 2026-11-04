/// Modèles du module GROS (ASSO CHINA / DUBAÏ / TURQUIE).
library;

import '../../core/utils/delivery_delay.dart';

class PriceTier {
  final int id;
  final String label;
  final double unitPrice;
  final double unitPriceXaf;
  final String currency;
  final int minQuantity; // « cota »
  final int? packSize;

  /// Poids d'une unité commandée à ce palier (pack, bidon, pièce), en kg.
  final double? weightKg;

  /// Dimensions du colis d'une unité à ce palier (null : celles du produit).
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final String formattedPrice;

  const PriceTier({
    required this.id,
    required this.label,
    required this.unitPrice,
    required this.unitPriceXaf,
    required this.currency,
    required this.minQuantity,
    this.packSize,
    this.weightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    required this.formattedPrice,
  });

  factory PriceTier.fromJson(Map<String, dynamic> j) => PriceTier(
    id: j['id'] as int,
    label: j['label']?.toString() ?? '',
    unitPrice: (j['unit_price'] as num?)?.toDouble() ?? 0,
    unitPriceXaf:
        (j['unit_price_xaf'] as num?)?.toDouble() ??
        (j['unit_price'] as num?)?.toDouble() ??
        0,
    currency: j['currency']?.toString() ?? 'XAF',
    minQuantity: (j['min_quantity'] as num?)?.toInt() ?? 1,
    packSize: (j['pack_size'] as num?)?.toInt(),
    weightKg: (j['weight_kg'] as num?)?.toDouble(),
    lengthCm: (j['length_cm'] as num?)?.toDouble(),
    widthCm: (j['width_cm'] as num?)?.toDouble(),
    heightCm: (j['height_cm'] as num?)?.toDouble(),
    formattedPrice: j['formatted_price']?.toString() ?? '',
  );

  /// Palier applicable à [quantity] : le plus haut dont le seuil est atteint ;
  /// sous le premier seuil, le premier palier, pour afficher un prix. Ce seuil
  /// est le minimum de commande : le serveur refuse une quantité inférieure.
  static PriceTier? forQuantity(List<PriceTier> tiers, int quantity) {
    if (tiers.isEmpty) return null;
    final sorted = [...tiers]
      ..sort((a, b) => a.minQuantity.compareTo(b.minQuantity));
    PriceTier result = sorted.first;
    for (final tier in sorted) {
      if (tier.minQuantity <= quantity) result = tier;
    }
    return result;
  }
}

/// Règles de transport du pays d'origine, décidées par le serveur.
class FreightRules {
  final double airMaxWeightKg;
  final int volumetricDivisor;
  final double pickupThresholdKg;
  final String? warehouseName;
  final String? warehouseAddress;

  const FreightRules({
    required this.airMaxWeightKg,
    required this.volumetricDivisor,
    required this.pickupThresholdKg,
    this.warehouseName,
    this.warehouseAddress,
  });

  /// Null pour une ancienne API : aucun seuil n'est alors appliqué.
  static FreightRules? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final warehouse = raw['warehouse'];
    return FreightRules(
      airMaxWeightKg:
          (raw['air_max_weight_kg'] as num?)?.toDouble() ?? double.infinity,
      volumetricDivisor: (raw['volumetric_divisor'] as num?)?.toInt() ?? 6000,
      pickupThresholdKg:
          (raw['pickup_threshold_kg'] as num?)?.toDouble() ?? double.infinity,
      warehouseName: warehouse is Map ? warehouse['name']?.toString() : null,
      warehouseAddress: warehouse is Map
          ? warehouse['address']?.toString()
          : null,
    );
  }
}

/// Dimensions du critère « Dimensions » (« 120 × 80 × 100 cm »), même lecture
/// que le serveur ; null pour un autre critère ou une valeur libre.
List<double>? packageDimensionsFromAttributes(Map<String, dynamic> attributes) {
  final pattern = RegExp(
    r'^\s*(\d+(?:[.,]\d+)?)\s*[x×*]\s*(\d+(?:[.,]\d+)?)\s*[x×*]\s*(\d+(?:[.,]\d+)?)\s*(?:cm)?\s*$',
    caseSensitive: false,
  );
  for (final entry in attributes.entries) {
    if (entry.key.trim().toLowerCase() != 'dimensions') continue;
    final match = pattern.firstMatch('${entry.value}');
    if (match != null) {
      return [
        for (final side in [1, 2, 3])
          double.parse(match.group(side)!.replaceAll(',', '.')),
      ];
    }
  }
  return null;
}

/// Une ligne de commande vue par le transport : poids et dimensions d'une unité.
class FreightLine {
  final double? unitWeightKg;
  final List<double>? dimensionsCm;
  final int quantity;

  const FreightLine({
    required this.quantity,
    this.unitWeightKg,
    this.dimensionsCm,
  });
}

/// Mesures d'une commande, même calcul que le serveur (ImportFreightService).
class FreightMeasure {
  final double weightKg;
  final double volumeCbm;
  final double billableKg;
  final double billableCbm;
  final bool missingWeight;
  final bool unmeasured;

  const FreightMeasure({
    this.weightKg = 0,
    this.volumeCbm = 0,
    this.billableKg = 0,
    this.billableCbm = 0,
    this.missingWeight = false,
    this.unmeasured = false,
  });

  factory FreightMeasure.of(Iterable<FreightLine> lines, FreightRules? rules) {
    var weight = 0.0;
    var cbm = 0.0;
    var missingWeight = false;
    var unmeasured = false;
    for (final line in lines) {
      final unit = line.unitWeightKg ?? 0;
      final dims = line.dimensionsCm;
      missingWeight = missingWeight || unit <= 0;
      unmeasured = unmeasured || (unit <= 0 && dims == null);
      weight += unit * line.quantity;
      if (dims != null) {
        cbm += dims[0] * dims[1] * dims[2] / 1000000 * line.quantity;
      }
    }
    final volumetric = cbm * 1000000 / (rules?.volumetricDivisor ?? 6000);
    return FreightMeasure(
      weightKg: weight,
      volumeCbm: cbm,
      billableKg: weight > volumetric ? weight : volumetric,
      // 1 000 kg comptent pour 1 CBM.
      billableCbm: cbm > weight / 1000 ? cbm : weight / 1000,
      missingWeight: missingWeight,
      unmeasured: unmeasured,
    );
  }
}

class ShippingOption {
  final int id;
  final String mode; // air | sea
  final String modeLabel; // Avion | Bateau
  final String rateType; // per_kg | per_cbm | flat
  final double rateAmount;
  final double rateAmountXaf;
  final String currency;
  final int? leadTimeDays;
  final String? expeditionNote;
  final List<String> destinations;

  /// Ville d'arrivée de l'import (entrepôt ASSO), d'où part la livraison locale.
  final String destination;
  final String formattedRate;

  const ShippingOption({
    required this.id,
    required this.mode,
    required this.modeLabel,
    required this.rateType,
    required this.rateAmount,
    required this.rateAmountXaf,
    required this.currency,
    this.leadTimeDays,
    this.expeditionNote,
    required this.destinations,
    this.destination = 'Douala',
    required this.formattedRate,
  });

  factory ShippingOption.fromJson(Map<String, dynamic> j) => ShippingOption(
    id: j['id'] as int,
    mode: j['mode']?.toString() ?? '',
    modeLabel: j['mode_label']?.toString() ?? '',
    rateType: j['rate_type']?.toString() ?? 'per_kg',
    rateAmount: (j['rate_amount'] as num?)?.toDouble() ?? 0,
    rateAmountXaf:
        (j['rate_amount_xaf'] as num?)?.toDouble() ??
        (j['rate_amount'] as num?)?.toDouble() ??
        0,
    currency: j['currency']?.toString() ?? 'XAF',
    leadTimeDays: (j['lead_time_days'] as num?)?.toInt(),
    expeditionNote: j['expedition_note']?.toString(),
    destinations:
        (j['destinations'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    destination: j['destination']?.toString() ?? 'Douala',
    formattedRate: j['formatted_rate']?.toString() ?? '',
  );

  /// L'avion s'arrête au seuil du pays ; le bateau reste toujours possible.
  bool isAvailableFor(FreightMeasure measure, FreightRules? rules) =>
      mode != 'air' ||
      measure.billableKg <= (rules?.airMaxWeightKg ?? double.infinity);

  /// Ancien bateau au kilo, gardé jusqu'à la saisie du tarif au CBM.
  bool get _legacySeaByKg => mode == 'sea' && rateType == 'per_kg';

  /// Le transport peut-il se chiffrer avec ces mesures ?
  bool canPrice(FreightMeasure measure) {
    if (rateType == 'flat') return true;
    if (measure.unmeasured) return false;
    return !_legacySeaByKg || !measure.missingWeight;
  }

  /// Quantité facturée dans l'unité du tarif (kg, CBM ou 1 pour un forfait).
  double billedQuantity(FreightMeasure measure) => switch (rateType) {
    'per_cbm' => measure.billableCbm,
    'flat' => 1,
    _ => _legacySeaByKg ? measure.weightKg : measure.billableKg,
  };

  double costFor(FreightMeasure measure) =>
      rateAmountXaf * billedQuantity(measure);
}

/// Vidéo de présentation d'un produit (facultative), grossiste ou non.
///
/// Deux versions : la boucle courte et muette des cartes ([previewUrl]),
/// légère pour ne pas épuiser le forfait pendant le défilement, et la version
/// complète avec le son pour la fiche ([url]).
class WholesaleVideo {
  final int id;
  final String url;
  final String previewUrl;
  final String? posterUrl;
  final int? width;
  final int? height;

  /// Durée en secondes.
  final double? duration;

  const WholesaleVideo({
    required this.id,
    required this.url,
    required this.previewUrl,
    this.posterUrl,
    this.width,
    this.height,
    this.duration,
  });

  /// Null quand le produit n'a pas de vidéo prête (le serveur envoie `null`).
  static WholesaleVideo? fromJson(dynamic json) {
    if (json is! Map) return null;
    final url = json['url']?.toString() ?? '';
    if (url.isEmpty) return null;
    final preview = json['preview_url']?.toString() ?? '';
    final poster = json['poster_url']?.toString() ?? '';
    return WholesaleVideo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      url: url,
      previewUrl: preview.isEmpty ? url : preview,
      posterUrl: poster.isEmpty ? null : poster,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toDouble(),
    );
  }

  /// Largeur / hauteur. Format téléphone (9:16) par défaut : c'est ainsi que
  /// les fournisseurs filment leurs marchandises.
  double get aspectRatio {
    final w = width, h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 9 / 16;
    return w / h;
  }

  /// « 0:27 », affiché sur les cartes comme sur Pinterest.
  String? get durationLabel {
    final seconds = duration;
    if (seconds == null || seconds <= 0) return null;
    final total = seconds.round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }
}

class WholesaleProduct {
  final int id;
  final String name;
  final String? description;
  final String? characteristics;
  final String? commercialInformation;
  final String? originCountry;
  final String currency;
  final int? minOrderQuantity;
  final double? unitWeightKg;

  /// Dimensions du colis d'une unité, facultatives (cm).
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;

  /// Règles de transport de son pays d'origine.
  final FreightRules? freightRules;
  final List<PriceTier> priceTiers;
  final List<Map<String, dynamic>> variants;
  final List<Map<String, dynamic>> variantOptions;
  final String? image;
  final List<String> images;
  final WholesaleVideo? video;

  /// Délai de livraison annoncé (jours ouvrables), fiche détaillée seulement.
  final DeliveryDelay? deliveryDelay;

  /// Livraison gratuite offerte par le vendeur : la course SOLEX depuis
  /// Douala est offerte, l'expédition jusqu'à Douala reste due.
  final bool freeDelivery;

  /// Les options (couleurs, tailles) se cumulent-elles pour atteindre un
  /// palier ? Sinon chaque option atteint son palier seule.
  final bool tierMixVariants;

  /// Vente avec acompte : % du prix du palier payé à la commande (avec
  /// l'expédition et la course SOLEX), solde après vérification ASSO.
  final bool depositEnabled;
  final double depositRate;

  bool get hasDeposit => depositEnabled && depositRate > 0;

  const WholesaleProduct({
    required this.id,
    required this.name,
    this.description,
    this.characteristics,
    this.commercialInformation,
    this.originCountry,
    required this.currency,
    this.minOrderQuantity,
    this.unitWeightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.freightRules,
    required this.priceTiers,
    this.variants = const [],
    this.variantOptions = const [],
    this.image,
    this.images = const [],
    this.video,
    this.deliveryDelay,
    this.freeDelivery = false,
    this.tierMixVariants = true,
    this.depositEnabled = false,
    this.depositRate = 0,
  });

  /// Dimensions d'une unité : celles du palier si complètes, sinon du produit.
  List<double>? dimensionsFor(PriceTier? tier) {
    bool complete(double? l, double? w, double? h) =>
        (l ?? 0) > 0 && (w ?? 0) > 0 && (h ?? 0) > 0;
    if (complete(tier?.lengthCm, tier?.widthCm, tier?.heightCm)) {
      return [tier!.lengthCm!, tier.widthCm!, tier.heightCm!];
    }
    if (complete(lengthCm, widthCm, heightCm)) {
      return [lengthCm!, widthCm!, heightCm!];
    }
    return null;
  }

  factory WholesaleProduct.fromJson(Map<String, dynamic> j) => WholesaleProduct(
    id: j['id'] as int,
    name: j['name']?.toString() ?? '',
    description: j['description']?.toString(),
    characteristics: j['characteristics']?.toString(),
    commercialInformation: j['commercial_information']?.toString(),
    originCountry: j['origin_country']?.toString(),
    currency: j['currency']?.toString() ?? 'XAF',
    minOrderQuantity: (j['min_order_quantity'] as num?)?.toInt(),
    unitWeightKg: (j['unit_weight_kg'] as num?)?.toDouble(),
    lengthCm: (j['length_cm'] as num?)?.toDouble(),
    widthCm: (j['width_cm'] as num?)?.toDouble(),
    heightCm: (j['height_cm'] as num?)?.toDouble(),
    freightRules: FreightRules.fromJson(j['freight_rules']),
    priceTiers:
        (j['price_tiers'] as List?)
            ?.map((e) => PriceTier.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    variants:
        (j['variants'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [],
    variantOptions:
        (j['variant_options'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [],
    image: j['image']?.toString(),
    images:
        (j['images'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [],
    video: WholesaleVideo.fromJson(j['video']),
    deliveryDelay: DeliveryDelay.fromApi(j['delivery_delay']),
    freeDelivery: j['free_delivery'] == true,
    tierMixVariants: j['tier_mix_variants'] != false,
    depositEnabled: j['deposit_enabled'] == true,
    depositRate: double.tryParse(j['deposit_rate']?.toString() ?? '') ?? 0,
  );

  /// Paliers du plus petit seuil au plus grand.
  List<PriceTier> get sortedTiers =>
      [...priceTiers]..sort((a, b) => a.minQuantity.compareTo(b.minQuantity));

  /// Premier palier : son seuil est le minimum de commande.
  PriceTier? get firstTier => sortedTiers.isEmpty ? null : sortedTiers.first;

  /// Prix d'entrée = plus petit prix parmi les paliers (pour l'affichage « à partir de »).
  PriceTier? get entryTier {
    if (priceTiers.isEmpty) return null;
    return priceTiers.reduce((a, b) => a.unitPrice <= b.unitPrice ? a : b);
  }
}

class WholesaleCatalog {
  final String countryCode;
  final String countryName;
  final String countryFlag;
  final List<WholesaleProduct> products;
  final List<ShippingOption> shippingOptions;

  /// Page reçue (1 sans pagination) et s'il en reste après elle.
  final int page;
  final bool hasMore;
  final int total;

  const WholesaleCatalog({
    required this.countryCode,
    required this.countryName,
    required this.countryFlag,
    required this.products,
    required this.shippingOptions,
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
  });

  factory WholesaleCatalog.fromJson(Map<String, dynamic> j) {
    final country = Map<String, dynamic>.from(j['country'] ?? {});
    final pagination = j['pagination'] is Map
        ? j['pagination'] as Map
        : const {};
    return WholesaleCatalog(
      page: (pagination['current_page'] as num?)?.toInt() ?? 1,
      hasMore: pagination['has_more'] == true,
      total:
          (pagination['total'] as num?)?.toInt() ??
          (j['products'] as List?)?.length ??
          0,
      countryCode: country['code']?.toString() ?? '',
      countryName: country['name']?.toString() ?? '',
      countryFlag: country['flag']?.toString() ?? '',
      products:
          (j['products'] as List?)
              ?.map(
                (e) => WholesaleProduct.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
      shippingOptions:
          (j['shipping_options'] as List?)
              ?.map(
                (e) => ShippingOption.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
    );
  }
}
