import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import '../../../data/providers/boost_service.dart';
import '../../../data/providers/vendor_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/offline_store.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../data/services/offline_product_sync_service.dart';
import '../../addProduct/controllers/add_product_controller.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/location_label.dart';

class VendorDashboardController extends GetxController {
  // State management
  bool _isDisposed = false;
  bool get isSafe => !_isDisposed && isClosed == false;

  // Loading state
  final isLoading = true.obs;

  // Statut de vérification
  final verificationStatus = 'pending'.obs; // pending, approved, rejected
  final verificationMessage = 'Votre demande est en cours de vérification'.obs;

  // Données du vendeur
  final shopName = ''.obs;
  final shopLocation = ''.obs;
  final shopDescription = ''.obs;
  final shopLogo = Rx<XFile?>(null);
  final shopLogoUrl = Rx<String?>(null); // Logo URL from backend
  final shopId = Rx<int?>(null);
  final selectedCategories = <String>[].obs;

  // Statistiques
  final totalOrders = 0.obs;
  final pendingOrders = 0.obs; // Commandes en attente
  final totalSales = 0.0.obs;
  final totalProducts = 0.obs;
  final rating = 0.0.obs;
  // Audience (P8)
  final totalVisits = 0.obs;
  final totalProductViews = 0.obs;
  final visitsLast7Days = 0.obs;
  final totalContacts = 0.obs;

  // Package info
  final hasPackage = false.obs;
  final packageInfo = Rx<Map<String, dynamic>?>(null);
  final storageTotalMb = 0.0.obs;
  final storageUsedMb = 0.0.obs;
  final storageRemainingMb = 0.0.obs;
  final storagePercentageUsed = 0.0.obs;
  final packageExpiresAt = Rx<String?>(null);
  final daysRemaining = 0.obs;

  // Certification info
  final isCertified = false.obs;
  final certificationExpiresAt = Rx<String?>(null);
  final certificationDaysRemaining = Rx<int?>(null);

  // Asso Ads — campagnes de sponsoring en cours.
  final runningBoosts = 0.obs;
  final boostImpressionsServed = 0.obs;
  final boostImpressionsQuota = 0.obs;

  // ── Mode hors ligne ────────────────────────────────────────────────────

  /// Clé Hive de la dernière réponse du tableau de bord.
  static const dashboardSnapshotKey = 'vendor_dashboard';

  /// Joignabilité du serveur, pour le badge et les actions réservées au
  /// mode en ligne.
  RxBool get isOnline => Get.isRegistered<ConnectivityService>()
      ? ConnectivityService.to.isOnline
      : true.obs;

  /// Données du tableau de bord connues (réponse du serveur ou instantané) :
  /// sans elles, on ignore si le vendeur a un forfait.
  bool _hasDashboardData = false;

  /// Vrai quand l'écran affiche l'instantané local faute de réseau.
  final isShowingSnapshot = false.obs;

  OfflineProductSyncService? get offlineSync =>
      Get.isRegistered<OfflineProductSyncService>()
          ? OfflineProductSyncService.to
          : null;

  final List<Worker> _offlineWorkers = [];

