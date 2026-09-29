import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/values/constants.dart';
import '../../../core/utils/device_location.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/widgets/product_variant_selector.dart';
import '../../../core/widgets/variant_quantity_list.dart';
import '../../../data/models/delivery_info.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/statistics_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../core/utils/app_design.dart';

/// Pourquoi la position automatique n'a pas pu être obtenue.
/// Une ligne de la commande : une variante (ou le produit sans options) et
/// sa quantité.
class OrderLine {
  const OrderLine({
    required this.variant,
    required this.quantity,
    required this.unitPriceXaf,
  });

  final Map<String, dynamic>? variant;
  final int quantity;

  /// Prix unitaire en XAF, supplément de la variante compris.
  final double unitPriceXaf;

  double get totalXaf => unitPriceXaf * quantity;

  /// « Rouge · 42 », vide pour un produit sans options.
  String get label => VariantCatalog.labelOf(variant);
}

enum LocationIssue {
  none,
  serviceDisabled,
  permissionDenied,
  deniedForever,
  failed,
}

class ProductController extends GetxController {
  final currentLocation = ''.obs;
  final clientLatitude = 0.0.obs;
  final clientLongitude = 0.0.obs;
  final locationIssue = LocationIssue.none.obs;
  final currentProductId = 0.obs;
  final isLoadingLocation = false.obs;
  final isLoadingPartners = false.obs;
  final isCreatingOrder = false.obs;
  final isLoadingSimilarProducts = false.obs;
  final isFavorite = false.obs;
  final isStartingConversation = false.obs;
  final withDelivery = false.obs;
  final orderQuantity = 1.obs;
  final deliveryPrice = 0.0.obs;
  final currentImageIndex = 0.obs;
  final selectedVariant = Rx<Map<String, dynamic>?>(null);

  /// Quantité commandée par variante (identifiant → quantité), pour un
  /// produit à options : plusieurs couleurs dans une même commande, chacune
  /// sur sa propre ligne.
  final variantQuantities = <int, int>{}.obs;

  /// Incrémenté quand la variante change hors de la fiche (feuille de commande) :
  /// le sélecteur de la fiche est alors reconstruit sur le nouveau choix.
  final variantSelectorEpoch = 0.obs;

  /// Texte saisi, observé pour activer/désactiver le bouton de paiement.
  final customerPhone = ''.obs;
  final PageController imagePageController = PageController();

  final deliveryPartners = <Map<String, dynamic>>[].obs;
  final similarProducts = <Map<String, dynamic>>[].obs;
  final selectedPartner = Rx<Map<String, dynamic>?>(null);

  /// Bloc `quote` du dernier devis (poids total, origine, destination, TVA).
  final deliveryQuote = Rx<Map<String, dynamic>?>(null);

  /// Message bloquant quand la livraison ne peut pas être chiffrée
  /// (poids manquant côté vendeur) : la commande est alors impossible.
  final deliveryBlockedMessage = RxnString();

  /// Quartier de livraison (grille zone à zone, ex. SOLEX Douala).
  final deliveryQuarter = RxnString();

  /// Ville envoyée pour le devis, reprise telle quelle à la commande.
  String _quotedCity = '';

  /// Jeton du dernier chargement : une réponse plus ancienne est ignorée.
  int _partnersRequest = 0;
  int? _quotedQuantity;

  final TextEditingController addressDetailsController =
      TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();

  /// Produits dont la consultation a déjà été signalée (statistiques vendeur).
  final Set<String> _trackedProductIds = {};

  /// Signale une consultation de fiche produit (une fois par produit affiché).
  void trackProductView(Map<String, dynamic> product) {
    final id = product['id']?.toString();
    if (id == null || id.isEmpty || !_trackedProductIds.add(id)) return;
    StatisticsService.trackProductView(id);

    // Asso Ads : la fiche a été ouverte depuis une carte sponsorisée. On le
    // signale au serveur pour mesurer l'efficacité de la campagne ; le quota
    // acheté n'est pas entamé, seul l'affichage de l'annonce est facturé.
    if (product['from_ad'] == true) {
      final numericId = int.tryParse(id);
      if (numericId != null) {
        ProductService.getProduct(numericId, fromAd: true);
      }
    }
    // Même point d'entrée, dédoublonné : la fiche est reconstruite à chaque
    // changement d'état et relancerait sinon la requête en boucle.
    loadSimilarProducts(product);
  }

