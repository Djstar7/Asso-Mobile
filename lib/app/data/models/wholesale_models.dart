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

  /// Volume d'un carton de [packSize] pièces (CBM), null : celui de la fiche.
  final double? cbm;
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
    this.cbm,
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
    cbm: (j['cbm'] as num?)?.toDouble(),
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

/// Règles de transport communes à tous les pays, décidées par le serveur.
class FreightRules {
  final double airMaxWeightKg;
  final double pickupThresholdKg;
  final String? warehouseName;
  final String? warehouseAddress;

  const FreightRules({
    required this.airMaxWeightKg,
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

  /// Volume de toute la ligne tiré du CBM du carton (cartons entiers) ; prime
  /// sur [dimensionsCm].
  final double? volumeCbm;

  const FreightLine({
    required this.quantity,
    this.unitWeightKg,
    this.dimensionsCm,
    this.volumeCbm,
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

  factory FreightMeasure.of(Iterable<FreightLine> lines) {
    var weight = 0.0;
    var cbm = 0.0;
    var cbmFromWeight = 0.0;
    var missingWeight = false;
    var unmeasured = false;
    for (final line in lines) {
      final unit = line.unitWeightKg ?? 0;
      final dims = line.dimensionsCm;
      final lineCbm =
          line.volumeCbm ??
          (dims == null
              ? null
              : dims[0] * dims[1] * dims[2] / 1000000 * line.quantity);
      missingWeight = missingWeight || unit <= 0;
      unmeasured = unmeasured || (unit <= 0 && lineCbm == null);
      weight += unit * line.quantity;
      if (lineCbm != null) {
        cbm += lineCbm;
      } else {
        // Aucun volume connu : 1 000 kg comptent pour 1 CBM.
        cbmFromWeight += unit * line.quantity / 1000;
      }
    }
    return FreightMeasure(
      weightKg: weight,
      volumeCbm: cbm,
      // Avion : poids réel + poids volumétrique, comme sur le serveur.
      billableKg: weight + cbm * 1000000 / 6000,
      // Bateau : le volume seul ; le poids ne compte que sans volume connu.
      billableCbm: cbm + cbmFromWeight,
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

  /// L'avion s'arrête au seuil commun ; le bateau reste toujours possible.
  bool isAvailableFor(FreightMeasure measure, FreightRules? rules) =>
      mode != 'air' ||
      measure.weightKg <= (rules?.airMaxWeightKg ?? double.infinity);

  /// Le transport peut-il se chiffrer avec ces mesures ?
  bool canPrice(FreightMeasure measure) {
    if (rateType == 'flat') return true;
    if (measure.unmeasured) return false;
    // Au kilo (avion, ou ancien bateau gardé jusqu'à la saisie du CBM), le poids
    // réel est indispensable.
    return rateType != 'per_kg' || !measure.missingWeight;
  }

  /// Quantité facturée dans l'unité du tarif (kg, CBM ou 1 pour un forfait).
  double billedQuantity(FreightMeasure measure) => switch (rateType) {
    'per_cbm' => measure.billableCbm,
    'flat' => 1,
    // Ancien bateau au kilo, gardé jusqu'à la saisie du tarif au CBM.
    _ => mode == 'sea' ? measure.weightKg : measure.billableKg,
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

  /// Carton du devis : volume (CBM) et nombre de pièces qu'il contient.
  final double? cbm;
  final int? piecesPerCarton;

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
    this.cbm,
    this.piecesPerCarton,
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

  /// Le volume vient-il d'un CBM de carton saisi (palier ou fiche) ?
  bool hasDeclaredCbm(PriceTier? tier) =>
      (tier?.cbm ?? 0) > 0 || (cbm ?? 0) > 0;

  /// Volume (CBM) de [quantity] pièces d'après le CBM du carton, comme le
  /// serveur (Product::packageVolumeCbm) : on paie les cartons entiers. Carton
  /// du palier : `pack_size` pièces ; carton de la fiche : `pieces_per_carton`
  /// (à défaut `pack_size`). Null sans CBM saisi.
  double? cartonVolumeCbm(PriceTier? tier, int quantity) {
    final packSize = (tier?.packSize ?? 0) > 0 ? tier!.packSize! : 1;
    if ((tier?.cbm ?? 0) > 0) {
      return (quantity / packSize).ceil() * tier!.cbm!;
    }
    if ((cbm ?? 0) > 0) {
      final perCarton = (piecesPerCarton ?? 0) > 0
          ? piecesPerCarton!
          : packSize;
      return (quantity / perCarton).ceil() * cbm!;
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
    cbm: (j['cbm'] as num?)?.toDouble(),
    piecesPerCarton: (j['pieces_per_carton'] as num?)?.toInt(),
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
