import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/string_utils.dart';
import '../../../core/widgets/product_variant_selector.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/storage_service.dart';

/// Pourquoi la position automatique n'a pas pu être obtenue.
enum LocationIssue { none, serviceDisabled, permissionDenied, deniedForever, failed }

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

  /// Incrémenté quand la variante change hors de la fiche (feuille de commande) :
  /// le sélecteur de la fiche est alors reconstruit sur le nouveau choix.
  final variantSelectorEpoch = 0.obs;

  /// Texte saisi, observé pour activer/désactiver le bouton de paiement.
  final customerPhone = ''.obs;
  final PageController imagePageController = PageController();

  final deliveryPartners = <Map<String, dynamic>>[].obs;
  final similarProducts = <Map<String, dynamic>>[].obs;
  final selectedPartner = Rx<Map<String, dynamic>?>(null);

  final TextEditingController addressDetailsController =
      TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();

  @override
  void onInit() {
    super.onInit();

    customerPhoneController.addListener(
      () => customerPhone.value = customerPhoneController.text.trim(),
    );
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

  bool productHasVariants(Map<String, dynamic> product) => !VariantCatalog
      .fromApi(product['variants'], product['variant_options'])
      .isEmpty;

  /// Prix unitaire en XAF, supplément de la variante choisie compris.
  double unitPriceXaf(Map<String, dynamic> product) {
    final variant = selectedVariant.value;
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
    final variant = selectedVariant.value;
    if (variant != null) return VariantCatalog.stockOf(variant);
    final raw = product['stock'];
    if (raw == null) return null;
    return raw is num ? raw.toInt() : int.tryParse(raw.toString());
  }

  void incrementQuantity(Map<String, dynamic> product) {
    final max = maxQuantity(product);
    if (max != null && orderQuantity.value >= max) {
      Get.snackbar(
        'Stock limité',
        'Il ne reste que $max article${max > 1 ? 's' : ''} disponible${max > 1 ? 's' : ''}.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    orderQuantity.value++;
  }

  void decrementQuantity() {
    if (orderQuantity.value > 1) orderQuantity.value--;
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
    if (productHasVariants(product) && selectedVariant.value == null)
      'Choisir les options du produit',
    if (!hasValidLocation) 'Indiquer l’adresse de livraison',
    if (!hasValidPhone) 'Renseigner un numéro à contacter valide',
    if (selectedPartner.value == null) 'Choisir un partenaire de livraison',
  ];

  Future<void> fetchCurrentLocation() async {
    isLoadingLocation.value = true;
    locationIssue.value = LocationIssue.none;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationIssue.value = LocationIssue.serviceDisabled;
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        locationIssue.value = LocationIssue.deniedForever;
        return;
      }
      if (permission == LocationPermission.denied) {
        locationIssue.value = LocationIssue.permissionDenied;
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await setDeliveryPosition(position.latitude, position.longitude);
    } catch (_) {
      // Pas de fix GPS à temps : la dernière position connue suffit pour livrer.
      final last = await Geolocator.getLastKnownPosition().catchError(
        (_) => null,
      );
      if (last != null) {
        await setDeliveryPosition(last.latitude, last.longitude);
      } else {
        locationIssue.value = LocationIssue.failed;
      }
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
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
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

  Future<void> loadDeliveryPartners(int productId) async {
    currentProductId.value = productId;
    isLoadingPartners.value = true;
    deliveryPartners.clear();
    selectedPartner.value = null;
    withDelivery.value = false;
    deliveryPrice.value = 0;

    try {
      final response = await DeliveryService.getDeliveryPartnersWithPricing(
        productId: productId,
        latitude: clientLatitude.value,
        longitude: clientLongitude.value,
        city: currentLocation.value,
      );

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
        final first = partners.first;
        selectPartner(first);
      }
    } catch (_) {
      Get.snackbar(
        'Erreur',
        'Impossible de charger les partenaires de livraison.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingPartners.value = false;
    }
  }

  void selectPartner(Map<String, dynamic> partner) {
    selectedPartner.value = partner;
    final price = partner['delivery_price'];
    deliveryPrice.value = price is num ? price.toDouble() : 0.0;
    withDelivery.value = true;
  }

  double subtotal(double productPrice) => productPrice * orderQuantity.value;

  double calculateTotal(double productPrice) {
    final total = subtotal(productPrice);
    if (withDelivery.value) {
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
    final partner = selectedPartner.value!;
    final deliveryCompanyId = int.tryParse(
      partner['company_id']?.toString() ?? '',
    );
    final deliveryZoneId = int.tryParse(partner['zone_id']?.toString() ?? '');
    if (deliveryCompanyId == null || deliveryZoneId == null) {
      Get.snackbar(
        'Erreur',
        'Le partenaire sélectionné ne contient pas de zone de livraison valide.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }

    final details = addressDetailsController.text.trim();
    final variant = selectedVariant.value;
    final variantLabel = variant == null
        ? ''
        : VariantCatalog.attributesOf(
            variant,
          ).entries.map((e) => '${e.key}: ${e.value}').join(', ');

    isCreatingOrder.value = true;
    try {
      final response = await OrderService.createOrder(
        items: [
          {
            'product_id': productId,
            'quantity': orderQuantity.value,
            if (variant?['id'] != null) 'variant_id': variant!['id'],
          },
        ],
        deliveryCompanyId: deliveryCompanyId,
        deliveryZoneId: deliveryZoneId,
        walletProvider: 'kpay',
        paymentMode: paymentMode,
        kpayProvider: kpayProvider,
        kpayPhone: kpayPhone,
        deliveryAddress: currentLocation.value,
        deliveryAddressDetails: details.isEmpty ? null : details,
        customerPhone: customerPhone.value,
        deliveryLatitude: clientLatitude.value,
        deliveryLongitude: clientLongitude.value,
        notes: variantLabel.isEmpty ? null : 'Variante: $variantLabel',
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
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
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
