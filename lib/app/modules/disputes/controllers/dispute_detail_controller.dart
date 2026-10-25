import 'package:asso/app/core/utils/app_feedback.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_design.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/dispute_service.dart';
import '../../../routes/app_pages.dart';
import '../models/dispute_models.dart';
import '../widgets/dispute_form_sheet.dart';
import '../widgets/dispute_shipment_payment.dart';

/// Détail d'un litige. Arguments : `{'id': int, 'role': 'client' | 'vendor',
/// 'pay': bool}` — `pay` ouvre directement le paiement de la course (depuis la
/// notification « paiement de livraison requis »).
class DisputeDetailController extends GetxController {
  late final int disputeId;
  late final bool isVendor;
  bool _payOnOpen = false;
  Timer? _refresh;
  bool _loading = false;

  final dispute = Rxn<Dispute>();
  final isLoading = true.obs;
  final isBusy = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    final args = Map<String, dynamic>.from(Get.arguments as Map? ?? const {});
    disputeId = int.tryParse('${args['id']}') ?? 0;
    isVendor = args['role'] == 'vendor';
    _payOnOpen = args['pay'] == true;
    load();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isBusy.value && (dispute.value?.isOpen ?? false)) load();
    });
  }

  @override
  void onClose() {
    _refresh?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      isLoading.value = dispute.value == null;
      error.value = null;
      final response = isVendor
          ? await DisputeService.vendorDispute(disputeId)
          : await DisputeService.clientDispute(disputeId);
      if (response.success && response.data?['dispute'] is Map) {
        dispute.value = Dispute.fromMap(
          Map<String, dynamic>.from(response.data!['dispute']),
        );
      } else {
        error.value = response.message;
      }
      isLoading.value = false;

      if (_payOnOpen &&
          isVendor &&
          dispute.value?.action('pay_shipment') == true) {
        _payOnOpen = false;
        await payShipment();
      }
    } finally {
      _loading = false;
    }
  }

  String formatPrice(double amount) => CurrencyService.formatFromPivot(amount);

  // ── Client ──────────────────────────────────────────────────────────────

  Future<void> confirmReplacement() =>
      _run(() => DisputeService.confirmReplacement(disputeId));

  Future<void> reportReplacement() async {
    final current = dispute.value;
    if (current == null) return;
    final form = await DisputeFormSheet.show(
      productName: current.productName,
      title: 'disputes.form.replacement_title'.tr,
    );
    if (form == null) return;
    await _run(
      () => DisputeService.reportReplacement(
        disputeId,
        description: form.description,
        reason: form.reason,
        photos: form.photos,
      ),
    );
  }

  void openSimilarProducts() =>
      Get.toNamed(Routes.DISPUTE_SIMILAR, arguments: {'id': disputeId});

  // ── Vendeur ─────────────────────────────────────────────────────────────

  Future<void> contestReceipt(Map<String, dynamic> receipt) async {
    final current = dispute.value;
    if (current == null || isBusy.value) return;
    final form = await DisputeFormSheet.show(
      productName: current.productName,
      withReason: false,
      title: 'disputes.receipt.contest'.tr,
      notice: 'disputes.receipt.proof_required'.tr,
    );
    if (form == null || form.photos.isEmpty) return;
    isBusy.value = true;
    try {
      final response = await DisputeService.sendEvidence(
        disputeId,
        note: form.description,
        files: form.photos,
      );
      if (!response.success) {
        _snack(response.message, error: true);
        return;
      }
      final payload = Map<String, dynamic>.from(
        response.data?['dispute'] as Map? ?? const {},
      );
      final events = (payload['events'] as List? ?? const []).whereType<Map>();
      final pieces = events
          .where((e) => e['type'] == 'evidence' && e['actor_type'] == 'vendor')
          .expand(
            (e) => (e['attachments'] as List? ?? const []).whereType<Map>(),
          )
          .toList();
      if (pieces.isEmpty) return;
      final attachmentId = pieces
          .map((p) => int.tryParse('${p['id']}') ?? 0)
          .reduce((a, b) => a > b ? a : b);
      final result = await DisputeService.contestReceipt(
        int.parse('${receipt['id']}'),
        attachmentId: attachmentId,
        note: form.description,
      );
      _snack(result.message, error: !result.success);
    } finally {
      isBusy.value = false;
      await load();
    }
  }

  Future<void> sendEvidence() async {
    final current = dispute.value;
    if (current == null) return;
    final form = await DisputeFormSheet.show(
      productName: current.productName,
      withReason: false,
      title: 'disputes.vendor.evidence_title'.tr,
    );
    if (form == null) return;
    await _run(
      () => DisputeService.sendEvidence(
        disputeId,
        note: form.description,
        files: form.photos,
      ),
    );
  }

  Future<void> replace() async {
    if (!await _confirm(
      (dispute.value?.internationalExport == true
              ? 'disputes.vendor.international_replace_confirm'
              : 'disputes.vendor.replace_confirm')
          .tr,
    )) {
      return;
    }
    final ok = await _run(() => DisputeService.replace(disputeId));
    if (ok) await payShipment();
  }

  Future<void> organizeReturn() async {
    if (!await _confirm('disputes.vendor.return_confirm'.tr)) return;
    final ok = await _run(() => DisputeService.organizeReturn(disputeId));
    if (ok) await payShipment();
  }

  Future<void> payShipment() async {
    final shipmentId = dispute.value?.pendingShipmentId;
    if (shipmentId == null || isBusy.value) return;
    isBusy.value = true;
    try {
      await DisputeShipmentPayment.pay(
        shipmentId: shipmentId,
        isReturn:
            dispute.value?.status == 'return' ||
            dispute.value?.collection?.id == shipmentId,
      );
    } finally {
      isBusy.value = false;
      await load();
    }
  }

  Future<void> markShipped() =>
      _shipmentStep(dispute.value?.replacement?.id, 'shipped');

  Future<void> prepareReplacement() async {
    if (!await _confirm('disputes.vendor.prepare_confirm'.tr)) return;
    final ok = await _run(() => DisputeService.replace(disputeId));
    if (ok) await payShipment();
  }

  Future<void> confirmReturnReceived() async {
    final current = dispute.value;
    final shipmentId = current?.receiptShipmentId;
    if (current == null || shipmentId == null) return;
    final message = current.isExchangeReceipt
        ? 'disputes.vendor.received_exchange_confirm'
        : 'disputes.vendor.received_confirm';
    if (!await _confirm(message.tr)) return;
    await _shipmentStep(shipmentId, 'confirmed');
  }

  /// Appelle le livreur de la course.
  Future<void> callCourier(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));

  Future<void> _shipmentStep(int? shipmentId, String step) async {
    if (shipmentId == null) return;
    await _run(() => DisputeService.shipmentStep(shipmentId, step));
  }

  // ── Outils ──────────────────────────────────────────────────────────────

  Future<bool> _run(Future<ApiResponse> Function() action) async {
    if (isBusy.value) return false;
    isBusy.value = true;
    try {
      final response = await action();
      if (!response.success) {
        _snack(response.message, error: true);
        return false;
      }
      if (response.data?['dispute'] is Map) {
        dispute.value = Dispute.fromMap(
          Map<String, dynamic>.from(response.data!['dispute']),
        );
      } else {
        await load();
      }
      if (response.message.isNotEmpty) _snack(response.message);
      return true;
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool> _confirm(String message) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('common.cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('common.confirm'.tr),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(String message, {bool error = false}) => AppFeedback.show(
    error ? 'my_order.errors.title'.tr : 'disputes.title'.tr,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: error ? AppDesign.danger : AppDesign.success,
    colorText: Colors.white,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
  );
}
