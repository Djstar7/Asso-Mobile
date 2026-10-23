import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../controllers/immo_home_controller.dart';
import 'immo_widgets.dart';

/// Pied de feuille « Tout effacer / Enregistrer » (capture SeLoger).
class _SheetFooter extends StatelessWidget {
  const _SheetFooter({required this.onClear, required this.onSave});

  final VoidCallback onClear;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(label: 'immo.filters.clear'.tr, variant: AppButtonVariant.ghost, onPressed: onClear),
        ),
        const SizedBox(width: AppDesign.space3),
        Expanded(
          flex: 2,
          child: AppButton(label: 'immo.filters.save'.tr, onPressed: onSave),
        ),
      ],
    );
  }
}

int? _parseAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');

  return digits.isEmpty ? null : int.tryParse(digits);
}

/// Curseur min-max avec deux champs de saisie (budget, surface).
class ImmoRangeField extends StatefulWidget {
  const ImmoRangeField({
    super.key,
    required this.max,
    required this.step,
    required this.values,
    required this.onChanged,
    required this.minLabel,
    required this.maxLabel,
    this.unit,
  });

  final double max;
  final double step;
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final String minLabel;
  final String maxLabel;
  final String? unit;

  @override
  State<ImmoRangeField> createState() => _ImmoRangeFieldState();
}

class _ImmoRangeFieldState extends State<ImmoRangeField> {
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    _min = TextEditingController(text: widget.values.start > 0 ? widget.values.start.toInt().toString() : '');
    _max = TextEditingController(text: widget.values.end < widget.max ? widget.values.end.toInt().toString() : '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _fromFields() {
    final start = (_parseAmount(_min.text) ?? 0).toDouble().clamp(0, widget.max).toDouble();
    final end = (_parseAmount(_max.text) ?? widget.max).toDouble().clamp(start, widget.max).toDouble();
    widget.onChanged(RangeValues(start, end));
  }

  @override
  Widget build(BuildContext context) {
    final divisions = (widget.max / widget.step).round();

    return Column(
      children: [
        RangeSlider(
          values: widget.values,
          max: widget.max,
          divisions: divisions > 0 ? divisions : null,
          activeColor: AppDesign.accent,
          onChanged: (v) {
            _min.text = v.start > 0 ? v.start.toInt().toString() : '';
            _max.text = v.end < widget.max ? v.end.toInt().toString() : '';
            widget.onChanged(v);
          },
        ),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: widget.minLabel,
                controller: _min,
                keyboardType: TextInputType.number,
                suffixIcon: widget.unit == null ? null : _Unit(widget.unit!),
                onChanged: (_) => _fromFields(),
              ),
            ),
            const SizedBox(width: AppDesign.space3),
            Expanded(
              child: AppTextField(
                label: widget.maxLabel,
                controller: _max,
                keyboardType: TextInputType.number,
                suffixIcon: widget.unit == null ? null : _Unit(widget.unit!),
                onChanged: (_) => _fromFields(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Unit extends StatelessWidget {
  const _Unit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppDesign.space3),
      child: Center(
        widthFactor: 1,
        child: Text(text, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
      ),
    );
  }
}

/// Interrupteur avec titre et explication (« Déjà viabilisé »).
class ImmoSwitchTile extends StatelessWidget {
  const ImmoSwitchTile({super.key, required this.title, required this.value, required this.onChanged, this.help});

  final String title;
  final String? help;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDesign.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
              ),
              Switch.adaptive(value: value, activeTrackColor: AppDesign.accent, onChanged: onChanged),
            ],
          ),
          if (help != null)
            Text(help!, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
        ],
      ),
    );
  }
}

Widget _sectionTitle(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: AppDesign.space4, bottom: AppDesign.space2),
      child: Text(text, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
    );

