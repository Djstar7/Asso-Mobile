import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';
import '../../immo/widgets/immo_widgets.dart';
import 'landlord_editor_view.dart';
import 'landlord_verification_view.dart';

/// Espace bailleur : statut de vérification et annonces publiées.
class LandlordDashboardView extends StatefulWidget {
  const LandlordDashboardView({super.key});

  @override
  State<LandlordDashboardView> createState() => _LandlordDashboardViewState();
}

class _LandlordDashboardViewState extends State<LandlordDashboardView> {
  LandlordStatus? _status;
  List<RealEstateListing> _listings = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([RealEstateService.landlordStatus(), RealEstateService.myListings()]);
    if (!mounted) return;
    setState(() {
      _status = results[0] as LandlordStatus?;
      _listings = results[1] as List<RealEstateListing>;
      _loading = false;
    });
  }

  Future<void> _openVerification() async {
    final sent = await Get.to<bool>(() => const LandlordVerificationView());
    if (sent == true) _load();
  }

  Future<void> _openEditor([int? id]) async {
    await Get.to(() => LandlordEditorView(listingId: id));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final gutter = context.ds.gutter;

    return Scaffold(
      backgroundColor: context.ds.canvas,
      appBar: AppBar(leading: const AppBackButton(), title: Text('landlord.title'.tr)),
      floatingActionButton: status?.canPublish ?? false
          ? FloatingActionButton.extended(
              heroTag: 'landlord-new',
              backgroundColor: AppDesign.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_home_outlined),
              label: Text('landlord.new_listing'.tr),
              onPressed: () => _openEditor(),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(gutter, AppDesign.space4, gutter, 96),
                children: [
                  _StatusCard(status: status, onVerify: _openVerification),
                  const SizedBox(height: AppDesign.space6),
                  Text('landlord.my_listings'.tr,
                      style: context.textStyle(FontSizeType.h6, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
                  const SizedBox(height: AppDesign.space3),
                  if (_listings.isEmpty)
                    AppEmptyState(
                      icon: Icons.home_work_outlined,
                      title: 'landlord.no_listing'.tr,
                      message: 'landlord.no_listing_help'.tr,
                    )
                  else
                    for (final l in _listings) ...[
                      _ListingTile(listing: l, onTap: () => _openEditor(l.id)),
                      const SizedBox(height: AppDesign.space3),
                    ],
                ],
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.onVerify});

  final LandlordStatus? status;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final s = status?.status ?? 'none';
    final (Color bg, Color fg, IconData icon) = switch (s) {
      'verified' => (AppDesign.successSubtle, AppDesign.successText, Icons.verified_rounded),
      'pending' => (AppDesign.warningSubtle, AppDesign.warningText, Icons.hourglass_top_rounded),
      'rejected' => (AppDesign.dangerSubtle, AppDesign.dangerText, Icons.error_outline_rounded),
      _ => (AppDesign.accentSubtle, AppDesign.accentText, Icons.badge_outlined),
    };

    return AppCard(
      color: bg,
      showBorder: false,
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: fg),
            const SizedBox(width: AppDesign.space2),
            Expanded(child: Text('landlord.status.$s'.tr,
                style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: fg))),
          ]),
          const SizedBox(height: AppDesign.space2),
          Text('landlord.status.${s}_help'.tr, style: context.textStyle(FontSizeType.body2, color: fg)),
          if (s == 'rejected' && status?.rejectionReason != null) ...[
            const SizedBox(height: AppDesign.space2),
            Text('landlord.status.reason'.trParams({'reason': status!.rejectionReason!}),
                style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w700, color: fg)),
          ],
          if (s == 'none' || s == 'rejected') ...[
            const SizedBox(height: AppDesign.space3),
            AppButton(label: 'landlord.verify.start'.tr, icon: Icons.upload_file_rounded, onPressed: onVerify),
          ],
        ],
      ),
    );
  }
}

class _ListingTile extends StatelessWidget {
  const _ListingTile({required this.listing, required this.onTap});

  final RealEstateListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = listing.status ?? 'draft';
    final tone = switch (status) {
      'published' => AppBadgeTone.success,
      'pending_review' => AppBadgeTone.warning,
      'rejected' => AppBadgeTone.danger,
      _ => AppBadgeTone.neutral,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDesign.space3),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            child: SizedBox(
              width: 72,
              height: 72,
              child: listing.images.isEmpty
                  ? ColoredBox(color: context.ds.surfaceMuted, child: Icon(Icons.home_work_outlined, color: context.ds.textTertiary))
                  : AppNetworkImage(url: listing.images.first, decodeSize: const Size(72, 72)),
            ),
          ),
          const SizedBox(width: AppDesign.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
                Text(listing.place, style: context.textStyle(FontSizeType.caption, color: context.ds.textSecondary)),
                const SizedBox(height: AppDesign.space1),
                Obx(() => Text('${immoPrice(listing.price)} ${'immo.card.per_month'.tr}',
                    style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w700, color: AppDesign.accent))),
              ],
            ),
          ),
          AppBadge(label: 'landlord.listing_status.$status'.tr, tone: tone),
        ],
      ),
    );
  }
}
