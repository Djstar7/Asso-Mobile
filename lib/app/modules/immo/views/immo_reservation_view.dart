import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../widgets/immo_fee_details.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';
import '../immo_nav.dart';
import '../widgets/immo_dispute_sheet.dart';
import '../widgets/immo_widgets.dart';

/// Suivi d'une réservation : coordonnées débloquées, compte à rebours de la
/// visite, « Le logement est conforme », signalement d'un problème, contrat
/// et facture. Le bailleur y voit le dossier du locataire et répond aux
/// litiges ([standalone] : ouverte hors de la rubrique, avec sa barre).
class ImmoReservationView extends StatefulWidget {
  const ImmoReservationView({super.key, required this.reservationId, this.standalone = false});

  final int reservationId;
  final bool standalone;

  @override
  State<ImmoReservationView> createState() => _ImmoReservationViewState();
}

class _ImmoReservationViewState extends State<ImmoReservationView> {
  RealEstateReservation? _r;
  bool _loading = true;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await RealEstateService.reservation(widget.reservationId);
    if (!mounted) return;
    setState(() {
      _r = r;
      _loading = false;
    });
  }

  Future<void> _confirm() async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('immo.booking.confirm_title'.tr),
      content: Text((_r!.isLand ? 'immo.booking.confirm_body_land' : 'immo.booking.confirm_body').tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('common.cancel'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('immo.booking.confirm_yes'.tr)),
      ],
    ));
    if (ok != true) return;
    setState(() => _busy = true);
    final res = await RealEstateService.confirmReservation(_r!.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      _load();
      Get.snackbar('immo.booking.confirmed_title'.tr, 'immo.booking.confirmed_message'.tr, snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('immo.reserve.error'.tr, res.message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _document(String kind) async {
    if (kIsWeb) return;
    setState(() => _busy = true);
    final file = await RealEstateService.downloadDocument(_r!, kind);
    if (!mounted) return;
    setState(() => _busy = false);
    if (file == null) {
      Get.snackbar('immo.reserve.error'.tr, 'immo.booking.document_error'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await Share.shareXFiles([XFile(file.path)], subject: '${_r!.reference} - ${'immo.booking.$kind'.tr}');
  }

  String _remaining(DateTime deadline) {
    final left = deadline.difference(DateTime.now());
    if (left.isNegative) return 'immo.booking.window_over'.tr;
    if (left.inDays >= 1) return 'immo.booking.days_left'.trParams({'days': '${left.inDays}', 'hours': '${left.inHours % 24}'});

    return 'immo.booking.hours_left'.trParams({'hours': '${left.inHours}', 'minutes': '${left.inMinutes % 60}'});
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final appBar = widget.standalone ? AppBar(leading: const AppBackButton(), title: Text('immo.booking.title'.tr)) : null;
    if (_loading) {
      return Scaffold(backgroundColor: context.ds.canvas, appBar: appBar, body: const Center(child: CircularProgressIndicator()));
    }
    if (r == null) {
      return Scaffold(
        backgroundColor: context.ds.canvas,
        appBar: appBar,
        body: AppEmptyState(icon: Icons.receipt_long_outlined, title: 'immo.booking.not_found'.tr),
      );
    }
    final gutter = context.ds.gutter;
    final contact = r.hasVisibleContact ? r.contact : null;
    final (Color tone, Color bg, String statusLabel) = switch (r.status) {
      'paid' => (AppDesign.warningText, AppDesign.warningSubtle, 'immo.booking.status_paid'.tr),
      'released' || 'confirmed' => (AppDesign.successText, AppDesign.successSubtle, 'immo.booking.status_released'.tr),
      'disputed' => (AppDesign.dangerText, AppDesign.dangerSubtle, 'immo.booking.status_disputed'.tr),
      'refunded' => (AppDesign.infoText, AppDesign.infoSubtle, 'immo.booking.status_refunded'.tr),
      _ => (context.ds.textSecondary, context.ds.surfaceMuted, 'immo.booking.status_pending'.tr),
    };

    return Scaffold(
      backgroundColor: context.ds.canvas,
      appBar: appBar,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, AppDesign.space4, gutter, AppDesign.space8),
          children: [
            Text(r.title, style: context.textStyle(FontSizeType.h6, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
            Text('${r.reference}${r.unitLabel == null ? '' : ' · ${r.unitLabel}'}',
                style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
            const SizedBox(height: AppDesign.space3),
            AppCard(
              color: bg,
              showBorder: false,
              padding: const EdgeInsets.all(AppDesign.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusLabel, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: tone)),
                  if (r.status == 'paid' && r.visitDeadlineAt != null) ...[
                    const SizedBox(height: AppDesign.space1),
                    Text(_remaining(r.visitDeadlineAt!), style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: tone)),
                    Text(
                      (r.isPayee ? 'immo.booking.window_help_payee' : r.isLand ? 'immo.booking.window_help_land' : 'immo.booking.window_help').tr,
                      style: context.textStyle(FontSizeType.body2, color: tone),
                    ),
                  ],
                ],
              ),
            ),
            if (r.isPayee) ...[
              const SizedBox(height: AppDesign.space4),
              _TenantCard(r: r),
            ],
            if (r.dispute != null) ...[
              const SizedBox(height: AppDesign.space4),
              _DisputeCard(
                r: r,
                onEvidence: _busy || !(r.canRespond || (!r.isPayee && r.dispute!.isOpen))
                    ? null
                    : () async {
                        if (await showImmoDisputeEvidenceSheet(r)) _load();
                      },
              ),
            ],
            if (contact != null) ...[
              const SizedBox(height: AppDesign.space4),
              AppCard(
                padding: const EdgeInsets.all(AppDesign.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.isLand || r.netPayeeKind == 'cabinet' ? 'immo.booking.cabinet_contact'.tr : 'immo.booking.owner_contact'.tr,
                        style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
                    const SizedBox(height: AppDesign.space2),
                    for (final (IconData icon, String key) in [
                      (Icons.person_outline_rounded, 'name'),
                      (Icons.phone_outlined, 'phone'),
                      (Icons.chat_outlined, 'whatsapp'),
                      (Icons.mail_outline_rounded, 'email'),
                      (Icons.location_on_outlined, 'address'),
                    ])
                      if ((contact[key]?.toString() ?? '').isNotEmpty)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, color: AppDesign.success),
                          title: Text(contact[key].toString(), style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600, color: context.ds.textPrimary)),
                          onTap: key == 'phone' || key == 'whatsapp'
                              ? () => launchUrl(Uri.parse('tel:${contact[key]}'))
                              : null,
                        ),
                    if (contact['latitude'] != null && contact['longitude'] != null)
                      AppButton(
                        label: 'immo.booking.open_map'.tr,
                        icon: Icons.map_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => launchUrl(
                          Uri.parse('https://www.google.com/maps/search/?api=1&query=${contact['latitude']},${contact['longitude']}'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppDesign.space4),
            Obx(() => AppCard(
                  padding: const EdgeInsets.all(AppDesign.space4),
                  child: Column(
                    children: [
                      _row(context, r.isLand ? 'immo.quote.lot_price'.tr : 'immo.quote.monthly_rent'.tr, immoPrice(r.unitPrice)),
                      _row(context, r.isLand ? 'immo.booking.deposit'.tr : 'immo.quote.advance'.trParams({'months': '${r.advanceMonths ?? 1}'}), immoPrice(r.baseAmount)),
                      ImmoFeeDetails(
                        netAmount: r.netAmount,
                        platformAmount: r.platformAmount,
                        cabinetName: r.commissionCabinet?.name,
                        netPayeeKind: r.netPayeeKind,
                      ),
                      if (r.commissionAmount > 0) _row(context, (r.partnerCommissionAmount != null && r.partnerCommissionAmount! > 0 ? 'immo.quote.commission' : 'immo.quote.legacy_commission').tr, immoPrice(r.commissionAmount)),
                      const Divider(),
                      _row(context, 'immo.booking.paid'.tr, immoPrice(r.totalAmount), bold: true),
                    ],
                  ),
                )),
            const SizedBox(height: AppDesign.space4),
            if (r.canConfirm)
              AppButton(
                label: (r.isLand ? 'immo.booking.confirm_land' : 'immo.booking.confirm').tr,
                icon: Icons.verified_rounded,
                isLoading: _busy,
                onPressed: _busy ? null : _confirm,
              ),
            if (r.canDispute) ...[
              const SizedBox(height: AppDesign.space2),
              AppButton(
                label: 'immo.booking.report'.tr,
                icon: Icons.report_problem_outlined,
                variant: AppButtonVariant.danger,
                onPressed: _busy ? null : () async {
                  if (await showImmoDisputeSheet(r)) _load();
                },
              ),
            ],
            if (r.hasDocuments && !kIsWeb) ...[
              const SizedBox(height: AppDesign.space4),
              Row(children: [
                Expanded(child: AppButton(label: 'immo.booking.contract'.tr, icon: Icons.description_outlined, variant: AppButtonVariant.secondary,
                    onPressed: _busy ? null : () => _document('contract'))),
                const SizedBox(width: AppDesign.space3),
                Expanded(child: AppButton(label: 'immo.booking.invoice'.tr, icon: Icons.receipt_long_outlined, variant: AppButtonVariant.secondary,
                    onPressed: _busy ? null : () => _document('invoice'))),
              ]),
            ],
            if (r.listingId != null && !widget.standalone) ...[
              const SizedBox(height: AppDesign.space2),
              AppButton(
                label: 'immo.booking.see_listing'.tr,
                variant: AppButtonVariant.ghost,
                onPressed: () => ImmoNav.push(ImmoNav.listing, arguments: r.listingId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDesign.space1),
        child: Row(children: [
          Expanded(child: Text(label, style: context.textStyle(FontSizeType.body1, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, color: context.ds.textPrimary))),
          Text(value, style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: bold ? AppDesign.accent : context.ds.textPrimary)),
        ]),
      );
}

/// Dossier du locataire, vu par le bailleur ou le cabinet.
class _TenantCard extends StatelessWidget {
  const _TenantCard({required this.r});

  final RealEstateReservation r;

  @override
  Widget build(BuildContext context) {
    final tenant = r.tenant ?? const {};
    final lines = <(IconData, String)>[
      if ((tenant['name']?.toString() ?? '').isNotEmpty) (Icons.person_outline_rounded, tenant['name'].toString()),
      if ((tenant['phone']?.toString() ?? '').isNotEmpty) (Icons.phone_outlined, tenant['phone'].toString()),
      for (final o in r.occupants) (Icons.group_outlined, o),
      if (r.applicantStatus != null) (Icons.badge_outlined, 'immo.criteria.status_${r.applicantStatus}'.tr),
      if ((r.schoolOrEmployer ?? '').isNotEmpty) (Icons.work_outline_rounded, r.schoolOrEmployer!),
      if (r.moveInDate != null) (Icons.calendar_today_outlined, immoDate(r.moveInDate!)),
      if ((r.months ?? 0) > 0) (Icons.timelapse_rounded, 'immo.criteria.months'.trParams({'count': '${r.months}'})),
      if ((r.message ?? '').isNotEmpty) (Icons.chat_bubble_outline_rounded, r.message!),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((r.isLand ? 'immo.booking.buyer' : 'immo.booking.tenant').tr,
              style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
          const SizedBox(height: AppDesign.space2),
          for (final (icon, text) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDesign.space1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: context.ds.textSecondary),
                  const SizedBox(width: AppDesign.space2),
                  Expanded(child: Text(text, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary))),
                ],
              ),
            ),
          if (r.ownerAmount != null) ...[
            const Divider(),
            Row(children: [
              Expanded(child: Text('immo.booking.your_share'.tr, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary))),
              Text(immoPrice(r.ownerAmount!), style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w800, color: AppDesign.accent)),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Litige : motif, explications, réponse du bailleur, pièces, décision.
class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.r, required this.onEvidence});

  final RealEstateReservation r;
  final VoidCallback? onEvidence;

  @override
  Widget build(BuildContext context) {
    final d = r.dispute!;
    final decided = switch (d.status) {
      'refunded' => 'immo.dispute.decided_refunded'.tr,
      'released' => 'immo.dispute.decided_released'.tr,
      _ => null,
    };

    Widget block(String title, String body) => Padding(
          padding: const EdgeInsets.only(top: AppDesign.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textStyle(FontSizeType.caption, fontWeight: FontWeight.w800, color: context.ds.textSecondary)),
              const SizedBox(height: AppDesign.space1),
              Text(body, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary)),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.gavel_rounded, color: AppDesign.dangerText),
            const SizedBox(width: AppDesign.space2),
            Expanded(
              child: Text('immo.dispute.title'.tr,
                  style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
            ),
            AppBadge(
              label: d.isOpen ? 'immo.dispute.status_open'.tr : 'immo.dispute.status_closed'.tr,
              tone: d.isOpen ? AppBadgeTone.danger : AppBadgeTone.neutral,
            ),
          ]),
          block('immo.dispute.reason'.tr, d.reason),
          block((r.isLand ? 'immo.dispute.buyer_says' : 'immo.dispute.tenant_says').tr, d.description),
          if ((d.payeeResponse ?? '').isNotEmpty)
            block((r.isLand ? 'immo.dispute.cabinet_says' : 'immo.dispute.owner_says').tr, d.payeeResponse!),
          if (d.attachments.isNotEmpty) ...[
            const SizedBox(height: AppDesign.space3),
            Wrap(
              spacing: AppDesign.space2,
              runSpacing: AppDesign.space2,
              children: [
                for (final a in d.attachments)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                    child: AppNetworkImage(url: a.url, decodeSize: const Size(72, 72), width: 72, height: 72),
                  ),
              ],
            ),
          ],
          if (decided != null) block('immo.dispute.decision'.tr, [decided, if ((d.decisionNote ?? '').isNotEmpty) d.decisionNote!].join('\n')),
          if (d.isOpen) ...[
            const SizedBox(height: AppDesign.space3),
            Text((r.isPayee ? 'immo.dispute.pending_payee' : 'immo.dispute.pending_tenant').tr,
                style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
          ],
          if (onEvidence != null) ...[
            const SizedBox(height: AppDesign.space3),
            AppButton(
              label: (r.isPayee ? 'immo.dispute.respond' : 'immo.dispute.add_evidence').tr,
              icon: Icons.add_photo_alternate_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: onEvidence,
            ),
          ],
        ],
      ),
    );
  }
}