  /// Lien public du produit, celui que l'on partage.
  ///
  /// Sans identifiant — produit de démonstration, fiche incomplète — il n'y a
  /// rien à partager : mieux vaut masquer l'action que diffuser un lien mort.
  String? shareUrl(Map<String, dynamic> product) {
    final id = product['id']?.toString().trim();
    if (id == null || id.isEmpty) return null;
    return AppConstants.productUrl(id);
  }

  /// Ouvre la feuille de partage du système avec le lien du produit.
  ///
  /// [origin] ancre la fenêtre sur iPad : sans ce rectangle, iOS refuse
  /// d'afficher la feuille.
  Future<void> shareProduct(
    Map<String, dynamic> product, {
    Rect? origin,
  }) async {
    final url = shareUrl(product);
    if (url == null) {
      Get.snackbar(
        'Partage indisponible',
        'Ce produit ne peut pas encore être partagé.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final name = product['name']?.toString().trim() ?? '';
    final price = product['formatted_price']?.toString().trim() ?? '';

    // Le message porte le nom et le prix : dans une conversation, un lien nu
    // n'apprend rien tant qu'on ne l'a pas ouvert.
    final lines = <String>[
      if (name.isNotEmpty) price.isEmpty ? name : '$name — $price',
      url,
    ];

    await Share.share(
      lines.join('\n'),
      subject: name.isEmpty ? null : name,
      sharePositionOrigin: origin,
    );
  }

  /// Charge les produits proches de celui affiché.
  ///
  /// La section existait dans la vue mais sa liste n'était jamais remplie :
  /// elle affichait donc toujours « Aucun produit similaire trouvé ».
  ///
  /// On cherche d'abord dans la sous-catégorie, plus précise ; si elle ne
  /// donne pas assez de résultats on élargit à la catégorie. Le produit
  /// affiché est retiré de sa propre liste.
  Future<void> loadSimilarProducts(Map<String, dynamic> product) async {
    final productId = product['id']?.toString();
    final categoryId = int.tryParse(
      product['category_id']?.toString() ??
          product['category']?['id']?.toString() ??
          '',
    );
    final subcategoryId = int.tryParse(
      product['subcategory_id']?.toString() ??
          product['subcategory']?['id']?.toString() ??
          '',
    );

    if (categoryId == null && subcategoryId == null) {
      similarProducts.clear();
      return;
    }

    try {
      isLoadingSimilarProducts.value = true;
      var results = subcategoryId != null
          ? await _fetchSimilar(
              subcategoryId: subcategoryId,
              excluding: productId,
            )
          : <Map<String, dynamic>>[];

      // Repli : une sous-catégorie trop étroite ne remplit pas la rangée.
      if (results.length < 4 && categoryId != null) {
        final wider = await _fetchSimilar(
          categoryId: categoryId,
          excluding: productId,
        );
        final seen = results.map((p) => p['id']?.toString()).toSet();
        results = [
          ...results,
          ...wider.where((p) => seen.add(p['id']?.toString())),
        ];
      }

      similarProducts.value = results.take(10).toList();
    } catch (e) {
      // Une section de suggestions vide ne doit jamais empêcher de consulter
      // la fiche : on la laisse masquée.
      similarProducts.clear();
    } finally {
      isLoadingSimilarProducts.value = false;
    }
  }

  /// Une page de produits filtrée, sans celui déjà affiché.
  Future<List<Map<String, dynamic>>> _fetchSimilar({
    int? categoryId,
    int? subcategoryId,
    String? excluding,
  }) async {
    final response = await ProductService.getProducts(
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      perPage: 12,
    );

    if (!response.success || response.data == null) return [];
    return extractProducts(response.data!, excluding: excluding);
  }

  /// Extrait la liste de produits d'une réponse de l'API.
  ///
  /// Exposée pour être vérifiable : c'est ici que la section échouait en
  /// silence. Le catalogue répond `{success, products, pagination}` quand
  /// d'autres routes paginent sous `data` ; lire la mauvaise clé renvoyait
  /// une liste vide sans la moindre erreur.
  @visibleForTesting
  static List<Map<String, dynamic>> extractProducts(
    Map<String, dynamic> body, {
    String? excluding,
  }) {
    final raw = body['products'] ?? body['data'];
    final list = raw is List ? raw : (raw is Map ? raw['data'] as List? : null);
    if (list == null) return [];

    return list
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) => p['id']?.toString() != excluding)
        .toList();
  }

