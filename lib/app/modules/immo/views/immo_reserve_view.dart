import 'package:asso/app/core/utils/app_feedback.dart';
import '../widgets/immo_summary_row.dart';
import 'package:flutter/material.dart';
import '../widgets/immo_fee_details.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';
import '../../../data/providers/storage_service.dart';
import '../controllers/immo_home_controller.dart';
import '../immo_nav.dart';
import '../immo_payment.dart';
import '../widgets/immo_sheets.dart';
import '../widgets/immo_widgets.dart';

DateTime immoMoveInPickerInitialDate(DateTime? selectedDate, DateTime today) {
  final firstDate = DateTime(today.year, today.month, today.day);
  final lastDate = firstDate.add(const Duration(days: 365));
  if (selectedDate == null) return firstDate;

  final selected = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );
  if (selected.isBefore(firstDate)) return firstDate;
  if (selected.isAfter(lastDate)) return lastDate;

  return selected;
}

String immoMoveInSummary(DateTime? date) => date == null ? '-' : immoDate(date);

String? immoMoveInApiValue(DateTime? date) =>
    date?.toIso8601String().substring(0, 10);

class ImmoReserveArgs {
  const ImmoReserveArgs({required this.listing, this.unit, this.advanceMonths});

  final RealEstateListing listing;
  final RealEstateUnit? unit;
  final int? advanceMonths;
}

/// Parcours « Réserver » (captures Studapart 22 à 26) : seul ou accompagné,
/// profil, dates, vérification des informations avec la force du dossier,
/// récapitulatif et contrat, puis paiement. Pour un terrain : lot,
/// récapitulatif de l'acompte et engagement, puis paiement.
class ImmoReserveView extends StatefulWidget {
  const ImmoReserveView({super.key, required this.args});

  final ImmoReserveArgs args;

  @override
  State<ImmoReserveView> createState() => _ImmoReserveViewState();
}

class _ImmoReserveViewState extends State<ImmoReserveView> {
  final PageController _pages = PageController();
  int _step = 0;

  bool _accompanied = false;
  final List<TextEditingController> _coTenants = [];
  String? _status;
  final _school = TextEditingController();
  final _message = TextEditingController();
  DateTime? _moveIn;
  int? _months;
  late int _advance =
      widget.args.advanceMonths ?? widget.args.listing.advanceMonths ?? 1;
  int _quoteRequest = 0;
  RealEstateQuote? _quote;
  bool _accepted = false;
  bool _paying = false;

  RealEstateListing get _listing => widget.args.listing;
  bool get _isLand => _listing.isLand;
  int get _stepCount => _isLand ? 1 : 5;

  @override
  void initState() {
    super.initState();
    final criteria = Get.isRegistered<ImmoHomeController>()
        ? Get.find<ImmoHomeController>().criteria.value
        : null;
    _status = criteria?.applicantStatus;
    _school.text = criteria?.school ?? '';
    _moveIn = criteria?.moveInDate;
    _months = (criteria?.leaseMonths ?? 0) > 0
        ? criteria!.leaseMonths
        : _listing.minLeaseMonths ?? 12;
    if (_isLand && !_listing.isOwnListing) _loadQuote();
  }

  @override
  void dispose() {
    for (final c in [_school, _message, ..._coTenants]) {
      c.dispose();
    }
    _pages.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    final request = ++_quoteRequest;
    setState(() {
      _quote = null;
      _accepted = false;
    });
    final q = await RealEstateService.quote(
      _listing.id,
      unitId: widget.args.unit?.id,
      advanceMonths: _isLand ? null : _advance,
    );
    if (mounted && request == _quoteRequest) setState(() => _quote = q);
  }

  /// Écarts avec les conditions du bailleur (bandeau « Attention »).
  List<String> get _mismatches => [
    if (!_isLand &&
        _listing.minLeaseMonths != null &&
        (_months ?? 0) < _listing.minLeaseMonths!)
      'immo.reserve.mismatch_lease'.trParams({
        'months': '${_listing.minLeaseMonths}',
      }),
    if (!_isLand &&
        _moveIn != null &&
        widget.args.unit?.availableFrom != null &&
        _moveIn!.isBefore(widget.args.unit!.availableFrom!))
      'immo.reserve.mismatch_date'.trParams({
        'date': immoDate(widget.args.unit!.availableFrom!),
      }),
  ];

