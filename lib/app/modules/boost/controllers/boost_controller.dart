import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/models/boost_models.dart';
import '../../../data/models/payment_method_option.dart';
import '../../../data/providers/boost_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/package_service.dart';
import '../../../data/providers/vendor_product_service.dart';
import '../../../data/services/stripe_native_service.dart';
import '../../packageSubscription/widgets/payment_loading_dialog.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../payment/widgets/wallet_payment_confirm_dialog.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';

/// Asso Ads — achat et suivi du sponsoring d'un article.
///
/// Le paiement emprunte les trois rails habituels (solde Wallet, Mobile Money,
/// carte) via `POST /v1/packages/subscribe`, avec en plus l'article à
/// sponsoriser. La campagne n'est ouverte qu'à l'encaissement : pour les rails
/// directs, on suit la confirmation par polling comme pour les forfaits.
class BoostController extends GetxController {
  bool _isDisposed = false;

  final isLoading = false.obs;
  final isSubscribing = false.obs;

  /// Offres disponibles.
  final packages = <BoostPackage>[].obs;

  /// Articles du vendeur éligibles au sponsoring.
  final products = <Map<String, dynamic>>[].obs;

  /// Campagnes passées et en cours.
  final campaigns = <BoostCampaign>[].obs;

  /// Sélection en cours dans le parcours d'achat.
  final selectedProduct = Rx<Map<String, dynamic>?>(null);
  final selectedPackage = Rx<BoostPackage?>(null);

  /// Faux quand l'administration a suspendu la diffusion.
  final adsEnabled = true.obs;

  /// Vrai quand le chargement a échoué (réseau, serveur).
  ///
  /// Sans cet état, une coupure réseau affichait « Vous n'avez aucun article à
  /// sponsoriser » : un message faux, qui laisse croire à un problème de
  /// compte et n'invite pas à réessayer.
  final hasLoadError = false.obs;

  @override
  void onInit() {
    super.onInit();

    // Un article peut être passé en argument depuis la fiche produit.
    final arg = Get.arguments;
    if (arg is Map && arg['product'] is Map) {
      selectedProduct.value = Map<String, dynamic>.from(arg['product'] as Map);
    }

    loadAll();
  }

  @override
  void onClose() {
    _isDisposed = true;
    super.onClose();
  }

  Future<void> loadAll() async {
    // Le plein écran de chargement n'est montré qu'au premier affichage :
    // pendant un pull-to-refresh, le contenu doit rester visible.
    if (packages.isEmpty && campaigns.isEmpty) {
      isLoading.value = true;
    }
    hasLoadError.value = false;

    await Future.wait([loadPackages(), loadProducts(), loadCampaigns()]);
    if (_isDisposed) return;
    isLoading.value = false;
  }