/// « Mes réservations » : maisons réservées et acomptes de terrains.
class ImmoReservationsView extends StatefulWidget {
  const ImmoReservationsView({super.key});

  @override
  State<ImmoReservationsView> createState() => _ImmoReservationsViewState();
}

class _ImmoReservationsViewState extends State<ImmoReservationsView> {
  List<RealEstateReservation> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await RealEstateService.reservations();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(backgroundColor: context.ds.canvas, body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: context.ds.canvas,
      body: _items.isEmpty
          ? AppEmptyState(icon: Icons.receipt_long_outlined, title: 'immo.booking.none'.tr)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(context.ds.gutter, AppDesign.space4, context.ds.gutter, AppDesign.space8),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppDesign.space3),
                itemBuilder: (context, i) {
                  final r = _items[i];

                  return ImmoReservationTile(
                    reservation: r,
                    onTap: () => ImmoNav.push(ImmoNav.reservation, arguments: r.id).then((_) => _load()),
                  );
                },
              ),
            ),
    );
  }
}

/// Ligne d'une réservation : bien, référence (ou locataire), statut.
class ImmoReservationTile extends StatelessWidget {
  const ImmoReservationTile({super.key, required this.reservation, required this.onTap, this.subtitle});

  final RealEstateReservation reservation;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final r = reservation;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Row(
        children: [
          Icon(r.isLand ? Icons.landscape_outlined : Icons.home_outlined, color: AppDesign.accent),
          const SizedBox(width: AppDesign.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
                Text([r.reference, if ((subtitle ?? '').isNotEmpty) subtitle!].join(' · '),
                    style: context.textStyle(FontSizeType.caption, color: context.ds.textSecondary)),
              ],
            ),
          ),
          AppBadge(
            label: 'immo.booking.short_${r.status}'.tr,
            tone: switch (r.status) {
              'paid' => AppBadgeTone.warning,
              'released' || 'confirmed' => AppBadgeTone.success,
              'disputed' => AppBadgeTone.danger,
              _ => AppBadgeTone.neutral,
            },
          ),
        ],
      ),
    );
  }
}
