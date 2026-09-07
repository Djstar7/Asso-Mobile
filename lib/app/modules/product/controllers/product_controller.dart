import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/storage_service.dart';

class ProductController extends GetxController {
  final currentLocation = ''.obs;
  final clientLatitude = 0.0.obs;
  final clientLongitude = 0.0.obs;
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

  final deliveryPartners = <Map<String, dynamic>>[].obs;
  final similarProducts = <Map<String, dynamic>>[].obs;
  final selectedPartner = Rx<Map<String, dynamic>?>(null);

  final TextEditingController addressDetailsController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();

  @override
  void onInit() {
    super.onInit();

    final user = StorageService.getUser();
    final rawPhone = (user?.phone ?? '').trim();
    if (rawPhone.isNotEmpty) {
      customerPhoneController.text = rawPhone;
    }
  }

  @override
  void onClose() {
    addressDetailsController.dispose();
    customerPhoneController.dispose();
    super.onClose();
  }

  Future<void> fetchCurrentLocation() async {
    isLoadingLocation.value = true;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        currentLocation.value = 'Services de localisation désactivés';
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        currentLocation.value = 'Permission de localisation refusée';
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      clientLatitude.value = position.latitude;
      clientLongitude.value = position.longitude;

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final parts = <String>[];

        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          parts.add(placemark.locality!);
        }
        if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
          parts.add(placemark.subLocality!);
        }
        if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
          parts.add(placemark.administrativeArea!);
        }

        currentLocation.value = parts.isNotEmpty ? parts.join(', ') : 'Position actuelle';
      } else {
        currentLocation.value = 'Position actuelle';
      }
    } catch (_) {
      currentLocation.value = 'Position actuelle';
    } finally {
      isLoadingLocation.value = false;
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

  Future<bool> createOrder({
    required int productId,
    required int quantity,
    String walletProvider = 'kpay',
    String paymentMode = 'wallet',
    String? kpayProvider,
    String? kpayPhone,
  }) async {
    if (isCreatingOrder.value) return false;

    final phone = customerPhoneController.text.trim();
    final details = addressDetailsController.text.trim();

    if (withDelivery.value && selectedPartner.value != null && phone.isEmpty) {
      Get.snackbar(
        'Téléphone requis',
        'Ajoutez un numéro de contact pour le livreur.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final partner = selectedPartner.value;
    int? deliveryCompanyId;
    int? deliveryZoneId;

    if (withDelivery.value) {
      if (partner == null) {
        Get.snackbar(
          'Livraison requise',
          'Choisissez un partenaire de livraison avant de confirmer.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final companyIdValue = partner['company_id'];
      final zoneIdValue = partner['zone_id'];
      deliveryCompanyId = companyIdValue is int
          ? companyIdValue
          : int.tryParse(companyIdValue?.toString() ?? '');
      deliveryZoneId = zoneIdValue is int
          ? zoneIdValue
          : int.tryParse(zoneIdValue?.toString() ?? '');

      if (deliveryCompanyId == null || deliveryZoneId == null) {
        Get.snackbar(
          'Erreur',
          'Le partenaire sélectionné ne contient pas de zone de livraison valide.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    }

    isCreatingOrder.value = true;
    try {
      final response = await OrderService.createOrder(
        items: [
          {'product_id': productId, 'quantity': quantity},
        ],
        deliveryCompanyId: deliveryCompanyId,
        deliveryZoneId: deliveryZoneId,
        walletProvider: walletProvider,
        paymentMode: paymentMode,
        kpayProvider: kpayProvider,
        kpayPhone: kpayPhone,
        deliveryAddress: currentLocation.value,
        deliveryAddressDetails: details.isEmpty ? null : details,
        customerPhone: phone.isEmpty ? null : phone,
        deliveryLatitude: clientLatitude.value,
        deliveryLongitude: clientLongitude.value,
        notes: details.isEmpty ? null : details,
      );

      if (!response.success) {
        Get.snackbar(
          'Commande impossible',
          response.message,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      return true;
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue pendant la commande: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isCreatingOrder.value = false;
    }
  }

  Future<Map<String, dynamic>?> createRedirectOrder({
    required int productId,
    required int quantity,
    required String paymentMode,
  }) async {
    final ok = await createOrder(
      productId: productId,
      quantity: quantity,
      paymentMode: paymentMode,
      walletProvider: 'kpay',
    );

    if (!ok) return null;

    final data = Get.arguments;
    if (data is Map<String, dynamic>) {
      return {'order_id': data['id'] ?? 0, 'approval_url': ''};
    }

    return {'order_id': 0, 'approval_url': ''};
  }

  Future<Map<String, dynamic>?> createCardOrder({
    required int productId,
    required int quantity,
  }) async {
    final ok = await createOrder(
      productId: productId,
      quantity: quantity,
      paymentMode: 'stripe_direct',
      walletProvider: 'kpay',
    );
    if (!ok) return null;
    return {
      'order_id': 0,
      'client_secret': '',
      'payment_intent_id': '',
      'publishable_key': '',
    };
  }

  void pollOrderPayment(int orderId) {
    // Implemented on the view orchestration layer; kept to satisfy the controller contract.
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

  Future<void> openConversationWithSeller({required Map<String, dynamic> product}) async {
    isStartingConversation.value = true;
    try {
      final shop = product['shop'] as Map<String, dynamic>?;
      final shopId = shop?['id'] ?? product['seller']?['id'];
      if (shopId != null) {
        await Get.toNamed('/chat', arguments: {'shop_id': shopId});
      } else {
        Get.snackbar('Erreur', 'Impossible de démarrer la conversation.', snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      isStartingConversation.value = false;
    }
  }
}
