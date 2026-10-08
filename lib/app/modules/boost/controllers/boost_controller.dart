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
import '../../payment/widgets/mobile_money_waiting.dart';

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
      _error('boost.errors.choose_product'.tr);
      return;
    }
    if (package == null) {
      _error('boost.errors.choose_package'.tr);
      return;
    }
    if (isProductBoosted(product['id'])) {
      _error('boost.errors.already_boosted'.tr);
      return;
    }

    final productId = int.tryParse(product['id']?.toString() ?? '');
    if (productId == null) {
      _error('boost.errors.invalid_product'.tr);
      return;
    }

    final display = CurrencyService.displayFromPivot(package.price);
    final method = await PaymentMethodSelector.show(
      amount: display.amount,
      currency: display.currency,
      amountLabel: 'boost.price'.tr,
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
        _error('boost.errors.method_unavailable'.tr);
    }
  }

  /// Solde Wallet ASSO : débit et diffusion immédiats.
  Future<void> _buyWithWallet(
    BoostPackage package,
    int productId,
    PaymentMethodOption method,
  ) async {
    final confirmed = await WalletPaymentConfirmDialog.show(
      itemLabel: 'boost.item_label'.trParams({'name': package.name}),
      amount: package.price,
      balance: method.balance ?? 0,
    );
    if (!confirmed || _isDisposed) return;

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'boost.activating'.tr);

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
      _error('boost.errors.generic'.trParams({'error': '$e'}));
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
      amountLabel: 'boost.price'.tr,
    );
    if (selection == null || _isDisposed) return;

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'boost.creating_campaign'.tr);

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

      // Rien n'est annoncé avant la réponse de l'opérateur.
      PaymentLoadingDialog.hide();
      final outcome = await MobileMoneyWaiting.run(
        amount: package.price,
        provider: selection['provider']!,
        phone: selection['phone']!,
        check: () => PackageService.subscriptionPaymentState(subscriptionId),
      );
      if (_isDisposed) return;
      switch (outcome.status) {
        case 'paid':
          await loadCampaigns();
          if (_isDisposed) return;
          _success(package);
        case 'failed':
          break; // motif déjà expliqué
        default:
          Get.snackbar(
            'package_subscription.payment_pending'.tr,
            'boost.validate_ussd'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppThemeSystem.warningColor,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          _pollPayment(subscriptionId, package);
      }
    } catch (e) {
      _error('boost.errors.generic'.trParams({'error': '$e'}));
    } finally {
      PaymentLoadingDialog.hide();
      isSubscribing.value = false;
    }
  }

  /// Carte bancaire (Payment Sheet Stripe native).
  Future<void> _buyWithCard(BoostPackage package, int productId) async {
    if (!StripeNativeService.isSupported) {
      _error('wallet.recharge.card_mobile_only'.tr);
      return;
    }

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'package_subscription.preparing_payment'.tr);

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
        _error('package_subscription.card_data_unavailable'.tr);
        return;
      }

      final ok = await StripeNativeService().payWithCard(
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );
      if (_isDisposed) return;

      if (!ok) {
        Get.snackbar(
          'wallet.webview.cancelled'.tr,
          'package_subscription.payment_not_finalized'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.warningColor,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      Get.snackbar(
        'package_subscription.payment_in_progress'.tr,
        'boost.payment_confirming'.tr,
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
            'package_subscription.payment_failed'.tr,
            'boost.payment_failed'.tr,
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
      'package_subscription.payment_pending'.tr,
      'boost.confirmation_pending'.tr,
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
        title: Text('boost.cancel_dialog.title'.tr),
        content: Text(
          'boost.cancel_dialog.message'.trParams({
            'product': campaign.productName,
            'views': '${campaign.impressionsRemaining}',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('boost.cancel_dialog.keep'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: AppThemeSystem.errorColor),
            child: Text('boost.cancel_dialog.stop'.tr),
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
          'boost.stopped_title'.tr,
          'boost.stopped_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        _error(res.message);
      }
    } catch (e) {
      _error('boost.errors.generic'.trParams({'error': '$e'}));
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
      'boost.activated_title'.tr,
      'boost.activated_message'.trParams({'reach': package.formattedReach}),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppDesign.success,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  void _error(String? message) {
    Get.snackbar(
      'boost.error'.tr,
      message?.isNotEmpty == true ? message! : 'boost.errors.launch_failed'.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.errorColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }
}
