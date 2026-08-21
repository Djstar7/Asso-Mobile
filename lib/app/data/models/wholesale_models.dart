/// Modèles du module GROS (ASSO CHINA / DUBAÏ / TURQUIE).

class PriceTier {
  final int id;
  final String label;
  final double unitPrice;
  final String currency;
  final int minQuantity; // « cota »
  final int? packSize;
  final String formattedPrice;

  const PriceTier({
    required this.id,
    required this.label,
    required this.unitPrice,
    required this.currency,
    required this.minQuantity,
    this.packSize,
    required this.formattedPrice,
  });

  factory PriceTier.fromJson(Map<String, dynamic> j) => PriceTier(
        id: j['id'] as int,
        label: j['label']?.toString() ?? '',
        unitPrice: (j['unit_price'] as num?)?.toDouble() ?? 0,
        currency: j['currency']?.toString() ?? 'XAF',
        minQuantity: (j['min_quantity'] as num?)?.toInt() ?? 1,
        packSize: (j['pack_size'] as num?)?.toInt(),
        formattedPrice: j['formatted_price']?.toString() ?? '',
      );
}

class ShippingOption {
  final int id;
  final String mode; // air | sea | express
  final String modeLabel; // Avion | Bateau | Express
  final String rateType; // per_kg | per_cbm | flat
  final double rateAmount;
  final String currency;
  final int? leadTimeDays;
  final String? expeditionNote;
  final List<String> destinations;
  final String formattedRate;

  const ShippingOption({
    required this.id,
    required this.mode,
    required this.modeLabel,
    required this.rateType,
    required this.rateAmount,
    required this.currency,
    this.leadTimeDays,
    this.expeditionNote,
    required this.destinations,
    required this.formattedRate,
  });

  factory ShippingOption.fromJson(Map<String, dynamic> j) => ShippingOption(
        id: j['id'] as int,
        mode: j['mode']?.toString() ?? '',
        modeLabel: j['mode_label']?.toString() ?? '',
        rateType: j['rate_type']?.toString() ?? 'per_kg',
        rateAmount: (j['rate_amount'] as num?)?.toDouble() ?? 0,
        currency: j['currency']?.toString() ?? 'XAF',
        leadTimeDays: (j['lead_time_days'] as num?)?.toInt(),
        expeditionNote: j['expedition_note']?.toString(),
        destinations: (j['destinations'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        formattedRate: j['formatted_rate']?.toString() ?? '',
      );
}

class WholesaleProduct {
  final int id;
  final String name;
  final String? description;
  final String? originCountry;
  final String currency;
  final int? minOrderQuantity;
  final List<PriceTier> priceTiers;
  final String? image;

  const WholesaleProduct({
    required this.id,
    required this.name,
    this.description,
    this.originCountry,
    required this.currency,
    this.minOrderQuantity,
    required this.priceTiers,
    this.image,
  });

  factory WholesaleProduct.fromJson(Map<String, dynamic> j) => WholesaleProduct(
        id: j['id'] as int,
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString(),
        originCountry: j['origin_country']?.toString(),
        currency: j['currency']?.toString() ?? 'XAF',
        minOrderQuantity: (j['min_order_quantity'] as num?)?.toInt(),
        priceTiers: (j['price_tiers'] as List?)
                ?.map((e) => PriceTier.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        image: j['image']?.toString(),
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

  const WholesaleCatalog({
    required this.countryCode,
    required this.countryName,
    required this.countryFlag,
    required this.products,
    required this.shippingOptions,
  });

  factory WholesaleCatalog.fromJson(Map<String, dynamic> j) {
    final country = Map<String, dynamic>.from(j['country'] ?? {});
    return WholesaleCatalog(
      countryCode: country['code']?.toString() ?? '',
      countryName: country['name']?.toString() ?? '',
      countryFlag: country['flag']?.toString() ?? '🏳️',
      products: (j['products'] as List?)
              ?.map((e) => WholesaleProduct.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      shippingOptions: (j['shipping_options'] as List?)
              ?.map((e) => ShippingOption.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}
