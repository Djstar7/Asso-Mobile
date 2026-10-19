import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';
import '../../disputes/widgets/dispute_form_sheet.dart';

/// « Signaler un problème » sur une réservation : les motifs viennent du
/// back-office (FR/EN), le reste reprend la feuille des litiges de commande.
/// Renvoie true quand le litige est ouvert.
Future<bool> showImmoDisputeSheet(RealEstateReservation r) async {
  final reasons = await RealEstateService.disputeReasons(r.kind);
  if (reasons.isEmpty) {
    _snack('immo.reserve.error'.tr, 'immo.dispute.no_reasons'.tr);
    return false;
  }
  final form = await DisputeFormSheet.show(
    productName: r.title,
    title: 'immo.booking.report'.tr,
    reasons: [for (final reason in reasons) ('${reason.id}', reason.label)],
    notice: (r.isLand ? 'immo.dispute.notice_land' : 'immo.dispute.notice').tr,
  );
  if (form == null) return false;

  final res = await RealEstateService.openDispute(
    r.id,
    reasonId: int.parse(form.reason),
    description: form.description,
    photos: form.photos,
  );
  if (!res.success) {
    _snack('immo.reserve.error'.tr, res.message);
    return false;
  }
  _snack('immo.dispute.opened_title'.tr, 'immo.dispute.opened_message'.tr);

  return true;
}

/// Pièces complémentaires du locataire, ou réponse du bailleur.
Future<bool> showImmoDisputeEvidenceSheet(RealEstateReservation r) async {
  final form = await DisputeFormSheet.show(
    productName: r.title,
    withReason: false,
    title: (r.isPayee ? 'immo.dispute.respond' : 'immo.dispute.add_evidence').tr,
    notice: 'immo.dispute.evidence_notice'.tr,
  );
  if (form == null) return false;

  final res = await RealEstateService.addDisputeEvidence(r.id, message: form.description, photos: form.photos);
  if (!res.success) {
    _snack('immo.reserve.error'.tr, res.message);
    return false;
  }
  _snack('immo.dispute.evidence_sent_title'.tr, 'immo.dispute.evidence_sent_message'.tr);

  return true;
}

void _snack(String title, String message) {
  if (message.isEmpty) return;
  Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
}