  /// Enveloppe une action qui demande le réseau : hors ligne, seul l'ajout
  /// de produit reste ouvert, le reste l'explique au lieu d'ouvrir un écran
  /// vide.
  VoidCallback onlineOnly(FutureOr<void> Function() action) {
    return () {
      if (ConnectivityService.isOffline) {
        Get.snackbar(
          'Hors ligne',
          'Cette section demande une connexion. Hors ligne, vous pouvez '
              'ajouter des produits : ils seront publiés au retour du réseau.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        );
        return;
      }
      action();
    };
  }

  @override
  void onInit() {
    super.onInit();

    final sync = offlineSync;
    if (sync != null) {
      sync.reload();
      // Produits hors ligne publiés : compteurs et stockage ont changé.
      _offlineWorkers.add(ever(sync.syncedRevision, (_) => refreshData()));
    }
    if (Get.isRegistered<ConnectivityService>()) {
      // Retour du réseau : l'instantané affiché laisse place au serveur.
      _offlineWorkers.add(ever<bool>(ConnectivityService.to.isOnline, (online) {
        if (online && isShowingSnapshot.value) refreshData();
      }));
    }

    if (Get.isRegistered<CurrencyService>()) {
      // Écoute d'un service permanent : sans `dispose`, l'écouteur gardait
      // ce contrôleur en mémoire bien après la fermeture de l'écran.
      _currencyWorker = ever(
        CurrencyService.to.userCurrencyRx,
        (_) => currencyRevision.value++,
      );
    }

    _loadVendorData();
  }

  /// Charge les données du vendeur depuis l'API
  void _loadVendorData() {
    _fetchVendorStats();
    // _fetchPendingOrdersCount() est maintenant inclus dans _fetchVendorStats via l'API dashboard
    _fetchBoosts();
  }

  /// Asso Ads — portée délivrée des campagnes en cours, pour que le vendeur
  /// voie depuis le tableau de bord où en est ce qu'il a payé.
  ///
  /// Silencieux en cas d'échec : le sponsoring est une option, son absence ne
  /// doit pas dégrader le reste du tableau de bord.
  Future<void> _fetchBoosts() async {
    if (_isDisposed || ConnectivityService.isOffline) return;

    try {
      final response = await BoostService.getCampaigns(limit: 50);
      if (_isDisposed || !response.success) return;

      final running = ((response.data?['boosts'] as List?) ?? const [])
          .whereType<Map>()
          .where((boost) => boost['is_running'] == true)
          .toList();

      runningBoosts.value = running.length;
      boostImpressionsServed.value = running.fold<int>(
        0,
        (total, boost) => total + _asInt(boost['impressions_served']),
      );
      boostImpressionsQuota.value = running.fold<int>(
        0,
        (total, boost) => total + _asInt(boost['impressions_quota']),
      );
    } catch (_) {
      // Sans incidence pour le vendeur.
    }
  }

  int _asInt(dynamic value) =>
      value is int ? value : int.tryParse('${value ?? ''}') ?? 0;

  /// Récupère les statistiques du vendeur depuis l'API
  Future<void> _fetchVendorStats() async {
    if (_isDisposed) return;

    // Hors ligne : on affiche tout de suite le dernier état connu, sans
    // attendre l'échec d'un appel voué à expirer.
    if (ConnectivityService.isOffline) {
      if (!_applySnapshot() && !_hasDashboardData) _loadOfflineIdentity();
      isLoading.value = false;
      return;
    }

    // Un rafraîchissement ne repasse pas par le squelette de chargement si
    // des données sont déjà à l'écran.
    if (!_hasDashboardData) isLoading.value = true;

    print('');
    print('========================================');
    print('📊 VENDOR DASHBOARD: FETCH STATS START');
    print('========================================');

    try {
      print('🌐 VENDOR DASHBOARD: Calling API...');
      final response = await VendorService.getVendorDashboard();

      if (_isDisposed) return;

      print('📥 VENDOR DASHBOARD: API Response received');
      print('  └─ Success: ${response.success}');
      print('  └─ Status Code: ${response.statusCode}');
      print('  └─ Message: ${response.message}');

      if (response.success && response.data != null) {
        print('✅ VENDOR DASHBOARD: Parsing response data...');
        final data = response.data!['data'] ?? response.data!;
        _applyDashboard(data);
        isShowingSnapshot.value = false;
        OfflineStore.saveSnapshot(dashboardSnapshotKey, data);
        // Prépare l'ajout de produit hors ligne (catégories, boutique).
        AddProductController.warmOfflineCache();
        print('========================================');
      } else {
        print('❌ VENDOR DASHBOARD: API failed or no data');
        print('========================================');
        _fallbackAfterFailure();
      }
    } catch (e, stackTrace) {
      print('💥 VENDOR DASHBOARD: Exception caught!');
      print('  └─ Error: $e');
      print('  └─ Stack Trace:');
      print(stackTrace.toString().split('\n').take(5).join('\n'));
      print('========================================');
      _fallbackAfterFailure();
    } finally {
      isLoading.value = false;
    }
  }

  /// Échec du serveur : dernier état connu, sinon l'ancien repli.
  void _fallbackAfterFailure() {
    if (_applySnapshot() || _hasDashboardData) return;
    if (ConnectivityService.isOffline) {
      _loadOfflineIdentity();
    } else {
      _loadMockData();
    }
  }

  /// Applique l'instantané Hive du tableau de bord. Faux s'il n'y en a pas.
  bool _applySnapshot() {
    final data = OfflineStore.readSnapshot(dashboardSnapshotKey);
    if (data is! Map) return false;
    _applyDashboard(Map<String, dynamic>.from(data));
    isShowingSnapshot.value = true;
    return true;
  }

  /// Premier passage hors ligne, sans rien en mémoire : pas de fausse
  /// boutique, juste de quoi ajouter un produit.
  void _loadOfflineIdentity() {
    shopName.value = 'Ma boutique';
    isShowingSnapshot.value = true;
  }

  /// Remplit l'écran à partir d'une réponse du tableau de bord (serveur ou
  /// instantané local).
  void _applyDashboard(Map<String, dynamic> data) {
    _hasDashboardData = true;
    // Parse shop info
    if (data['shop'] != null) {
      final shop = data['shop'];
      shopId.value = shop['id'];
      shopName.value = shop['name'] ?? '';
      shopLocation.value =
          LocationLabel.fromApi(Map<String, dynamic>.from(shop)) ?? '';
      shopDescription.value = shop['description'] ?? '';
      shopLogoUrl.value = shop['logo_url'] ?? shop['logo'];
      print('  └─ Shop ID: ${shopId.value}');
      print('  └─ Shop Name: ${shopName.value}');
      print('  └─ Shop Description: ${shopDescription.value.isNotEmpty ? "YES" : "NO"}');
      print('  └─ Shop Logo URL: ${shopLogoUrl.value ?? "NONE"}');
    } else {
      print('  └─ ⚠️ No shop data in response');
    }

    // Parse stats
    if (data['stats'] != null) {
      final stats = data['stats'];
      totalOrders.value = stats['total_orders'] ?? 0;
      pendingOrders.value = stats['pending_orders'] ?? 0;
      totalSales.value = (stats['total_sales'] ?? 0).toDouble();
      totalProducts.value = stats['total_products'] ?? 0;
      rating.value = (stats['rating'] ?? 0).toDouble();
      totalVisits.value = (stats['total_visits'] as num?)?.toInt() ?? 0;
      totalProductViews.value = (stats['total_product_views'] as num?)?.toInt() ?? 0;
      visitsLast7Days.value = (stats['visits_last_7_days'] as num?)?.toInt() ?? 0;
      totalContacts.value = (stats['total_contacts'] as num?)?.toInt() ?? 0;
      print('  └─ Total Orders: ${totalOrders.value}');
      print('  └─ Pending Orders: ${pendingOrders.value}');
      print('  └─ Total Sales: ${totalSales.value}');
      print('  └─ Total Products: ${totalProducts.value}');
      print('  └─ Rating: ${rating.value}');
    } else {
      print('  └─ ⚠️ No stats data in response');
    }

    // Parse verification status
    if (data['verification'] != null) {
      final verification = data['verification'];
      verificationStatus.value = verification['status'] ?? 'pending';
      verificationMessage.value = verification['message'] ?? 'Votre demande est en cours de vérification';
      print('  └─ Verification Status: ${verificationStatus.value}');
      print('  └─ Verification Message: ${verificationMessage.value}');
    } else {
      print('  └─ ⚠️ No verification data in response');
    }

    // Parse certification info
    if (data['certification'] != null) {
      final certification = data['certification'];
      isCertified.value = certification['is_certified'] ?? false;
      certificationExpiresAt.value = certification['certification_expires_at'];
      certificationDaysRemaining.value = certification['days_until_expiry'];
      print('  └─ Is Certified: ${isCertified.value}');
      if (isCertified.value) {
        print('  └─ Certification Days Remaining: ${certificationDaysRemaining.value}');
      }
    } else {
      print('  └─ ⚠️ No certification data in response');
    }

    // Parse package info
    if (data['package'] != null) {
      final package = data['package'];
      hasPackage.value = package['has_package'] ?? false;
      print('  └─ Has Package: ${hasPackage.value}');

      if (hasPackage.value && package['vendor_package'] != null) {
        packageInfo.value = package['vendor_package'];
        storageTotalMb.value = (package['vendor_package']['storage_total_mb'] ?? 0).toDouble();
        storageUsedMb.value = (package['vendor_package']['storage_used_mb'] ?? 0).toDouble();
        storageRemainingMb.value = (package['vendor_package']['storage_remaining_mb'] ?? 0).toDouble();
        storagePercentageUsed.value = (package['vendor_package']['storage_percentage_used'] ?? 0).toDouble();
        packageExpiresAt.value = package['vendor_package']['expires_at'];

        // Convert days_remaining to int (backend might return double)
        final daysRemainingValue = package['vendor_package']['days_remaining'] ?? 0;
        daysRemaining.value = daysRemainingValue is int
            ? daysRemainingValue
            : (daysRemainingValue as num).toInt();

        print('  └─ Storage Used: ${storageUsedMb.value} MB');
        print('  └─ Storage Total: ${storageTotalMb.value} MB');
        print('  └─ Storage Percentage: ${storagePercentageUsed.value}%');
        print('  └─ Days Remaining: ${daysRemaining.value}');
        print('  └─ Package Name: ${package['vendor_package']['package']?['name'] ?? "N/A"}');
        print('  └─ Package Price: ${package['vendor_package']['package']?['formatted_price'] ?? "N/A"}');
      }
    } else {
      print('  └─ ⚠️ No package data in response');
    }
  }

  /// Récupère le nombre de commandes en attente
  Future<void> _fetchPendingOrdersCount() async {
    if (_isDisposed) return;

    print('');
    print('========================================');
    print('📦 VENDOR DASHBOARD: FETCH PENDING ORDERS COUNT');
    print('========================================');

    try {
      print('🌐 VENDOR DASHBOARD: Calling pending orders API...');
      final response = await VendorService.getVendorOrders(status: 'pending', page: 1);

      if (_isDisposed) return;

      print('📥 VENDOR DASHBOARD: Pending orders API response received');
      print('  └─ Success: ${response.success}');

      if (response.success && response.data != null) {
        // Format actuel de l'API : { orders: [...], pagination: { total } }.
        final pagination = response.data!['pagination'];
        final data = response.data!['orders'] ?? response.data!['data'];
        if (pagination is Map && pagination['total'] is num) {
          pendingOrders.value = (pagination['total'] as num).toInt();
        } else if (data is Map && data['data'] is List) {
          final orders = data['data'] as List;
          pendingOrders.value = orders.length;
          print('  └─ Pending Orders Count: ${pendingOrders.value}');
        } else if (data is List) {
          pendingOrders.value = data.length;
          print('  └─ Pending Orders Count: ${pendingOrders.value}');
        }
      } else {
        print('  └─ ⚠️ Failed to fetch pending orders');
      }
      print('========================================');
    } catch (e) {
      print('💥 VENDOR DASHBOARD: Exception fetching pending orders!');
      print('  └─ Error: $e');
      print('========================================');
      // Ne pas bloquer si cette requête échoue
    }
  }

  /// Données fictives de secours
  void _loadMockData() {
    shopName.value = 'Boutique Kira';
    shopDescription.value = 'Vente d\'articles de mode et électronique';
    selectedCategories.value = ['Électronique', 'Mode & Vêtements'];
    totalOrders.value = 0;
    totalSales.value = 0.0;
    totalProducts.value = 0;
    rating.value = 0.0;
  }

  /// Vérifie le statut de vérification (appelé via l'API)
  Future<void> checkVerificationStatus() async {
    await _fetchVendorStats();
  }

  /// Rafraîchit les données
  Future<void> refreshData() async {
    // checkVerificationStatus appelle déjà _fetchVendorStats qui récupère
    // toutes les données incluant pending_orders
    await Future.wait([checkVerificationStatus(), _fetchBoosts()]);
  }

  /// Navigate to add product with package check
  void navigateToAddProduct() {
    if (!hasPackage.value) {
      if (!ConnectivityService.isOffline) {
        // Show dialog explaining they need a package
        Get.dialog(
          AlertDialog(
            title: Text('Package requis'),
            content: Text(
              'Vous devez souscrire à un package de stockage pour ajouter des produits.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed('/package-subscription');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                ),
                child: Text(
                  'Voir les packages',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
        return;
      }
      // Hors ligne, la souscription est impossible. Sans tableau de bord
      // connu, on ignore s'il y a un forfait : le serveur tranchera à l'envoi.
      if (_hasDashboardData) {
        Get.snackbar(
          'Forfait requis',
          'Un forfait de stockage est nécessaire pour ajouter des produits. '
              'Reconnectez-vous pour en souscrire un.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }
    }

    Get.toNamed('/add-product')?.then((_) {
      // Refresh dashboard after adding product
      refreshData();
    });
  }

  /// Écran des statistiques détaillées (visites, consultations, ventes, CA)
  void navigateToStatistics() => onlineOnly(() {
        Get.toNamed('/shop-statistics')?.then((_) => refreshData());
      })();

  /// Navigate to product management
  void navigateToProductManagement() => onlineOnly(_openProductManagement)();

  void _openProductManagement() {
    Get.toNamed('/product-management')?.then((_) {
      // Refresh dashboard after managing products
      refreshData();
    });
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format price with user's currency
  /// Sentinelle réactive de la devise d'affichage : les montants sont
  /// convertis au rendu, changer de devise doit redessiner sans rappeler l'API.
  final currencyRevision = 0.obs;
  Worker? _currencyWorker;

  String formatPrice(double priceInXOF, {bool showSymbol = true}) {
    // Lecture volontaire : abonne les Obx au changement de devise.
    currencyRevision.value;
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: showSymbol);
  }

  /// Get currency symbol
  String get currencySymbol {
    if (!Get.isRegistered<CurrencyService>()) {
      return 'FCFA';
    }
    return CurrencyService.to.currencySymbol;
  }

  @override
  void onClose() {
    print('');
    print('========================================');
    print('📊 VENDOR DASHBOARD CONTROLLER: Closing');
    print('========================================');

    _isDisposed = true;
    _currencyWorker?.dispose();
    for (final worker in _offlineWorkers) {
      worker.dispose();
    }
    super.onClose();

    print('  └─ Controller disposed safely');
    print('========================================');
  }
}