/// Prix (loyer mensuel ou budget d'un terrain).
Future<void> showImmoPriceSheet(ImmoHomeController c) {
  final isLand = c.type.value == RealEstateType.land;
  final max = isLand ? 100000000.0 : 1000000.0;
  final step = isLand ? 500000.0 : 5000.0;
  var range = RangeValues(
    ((c.filters['price_min'] as num?) ?? 0).toDouble().clamp(0, max).toDouble(),
    ((c.filters['price_max'] as num?) ?? max).toDouble().clamp(0, max).toDouble(),
  );

  return AppSheet.show(
    StatefulBuilder(
      builder: (context, setState) => AppSheet(
        title: isLand ? 'immo.filters.budget'.tr : 'immo.filters.monthly_rent'.tr,
        footer: _SheetFooter(
          onClear: () {
            AppNavigation.pop();
            c.applyFilters({'price_min': null, 'price_max': null});
          },
          onSave: () {
            AppNavigation.pop();
            c.applyFilters({
              'price_min': range.start > 0 ? range.start.toInt() : null,
              'price_max': range.end < max ? range.end.toInt() : null,
            });
          },
        ),
        child: ImmoRangeField(
          max: max,
          step: step,
          values: range,
          unit: 'FCFA',
          minLabel: 'immo.filters.minimum'.tr,
          maxLabel: 'immo.filters.maximum'.tr,
          onChanged: (v) => setState(() => range = v),
        ),
      ),
    ),
  );
}