  Future<void> loadPackages() async {
    try {
      final res = await BoostService.getPackages();
      if (_isDisposed) return;

      if (!res.success) {
        hasLoadError.value = true;
        return;
      }

      packages.value = ((res.data?['packages'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BoostPackage.fromJson(e.cast<String, dynamic>()))
          .toList();

      // Le forfait mis en avant est présélectionné : le vendeur n'a qu'à
      // confirmer s'il n'a pas d'avis sur la question.
      selectedPackage.value ??= packages.firstWhereOrNull((p) => p.isPopular) ??
          (packages.isNotEmpty ? packages.first : null);
    } catch (_) {
      if (!_isDisposed) hasLoadError.value = true;
    }
  }

  Future<void> loadProducts() async {
    try {
      final res = await VendorProductService.getVendorProducts(
        perPage: 100,
        status: 'active',
      );
      if (_isDisposed) return;

      if (!res.success) {
        hasLoadError.value = true;
        return;
      }

      // L'API vendeur renvoie sa liste sous `data` (paginée), contrairement
      // au catalogue public qui utilise `products`.
      final raw = (res.data?['data'] as List?) ??
          (res.data?['products'] as List?) ??
          const [];
      products.value = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          // Seul un article en ligne peut être sponsorisé.
          .where((p) => (p['status']?.toString() ?? 'active') == 'active')
          .toList();
    } catch (_) {
      if (!_isDisposed) hasLoadError.value = true;
    }
  }

  Future<void> loadCampaigns() async {
    try {
      final res = await BoostService.getCampaigns();
      if (_isDisposed) return;

      if (!res.success) {
        hasLoadError.value = true;
        return;
      }

      adsEnabled.value = res.data?['ads_enabled'] != false;
      campaigns.value = ((res.data?['boosts'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BoostCampaign.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      if (!_isDisposed) hasLoadError.value = true;
    }
  }

  /// Campagnes actuellement diffusées.
  List<BoostCampaign> get runningCampaigns =>
      campaigns.where((c) => c.isRunning).toList();

  /// Articles déjà sponsorisés : ils ne peuvent pas l'être deux fois.
  Set<int> get boostedProductIds =>
      campaigns.where((c) => c.isRunning).map((c) => c.productId).toSet();

  bool isProductBoosted(dynamic productId) {
    final id = int.tryParse(productId?.toString() ?? '');
    return id != null && boostedProductIds.contains(id);
  }

  void selectProduct(Map<String, dynamic>? product) =>
      selectedProduct.value = product;

  void selectPackage(BoostPackage package) => selectedPackage.value = package;

  // ------------------------------------------------------------------
  // Achat
  // ------------------------------------------------------------------

  /// Lance l'achat du forfait sélectionné pour l'article sélectionné.
  Future<void> buy() async {
    if (_isDisposed || isSubscribing.value) return;

    final product = selectedProduct.value;
    final package = selectedPackage.value;

    if (product == null) {
      _error('Choisissez l\'article à sponsoriser.');
      return;
    }
    if (package == null) {
      _error('Choisissez une formule.');
      return;
    }
    if (isProductBoosted(product['id'])) {
      _error('Cet article est déjà sponsorisé. Attendez la fin de la campagne en cours.');
      return;
    }

    final productId = int.tryParse(product['id']?.toString() ?? '');
    if (productId == null) {
      _error('Article invalide.');
      return;
    }

    final display = CurrencyService.displayFromPivot(package.price);
    final method = await PaymentMethodSelector.show(
      amount: display.amount,
      currency: display.currency,
      amountLabel: 'Prix du sponsoring',
      allowedCodes: const {'kpay', 'stripe'},
      includeWallet: true,
    );
    if (method == null || _isDisposed) return;

    switch (method.code) {
      case 'wallet':
        await _buyWithWallet(package, productId, method);
        break;
      case 'kpay':
        await _buyWithKpay(package, productId);
        break;
      case 'stripe':
        await _buyWithCard(package, productId);
        break;
      default:
        _error("Ce moyen de paiement n'est pas disponible pour le sponsoring.");
    }
  }

  /// Solde Wallet ASSO : débit et diffusion immédiats.
  Future<void> _buyWithWallet(
    BoostPackage package,
    int productId,
    PaymentMethodOption method,
  ) async {
    final confirmed = await WalletPaymentConfirmDialog.show(
      itemLabel: 'Sponsoring — ${package.name}',
      amount: package.price,
      balance: method.balance ?? 0,
    );
    if (!confirmed || _isDisposed) return;

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'Activation du sponsoring...');

    try {
      final res = await PackageService.subscribePackageDirect(
        package.id,
        paymentMode: 'wallet',
        productId: productId,
      );
      if (_isDisposed) return;

      if (!res.success) {
        _error(res.message);
        return;
      }

      await loadCampaigns();
      if (_isDisposed) return;
      _success(package);
    } catch (e) {
      _error('Une erreur est survenue : $e');
    } finally {
      // Fermé ici et nulle part ailleurs : un `return` anticipé (écran quitté
      // pendant l'appel) laissait sinon un dialogue bloquant à l'écran.
      PaymentLoadingDialog.hide();
      isSubscribing.value = false;
    }
  }

  /// Mobile Money (USSD) : la campagne démarre à la confirmation du paiement.
  Future<void> _buyWithKpay(BoostPackage package, int productId) async {
    final selection = await KpayDirectPaymentSheet.show(
      amount: package.price,
      amountLabel: 'Prix du sponsoring',
    );
    if (selection == null || _isDisposed) return;

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'Création de votre campagne...');

    try {
      final res = await PackageService.subscribePackageDirect(
        package.id,
        paymentMode: 'kpay_direct',
        provider: selection['provider'],
        phoneNumber: selection['phone'],
        productId: productId,
      );
      if (_isDisposed) return;

      final subscriptionId = _subscriptionIdFrom(res);
      if (!res.success || subscriptionId == null) {
        _error(res.message);
        return;
      }

      Get.snackbar(
        'Paiement en attente',
        'Validez le paiement sur votre téléphone (USSD). Le sponsoring démarrera ensuite.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.warningColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      _pollPayment(subscriptionId, package);
    } catch (e) {
      _error('Une erreur est survenue : $e');
    } finally {
      PaymentLoadingDialog.hide();
      isSubscribing.value = false;
    }
  }

  /// Carte bancaire (Payment Sheet Stripe native).
  Future<void> _buyWithCard(BoostPackage package, int productId) async {
    if (!StripeNativeService.isSupported) {
      _error("Le paiement par carte est disponible sur l'application mobile.");
      return;
    }

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'Préparation du paiement...');

    try {
      final res = await PackageService.subscribePackageDirect(
        package.id,
        paymentMode: 'stripe_direct',
        productId: productId,
      );
      if (_isDisposed) return;
      // La Payment Sheet s'ouvre ensuite : le dialogue de chargement doit
      // disparaître avant, sinon il la recouvre.
      PaymentLoadingDialog.hide();

      final subscriptionId = _subscriptionIdFrom(res);
      final clientSecret = res.data?['client_secret']?.toString();
      final publishableKey = res.data?['publishable_key']?.toString();

      if (!res.success || subscriptionId == null) {
        _error(res.message);
        return;
      }
      if (clientSecret == null || clientSecret.isEmpty ||
          publishableKey == null || publishableKey.isEmpty) {
        _error('Données de paiement carte indisponibles. Réessayez.');
        return;
      }

      final ok = await StripeNativeService().payWithCard(
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );
      if (_isDisposed) return;

      if (!ok) {
        Get.snackbar(
          'Paiement annulé',
          "Le paiement n'a pas été finalisé.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.warningColor,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      Get.snackbar(
        'Paiement en cours',
        'Votre paiement est en cours de confirmation.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

      _pollPayment(subscriptionId, package);
    } catch (e) {
      _error(e.toString().replaceAll('Exception: ', ''));
    } finally {
      PaymentLoadingDialog.hide();
      isSubscribing.value = false;
    }
  }

  /// Suit la confirmation d'un paiement direct (5 s, 10 min max). Le succès
  /// n'est annoncé qu'au statut « paid » : la campagne est alors réellement
  /// ouverte côté serveur.
  void _pollPayment(int subscriptionId, BoostPackage package) async {
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (_isDisposed) return;

      try {
        final res = await PackageService.getSubscriptionPaymentStatus(subscriptionId);
        final status = res.data?['data']?['status'];

        if (status == 'paid') {
          await loadCampaigns();
          if (_isDisposed) return;
          _success(package);
          return;
        }
        if (status == 'failed') {
          Get.snackbar(
            'Paiement échoué',
            "Le paiement du sponsoring n'a pas abouti.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppThemeSystem.errorColor,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          return;
        }
      } catch (_) {}
    }

    if (_isDisposed) return;
    Get.snackbar(
      'Paiement en attente',
      "La confirmation n'est pas encore arrivée. Vos campagnes se mettront à jour automatiquement.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.warningColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  // ------------------------------------------------------------------
  // Pilotage d'une campagne
  // ------------------------------------------------------------------

  /// Arrêt anticipé. La portée déjà délivrée reste due : on le dit clairement.
  Future<void> cancelCampaign(BoostCampaign campaign) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Arrêter le sponsoring ?'),
        content: Text(
          '« ${campaign.productName} » ne sera plus mis en avant. '
          'Les ${campaign.impressionsRemaining} vues restantes seront perdues '
          'et ne sont pas remboursées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Continuer le sponsoring'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: AppThemeSystem.errorColor),
            child: const Text('Arrêter'),
          ),
        ],
      ),
    );

    if (confirmed != true || _isDisposed) return;

    try {
      final res = await BoostService.cancel(campaign.id);
      if (_isDisposed) return;

      if (res.success) {
        await loadCampaigns();
        Get.snackbar(
          'Sponsoring arrêté',
          'La campagne est terminée.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        _error(res.message);
      }
    } catch (e) {
      _error('Une erreur est survenue : $e');
    }
  }

  /// Recharge le détail d'une campagne (suivi en temps réel).
  Future<BoostCampaign?> refreshCampaign(int boostId) async {
    try {
      final res = await BoostService.getCampaign(boostId);
      if (!res.success || res.data?['boost'] == null) return null;

      final fresh = BoostCampaign.fromJson(
        (res.data!['boost'] as Map).cast<String, dynamic>(),
      );

      final index = campaigns.indexWhere((c) => c.id == boostId);
      if (index >= 0) campaigns[index] = fresh;

      return fresh;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------

  int? _subscriptionIdFrom(dynamic response) {
    final raw = response.data?['subscription_id'];
    if (raw is int) return raw;
    return int.tryParse('$raw');
  }

  void _success(BoostPackage package) {
    Get.snackbar(
      'Sponsoring activé 🚀',
      'Votre article sera vu par ${package.formattedReach}.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppDesign.success,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  void _error(String? message) {
    Get.snackbar(
      'Erreur',
      message?.isNotEmpty == true ? message! : 'Impossible de lancer le sponsoring',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.errorColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }
}
