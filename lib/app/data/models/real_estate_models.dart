/// Rubrique Immobilier : maisons à louer et terrains à vendre.
///
/// Les montants arrivent en FCFA (pivot XAF), déjà majorés par le backend ;
/// l'affichage passe par `CurrencyService.formatFromPivot`.
library;

int _int(dynamic v, [int fallback = 0]) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? (v is num ? v.toInt() : fallback);

int? _intOrNull(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));

double? _doubleOrNull(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

bool _bool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

enum RealEstateType { rent, land }

extension RealEstateTypeApi on RealEstateType {
  String get api => this == RealEstateType.land ? 'land' : 'rent';
}

class RealEstateAmenity {
  final int id;
  final String kind;
  final String code;
  final String name;
  final String? icon;

  const RealEstateAmenity({
    required this.id,
    required this.kind,
    required this.code,
    required this.name,
    this.icon,
  });

  factory RealEstateAmenity.fromJson(Map<String, dynamic> j) => RealEstateAmenity(
        id: _int(j['id']),
        kind: j['kind']?.toString() ?? 'equipment',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        icon: j['icon']?.toString(),
      );
}

class RealEstateMedia {
  final int id;
  final String type;
  final String url;
  final String? posterUrl;
  final int? roomId;

  const RealEstateMedia({
    required this.id,
    required this.type,
    required this.url,
    this.posterUrl,
    this.roomId,
  });

  bool get isVideo => type == 'video';

  factory RealEstateMedia.fromJson(Map<String, dynamic> j) => RealEstateMedia(
        id: _int(j['id']),
        type: j['type']?.toString() ?? 'image',
        url: j['url']?.toString() ?? '',
        posterUrl: j['poster_url']?.toString(),
        roomId: _intOrNull(j['room_id']),
      );
}

/// Pièce de la visite pièce par pièce.
class RealEstateTourRoom {
  final int id;
  final String kind;
  final String? label;
  final List<RealEstateMedia> media;

  const RealEstateTourRoom({
    required this.id,
    required this.kind,
    this.label,
    this.media = const [],
  });

  factory RealEstateTourRoom.fromJson(Map<String, dynamic> j) => RealEstateTourRoom(
        id: _int(j['id']),
        kind: j['kind']?.toString() ?? 'other',
        label: j['label']?.toString(),
        media: _maps(j['media']).map(RealEstateMedia.fromJson).toList(),
      );
}

/// Type de logement (studio, chambre…) ou lot de surface d'un terrain.
class RealEstateUnit {
  final int id;
  final String label;
  final int? surfaceMin;
  final int? surfaceMax;
  final int price;
  final int? oldPrice;
  final int? capacity;
  final String? kitchen;
  final bool furnished;
  final bool serviced;
  final int unitsTotal;
  final int unitsAvailable;
  final DateTime? availableFrom;

  const RealEstateUnit({
    required this.id,
    required this.label,
    this.surfaceMin,
    this.surfaceMax,
    required this.price,
    this.oldPrice,
    this.capacity,
    this.kitchen,
    this.furnished = false,
    this.serviced = false,
    this.unitsTotal = 1,
    this.unitsAvailable = 1,
    this.availableFrom,
  });

  bool get isAvailable => unitsAvailable > 0;

  factory RealEstateUnit.fromJson(Map<String, dynamic> j) => RealEstateUnit(
        id: _int(j['id']),
        label: j['label']?.toString() ?? '',
        surfaceMin: _intOrNull(j['surface_min']),
        surfaceMax: _intOrNull(j['surface_max']),
        price: _int(j['price']),
        oldPrice: _intOrNull(j['old_price']),
        capacity: _intOrNull(j['capacity']),
        kitchen: j['kitchen']?.toString(),
        furnished: _bool(j['furnished']),
        serviced: _bool(j['serviced']),
        unitsTotal: _int(j['units_total'], 1),
        unitsAvailable: _int(j['units_available'], 1),
        availableFrom: _date(j['available_from']),
      );
}

/// Questionnaire d'accès et de quartier.
class RealEstateAccess {
  final String? roadAccess;
  final int? distanceToRoadM;
  final String? roadCondition;
  final bool isLandlocked;
  final String? waterSource;
  final String? electricity;
  final String? securityLevel;
  final bool hasParking;
  final bool hasFence;
  final bool hasGuard;

  const RealEstateAccess({
    this.roadAccess,
    this.distanceToRoadM,
    this.roadCondition,
    this.isLandlocked = false,
    this.waterSource,
    this.electricity,
    this.securityLevel,
    this.hasParking = false,
    this.hasFence = false,
    this.hasGuard = false,
  });

  factory RealEstateAccess.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const RealEstateAccess();
    return RealEstateAccess(
      roadAccess: j['road_access']?.toString(),
      distanceToRoadM: _intOrNull(j['distance_to_road_m']),
      roadCondition: j['road_condition']?.toString(),
      isLandlocked: _bool(j['is_landlocked']),
      waterSource: j['water_source']?.toString(),
      electricity: j['electricity']?.toString(),
      securityLevel: j['security_level']?.toString(),
      hasParking: _bool(j['has_parking']),
      hasFence: _bool(j['has_fence']),
      hasGuard: _bool(j['has_guard']),
    );
  }
}