/// Ville et quartier.
Future<void> showImmoLocationSheet(ImmoHomeController c) {
  String? city = c.filters['city'] as String?;
  final district = TextEditingController(text: c.filters['district'] as String? ?? '');

  return AppSheet.show(
    StatefulBuilder(
      builder: (context, setState) => AppSheet(
        title: 'immo.filters.location'.tr,
        footer: _SheetFooter(
          onClear: () {
            AppNavigation.pop();
            c.applyFilters({'city': null, 'district': null});
          },
          onSave: () {
            AppNavigation.pop();
            c.applyFilters({'city': city, 'district': district.text.trim()});
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'immo.filters.city'.tr),
            Obx(() => Wrap(
                  spacing: AppDesign.space2,
                  runSpacing: AppDesign.space2,
                  children: [
                    for (final name in c.cities)
                      ImmoFilterChip(
                        label: name,
                        selected: city == name,
                        trailing: null,
                        onTap: () => setState(() => city = city == name ? null : name),
                      ),
                    if (c.cities.isEmpty)
                      Text('immo.filters.no_city'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
                  ],
                )),
            _sectionTitle(context, 'immo.filters.district'.tr),
            AppTextField(
              hint: 'immo.filters.district_hint'.tr,
              controller: district,
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Sélecteur 1, 2, 3, 4, 5+ (pièces, chambres).
class _CountPicker extends StatelessWidget {
  const _CountPicker({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDesign.space2,
      children: [
        for (final n in [1, 2, 3, 4, 5])
          ImmoFilterChip(
            label: n == 5 ? '5+' : '$n+',
            selected: value == n,
            trailing: null,
            onTap: () => onChanged(value == n ? null : n),
          ),
      ],
    );
  }
}

/// « Plus de filtres » des maisons.
Future<void> showImmoMoreFiltersSheet(ImmoHomeController c) {
  int? rooms = c.filters['rooms_min'] as int?;
  int? bedrooms = c.filters['bedrooms_min'] as int?;
  bool furnished = c.filters['furnished'] == true;
  bool notLandlocked = c.filters['not_landlocked'] == true;
  bool roadside = c.filters['roadside'] == true;
  const keys = ['rooms_min', 'bedrooms_min', 'furnished', 'not_landlocked', 'roadside'];

  return AppSheet.show(
    StatefulBuilder(
      builder: (context, setState) => AppSheet(
        title: 'immo.filters.more'.tr,
        footer: _SheetFooter(
          onClear: () {
            AppNavigation.pop();
            c.applyFilters({for (final k in keys) k: null});
          },
          onSave: () {
            AppNavigation.pop();
            c.applyFilters({
              'rooms_min': rooms,
              'bedrooms_min': bedrooms,
              'furnished': furnished,
              'not_landlocked': notLandlocked,
              'roadside': roadside,
            });
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'immo.filters.rooms'.tr),
            _CountPicker(value: rooms, onChanged: (v) => setState(() => rooms = v)),
            _sectionTitle(context, 'immo.filters.bedrooms'.tr),
            _CountPicker(value: bedrooms, onChanged: (v) => setState(() => bedrooms = v)),
            const SizedBox(height: AppDesign.space3),
            ImmoSwitchTile(title: 'immo.filters.furnished'.tr, value: furnished, onChanged: (v) => setState(() => furnished = v)),
            ImmoSwitchTile(
              title: 'immo.filters.roadside'.tr,
              help: 'immo.filters.roadside_help'.tr,
              value: roadside,
              onChanged: (v) => setState(() => roadside = v),
            ),
            ImmoSwitchTile(
              title: 'immo.filters.not_landlocked'.tr,
              help: 'immo.filters.not_landlocked_help'.tr,
              value: notLandlocked,
              onChanged: (v) => setState(() => notLandlocked = v),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Filtre « Terrain » : surface, viabilisé, titré (capture SeLoger).
Future<void> showImmoLandFiltersSheet(ImmoHomeController c) {
  const max = 10000.0;
  var range = RangeValues(
    ((c.filters['surface_min'] as num?) ?? 0).toDouble().clamp(0, max).toDouble(),
    ((c.filters['surface_max'] as num?) ?? max).toDouble().clamp(0, max).toDouble(),
  );
  bool serviced = c.filters['serviced'] == true;
  bool titled = c.filters['titled'] == true;
  const keys = ['surface_min', 'surface_max', 'serviced', 'titled'];

  return AppSheet.show(
    StatefulBuilder(
      builder: (context, setState) => AppSheet(
        title: 'immo.filters.land'.tr,
        footer: _SheetFooter(
          onClear: () {
            AppNavigation.pop();
            c.applyFilters({for (final k in keys) k: null});
          },
          onSave: () {
            AppNavigation.pop();
            c.applyFilters({
              'surface_min': range.start > 0 ? range.start.toInt() : null,
              'surface_max': range.end < max ? range.end.toInt() : null,
              'serviced': serviced,
              'titled': titled,
            });
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'immo.filters.surface'.tr),
            ImmoRangeField(
              max: max,
              step: 50,
              values: range,
              unit: 'm²',
              minLabel: 'immo.filters.minimum'.tr,
              maxLabel: 'immo.filters.maximum'.tr,
              onChanged: (v) => setState(() => range = v),
            ),
            const Divider(height: AppDesign.space8),
            ImmoSwitchTile(
              title: 'immo.filters.serviced'.tr,
              help: 'immo.filters.serviced_help'.tr,
              value: serviced,
              onChanged: (v) => setState(() => serviced = v),
            ),
            ImmoSwitchTile(
              title: 'immo.filters.titled'.tr,
              help: 'immo.filters.titled_help'.tr,
              value: titled,
              onChanged: (v) => setState(() => titled = v),
            ),
          ],
        ),
      ),
    ),
  );
}

/// « Trier par ».
Future<void> showImmoSortSheet(ImmoHomeController c) {
  return AppSheet.show(
    AppSheet(
      title: 'immo.sort.title'.tr,
      child: Column(
        children: [
          for (final key in kImmoSorts)
            Obx(() => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('immo.sort.$key'.tr),
                  trailing: AppSelectionDot(isSelected: c.sort.value == key),
                  onTap: () {
                    AppNavigation.pop();
                    c.setSort(key);
                  },
                )),
        ],
      ),
    ),
  );
}

/// « Vos critères, nos meilleurs logements » (captures Studapart 1 à 5).
Future<void> showImmoCriteriaSheet(ImmoHomeController c) {
  final isLand = c.type.value == RealEstateType.land;
  final initial = c.criteria.value?.type == c.type.value
      ? c.criteria.value!
      : RealEstateCriteria(type: c.type.value);
  String? status = initial.applicantStatus;
  DateTime? moveIn = initial.moveInDate;
  int? months = initial.leaseMonths;
  bool undetermined = initial.leaseMonths == 0;
  final max = isLand ? 200000000.0 : 1000000.0;
  var budget = RangeValues(
    (initial.budgetMin ?? 0).toDouble().clamp(0, max).toDouble(),
    (initial.budgetMax ?? max).toDouble().clamp(0, max).toDouble(),
  );
  final school = TextEditingController(text: initial.school ?? '');
  final city = TextEditingController(text: initial.city ?? '');
  const statuses = ['student', 'employee', 'self_employed', 'other'];

  return AppSheet.show(
    StatefulBuilder(
      builder: (context, setState) {
        final canSubmit = city.text.trim().isNotEmpty && (isLand || (moveIn != null && (months != null || undetermined)));

        return AppSheet(
          title: (isLand ? 'immo.criteria.land_title' : 'immo.criteria.title').tr,
          subtitle: (isLand ? 'immo.criteria.land_subtitle' : 'immo.criteria.subtitle').tr,
          footer: AppButton(
            label: 'immo.criteria.submit'.tr,
            onPressed: !canSubmit
                ? null
                : () async {
                    AppNavigation.pop();
                    await c.saveCriteria(RealEstateCriteria(
                      type: c.type.value,
                      applicantStatus: isLand ? null : status,
                      school: !isLand && status == 'student' ? school.text.trim() : null,
                      city: city.text.trim(),
                      moveInDate: isLand ? null : moveIn,
                      leaseMonths: isLand ? null : (undetermined ? 0 : months),
                      budgetMin: budget.start > 0 ? budget.start.toInt() : null,
                      budgetMax: budget.end < max ? budget.end.toInt() : null,
                    ));
                  },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isLand) ...[
                _sectionTitle(context, 'immo.criteria.you_are'.tr),
                Wrap(
                  spacing: AppDesign.space2,
                  runSpacing: AppDesign.space2,
                  children: [
                    for (final s in statuses)
                      ImmoFilterChip(
                        label: 'immo.criteria.status_$s'.tr,
                        selected: status == s,
                        trailing: null,
                        onTap: () => setState(() => status = status == s ? null : s),
                      ),
                  ],
                ),
                if (status == 'student') ...[
                  const SizedBox(height: AppDesign.space3),
                  AppTextField(
                    hint: 'immo.criteria.school'.tr,
                    controller: school,
                    prefixIcon: const Icon(Icons.school_outlined),
                  ),
                ],
              ],
              const SizedBox(height: AppDesign.space4),
              AppTextField(
                label: 'immo.criteria.city'.tr,
                hint: 'immo.criteria.city_hint'.tr,
                controller: city,
                prefixIcon: const Icon(Icons.search_rounded),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppDesign.space3),
              if (!isLand) ...[
                _DateField(
                  label: 'immo.criteria.move_in'.tr,
                  value: moveIn,
                  onChanged: (d) => setState(() => moveIn = d),
                ),
                const SizedBox(height: AppDesign.space3),
                ImmoMonthsStepper(
                  label: 'immo.criteria.duration'.tr,
                  value: undetermined ? null : months,
                  onChanged: (v) => setState(() {
                    undetermined = false;
                    months = v;
                  }),
                ),
                const SizedBox(height: AppDesign.space2),
                Wrap(
                  spacing: AppDesign.space2,
                  runSpacing: AppDesign.space2,
                  children: [
                    for (final m in [6, 12, 24])
                      ImmoFilterChip(
                        label: 'immo.criteria.months'.trParams({'count': '$m'}),
                        selected: !undetermined && months == m,
                        trailing: null,
                        onTap: () => setState(() {
                          undetermined = false;
                          months = m;
                        }),
                      ),
                    ImmoFilterChip(
                      label: 'immo.criteria.undetermined'.tr,
                      selected: undetermined,
                      trailing: null,
                      onTap: () => setState(() => undetermined = !undetermined),
                    ),
                  ],
                ),
              ],
              _sectionTitle(context, 'immo.criteria.budget'.tr),
              ImmoRangeField(
                max: max,
                step: isLand ? 100000 : 5000,
                values: budget,
                unit: 'FCFA',
                minLabel: 'immo.filters.minimum'.tr,
                maxLabel: 'immo.filters.maximum'.tr,
                onChanged: (v) => setState(() => budget = v),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Champ date avec calendrier.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onChanged});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year, now.month, now.day),
          lastDate: now.add(const Duration(days: 730)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesign.radiusSm)),
        ),
        child: Text(
          value == null ? '' : immoDate(value!),
          style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary),
        ),
      ),
    );
  }
}

/// Durée en mois avec boutons - / + (captures Studapart).
class ImmoMonthsStepper extends StatelessWidget {
  const ImmoMonthsStepper({super.key, required this.label, required this.value, required this.onChanged, this.min = 1, this.max = 60});

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final current = value;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesign.radiusSm)),
        contentPadding: const EdgeInsets.fromLTRB(AppDesign.space3, AppDesign.space2, AppDesign.space1, AppDesign.space2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              current == null ? '-' : '$current',
              style: context.textStyle(FontSizeType.subtitle1, color: context.ds.textPrimary),
            ),
          ),
          Text('immo.criteria.months_unit'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
          const SizedBox(width: AppDesign.space2),
          IconButton.outlined(
            icon: const Icon(Icons.remove_rounded),
            onPressed: current == null || current <= min ? null : () => onChanged(current - 1),
          ),
          IconButton.outlined(
            icon: const Icon(Icons.add_rounded),
            onPressed: current != null && current >= max ? null : () => onChanged((current ?? min - 1) + 1),
          ),
        ],
      ),
    );
  }
}
