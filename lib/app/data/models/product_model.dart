import 'package:get/get.dart';
import '../providers/currency_service.dart';

/// Modèle de données pour un produit dans l'application
class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String category;
  final String location;
  final String locationCity;
  final String locationCountry;
  final List<String> images;
  final ProductCondition condition;
  final DateTime createdAt;
  final bool isFavorite;
  final SellerModel seller;
  final List<String> tags;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.currency = 'FCFA',
    required this.category,
    required this.location,
    required this.locationCity,
    required this.locationCountry,
    required this.images,
    this.condition = ProductCondition.nouveau,
    required this.createdAt,
    this.isFavorite = false,
    required this.seller,
    this.tags = const [],
  });

  /// Constructeur à partir d'un Map (pour la compatibilité avec les données hardcodées)
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: _parsePrice(map['price']),
      currency: map['currency'] ?? 'FCFA',
      category: map['category'] ?? 'Tous',
      location: map['location'] ?? '',
      locationCity: _extractCity(map['location'] ?? ''),
      locationCountry: _extractCountry(map['location'] ?? ''),
      images: _parseImages(map),
      condition: _parseCondition(map['condition']),
      createdAt: map['createdAt'] != null || map['created_at'] != null
          ? DateTime.parse(map['createdAt'] ?? map['created_at'])
          : DateTime.now(),
      isFavorite: map['isFavorite'] ?? map['is_favorite'] ?? false,
      seller: map['seller'] != null
          ? SellerModel.fromMap(map['seller'])
          : SellerModel.defaultSeller(),
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  /// Convertir en Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'category': category,
      'location': location,
      'locationCity': locationCity,
      'locationCountry': locationCountry,
      'images': images,
      'condition': condition.name,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'seller': seller.toMap(),
      'tags': tags,
    };
  }

  /// Copie avec modifications
  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? currency,
    String? category,
    String? location,
    String? locationCity,
    String? locationCountry,
    List<String>? images,
    ProductCondition? condition,
    DateTime? createdAt,
    bool? isFavorite,
    SellerModel? seller,
    List<String>? tags,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      location: location ?? this.location,
      locationCity: locationCity ?? this.locationCity,
      locationCountry: locationCountry ?? this.locationCountry,
      images: images ?? this.images,
      condition: condition ?? this.condition,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      seller: seller ?? this.seller,
      tags: tags ?? this.tags,
    );
  }

  /// Prix formaté avec la devise
  String get formattedPrice {
    try {
      if (Get.isRegistered<CurrencyService>()) {
        return CurrencyService.to.formatPrice(price);
      }
    } catch (e) {
      // Fallback si CurrencyService n'est pas encore initialisé
    }
    return '$price $currency';
  }

  /// Prix formaté avec séparateur de milliers
  String get formattedPriceWithSeparator {
    try {
      if (Get.isRegistered<CurrencyService>()) {
        return CurrencyService.to.formatPrice(price);
      }
    } catch (e) {
      // Fallback si CurrencyService n'est pas encore initialisé
    }
    final priceStr = price.toStringAsFixed(0);
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final result = priceStr.replaceAllMapped(regex, (Match m) => '${m[1]} ');
    return '$result $currency';
  }

  /// Image principale
  String get mainImage => images.isNotEmpty ? images.first : '';

  /// Vérifie si le produit correspond à une requête de recherche
  bool matchesSearchQuery(String query) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return name.toLowerCase().contains(lowerQuery) ||
        description.toLowerCase().contains(lowerQuery) ||
        category.toLowerCase().contains(lowerQuery) ||
        tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
  }

  /// Helpers statiques
  static double _parsePrice(dynamic price) {
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      // Enlever les espaces et la devise
      final cleaned = price.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static String _extractCity(String location) {
    // Format attendu: "Ville, Pays"
    if (location.contains(',')) {
      return location.split(',').first.trim();
    }
    return location;
  }

  static String _extractCountry(String location) {
    // Format attendu: "Ville, Pays"
    if (location.contains(',')) {
      return location.split(',').last.trim();
    }
    return '';
  }

  static ProductCondition _parseCondition(dynamic condition) {
    if (condition is ProductCondition) return condition;
    if (condition is String) {
      switch (condition.toLowerCase()) {
        case 'nouveau':
          return ProductCondition.nouveau;
        case 'comme_neuf':
          return ProductCondition.commeNeuf;
        case 'tres_bon_etat':
          return ProductCondition.tresBonEtat;
        case 'bon_etat':
          return ProductCondition.bonEtat;
        default:
          return ProductCondition.nouveau;
      }
    }
    return ProductCondition.nouveau;
  }

  static List<String> _parseImages(Map<String, dynamic> map) {
    // Try different possible image fields from backend
    final images = <String>[];

    // Check for 'images' array
    if (map['images'] != null) {
      if (map['images'] is List) {
        for (final item in map['images'] as List) {
          if (item is String) {
            images.add(item);
          } else if (item is Map && item['url'] != null) {
            images.add(item['url'].toString());
          }
        }
      }
    }

    // Check for 'primary_image' field
    if (map['primary_image'] != null && map['primary_image'].toString().isNotEmpty) {
      final primaryImage = map['primary_image'].toString();
      if (!images.contains(primaryImage)) {
        images.insert(0, primaryImage);
      }
    }

    // Check for single 'image' field
    if (map['image'] != null && map['image'].toString().isNotEmpty) {
      final image = map['image'].toString();
      if (!images.contains(image)) {
        images.add(image);
      }
    }

    // Return empty list if no images found
    return images;
  }
}

/// Modèle pour le vendeur
class SellerModel {
  final String id;
  final String name;
  final double rating;
  final int reviewsCount;
  final String? avatar;

  SellerModel({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewsCount,
    this.avatar,
  });

  factory SellerModel.fromMap(Map<String, dynamic> map) {
    return SellerModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewsCount: map['reviews'] ?? map['reviewsCount'] ?? 0,
      avatar: map['avatar'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'avatar': avatar,
    };
  }

  factory SellerModel.defaultSeller() {
    return SellerModel(
      id: 'default',
      name: 'Vendeur',
      rating: 0.0,
      reviewsCount: 0,
    );
  }
}

/// État du produit
enum ProductCondition {
  nouveau,
  commeNeuf,
  tresBonEtat,
  bonEtat,
}

/// Extension pour obtenir le label français
extension ProductConditionExtension on ProductCondition {
  String get label {
    switch (this) {
      case ProductCondition.nouveau:
        return 'Nouveau';
      case ProductCondition.commeNeuf:
        return 'Comme neuf';
      case ProductCondition.tresBonEtat:
        return 'Très bon état';
      case ProductCondition.bonEtat:
        return 'Bon état';
    }
  }
}