  @override
  void onInit() {
    super.onInit();

    customerPhoneController.addListener(
      () => customerPhone.value = customerPhoneController.text.trim(),
    );
    // Le prix de livraison dépend du poids total (poids × quantité).
    debounce<int>(orderQuantity, (quantity) {
      if (quantity > 0 &&
          currentProductId.value != 0 &&
          hasValidLocation &&
          quantity != _quotedQuantity) {
        loadDeliveryPartners(currentProductId.value);
      }
    }, time: const Duration(milliseconds: 500));

    final user = StorageService.getUser();
    final rawPhone = (user?.phone ?? '').trim();
    if (rawPhone.isNotEmpty) {
      customerPhoneController.text = rawPhone;
    }
  }

  @override
  void onClose() {
    imagePageController.dispose();
    addressDetailsController.dispose();
    customerPhoneController.dispose();
    super.onClose();
  }

  void goToImage(int index) {
    currentImageIndex.value = index;
    if (imagePageController.hasClients) {
      imagePageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  bool productHasVariants(Map<String, dynamic> product) =>
      !VariantCatalog.fromApi(
        product['variants'],
        product['variant_options'],
      ).isEmpty;

  /// Prix unitaire en XAF, supplément de la variante choisie compris.
  double unitPriceXaf(Map<String, dynamic> product) =>
      _priceFor(product, selectedVariantOf(product));

  /// Variante choisie sur la fiche, seulement si elle appartient à [product].
  ///
  /// Le contrôleur est partagé entre fiches empilées (produit similaire,
  /// boutique…) : sans ce contrôle, la variante d'un autre produit imposait
  /// son prix — et, avant la commande par lignes, son identifiant.
  Map<String, dynamic>? selectedVariantOf(Map<String, dynamic> product) {
    final variant = selectedVariant.value;
    final id = variant == null ? null : VariantQuantityList.idOf(variant);
    if (id == null) return null;
    final variants = product['variants'];
    if (variants is! List) return null;
    final belongs = variants.any(
      (v) => v is Map && v['id']?.toString() == id.toString(),
    );
    return belongs ? variant : null;
  }

  /// Prix unitaire en XAF d'une variante donnée (liste des options).
  double variantPriceXaf(
    Map<String, dynamic> product,
    Map<String, dynamic> variant,
  ) => _priceFor(product, variant);

  double _priceFor(
    Map<String, dynamic> product,
    Map<String, dynamic>? variant,
  ) {
    final variantPrice = variant?['price_xaf'];
    if (variantPrice is num) return variantPrice.toDouble();
    final base =
        double.tryParse(
          (product['price_xaf'] ?? product['price'] ?? 0).toString().replaceAll(
            ' ',
            '',
          ),
        ) ??
        0;
    final adjustment =
        (variant?['price_adjustment_xaf'] as num?)?.toDouble() ??
        (variant?['price_adjustment'] as num?)?.toDouble() ??
        0;
    return base + adjustment;
  }

  /// Quantité maximale commandable : stock de la variante choisie, sinon du produit.
  /// `null` quand le stock n'est pas connu (aucune limite côté app).
  int? maxQuantity(Map<String, dynamic> product) {
    final variant = selectedVariantOf(product);
    if (variant != null) return VariantCatalog.stockOf(variant);
    final raw = product['stock'];
    if (raw == null) return null;
    return raw is num ? raw.toInt() : int.tryParse(raw.toString());
  }

  /// Explique pourquoi la quantité ne monte plus.
  void notifyStockLimit(int max) {
    Get.snackbar(
      'Stock limité',
      max <= 0
          ? 'Cette option est épuisée.'
          : 'Il ne reste que $max article${max > 1 ? 's' : ''} disponible${max > 1 ? 's' : ''}.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Quantité d'un produit sans options, plafonnée au stock.
  void setOrderQuantity(Map<String, dynamic> product, int quantity) {
    final max = maxQuantity(product);
    orderQuantity.value = (max != null && quantity > max) ? max : quantity;
  }

  /// Quantités par variante ; la quantité totale suit, pour que le devis de
  /// livraison (poids × quantité) se recalcule.
  void setVariantQuantities(Map<int, int> quantities) {
    variantQuantities.assignAll(quantities);
    orderQuantity.value = VariantQuantityList.totalOf(quantities);
  }

  /// Remet la commande à zéro à l'ouverture de la feuille. La variante
  /// regardée sur la fiche, si elle est en stock, est proposée d'office.
  void resetOrderQuantities(Map<String, dynamic> product) {
    variantQuantities.clear();
    if (!productHasVariants(product)) {
      orderQuantity.value = 1;
      return;
    }
    final variant = selectedVariantOf(product);
    final id = variant == null ? null : VariantQuantityList.idOf(variant);
    if (id != null && VariantCatalog.stockOf(variant!) > 0) {
      setVariantQuantities({id: 1});
    } else {
      setVariantQuantities(const {});
    }
  }

  /// Lignes de la commande : une par variante choisie, ou une seule pour un
  /// produit sans options.
  List<OrderLine> orderLines(Map<String, dynamic> product) {
    final catalog = VariantCatalog.fromApi(
      product['variants'],
      product['variant_options'],
    );
    if (catalog.isEmpty) {
      return [
        OrderLine(
          variant: null,
          quantity: orderQuantity.value,
          unitPriceXaf: _priceFor(product, null),
        ),
      ];
    }
    return [
      for (final variant in catalog.variants)
        if ((variantQuantities[VariantQuantityList.idOf(variant)] ?? 0) > 0)
          OrderLine(
            variant: variant,
            quantity: variantQuantities[VariantQuantityList.idOf(variant)]!,
            unitPriceXaf: _priceFor(product, variant),
          ),
    ];
  }

  /// Ramène la quantité dans le stock de la nouvelle variante.
  void onVariantChanged(
    Map<String, dynamic> product,
    Map<String, dynamic>? variant,
  ) {
    selectedVariant.value = variant;
    final max = maxQuantity(product);
    if (max != null && max > 0 && orderQuantity.value > max) {
      orderQuantity.value = max;
    }
  }

  bool get hasValidLocation =>
      currentLocation.value.trim().isNotEmpty &&
      !(clientLatitude.value == 0 && clientLongitude.value == 0);

  /// Chiffres du numéro à contacter (espaces, tirets et « + » ignorés).
  static String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  bool get hasValidPhone {
    final digits = _digits(customerPhone.value);
    return digits.length >= 8 && digits.length <= 15;
  }

  /// Étapes restantes avant de pouvoir payer (vide = commande prête).
  List<String> missingOrderSteps(Map<String, dynamic> product) => [
    if (productHasVariants(product) && variantQuantities.isEmpty)
      'Indiquer la quantité d’au moins une option'
    else if (orderQuantity.value < 1)
      'Indiquer une quantité',
    if (!hasValidLocation) 'Indiquer l’adresse de livraison',
    if (!hasValidPhone) 'Renseigner un numéro à contacter valide',
    if (deliveryBlockedMessage.value != null)
      'Livraison impossible : le vendeur doit renseigner le poids du produit'
    else if (selectedPartner.value == null)
      'Choisir un partenaire de livraison',
  ];

  Future<void> fetchCurrentLocation() async {
    isLoadingLocation.value = true;
    locationIssue.value = LocationIssue.none;
    try {
      // Fix précis, puis position réseau, puis dernière position connue :
      // la lecture est bornée dans le temps (voir DeviceLocation).
      final result = await DeviceLocation.current();
      final position = result.position;
      if (position == null) {
        locationIssue.value = switch (result.failure) {
          LocationFailure.serviceDisabled => LocationIssue.serviceDisabled,
          LocationFailure.permissionDenied => LocationIssue.permissionDenied,
          LocationFailure.deniedForever => LocationIssue.deniedForever,
          _ => LocationIssue.failed,
        };
        return;
      }
      await setDeliveryPosition(position.latitude, position.longitude);
    } finally {
      isLoadingLocation.value = false;
    }
  }

  /// Enregistre la position de livraison et en déduit une adresse lisible.
  Future<void> setDeliveryPosition(
    double latitude,
    double longitude, {
    String? fallbackAddress,
  }) async {
    clientLatitude.value = latitude;
    clientLongitude.value = longitude;
    locationIssue.value = LocationIssue.none;

    String? label;
    try {
      // Borné : sans réponse du géocodeur du téléphone, « Ma position » et
      // « Modifier » restaient grisés pendant le chargement.
      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(const Duration(seconds: 8));
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final city = [
          placemark.locality,
          placemark.subAdministrativeArea,
          placemark.administrativeArea,
        ].firstWhereOrNull((part) => part != null && part.isNotEmpty);
        final parts = <String>[
          if (city != null) city,
          if (placemark.subLocality?.isNotEmpty == true) placemark.subLocality!,
          if (placemark.street?.isNotEmpty == true &&
              !(placemark.street!.contains('+')))
            placemark.street!,
        ];
        if (parts.isNotEmpty) label = parts.join(', ');
      }
    } catch (_) {}

    currentLocation.value =
        label ??
        (fallbackAddress?.trim().isNotEmpty == true
            ? fallbackAddress!.trim()
            : 'Position GPS (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})');
  }

  Future<void> openLocationSettings() async {
    if (locationIssue.value == LocationIssue.deniedForever) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.openLocationSettings();
    }
  }

  /// Poids total du colis (kg) d'après le dernier devis.
  double? get deliveryWeightKg {
    final raw = deliveryQuote.value?['weight_kg'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  Future<void> loadDeliveryPartners(int productId) async {
    currentProductId.value = productId;
    final request = ++_partnersRequest;
    // Aucune option encore choisie : on chiffre un article, pour montrer
    // les partenaires et un ordre de prix dès l'ouverture.
    final quantity = orderQuantity.value < 1 ? 1 : orderQuantity.value;
    final previousKey = selectedPartner.value == null
        ? null
        : DeliveryPartnerQuote(selectedPartner.value!).key;
    _quotedQuantity = quantity;
    _quotedCity = currentLocation.value.trim();

    isLoadingPartners.value = true;
    deliveryPartners.clear();
    deliveryQuote.value = null;
    deliveryBlockedMessage.value = null;
    selectedPartner.value = null;
    withDelivery.value = false;
    deliveryPrice.value = 0;

    try {
      final response = await DeliveryService.getDeliveryPartnersWithPricing(
        productId: productId,
        quantity: quantity,
        latitude: clientLatitude.value,
        longitude: clientLongitude.value,
        city: _quotedCity,
        quarter: deliveryQuarter.value,
      );
      if (request != _partnersRequest) return; // réponse périmée

      final quote = response.data?['quote'];
      if (quote is Map) {
        deliveryQuote.value = Map<String, dynamic>.from(quote);
        if (quote['reason'] == 'missing_weight') {
          final products =
              (quote['missing_weight_products'] as List?)
                  ?.map((e) => e.toString())
                  .join(', ') ??
              '';
          deliveryBlockedMessage.value =
              quote['message']?.toString() ??
              response.data?['message']?.toString() ??
              'Livraison impossible à chiffrer : le vendeur doit renseigner le poids${products.isNotEmpty ? ' de $products' : ' du produit'}.';
          return;
        }
      }

      if (!response.success) {
        Get.snackbar(
          'Livraison indisponible',
          response.message,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final rawPartners = response.data?['partners'] ?? response.data ?? [];
      if (rawPartners is! List) {
        return;
      }

      final partners = rawPartners
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      deliveryPartners.assignAll(partners);
      if (partners.isNotEmpty) {
        // Garder le partenaire choisi si le nouveau devis le propose encore.
        final kept = partners.firstWhereOrNull(
          (p) => DeliveryPartnerQuote(p).key == previousKey,
        );
        selectPartner(kept ?? partners.first);
      }
    } catch (_) {
      if (request != _partnersRequest) return;
      Get.snackbar(
        'Erreur',
        'Impossible de charger les partenaires de livraison.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (request == _partnersRequest) isLoadingPartners.value = false;
    }
  }

  void selectPartner(Map<String, dynamic> partner) {
    selectedPartner.value = partner;
    final price = partner['delivery_price'];
    deliveryPrice.value = price is num ? price.toDouble() : 0.0;
    withDelivery.value = true;
  }

  /// Sous-total des articles, ligne par ligne : chaque option garde son prix.
  double orderSubtotal(Map<String, dynamic> product) =>
      orderLines(product).fold(0.0, (sum, line) => sum + line.totalXaf);

  /// Course choisie offerte par le vendeur : son prix s'affiche barré et
  /// n'entre pas dans le total.
  bool get deliveryIsFree {
    final partner = selectedPartner.value;
    return partner != null && DeliveryPartnerQuote(partner).isFree;
  }

  double orderTotal(Map<String, dynamic> product) {
    final total = orderSubtotal(product);
    if (withDelivery.value && !deliveryIsFree) {
      return total + deliveryPrice.value;
    }
    return total;
  }

  String formatPrice(double amount) {
    final formatter = NumberFormat.decimalPattern('fr_FR');
    return '${formatter.format(amount.round())} FCFA';
  }

  /// Crée la commande et renvoie la réponse du serveur (`order`, `order_id`,
  /// données Stripe…), ou null si elle n'a pas pu être créée.
  Future<Map<String, dynamic>?> createOrder({
    required Map<String, dynamic> product,
    required String paymentMode,
    String? kpayProvider,
    String? kpayPhone,
  }) async {
    if (isCreatingOrder.value) return null;

    final missing = missingOrderSteps(product);
    if (missing.isNotEmpty) {
      Get.snackbar(
        'Commande incomplète',
        missing.first,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }

    final productId = int.tryParse(product['id']?.toString() ?? '') ?? 0;
    final partner = DeliveryPartnerQuote(selectedPartner.value!);
    final deliveryCompanyId = partner.companyId;
    // Transporteur : route interurbaine/internationale ; sinon zone urbaine.
    final deliveryRouteId = partner.routeId;
    final deliveryZoneId = partner.zoneId;
    final deliveryGridId = partner.gridId;
    if (deliveryCompanyId == null ||
        (deliveryRouteId == null &&
            deliveryZoneId == null &&
            deliveryGridId == null)) {
      Get.snackbar(
        'Erreur',
        'Le partenaire sélectionné ne contient pas de zone ou de trajet de livraison valide.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }

    final details = addressDetailsController.text.trim();
    final lines = orderLines(product);
    // Rappel lisible pour le vendeur : « Couleur: Rouge × 3 ; Couleur: Noir × 2 ».
    final variantNote = lines
        .where((line) => line.variant != null)
        .map(
          (line) =>
              '${VariantCatalog.attributesOf(line.variant!).entries.map((e) => '${e.key}: ${e.value}').join(', ')} × ${line.quantity}',
        )
        .join(' ; ');

    isCreatingOrder.value = true;
    try {
      final response = await OrderService.createOrder(
        // Une ligne par option choisie : le serveur vérifie et décompte le
        // stock de chacune.
        items: [
          for (final line in lines)
            {
              'product_id': productId,
              'quantity': line.quantity,
              if (line.variant?['id'] != null) 'variant_id': line.variant!['id'],
            },
        ],
        deliveryCompanyId: deliveryCompanyId,
        deliveryZoneId: deliveryZoneId,
        deliveryRouteId: deliveryRouteId,
        deliveryGridId: deliveryGridId,
        deliveryVehicle: partner.vehicle,
        deliveryQuarter: deliveryQuarter.value,
        deliveryCity: _quotedCity.isNotEmpty
            ? _quotedCity
            : currentLocation.value,
        deliveryCountry: deliveryQuote.value?['destination'] is Map
            ? deliveryQuote.value!['destination']['country']?.toString()
            : null,
        walletProvider: 'kpay',
        paymentMode: paymentMode,
        kpayProvider: kpayProvider,
        kpayPhone: kpayPhone,
        deliveryAddress: currentLocation.value,
        deliveryAddressDetails: details.isEmpty ? null : details,
        customerPhone: customerPhone.value,
        deliveryLatitude: clientLatitude.value,
        deliveryLongitude: clientLongitude.value,
        notes: variantNote.isEmpty ? null : 'Variantes : $variantNote',
      );

      if (!response.success) {
        Get.snackbar(
          'Commande impossible',
          response.message,
          snackPosition: SnackPosition.BOTTOM,
        );
        return null;
      }

      return response.data ?? const {};
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue pendant la commande: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      isCreatingOrder.value = false;
    }
  }

  /// Suit la confirmation serveur d'un paiement direct (Mobile Money / carte)
  /// et prévient l'acheteur dès que le statut est connu.
  Future<void> pollOrderPayment(int orderId) async {
    if (orderId <= 0) return;
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        final res = await OrderService.orderPaymentStatus(orderId);
        final status = res.data?['data']?['payment_status'];
        if (status == 'paid') {
          Get.snackbar(
            'Paiement confirmé',
            'Votre commande est payée. Le vendeur va la préparer.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppDesign.success,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          return;
        }
        if (status == 'failed') {
          Get.snackbar(
            'Paiement échoué',
            "Le paiement n'a pas abouti. Vous pouvez réessayer depuis vos commandes.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppDesign.danger,
            colorText: Colors.white,
            duration: const Duration(seconds: 6),
          );
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> toggleFavorite(int productId) async {
    try {
      final response = await ProductService.toggleFavorite(productId);
      if (response.success) {
        final favorite = response.data?['is_favorite'] ?? false;
        isFavorite.value = favorite;
      }
    } catch (_) {}
  }

  /// Ouvre directement la conversation avec le vendeur à propos du produit.
  /// Le chat s'empile au-dessus de la fiche : son bouton retour y ramène.
  Future<void> openConversationWithSeller({
    required Map<String, dynamic> product,
  }) async {
    if (isStartingConversation.value) return;
    final seller = product['seller'] as Map?;
    final shop = product['shop'] as Map?;
    final sellerId = int.tryParse(
      (seller?['id'] ?? shop?['user_id'] ?? product['user_id'])?.toString() ??
          '',
    );
    if (sellerId == null) {
      Get.snackbar(
        'Erreur',
        'Impossible de démarrer la conversation.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isStartingConversation.value = true;
    try {
      final productId = int.tryParse(product['id']?.toString() ?? '');
      final response = await ConversationService.startConversation(
        userId: sellerId,
        productId: productId,
      );
      final conversation = response.data?['conversation'] ?? response.data;
      final conversationId =
          conversation?['id'] ?? conversation?['conversation_id'];
      if (response.success && conversationId != null) {
        StatisticsService.trackContact(
          productId: productId,
          shopId: shop?['id'],
        );
      }
      if (!response.success || conversationId == null) {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty
              ? response.message
              : 'Impossible de démarrer la conversation.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final otherName = conversation['other_user']?['name']?.toString();
      final name = otherName?.isNotEmpty == true
          ? otherName!
          : (shop?['name'] ?? seller?['name'] ?? 'Vendeur').toString();
      final variantLabel = VariantCatalog.labelOf(selectedVariant.value);

      await Get.toNamed(
        '/chatdetail',
        arguments: {
          'id': conversationId.toString(),
          'name': name,
          'avatar': StringUtils.getInitials(name),
          'userId': sellerId,
          'productId': productId,
          'isOnline': false,
          'default_message':
              'Bonjour, je suis intéressé(e) par « ${product['name']}'
              '${variantLabel.isNotEmpty ? ' ($variantLabel)' : ''} ». ',
        },
      );
    } catch (_) {
      Get.snackbar(
        'Erreur',
        'Impossible de démarrer la conversation.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isStartingConversation.value = false;
    }
  }
}