  /// « Force du dossier » : part des informations renseignées.
  int get _strength {
    final checks = [
      _status != null,
      _status != 'student' || _school.text.trim().isNotEmpty,
      _moveIn != null,
      _months != null,
      _message.text.trim().length >= 20,
      !_accompanied || _coTenants.every((c) => c.text.trim().isNotEmpty),
      (StorageService.getUser()?.phone ?? '').isNotEmpty,
    ];

    return (checks.where((c) => c).length * 100 / checks.length).round();
  }

  void _go(int step) {
    if (step == _stepCount - 1) _loadQuote();
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pay() async {
    if (_paying) return;
    if (_listing.isOwnListing) {
      AppFeedback.show(
        'immo.reserve.own_listing_title'.tr,
        'immo.reserve.own_listing_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final q = _quote;
    if (q == null) return;
    setState(() => _paying = true);
    try {
      final reservation = await ImmoPayment.pay(
        listingId: _listing.id,
        total: q.total,
        label: _listing.title,
        body: {
          'unit_id': ?widget.args.unit?.id,
          if (!_isLand) 'advance_months': _advance,
          if (!_isLand) 'months': _months ?? 0,
          if (_moveIn != null) 'move_in_date': immoMoveInApiValue(_moveIn),
          'applicant_status': ?_status,
          if (_school.text.trim().isNotEmpty)
            'school_or_employer': _school.text.trim(),
          if (_message.text.trim().isNotEmpty) 'message': _message.text.trim(),
          if (_accompanied && _coTenants.isNotEmpty)
            'occupants': [
              for (final c in _coTenants)
                if (c.text.trim().isNotEmpty) {'name': c.text.trim()},
            ],
          'contract_accepted': true,
          'expected_total': q.total,
        },
      );
      if (!mounted) return;
      if (reservation != null) {
        Navigator.of(
          context,
        ).pushReplacementNamed(ImmoNav.reservation, arguments: reservation.id);
      }
    } catch (error) {
      if (!mounted) return;
      AppFeedback.show(
        'immo.reserve.error'.tr,
        error.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.ds.gutter;
    if (_listing.isOwnListing) {
      return Scaffold(
        backgroundColor: context.ds.canvas,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text('immo.reserve.own_listing_title'.tr),
        ),
        body: AppEmptyState(
          icon: Icons.home_work_outlined,
          title: 'immo.reserve.own_listing_title'.tr,
          message: 'immo.reserve.own_listing_message'.tr,
          actionLabel: 'immo.reserve.own_listing_back'.tr,
          onAction: () {
            ImmoNav.maybePop();
          },
        ),
      );
    }
    final last = _step == _stepCount - 1;
    final mismatches = _mismatches;

    return Scaffold(
      backgroundColor: context.ds.canvas,
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          gutter,
          AppDesign.space2,
          gutter,
          AppDesign.space3,
        ),
        decoration: BoxDecoration(
          color: context.ds.surface,
          border: Border(top: BorderSide(color: context.ds.border)),
        ),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: AppButton(
                  label: 'immo.reserve.edit'.tr,
                  variant: AppButtonVariant.secondary,
                  onPressed: _paying ? null : () => _go(_step - 1),
                ),
              ),
            if (_step > 0) const SizedBox(width: AppDesign.space3),
            Expanded(
              flex: 2,
              child: AppButton(
                label: last
                    ? (_quote == null
                          ? 'immo.reserve.pay'.tr
                          : 'immo.reserve.pay_amount'.trParams({
                              'amount': immoPrice(_quote!.total),
                            }))
                    : 'immo.reserve.continue'.tr,
                onPressed: _paying
                    ? null
                    : last
                    ? (_accepted && _quote != null && mismatches.isEmpty
                          ? _pay
                          : null)
                    : (_step == 3 && mismatches.isNotEmpty
                          ? null
                          : () => _go(_step + 1)),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppDesign.accent,
            padding: EdgeInsets.fromLTRB(
              gutter,
              AppDesign.space3,
              gutter,
              AppDesign.space4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _stepCount,
                    minHeight: 5,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: AppDesign.space3),
                Text(
                  _isLand
                      ? 'immo.reserve.land_title'.tr
                      : 'immo.reserve.step_title_$_step'.tr,
                  style: context.textStyle(
                    FontSizeType.h5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              children: _isLand
                  ? [_recap(context)]
                  : [
                      _occupants(context),
                      _profile(context),
                      _dates(context),
                      _check(context, mismatches),
                      _recap(context),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scroll(List<Widget> children) => ListView(
    padding: EdgeInsets.fromLTRB(
      context.ds.gutter,
      AppDesign.space4,
      context.ds.gutter,
      AppDesign.space8,
    ),
    children: children,
  );

  Widget _choice({
    required IconData icon,
    required String title,
    required String body,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space3),
      child: AppCard(
        onTap: onTap,
        color: selected ? AppDesign.accentSubtle : null,
        padding: const EdgeInsets.all(AppDesign.space4),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppDesign.accent : context.ds.textSecondary,
            ),
            const SizedBox(width: AppDesign.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyle(
                      FontSizeType.body1,
                      fontWeight: FontWeight.w700,
                      color: context.ds.textPrimary,
                    ),
                  ),
                  Text(
                    body,
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: context.ds.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppSelectionDot(isSelected: selected),
          ],
        ),
      ),
    );
  }

  Widget _occupants(BuildContext context) => _scroll([
    _choice(
      icon: Icons.person_outline_rounded,
      title: 'immo.reserve.alone'.tr,
      body: 'immo.reserve.alone_help'.tr,
      selected: !_accompanied,
      onTap: () => setState(() => _accompanied = false),
    ),
    _choice(
      icon: Icons.group_outlined,
      title: 'immo.reserve.accompanied'.tr,
      body: 'immo.reserve.accompanied_help'.tr,
      selected: _accompanied,
      onTap: () => setState(() {
        _accompanied = true;
        if (_coTenants.isEmpty) _coTenants.add(TextEditingController());
      }),
    ),
    if (_accompanied) ...[
      for (var i = 0; i < _coTenants.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppDesign.space2),
          child: AppTextField(
            label: 'immo.reserve.co_tenant'.trParams({'n': '${i + 2}'}),
            controller: _coTenants[i],
            onChanged: (_) => setState(() {}),
          ),
        ),
      if (_coTenants.length < 6)
        AppButton(
          label: 'immo.reserve.add_co_tenant'.tr,
          icon: Icons.add_rounded,
          variant: AppButtonVariant.ghost,
          expand: false,
          onPressed: () =>
              setState(() => _coTenants.add(TextEditingController())),
        ),
    ],
    const SizedBox(height: AppDesign.space4),
    Text(
      'immo.reserve.for_someone'.tr,
      style: context.textStyle(
        FontSizeType.body2,
        color: context.ds.textSecondary,
      ),
    ),
  ]);

  Widget _profile(BuildContext context) => _scroll([
    Text(
      'immo.criteria.you_are'.tr,
      style: context.textStyle(
        FontSizeType.subtitle1,
        fontWeight: FontWeight.w700,
        color: context.ds.textPrimary,
      ),
    ),
    const SizedBox(height: AppDesign.space2),
    Wrap(
      spacing: AppDesign.space2,
      runSpacing: AppDesign.space2,
      children: [
        for (final s in ['student', 'employee', 'self_employed', 'other'])
          ImmoFilterChip(
            label: 'immo.criteria.status_$s'.tr,
            selected: _status == s,
            trailing: null,
            onTap: () => setState(() => _status = s),
          ),
      ],
    ),
    const SizedBox(height: AppDesign.space4),
    AppTextField(
      label: _status == 'student'
          ? 'immo.criteria.school'.tr
          : 'immo.reserve.employer'.tr,
      controller: _school,
      prefixIcon: Icon(
        _status == 'student'
            ? Icons.school_outlined
            : Icons.work_outline_rounded,
      ),
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: AppDesign.space3),
    AppTextField(
      label: 'immo.reserve.message'.tr,
      hint: 'immo.reserve.message_hint'.tr,
      controller: _message,
      maxLines: 4,
      onChanged: (_) => setState(() {}),
    ),
  ]);

  Widget _dates(BuildContext context) => _scroll([
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text('immo.criteria.move_in'.tr),
      subtitle: Text(
        _moveIn == null ? 'immo.reserve.choose_date'.tr : immoDate(_moveIn!),
      ),
      onTap: () async {
        final now = DateTime.now();
        final firstDate = DateTime(now.year, now.month, now.day);
        final lastDate = firstDate.add(const Duration(days: 365));
        final picked = await showDatePicker(
          context: context,
          firstDate: firstDate,
          lastDate: lastDate,
          initialDate: immoMoveInPickerInitialDate(_moveIn, firstDate),
        );
        if (picked != null) setState(() => _moveIn = picked);
      },
    ),
    const SizedBox(height: AppDesign.space3),
    ImmoMonthsStepper(
      label: 'immo.criteria.duration'.tr,
      value: _months,
      max: 120,
      onChanged: (v) => setState(() => _months = v),
    ),
    const SizedBox(height: AppDesign.space2),
    Wrap(
      spacing: AppDesign.space2,
      children: [
        for (final m in [6, 12, 24])
          ImmoFilterChip(
            label: 'immo.criteria.months'.trParams({'count': '$m'}),
            selected: _months == m,
            trailing: null,
            onTap: () => setState(() => _months = m),
          ),
      ],
    ),
    const SizedBox(height: AppDesign.space4),
    ImmoMonthsStepper(
      label: 'immo.quote.advance_months'.tr,
      value: _advance,
      min: _listing.advanceMonths ?? 1,
      max: 24,
      onChanged: (v) => setState(() => _advance = v),
    ),
    Padding(
      padding: const EdgeInsets.only(top: AppDesign.space2),
      child: Text(
        'immo.reserve.advance_help'.trParams({
          'months': '${_listing.advanceMonths ?? 1}',
        }),
        style: context.textStyle(
          FontSizeType.body2,
          color: context.ds.textSecondary,
        ),
      ),
    ),
  ]);

  Widget _section(
    BuildContext context,
    String title,
    List<String> lines,
    int editStep,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppDesign.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: context.textStyle(
            FontSizeType.caption,
            fontWeight: FontWeight.w800,
            color: context.ds.textSecondary,
          ),
        ),
        const SizedBox(height: AppDesign.space1),
        AppCard(
          onTap: () => _go(editStep),
          padding: const EdgeInsets.all(AppDesign.space4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in lines)
                      Text(
                        l,
                        style: context.textStyle(
                          FontSizeType.body1,
                          color: context.ds.textPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: context.ds.textSecondary),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _check(BuildContext context, List<String> mismatches) {
    final user = StorageService.getUser();
    final strength = _strength;

    return _scroll([
      if (mismatches.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppDesign.space4),
          child: AppCard(
            color: AppDesign.warningSubtle,
            showBorder: false,
            padding: const EdgeInsets.all(AppDesign.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppDesign.warningText,
                ),
                const SizedBox(width: AppDesign.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'immo.reserve.mismatch_title'.trParams({
                          'count': '${mismatches.length}',
                        }),
                        style: context.textStyle(
                          FontSizeType.body2,
                          fontWeight: FontWeight.w700,
                          color: AppDesign.warningText,
                        ),
                      ),
                      for (final m in mismatches)
                        Text(
                          '• $m',
                          style: context.textStyle(
                            FontSizeType.body2,
                            color: AppDesign.warningText,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      _section(context, 'immo.reserve.tenants'.tr, [
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
        if ((user?.phone ?? '').isNotEmpty) user!.phone,
        for (final c in _coTenants.where(
          (c) => _accompanied && c.text.trim().isNotEmpty,
        ))
          c.text.trim(),
      ], 0),
      _section(context, 'immo.criteria.move_in'.tr, [
        immoMoveInSummary(_moveIn),
      ], 2),
      _section(context, 'immo.criteria.duration'.tr, [
        'immo.criteria.months'.trParams({'count': '${_months ?? '-'}'}),
      ], 2),
      _section(context, 'immo.reserve.message'.tr, [
        _message.text.trim().isEmpty
            ? 'immo.reserve.no_message'.tr
            : _message.text.trim(),
      ], 1),
      AppCard(
        padding: const EdgeInsets.all(AppDesign.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.fitness_center_rounded,
                  color: AppDesign.accent,
                ),
                const SizedBox(width: AppDesign.space2),
                Text(
                  'immo.reserve.strength'.trParams({'percent': '$strength'}),
                  style: context.textStyle(
                    FontSizeType.body1,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesign.space2),
            LinearProgressIndicator(
              value: strength / 100,
              color: AppDesign.accent,
              backgroundColor: AppDesign.accentSubtle,
            ),
            const SizedBox(height: AppDesign.space2),
            Text(
              'immo.reserve.strength_help'.tr,
              style: context.textStyle(
                FontSizeType.body2,
                color: context.ds.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _recap(BuildContext context) {
    final q = _quote;
    final days = '${_listing.visitWindowDays}';

    return _scroll([
      Text(
        _listing.title,
        style: context.textStyle(
          FontSizeType.subtitle1,
          fontWeight: FontWeight.w800,
          color: context.ds.textPrimary,
        ),
      ),
      if (widget.args.unit != null)
        Text(
          widget.args.unit!.label,
          style: context.textStyle(
            FontSizeType.body2,
            color: context.ds.textSecondary,
          ),
        ),
      const SizedBox(height: AppDesign.space4),
      if (q == null)
        const Center(child: CircularProgressIndicator())
      else
        Obx(
          () => AppCard(
            padding: const EdgeInsets.all(AppDesign.space4),
            child: Column(
              children: [
                if (!_isLand)
                  _row(
                    context,
                    'immo.criteria.move_in'.tr,
                    immoMoveInSummary(_moveIn),
                  ),
                _row(
                  context,
                  _isLand
                      ? 'immo.quote.lot_price'.tr
                      : 'immo.quote.monthly_rent'.tr,
                  immoPrice(q.unitPrice),
                ),
                _row(
                  context,
                  _isLand
                      ? 'immo.quote.deposit'.trParams({
                          'percent': (q.depositPercent ?? 0).toStringAsFixed(0),
                        })
                      : 'immo.quote.advance'.trParams({
                          'months': '${q.advanceMonths}',
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
              ],
            ),
          ),
        ),
      const SizedBox(height: AppDesign.space4),
      Text(
        'immo.reserve.contract_title'.tr,
        style: context.textStyle(
          FontSizeType.subtitle1,
          fontWeight: FontWeight.w800,
          color: context.ds.textPrimary,
        ),
      ),
      const SizedBox(height: AppDesign.space2),
      for (final key
          in _isLand
              ? [
                  'immo.reserve.contract_land_1',
                  'immo.reserve.contract_2',
                  'immo.reserve.contract_3',
                  'immo.reserve.contract_land_4',
                ]
              : [
                  'immo.reserve.contract_1',
                  'immo.reserve.contract_2',
                  'immo.reserve.contract_3',
                ])
        Padding(
          padding: const EdgeInsets.only(bottom: AppDesign.space2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.circle, size: 6, color: AppDesign.accent),
              ),
              const SizedBox(width: AppDesign.space2),
              Expanded(
                child: Text(
                  key.trParams({'days': days}),
                  style: context.textStyle(
                    FontSizeType.body2,
                    color: context.ds.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: AppDesign.space2),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppDesign.accent,
        value: _accepted,
        onChanged: (v) => setState(() => _accepted = v ?? false),
        title: Text(
          'immo.reserve.accept'.tr,
          style: context.textStyle(
            FontSizeType.body2,
            fontWeight: FontWeight.w600,
            color: context.ds.textPrimary,
          ),
        ),
      ),
    ]);
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    String? help,
  }) => ImmoSummaryRow(label: label, value: value, bold: bold, help: help);
}