class RealEstateCabinet {
  final int id;
  final String name;
  final String? tagline;
  final String? logoUrl;
  final bool isVerified;
  final String? headquartersCity;
  final String? specialties;
  final String? description;
  final List<String> whyChooseUs;
  final String? ownersMessage;
  final String? bannerUrl;
  final String? region;
  final int listingsCount;
  final bool contactUnlocked;
  final Map<String, dynamic>? contact;
  final List<RealEstateListing> listings;

  const RealEstateCabinet({
    required this.id,
    required this.name,
    this.tagline,
    this.logoUrl,
    this.isVerified = false,
    this.headquartersCity,
    this.specialties,
    this.description,
    this.whyChooseUs = const [],
    this.ownersMessage,
    this.bannerUrl,
    this.region,
    this.listingsCount = 0,
    this.contactUnlocked = false,
    this.contact,
    this.listings = const [],
  });

  factory RealEstateCabinet.fromJson(Map<String, dynamic> j) => RealEstateCabinet(
        id: _int(j['id']),
        name: j['name']?.toString() ?? '',
        tagline: j['tagline']?.toString(),
        logoUrl: j['logo_url']?.toString(),
        isVerified: _bool(j['is_verified']),
        headquartersCity: j['headquarters_city']?.toString(),
        specialties: j['specialties']?.toString(),
        description: j['description']?.toString(),
        whyChooseUs: (j['why_choose_us'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        ownersMessage: j['owners_message']?.toString(),
        bannerUrl: j['banner_url']?.toString(),
        region: j['region']?.toString(),
        listingsCount: _int(j['listings_count']),
        contactUnlocked: _bool(j['contact_unlocked']),
        contact: j['contact'] is Map ? Map<String, dynamic>.from(j['contact']) : null,
        listings: _maps(j['listings']).map(RealEstateListing.fromJson).toList(),
      );
}

/// Bailleur, masqué tant que le visiteur n'a pas payé.
class RealEstateOwner {
  final bool isVerified;
  final int? memberSince;
  final String? name;
  final String? phone;

  const RealEstateOwner({this.isVerified = false, this.memberSince, this.name, this.phone});

  factory RealEstateOwner.fromJson(Map<String, dynamic> j) => RealEstateOwner(
        isVerified: _bool(j['is_verified']),
        memberSince: _intOrNull(j['member_since']),
        name: j['name']?.toString(),
        phone: j['phone']?.toString(),
      );
}

class RealEstateListing {
  final int id;
  final String reference;
  final RealEstateType type;
  final String? propertyKind;
  final String title;
  final String city;
  final String? district;
  final int? rooms;
  final int? bedrooms;
  final int? bathrooms;
  final int? surfaceM2;
  final String? surfaceLabel;
  final bool furnished;
  final bool landTitled;
  final bool serviced;
  final int price;
  final int? oldPrice;
  final bool priceFrom;
  final List<String> images;
  final int photosCount;
  final bool hasVideo;
  final bool hasRoomTour;
  final bool isFeatured;
  final bool isPopular;
  final String? promoText;
  final DateTime? availableFrom;
  final bool availableNow;
  final int unitsAvailable;
  final bool lowStock;
  final List<String> amenityNames;
  final RealEstateCabinet? cabinet;
  bool isFavorite;

  // Fiche détaillée.
  final String? description;
  final RealEstateAccess access;
  final String? landTitleStatus;
  final double? depositPercent;
  final int? minLeaseMonths;
  final int? advanceMonths;
  final double commissionRate;
  final int visitWindowDays;
  final List<RealEstateAmenity> highlights;
  final List<RealEstateAmenity> equipments;
  final List<RealEstateAmenity> services;
  final List<RealEstateUnit> units;
  final List<RealEstateTourRoom> roomsTour;
  final List<RealEstateMedia> media;
  final RealEstateMedia? video;
  final int viewsCount;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool unlocked;
  final RealEstateOwner? owner;
  final String? status;

  RealEstateListing({
    required this.id,
    required this.reference,
    required this.type,
    this.propertyKind,
    required this.title,
    required this.city,
    this.district,
    this.rooms,
    this.bedrooms,
    this.bathrooms,
    this.surfaceM2,
    this.surfaceLabel,
    this.furnished = false,
    this.landTitled = false,
    this.serviced = false,
    required this.price,
    this.oldPrice,
    this.priceFrom = false,
    this.images = const [],
    this.photosCount = 0,
    this.hasVideo = false,
    this.hasRoomTour = false,
    this.isFeatured = false,
    this.isPopular = false,
    this.promoText,
    this.availableFrom,
    this.availableNow = true,
    this.unitsAvailable = 1,
    this.lowStock = false,
    this.amenityNames = const [],
    this.cabinet,
    this.isFavorite = false,
    this.description,
    this.access = const RealEstateAccess(),
    this.landTitleStatus,
    this.depositPercent,
    this.minLeaseMonths,
    this.advanceMonths,
    this.commissionRate = 0,
    this.visitWindowDays = 7,
    this.highlights = const [],
    this.equipments = const [],
    this.services = const [],
    this.units = const [],
    this.roomsTour = const [],
    this.media = const [],
    this.video,
    this.viewsCount = 0,
    this.address,
    this.latitude,
    this.longitude,
    this.unlocked = false,
    this.owner,
    this.status,
  });

  bool get isLand => type == RealEstateType.land;

  String get place => district == null || district!.isEmpty ? city : '$city, $district';

  factory RealEstateListing.fromJson(Map<String, dynamic> j) {
    final location = j['location'] is Map ? Map<String, dynamic>.from(j['location']) : const <String, dynamic>{};
    final amenities = j['amenities'];

    return RealEstateListing(
      id: _int(j['id']),
      reference: j['reference']?.toString() ?? '',
      type: j['type'] == 'land' ? RealEstateType.land : RealEstateType.rent,
      propertyKind: j['property_kind']?.toString(),
      title: j['title']?.toString() ?? '',
      city: j['city']?.toString() ?? '',
      district: j['district']?.toString(),
      rooms: _intOrNull(j['rooms']),
      bedrooms: _intOrNull(j['bedrooms']),
      bathrooms: _intOrNull(j['bathrooms']),
      surfaceM2: _intOrNull(j['surface_m2']),
      surfaceLabel: j['surface_label']?.toString(),
      furnished: _bool(j['furnished']),
      landTitled: _bool(j['land_titled']),
      serviced: _bool(j['serviced']),
      price: _int(j['price']),
      oldPrice: _intOrNull(j['old_price']),
      priceFrom: _bool(j['price_from']),
      images: (j['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      photosCount: _int(j['photos_count']),
      hasVideo: _bool(j['has_video']),
      hasRoomTour: _bool(j['has_room_tour']),
      isFeatured: _bool(j['is_featured']),
      isPopular: _bool(j['is_popular']),
      promoText: j['promo_text']?.toString(),
      availableFrom: _date(j['available_from']),
      availableNow: j['available_now'] == null ? true : _bool(j['available_now']),
      unitsAvailable: _int(j['units_available'], 1),
      lowStock: _bool(j['low_stock']),
      amenityNames: amenities is List ? amenities.map((e) => e.toString()).toList() : const [],
      cabinet: j['cabinet'] is Map ? RealEstateCabinet.fromJson(Map<String, dynamic>.from(j['cabinet'])) : null,
      isFavorite: _bool(j['is_favorite']),
      description: j['description']?.toString(),
      access: RealEstateAccess.fromJson(j['access'] is Map ? Map<String, dynamic>.from(j['access']) : null),
      landTitleStatus: j['land_title_status']?.toString(),
      depositPercent: _doubleOrNull(j['deposit_percent']),
      minLeaseMonths: _intOrNull(j['min_lease_months']),
      advanceMonths: _intOrNull(j['advance_months']),
      commissionRate: _doubleOrNull(j['commission_rate']) ?? 0,
      visitWindowDays: _int(j['visit_window_days'], 7),
      highlights: _maps(j['highlights']).map(RealEstateAmenity.fromJson).toList(),
      equipments: _maps(j['equipments']).map(RealEstateAmenity.fromJson).toList(),
      services: _maps(j['services']).map(RealEstateAmenity.fromJson).toList(),
      units: _maps(j['units']).map(RealEstateUnit.fromJson).toList(),
      roomsTour: _maps(j['rooms_tour']).map(RealEstateTourRoom.fromJson).toList(),
      media: _maps(j['media']).map(RealEstateMedia.fromJson).toList(),
      video: j['video'] is Map ? RealEstateMedia.fromJson(Map<String, dynamic>.from(j['video'])) : null,
      viewsCount: _int(j['views_count']),
      address: location['address']?.toString(),
      latitude: _doubleOrNull(location['latitude']),
      longitude: _doubleOrNull(location['longitude']),
      unlocked: _bool(j['unlocked']),
      owner: j['owner'] is Map ? RealEstateOwner.fromJson(Map<String, dynamic>.from(j['owner'])) : null,
      status: j['status']?.toString(),
    );
  }
}

/// Montants d'un paiement, calculés par le backend.
class RealEstateQuote {
  final int unitPrice;
  final int? advanceMonths;
  final double? depositPercent;
  final int baseAmount;
  final int commission;
  final int total;
  final int? unitId;

  const RealEstateQuote({
    required this.unitPrice,
    this.advanceMonths,
    this.depositPercent,
    required this.baseAmount,
    required this.commission,
    required this.total,
    this.unitId,
  });

  factory RealEstateQuote.fromJson(Map<String, dynamic> j) => RealEstateQuote(
        unitPrice: _int(j['unit_price']),
        advanceMonths: _intOrNull(j['advance_months']),
        depositPercent: _doubleOrNull(j['deposit_percent']),
        baseAmount: _int(j['base_amount']),
        commission: _int(j['commission']),
        total: _int(j['total']),
        unitId: _intOrNull(j['unit_id']),
      );
}

/// Critères enregistrés (« Vos critères »).
class RealEstateCriteria {
  String? applicantStatus;
  String? school;
  String? city;
  DateTime? moveInDate;
  int? leaseMonths;
  int? budgetMin;
  int? budgetMax;

  RealEstateCriteria({
    this.applicantStatus,
    this.school,
    this.city,
    this.moveInDate,
    this.leaseMonths,
    this.budgetMin,
    this.budgetMax,
  });

  factory RealEstateCriteria.fromJson(Map<String, dynamic> j) => RealEstateCriteria(
        applicantStatus: j['applicant_status']?.toString(),
        school: j['school']?.toString(),
        city: j['city']?.toString(),
        moveInDate: _date(j['move_in_date']),
        leaseMonths: _intOrNull(j['lease_months']),
        budgetMin: _intOrNull(j['budget_min']),
        budgetMax: _intOrNull(j['budget_max']),
      );

  Map<String, dynamic> toJson() => {
        'applicant_status': applicantStatus,
        'school': school,
        'city': city,
        'move_in_date': moveInDate?.toIso8601String().substring(0, 10),
        'lease_months': leaseMonths,
        'budget_min': budgetMin,
        'budget_max': budgetMax,
      }..removeWhere((_, v) => v == null);
}

class RealEstatePage {
  final List<RealEstateListing> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const RealEstatePage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}
