import 'package:asso/app/core/utils/app_feedback.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/values/constants.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/authenticated_download.dart';
import '../../../data/providers/private_exports.dart';
import '../../../core/utils/session_scope.dart';
import '../../../core/utils/app_design.dart';

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
    developer.log(
      '========== INVOICES CONTROLLER INIT ==========',
      name: 'InvoicesController',
    );
    fetchInvoices();
  }

  /// Fetch invoices from API
  Future<void> fetchInvoices({bool refresh = false}) async {
    final session = SessionScope.current;
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

      if (!SessionScope.isCurrent(session)) return;
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
          error:
              'Total: ${total.value}, Page: ${currentPage.value}/$lastPage.value',
        );
      } else {
        AppFeedback.show(
          'invoices.error'.tr,
          response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
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
      AppFeedback.show(
        'invoices.error'.tr,
        'invoices.load_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
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

  /// Facture en cours de téléchargement (affiche une roue sur sa carte).
  final downloadingNumber = RxnString();

  /// Télécharge le PDF de la facture AVEC la session de l'utilisateur, puis
  /// ouvre le partage système (enregistrer dans Fichiers, ouvrir, envoyer…).
  /// Ouvrir le lien dans le navigateur échouait : la route exige d'être connecté.
  Future<void> downloadInvoice(InvoiceModel invoice) async {
    final session = SessionScope.current;
    final url = invoice.pdfUrl;
    if (url == null) {
      _error('invoices.download_url_unavailable'.tr);
      return;
    }
    if (downloadingNumber.value != null) return;
    downloadingNumber.value = invoice.invoiceNumber;

    try {
      final uri = Uri.tryParse(url);
      final response = uri == null
          ? null
          : await AuthenticatedDownload.get(uri, accept: 'application/pdf');
      if (!SessionScope.isCurrent(session)) return;
      if (response == null) {
        _error('invoices.download_error'.tr);
        return;
      }
      final isPdf = (response.headers['content-type'] ?? '').contains('pdf');
      if (response.statusCode != 200 || !isPdf) {
        developer.log(
          'Invoice download failed',
          name: 'InvoicesController',
          error: 'Status: ${response.statusCode}',
        );
        _error('invoices.download_error'.tr);
        return;
      }

      final file = await PrivateExports.write(
        'facture_${invoice.invoiceNumber}.pdf',
        response.bodyBytes,
        session,
      );
      if (file == null || !SessionScope.isCurrent(session)) return;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'package_subscription.invoice.share_subject'.tr,
        text: 'package_subscription.invoice.share_text'.tr,
      );
    } catch (e) {
      developer.log(
        'Error downloading invoice',
        name: 'InvoicesController',
        error: e,
      );
      _error('invoices.download_error'.tr);
    } finally {
      if (SessionScope.isCurrent(session)) downloadingNumber.value = null;
    }
  }

  void _error(String message) {
    AppFeedback.show(
      'invoices.error'.tr,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppDesign.danger,
      colorText: Colors.white,
    );
  }

  String getTypeLabel(String type) {
    switch (type) {
      case 'all':
        return 'invoices.filter_all'.tr;
      case 'package':
        return 'invoices.filter_packages'.tr;
      case 'wallet':
        return 'invoices.filter_recharges'.tr;
      default:
        return type;
    }
  }
}
