/// Modèles du module GROS (ASSO CHINA / DUBAÏ / TURQUIE).

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
    formattedPrice: j['formatted_price']?.toString() ?? '',
  );
}

class ShippingOption {
  final int id;
  final String mode; // air | sea | express
  final String modeLabel; // Avion | Bateau | Express
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
}

/// Vidéo de présentation d'un produit grossiste (facultative).
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
  final List<PriceTier> priceTiers;
  final List<Map<String, dynamic>> variants;
  final List<Map<String, dynamic>> variantOptions;
  final String? image;
  final List<String> images;
  final WholesaleVideo? video;

  /// Livraison gratuite offerte par le vendeur : la course SOLEX depuis
  /// Douala est offerte, l'expédition jusqu'à Douala reste due.
  final bool freeDelivery;

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
    required this.priceTiers,
    this.variants = const [],
    this.variantOptions = const [],
    this.image,
    this.images = const [],
    this.video,
    this.freeDelivery = false,
  });

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
    freeDelivery: j['free_delivery'] == true,
  );

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

  const WholesaleCatalog({
    required this.countryCode,
    required this.countryName,
    required this.countryFlag,
    required this.products,
    required this.shippingOptions,
    this.page = 1,
    this.hasMore = false,
  });

  factory WholesaleCatalog.fromJson(Map<String, dynamic> j) {
    final country = Map<String, dynamic>.from(j['country'] ?? {});
    final pagination = j['pagination'] is Map
        ? j['pagination'] as Map
        : const {};
    return WholesaleCatalog(
      page: (pagination['current_page'] as num?)?.toInt() ?? 1,
      hasMore: pagination['has_more'] == true,
      countryCode: country['code']?.toString() ?? '',
      countryName: country['name']?.toString() ?? '',
      countryFlag: country['flag']?.toString() ?? '🏳️',
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
