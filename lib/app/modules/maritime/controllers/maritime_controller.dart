import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../data/models/maritime.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/maritime_service.dart';
import '../../../routes/app_pages.dart';

/// Rubrique Maritime de Diaspo Exchange : départs à venir et envois de
/// l'utilisateur.
class MaritimeController extends GetxController {
  final MaritimeService _service = Get.find<MaritimeService>();

  /// 0 = Départs, 1 = Mes envois.
  final selectedTab = 0.obs;

  final departures = <MaritimeDeparture>[].obs;
  final myBookings = <MaritimeBooking>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final isLoadingBookings = false.obs;
  final error = RxnString();

  int _page = 1;
  int _lastPage = 1;
  bool _loaded = false;

  /// Chargé à la première ouverture de la rubrique, pas avant.
  void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    loadDepartures();
  }

  Future<void> loadDepartures() async {
    isLoading.value = true;
    error.value = null;
    try {
      final result = await _service.getDepartures();
      departures.assignAll(result.items);
      _page = 1;
      _lastPage = result.lastPage;
    } catch (e) {
      error.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || _page >= _lastPage) return;
    isLoadingMore.value = true;
    try {
      final result = await _service.getDepartures(page: _page + 1);
      departures.addAll(result.items);
      _page++;
      _lastPage = result.lastPage;
    } catch (_) {
      // On réessaiera au prochain défilement.
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMyBookings() async {
    isLoadingBookings.value = true;
    try {
      myBookings.assignAll(await _service.getMyBookings());
    } catch (e) {
      error.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoadingBookings.value = false;
    }
  }

  void changeTab(int index) {
    selectedTab.value = index;
    if (index == 1) loadMyBookings();
  }

  Future<void> refreshAll() async {
    await (selectedTab.value == 0 ? loadDepartures() : loadMyBookings());
  }

  void openDeparture(MaritimeDeparture departure) {
    if (!departure.isBookable) {
      Get.snackbar(
        'maritime.trip_impossible_title'.tr,
        'maritime.trip_impossible'.tr,
        backgroundColor: AppDesign.accent,
        colorText: Colors.white,
      );
      return;
    }
    Get.toNamed(Routes.MARITIME_BOOKING, arguments: {'departure': departure});
  }

  Future<void> cancelBooking(MaritimeBooking booking) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('maritime.cancel_title'.tr),
        content: Text('maritime.cancel_message'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('maritime.keep'.tr)),
          ElevatedButton(onPressed: () => Get.back(result: true), child: Text('maritime.cancel_confirm'.tr)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.cancel(booking.id);
      Get.snackbar('maritime.cancelled_title'.tr, 'maritime.cancelled_message'.tr,
          backgroundColor: AppDesign.success, colorText: Colors.white);
      loadMyBookings();
    } catch (e) {
      Get.snackbar('maritime.error'.tr, e.toString().replaceAll('Exception: ', ''),
          backgroundColor: AppDesign.danger, colorText: Colors.white);
    }
  }

  /// Montant exprimé dans [currency], affiché dans la devise de l'utilisateur.
  String formatAmount(double amount, String currency) =>
      CurrencyService.formatFromCurrency(amount, currency);

  String formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
