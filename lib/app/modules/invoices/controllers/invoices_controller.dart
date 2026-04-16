import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/values/constants.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/providers/api_provider.dart';

class InvoicesController extends GetxController {
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final invoices = <InvoiceModel>[].obs;

  final currentPage = 1.obs;
  final lastPage = 1.obs;
  final total = 0.obs;
  final perPage = 20;

  final selectedType = 'all'.obs;
  final types = ['all', 'package', 'wallet'];

  @override
  void onInit() {
    super.onInit();
    developer.log('========== INVOICES CONTROLLER INIT ==========', name: 'InvoicesController');
    fetchInvoices();
  }

  /// Fetch invoices from API
  Future<void> fetchInvoices({bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 1;
      invoices.clear();
    }

    if (currentPage.value == 1) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    developer.log(
      '========== FETCH INVOICES ==========',
      name: 'InvoicesController',
      error: 'Page: ${currentPage.value}, Type: ${selectedType.value}',
    );

    try {
      final response = await ApiProvider.get(
        AppConstants.invoicesUrl,
        queryParams: {
          'type': selectedType.value,
          'page': currentPage.value.toString(),
          'per_page': perPage.toString(),
        },
      );

      developer.log(
        'Invoices fetch response',
        name: 'InvoicesController',
        error: 'Success: ${response.success}',
      );

      if (response.success && response.data != null) {
        final invoicesData = response.data!['invoices'] as Map<String, dynamic>;
        final invoicesList = (invoicesData['data'] as List)
            .map((json) => InvoiceModel.fromJson(json))
            .toList();

        if (refresh) {
          invoices.value = invoicesList;
        } else {
          invoices.addAll(invoicesList);
        }

        currentPage.value = invoicesData['current_page'] as int;
        lastPage.value = invoicesData['last_page'] as int;
        total.value = invoicesData['total'] as int;

        developer.log(
          'Invoices loaded',
          name: 'InvoicesController',
          error: 'Total: ${total.value}, Page: ${currentPage.value}/$lastPage.value',
        );
      } else {
        Get.snackbar(
          'Erreur',
          response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching invoices',
        name: 'InvoicesController',
        error: e,
        stackTrace: stackTrace,
      );
      Get.snackbar(
        'Erreur',
        'Impossible de charger les factures',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  /// Load more invoices (pagination)
  Future<void> loadMore() async {
    if (isLoadingMore.value || currentPage.value >= lastPage.value) {
      return;
    }

    currentPage.value++;
    await fetchInvoices();
  }

  /// Change filter type
  void changeType(String type) {
    if (selectedType.value == type) return;

    developer.log(
      'Changing invoice type filter',
      name: 'InvoicesController',
      error: 'From: ${selectedType.value}, To: $type',
    );

    selectedType.value = type;
    fetchInvoices(refresh: true);
  }

  /// Refresh invoices
  @override
  Future<void> refresh() async {
    await fetchInvoices(refresh: true);
  }

  /// Download or open invoice
  Future<void> downloadInvoice(InvoiceModel invoice) async {
    final url = invoice.pdfUrl ?? invoice.downloadUrl;

    if (url == null) {
      Get.snackbar(
        'Erreur',
        'URL de t�l�chargement non disponible',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    developer.log(
      'Downloading invoice',
      name: 'InvoicesController',
      error: 'URL: $url',
    );

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'Erreur',
          'Impossible d\'ouvrir le lien',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      developer.log(
        'Error downloading invoice',
        name: 'InvoicesController',
        error: e,
      );
      Get.snackbar(
        'Erreur',
        'Impossible de t�l�charger la facture',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String getTypeLabel(String type) {
    switch (type) {
      case 'all':
        return 'Toutes';
      case 'package':
        return 'Packages';
      case 'wallet':
        return 'Recharges';
      default:
        return type;
    }
  }
}
