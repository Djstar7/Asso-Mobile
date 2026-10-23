import 'immo_summary_row.dart';
import 'package:flutter/material.dart';
import 'immo_fee_details.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';
import 'immo_sheets.dart';
import 'immo_widgets.dart';

/// Récapitulatif des montants avant de réserver : loyer × mois d'avance (ou
/// acompte du terrain), parts ASSO et cabinet partenaire, total.
Future<void> showImmoQuoteSheet(
  BuildContext context, {
  required RealEstateListing listing,
  RealEstateUnit? unit,
  ValueChanged<int?>? onContinue,
}) {
  return AppSheet.show(
    _QuoteSheet(listing: listing, unit: unit, onContinue: onContinue),
  );
}

class _QuoteSheet extends StatefulWidget {
  const _QuoteSheet({required this.listing, this.unit, this.onContinue});

  final RealEstateListing listing;
  final RealEstateUnit? unit;
  final ValueChanged<int?>? onContinue;

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  RealEstateQuote? _quote;
  bool _loading = true;
  int _quoteRequest = 0;
  late int _months = widget.listing.advanceMonths ?? 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_quoteRequest;
    setState(() => _loading = true);
    final quote = await RealEstateService.quote(
      widget.listing.id,
      unitId: widget.unit?.id,
      advanceMonths: widget.listing.isLand ? null : _months,
    );
    if (!mounted || request != _quoteRequest) return;
    setState(() {
      _quote = quote;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final q = _quote;

    return AppSheet(
      title: listing.isLand
          ? 'immo.quote.title_land'.tr
          : 'immo.quote.title'.tr,
      subtitle: widget.unit == null
          ? listing.title
          : '${listing.title} · ${widget.unit!.label}',
      footer: AppButton(
        label: 'immo.quote.continue'.tr,
        onPressed: _loading || q == null || widget.onContinue == null
            ? null
            : () {
                AppNavigation.pop();
                widget.onContinue!(q.advanceMonths);
              },
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(AppDesign.space8),
              child: Center(child: CircularProgressIndicator()),
            )
          : q == null
          ? AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'immo.quote.error'.tr,
              actionLabel: 'immo.home.retry'.tr,
              onAction: _load,
            )
          : Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!listing.isLand) ...[
                    ImmoMonthsStepper(
                      label: 'immo.quote.advance_months'.tr,
                      value: _months,
                      min: listing.advanceMonths ?? 1,
                      max: 24,
                      onChanged: (v) {
                        setState(() => _months = v);
                        _load();
                      },
                    ),
                    const SizedBox(height: AppDesign.space4),
                  ],
                  _row(
                    context,
                    listing.isLand
                        ? 'immo.quote.lot_price'.tr
                        : 'immo.quote.monthly_rent'.tr,
                    immoPrice(q.unitPrice),
                  ),
                  if (listing.isLand)
                    _row(
                      context,
                      'immo.quote.deposit'.trParams({
                        'percent': (q.depositPercent ?? 0).toStringAsFixed(0),
                      }),
                      immoPrice(q.baseAmount),
                    )
                  else
                    _row(
                      context,
                      'immo.quote.advance'.trParams({
                        'months': '${q.advanceMonths ?? _months}',
                      }),
                      immoPrice(q.baseAmount),
                    ),
                  ImmoFeeDetails(
                    netAmount: q.netAmount,
                    platformAmount: q.platformAmount,
                    netPayeeKind: q.netPayeeKind,
                  ),
                  if (q.commission > 0)
                    _row(
                      context,
                      'immo.quote.commission'.tr,
                      immoPrice(q.commission),
                      help: 'immo.quote.commission_help'.tr,
                    ),
                  const Divider(height: AppDesign.space6),
                  _row(
                    context,
                    'immo.quote.total'.tr,
                    immoPrice(q.total),
                    bold: true,
                  ),
                  const SizedBox(height: AppDesign.space2),
                  Text(
                    'immo.quote.non_refundable_note'.tr,
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: context.ds.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDesign.space4),
                  Container(
                    padding: const EdgeInsets.all(AppDesign.space3),
                    decoration: BoxDecoration(
                      color: AppDesign.infoSubtle,
                      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          color: AppDesign.infoText,
                        ),
                        const SizedBox(width: AppDesign.space2),
                        Expanded(
                          child: Text(
                            (listing.isLand
                                    ? 'immo.quote.escrow_land'
                                    : 'immo.quote.escrow')
                                .trParams({
                                  'days': '${listing.visitWindowDays}',
                                }),
                            style: context.textStyle(
                              FontSizeType.body2,
                              color: AppDesign.infoText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    String? help,
  }) => ImmoSummaryRow(label: label, value: value, bold: bold, help: help);
}
