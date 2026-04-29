import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../../../data/providers/vendor_service.dart';
import '../../../core/utils/app_theme_system.dart';

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
  final shopDescription = ''.obs;
  final shopLogo = Rx<File?>(null);
  final shopLogoUrl = Rx<String?>(null); // Logo URL from backend
  final shopId = Rx<int?>(null);
  final selectedCategories = <String>[].obs;

  // Statistiques
  final totalOrders = 0.obs;
  final pendingOrders = 0.obs; // Commandes en attente
  final totalSales = 0.0.obs;
  final totalProducts = 0.obs;
  final rating = 0.0.obs;

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

  @override
  void onInit() {
    super.onInit();
    _loadVendorData();
  }

  /// Charge les données du vendeur depuis l'API
  void _loadVendorData() {
    _fetchVendorStats();
    // _fetchPendingOrdersCount() est maintenant inclus dans _fetchVendorStats via l'API dashboard
  }

  /// Récupère les statistiques du vendeur depuis l'API
  Future<void> _fetchVendorStats() async {
    if (_isDisposed) return;

    isLoading.value = true;

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

        // Parse shop info
        if (data['shop'] != null) {
          final shop = data['shop'];
          shopId.value = shop['id'];
          shopName.value = shop['name'] ?? '';
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

        print('========================================');
      } else {
        print('❌ VENDOR DASHBOARD: API failed or no data');
        print('  └─ Falling back to mock data');
        print('========================================');
        // Fallback to mock data if API fails
        _loadMockData();
      }
    } catch (e, stackTrace) {
      print('💥 VENDOR DASHBOARD: Exception caught!');
      print('  └─ Error: $e');
      print('  └─ Stack Trace:');
      print(stackTrace.toString().split('\n').take(5).join('\n'));
      print('  └─ Falling back to mock data');
      print('========================================');
      // Fallback to mock data on error
      _loadMockData();
    } finally {
      isLoading.value = false;
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
        final data = response.data!['data'];
        if (data is Map && data['data'] is List) {
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
    await checkVerificationStatus();
  }

  /// Navigate to add product with package check
  void navigateToAddProduct() {
    if (!hasPackage.value) {
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
    } else {
      // Navigate to AddProduct
      Get.toNamed('/add-product')?.then((_) {
        // Refresh dashboard after adding product
        refreshData();
      });
    }
  }

  /// Navigate to product management
  void navigateToProductManagement() {
    Get.toNamed('/product-management')?.then((_) {
      // Refresh dashboard after managing products
      refreshData();
    });
  }

  @override
  void onClose() {
    print('');
    print('========================================');
    print('📊 VENDOR DASHBOARD CONTROLLER: Closing');
    print('========================================');

    _isDisposed = true;
    super.onClose();

    print('  └─ Controller disposed safely');
    print('========================================');
  }
}
