import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';
import '../../immo/views/immo_room_tour_view.dart' show immoRoomName;
import '../../immo/widgets/immo_sheets.dart' show ImmoMonthsStepper, ImmoSwitchTile;
import '../../immo/widgets/immo_widgets.dart';
import '../../vendorConfig/views/map_location_picker_view.dart';
import '../landlord_pickers.dart';

/// Publication d'une maison à louer, en étapes (barre de progression comme
/// le parcours de demande Studapart) : type, localisation, quartier,
/// caractéristiques, prix, équipements, visite pièce par pièce, envoi.
class LandlordEditorView extends StatefulWidget {
  const LandlordEditorView({super.key, this.listingId});

  final int? listingId;

  @override
  State<LandlordEditorView> createState() => _LandlordEditorViewState();
}

class _LandlordEditorViewState extends State<LandlordEditorView> {
  static const _kinds = ['house', 'villa', 'apartment', 'studio', 'room', 'duplex', 'residence'];
  static const _stepCount = 8;
  static const _tourStep = 6;

  final PageController _pages = PageController();
  int _step = 0;
  int? _id;
  bool _loading = true;
  bool _saving = false;

  /// Champs envoyés à l'API, aux noms de l'API.
  final Map<String, dynamic> _d = {
    'property_kind': 'house',
    'furnished': false,
    'is_landlocked': false,
    'has_parking': false,
    'has_fence': false,
    'has_guard': false,
    'advance_months': 3,
    'min_lease_months': 12,
  };
  List<Map<String, dynamic>> _units = [];
  List<RealEstateTourRoom> _rooms = [];
  RealEstateMedia? _video;
  List<RealEstateAmenity> _amenities = const [];
  final Set<int> _amenityIds = {};
  String? _status;
  String? _description;
  String? _rejection;
  List<String> _missing = const [];
  Map<String, dynamic>? _preview;

  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _address = TextEditingController();
  final _price = TextEditingController();
  final _oldPrice = TextEditingController();
  final _promo = TextEditingController();
  final _distance = TextEditingController();
  final _surface = TextEditingController();

  @override
  void initState() {
    super.initState();
    _id = widget.listingId;
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _city, _district, _address, _price, _oldPrice, _promo, _distance, _surface]) {
      c.dispose();
    }
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _amenities = await RealEstateService.amenities();
    if (_id != null) {
      final data = await RealEstateService.myListing(_id!);
      if (data != null) _apply(data);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _apply(Map<String, dynamic> j) {
    final listing = RealEstateListing.fromJson(j);
    final a = listing.access;
    _d.addAll({
      'property_kind': listing.propertyKind ?? 'house',
      'rooms': listing.rooms,
      'bedrooms': listing.bedrooms,
      'bathrooms': listing.bathrooms,
      'furnished': listing.furnished,
      'road_access': a.roadAccess,
      'road_condition': a.roadCondition,
      'is_landlocked': a.isLandlocked,
      'water_source': a.waterSource,
      'electricity': a.electricity,
      'security_level': a.securityLevel,
      'has_parking': a.hasParking,
      'has_fence': a.hasFence,
      'has_guard': a.hasGuard,
      'min_lease_months': listing.minLeaseMonths,
      'advance_months': listing.advanceMonths,
      'available_from': listing.availableFrom?.toIso8601String().substring(0, 10),
      'latitude': j['latitude'],
      'longitude': j['longitude'],
    });
    _title.text = listing.title;
    _desc.text = j['owner_description']?.toString() ?? '';
    _city.text = listing.city;
    _district.text = listing.district ?? '';
    _address.text = j['address']?.toString() ?? '';
    _price.text = '${j['net_price'] ?? ''}';
    _oldPrice.text = j['old_net_price'] == null ? '' : '${j['old_net_price']}';
    _promo.text = listing.promoText ?? '';
    _distance.text = a.distanceToRoadM == null ? '' : '${a.distanceToRoadM}';
    _surface.text = listing.surfaceM2 == null ? '' : '${listing.surfaceM2}';
    _units = (j['units_net'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    _rooms = listing.roomsTour;
    _video = listing.video;
    _amenityIds
      ..clear()
      ..addAll((j['amenity_ids'] as List? ?? const []).map((e) => (e as num).toInt()));
    _status = listing.status;
    _description = listing.description;
    _rejection = j['rejection_reason']?.toString();
    _missing = (j['missing'] as List? ?? const []).map((e) => e.toString()).toList();
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), ''));

  /// Pièces proposées pour une nouvelle annonce, d'après le nombre de chambres.
  List<Map<String, dynamic>> _defaultRooms() {
    final bedrooms = (_d['bedrooms'] as int?) ?? 1;
    return [
      {'kind': 'entrance', 'label': 'immo.rooms.entrance'.tr},
      {'kind': 'living', 'label': 'immo.rooms.living'.tr},
      for (var i = 1; i <= bedrooms.clamp(1, 6); i++) {'kind': 'bedroom', 'label': '${'immo.rooms.bedroom'.tr} $i'},
      {'kind': 'kitchen', 'label': 'immo.rooms.kitchen'.tr},
      {'kind': 'bathroom', 'label': 'immo.rooms.bathroom'.tr},
      {'kind': 'outside', 'label': 'immo.rooms.outside'.tr},
      {'kind': 'road', 'label': 'immo.rooms.road'.tr},
    ];
  }

  Map<String, dynamic> _body({List<Map<String, dynamic>>? rooms}) {
    return {
      ..._d,
      'title': _title.text.trim(),
      'owner_description': _desc.text.trim(),
      'city': _city.text.trim(),
      'district': _district.text.trim(),
      'address': _address.text.trim(),
      'net_price': _int(_price),
      'old_net_price': _int(_oldPrice),
      'promo_text': _promo.text.trim(),
      'distance_to_road_m': _d['road_access'] == 'roadside' ? null : _int(_distance),
      'surface_m2': _int(_surface),
      'amenity_ids': _amenityIds.toList(),
      'units': _units,
      'rooms_tour': ?rooms,
    }..removeWhere((k, v) => v == null || (v is String && v.isEmpty && k != 'owner_description'));
  }

  Future<bool> _save({List<Map<String, dynamic>>? rooms}) async {
    setState(() => _saving = true);
    final res = await RealEstateService.saveListing(_id, _body(rooms: rooms ?? (_id == null ? _defaultRooms() : null)));
    if (!mounted) return false;
    setState(() => _saving = false);
    final data = res.data?['data'];
    if (!res.success || data is! Map) {
      final errors = res.data?['errors'];
      final first = errors is Map && errors.isNotEmpty ? (errors.values.first as List).first.toString() : res.message;
      Get.snackbar('landlord.editor.error'.tr, first, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    final json = Map<String, dynamic>.from(data);
    _id = (json['id'] as num).toInt();
    setState(() => _apply(json));

    return true;
  }

  bool _stepValid(int step) => switch (step) {
        0 => _title.text.trim().length >= 3,
        1 => _city.text.trim().isNotEmpty,
        4 => (_int(_price) ?? 0) > 0,
        _ => true,
      };

  Future<void> _next() async {
    if (!_stepValid(_step)) {
      Get.snackbar('landlord.editor.incomplete'.tr, 'landlord.editor.step_required_$_step'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    // On enregistre avant la visite : les photos s'attachent à des pièces
    // déjà créées côté serveur.
    if (_step == _tourStep - 1 && !await _save()) return;
    if (_step == _tourStep && !await _save()) return;
    _go(_step + 1);
  }

  void _go(int step) {
    setState(() => _step = step);
    _pages.animateToPage(step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final res = await RealEstateService.submitListing(_id!);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      Get.back();
      Get.snackbar('landlord.editor.submitted_title'.tr, 'landlord.editor.submitted_message'.tr, snackPosition: SnackPosition.BOTTOM);
    } else {
      final missing = (res.data?['missing'] as List? ?? const []).map((e) => e.toString()).toList();
      setState(() => _missing = missing);
      Get.snackbar('landlord.editor.incomplete'.tr, res.message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: context.ds.canvas, body: const Center(child: CircularProgressIndicator()));
    }
    final gutter = context.ds.gutter;
    final last = _step == _stepCount - 1;

    return Scaffold(
      backgroundColor: context.ds.canvas,
      appBar: AppBar(
        leading: const AppBackButton(close: true),
        title: Text(_id == null ? 'landlord.editor.new_title'.tr : 'landlord.editor.edit_title'.tr),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / _stepCount,
            color: AppDesign.accent,
            backgroundColor: AppDesign.accentSubtle,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, AppDesign.space2, gutter, AppDesign.space3),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(child: AppButton(label: 'landlord.editor.previous'.tr, variant: AppButtonVariant.secondary, onPressed: _saving ? null : () => _go(_step - 1))),
              if (_step > 0) const SizedBox(width: AppDesign.space3),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: last ? 'landlord.editor.submit'.tr : 'landlord.editor.next'.tr,
                  isLoading: _saving,
                  onPressed: _saving ? null : (last ? (_missing.isEmpty ? _submit : null) : _next),
                ),
              ),
            ],
          ),
        ),
      ),
      body: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _page(context, 'landlord.editor.step_kind'.tr, _kindStep(context)),
          _page(context, 'landlord.editor.step_location'.tr, _locationStep(context)),
          _page(context, 'landlord.editor.step_area'.tr, _areaStep(context)),
          _page(context, 'landlord.editor.step_features'.tr, _featuresStep(context)),
          _page(context, 'landlord.editor.step_price'.tr, _priceStep(context)),
          _page(context, 'landlord.editor.step_amenities'.tr, _amenitiesStep(context)),
          _page(context, 'landlord.editor.step_tour'.tr, _tourStepView(context)),
          _page(context, 'landlord.editor.step_review'.tr, _reviewStep(context)),
        ],
      ),
    );
  }

  Widget _page(BuildContext context, String title, Widget child) {
    final gutter = context.ds.gutter;

    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, AppDesign.space4, gutter, AppDesign.space8),
      children: [
        Text('landlord.editor.step'.trParams({'n': '${_step + 1}', 'total': '$_stepCount'}),
            style: context.textStyle(FontSizeType.caption, color: context.ds.textSecondary)),
        Text(title, style: context.textStyle(FontSizeType.h5, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
        const SizedBox(height: AppDesign.space4),
        child,
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: AppDesign.space4, bottom: AppDesign.space2),
        child: Text(text, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
      );

  /// Choix unique parmi des puces, avec désélection.
  Widget _choices(String field, List<String> values, String prefix) {
    return Wrap(
      spacing: AppDesign.space2,
      runSpacing: AppDesign.space2,
      children: [
        for (final v in values)
          ImmoFilterChip(
            label: '$prefix$v'.tr,
            selected: _d[field] == v,
            trailing: null,
            onTap: () => setState(() => _d[field] = _d[field] == v ? null : v),
          ),
      ],
    );
  }

  Widget _kindStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _choices('property_kind', _kinds, 'immo.kinds.'),
          const SizedBox(height: AppDesign.space4),
          AppTextField(label: 'landlord.editor.title_field'.tr, hint: 'landlord.editor.title_hint'.tr, controller: _title),
          const SizedBox(height: AppDesign.space3),
          AppTextField(label: 'landlord.editor.description'.tr, hint: 'landlord.editor.description_hint'.tr, controller: _desc, maxLines: 5),
        ],
      );

  Widget _locationStep(BuildContext context) {
    final lat = (_d['latitude'] as num?)?.toDouble();
    final lng = (_d['longitude'] as num?)?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(label: 'immo.filters.city'.tr, controller: _city, prefixIcon: const Icon(Icons.location_city_outlined)),
        const SizedBox(height: AppDesign.space3),
        AppTextField(label: 'immo.filters.district'.tr, controller: _district, prefixIcon: const Icon(Icons.location_on_outlined)),
        const SizedBox(height: AppDesign.space3),
        AppTextField(label: 'landlord.editor.address'.tr, helperText: 'landlord.editor.address_help'.tr, controller: _address),
        const SizedBox(height: AppDesign.space4),
        AppButton(
          label: lat == null ? 'landlord.editor.place_on_map'.tr : 'landlord.editor.move_on_map'.tr,
          icon: Icons.map_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () async {
            final result = await Get.to<Map<String, dynamic>>(() => MapLocationPickerView(
                  initialPosition: lat == null || lng == null ? null : LatLng(lat, lng),
                  initialAddress: _address.text.isEmpty ? null : _address.text,
                ));
            if (result == null) return;
            setState(() {
              _d['latitude'] = result['latitude'];
              _d['longitude'] = result['longitude'];
              if (_address.text.isEmpty) _address.text = result['address']?.toString() ?? '';
            });
          },
        ),
        if (lat != null)
          Padding(
            padding: const EdgeInsets.only(top: AppDesign.space2),
            child: Text('landlord.editor.position_saved'.tr,
                style: context.textStyle(FontSizeType.body2, color: AppDesign.success)),
          ),
      ],
    );
  }

  Widget _areaStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('landlord.editor.area_intro'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
          _label(context, 'landlord.editor.road_access'.tr),
          _choices('road_access', ['roadside', 'near_road', 'inside'], 'landlord.road_access.'),
          if (_d['road_access'] != 'roadside') ...[
            const SizedBox(height: AppDesign.space3),
            AppTextField(label: 'landlord.editor.distance'.tr, controller: _distance, keyboardType: TextInputType.number),
          ],
          _label(context, 'landlord.editor.road_condition'.tr),
          _choices('road_condition', ['paved', 'dirt', 'poor'], 'landlord.road_condition.'),
          _label(context, 'landlord.editor.water'.tr),
          _choices('water_source', ['network', 'borehole', 'well', 'none'], 'landlord.water.'),
          _label(context, 'landlord.editor.electricity'.tr),
          _choices('electricity', ['network', 'prepaid', 'solar', 'none'], 'landlord.electricity.'),
          _label(context, 'landlord.editor.security'.tr),
          _choices('security_level', ['high', 'medium', 'low'], 'landlord.security.'),
          const SizedBox(height: AppDesign.space3),
          ImmoSwitchTile(title: 'immo.access.landlocked'.tr, help: 'landlord.editor.landlocked_help'.tr,
              value: _d['is_landlocked'] == true, onChanged: (v) => setState(() => _d['is_landlocked'] = v)),
          ImmoSwitchTile(title: 'immo.access.parking'.tr, value: _d['has_parking'] == true, onChanged: (v) => setState(() => _d['has_parking'] = v)),
          ImmoSwitchTile(title: 'immo.access.fence'.tr, value: _d['has_fence'] == true, onChanged: (v) => setState(() => _d['has_fence'] = v)),
          ImmoSwitchTile(title: 'immo.access.guard'.tr, value: _d['has_guard'] == true, onChanged: (v) => setState(() => _d['has_guard'] = v)),
        ],
      );

  Widget _counter(BuildContext context, String field, String label) {
    final value = (_d[field] as int?) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary))),
          IconButton.outlined(icon: const Icon(Icons.remove_rounded), onPressed: value <= 0 ? null : () => setState(() => _d[field] = value - 1)),
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary))),
          IconButton.outlined(icon: const Icon(Icons.add_rounded), onPressed: value >= 30 ? null : () => setState(() => _d[field] = value + 1)),
        ],
      ),
    );
  }

  Widget _featuresStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _counter(context, 'rooms', 'immo.filters.rooms'.tr),
          _counter(context, 'bedrooms', 'immo.filters.bedrooms'.tr),
          _counter(context, 'bathrooms', 'landlord.editor.bathrooms'.tr),
          const SizedBox(height: AppDesign.space2),
          AppTextField(label: 'landlord.editor.surface'.tr, controller: _surface, keyboardType: TextInputType.number),
          ImmoSwitchTile(title: 'immo.card.furnished'.tr, value: _d['furnished'] == true, onChanged: (v) => setState(() => _d['furnished'] = v)),
          _label(context, 'landlord.editor.units_title'.tr),
          Text('landlord.editor.units_help'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
          const SizedBox(height: AppDesign.space3),
          for (var i = 0; i < _units.length; i++) _unitCard(context, i),
          AppButton(
            label: 'landlord.editor.add_unit'.tr,
            icon: Icons.add_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => setState(() => _units.add({'label': '', 'net_price': null, 'units_total': 1, 'kitchen': 'private'})),
          ),
        ],
      );

  Widget _unitCard(BuildContext context, int i) {
    final u = _units[i];
    Widget field(String key, String label, {bool number = true}) => Expanded(
          child: TextFormField(
            initialValue: u[key] == null ? '' : '${u[key]}',
            keyboardType: number ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
            onChanged: (v) => u[key] = number ? int.tryParse(v) : v,
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space3),
      child: AppCard(
        padding: const EdgeInsets.all(AppDesign.space3),
        child: Column(
          children: [
            Row(children: [
              field('label', 'landlord.editor.unit_label'.tr, number: false),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppDesign.danger), onPressed: () => setState(() => _units.removeAt(i))),
            ]),
            const SizedBox(height: AppDesign.space2),
            Row(children: [
              field('net_price', 'landlord.editor.unit_price'.tr),
              const SizedBox(width: AppDesign.space2),
              field('units_total', 'landlord.editor.unit_total'.tr),
            ]),
            const SizedBox(height: AppDesign.space2),
            Row(children: [
              field('surface_min', 'landlord.editor.unit_surface'.tr),
              const SizedBox(width: AppDesign.space2),
              field('capacity', 'landlord.editor.unit_capacity'.tr),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _priceStep(BuildContext context) {
    final preview = _preview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'landlord.editor.net_price'.tr,
          helperText: 'landlord.editor.net_price_help'.tr,
          controller: _price,
          keyboardType: TextInputType.number,
          onChanged: (_) => _refreshPreview(),
        ),
        const SizedBox(height: AppDesign.space3),
        ImmoMonthsStepper(
          label: 'landlord.editor.advance'.tr,
          value: _d['advance_months'] as int?,
          max: 24,
          onChanged: (v) {
            setState(() => _d['advance_months'] = v);
            _refreshPreview();
          },
        ),
        const SizedBox(height: AppDesign.space3),
        ImmoMonthsStepper(
          label: 'landlord.editor.min_lease'.tr,
          value: _d['min_lease_months'] as int?,
          max: 60,
          onChanged: (v) => setState(() => _d['min_lease_months'] = v),
        ),
        const SizedBox(height: AppDesign.space3),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_available_outlined),
          title: Text('landlord.editor.available_from'.tr),
          subtitle: Text(_d['available_from'] == null
              ? 'immo.card.available_now'.tr
              : immoDate(DateTime.parse(_d['available_from']))),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: now);
            if (picked != null) setState(() => _d['available_from'] = picked.toIso8601String().substring(0, 10));
          },
        ),
        AppTextField(label: 'landlord.editor.old_price'.tr, controller: _oldPrice, keyboardType: TextInputType.number),
        const SizedBox(height: AppDesign.space3),
        AppTextField(label: 'landlord.editor.promo'.tr, hint: 'landlord.editor.promo_hint'.tr, controller: _promo),
        if (preview != null) ...[
          const SizedBox(height: AppDesign.space4),
          AppCard(
            color: AppDesign.accentSubtle,
            showBorder: false,
            padding: const EdgeInsets.all(AppDesign.space4),
            child: Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('landlord.editor.preview_title'.tr,
                        style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: AppDesign.accentText)),
                    const SizedBox(height: AppDesign.space2),
                    Text('landlord.editor.preview_displayed'.trParams({'price': immoPrice((preview['displayed_price'] as num).toInt())}),
                        style: context.textStyle(FontSizeType.body2, color: AppDesign.accentText)),
                    Text('landlord.editor.preview_receive'.trParams({'amount': immoPrice((preview['owner_receives_advance'] as num).toInt())}),
                        style: context.textStyle(FontSizeType.body2, color: AppDesign.accentText)),
                    Text('landlord.editor.preview_blocked'.trParams({'days': '${preview['visit_window_days']}'}),
                        style: context.textStyle(FontSizeType.body2, color: AppDesign.accentText)),
                  ],
                )),
          ),
        ],
      ],
    );
  }

  Future<void> _refreshPreview() async {
    final price = _int(_price);
    if (price == null || price <= 0) return;
    final preview = await RealEstateService.pricePreview(price, _d['advance_months'] as int?);
    if (mounted) setState(() => _preview = preview);
  }

  Widget _amenitiesStep(BuildContext context) {
    final groups = <String, List<RealEstateAmenity>>{};
    for (final a in _amenities) {
      groups.putIfAbsent(a.kind, () => []).add(a);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final kind in ['highlight', 'equipment', 'service'])
          if (groups[kind] != null) ...[
            _label(context, 'landlord.amenity_kind.$kind'.tr),
            Wrap(
              spacing: AppDesign.space2,
              runSpacing: AppDesign.space2,
              children: [
                for (final a in groups[kind]!)
                  FilterChip(
                    avatar: Icon(immoAmenityIcon(a.icon), size: 18),
                    label: Text(a.name),
                    selected: _amenityIds.contains(a.id),
                    selectedColor: AppDesign.accentSubtle,
                    onSelected: (v) => setState(() => v ? _amenityIds.add(a.id) : _amenityIds.remove(a.id)),
                  ),
              ],
            ),
          ],
      ],
    );
  }

  List<Map<String, dynamic>> _roomsPayload() =>
      _rooms.map((r) => {'id': r.id, 'kind': r.kind, 'label': r.label}).toList();

  Future<void> _addRoom() async {
    String kind = 'bedroom';
    final label = TextEditingController();
    final ok = await Get.dialog<bool>(StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text('landlord.editor.add_room'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: kind,
              items: [for (final k in ['entrance', 'living', 'bedroom', 'kitchen', 'bathroom', 'outside', 'road', 'other'])
                DropdownMenuItem(value: k, child: Text('immo.rooms.$k'.tr))],
              onChanged: (v) => setLocal(() => kind = v ?? kind),
            ),
            TextField(controller: label, decoration: InputDecoration(labelText: 'landlord.editor.room_label'.tr)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('common.cancel'.tr)),
          TextButton(onPressed: () => Get.back(result: true), child: Text('landlord.editor.add'.tr)),
        ],
      ),
    ));
    if (ok != true) return;
    await _save(rooms: [..._roomsPayload(), {'kind': kind, 'label': label.text.trim().isEmpty ? 'immo.rooms.$kind'.tr : label.text.trim()}]);
  }

  Future<void> _removeRoom(RealEstateTourRoom room) async {
    await _save(rooms: _roomsPayload().where((r) => r['id'] != room.id).toList());
  }

  Future<void> _addPhotos(RealEstateTourRoom room) async {
    final files = await LandlordPickers.photos();
    if (files.isEmpty || _id == null) return;
    setState(() => _saving = true);
    for (final f in files) {
      await RealEstateService.uploadMedia(_id!, f, roomId: room.id, cover: room.kind == 'entrance');
    }
    final data = await RealEstateService.myListing(_id!);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (data != null) _apply(data);
    });
  }

  Future<void> _deleteMedia(RealEstateMedia media) async {
    await RealEstateService.deleteMedia(_id!, media.id);
    final data = await RealEstateService.myListing(_id!);
    if (mounted && data != null) setState(() => _apply(data));
  }

  Future<void> _addVideo() async {
    final file = await LandlordPickers.video(context);
    if (file == null || _id == null) return;
    setState(() => _saving = true);
    final res = await RealEstateService.uploadMedia(_id!, file);
    final data = await RealEstateService.myListing(_id!);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (data != null) _apply(data);
    });
    if (!res.success) Get.snackbar('landlord.editor.error'.tr, res.message, snackPosition: SnackPosition.BOTTOM);
  }

  Widget _tourStepView(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('landlord.editor.tour_intro'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
          const SizedBox(height: AppDesign.space4),
          for (final room in _rooms) ...[
            AppCard(
              padding: const EdgeInsets.all(AppDesign.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(room.media.isEmpty ? Icons.radio_button_unchecked : Icons.check_circle_rounded,
                        color: room.media.isEmpty ? context.ds.textTertiary : AppDesign.success, size: 20),
                    const SizedBox(width: AppDesign.space2),
                    Expanded(child: Text(immoRoomName(room),
                        style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: context.ds.textPrimary))),
                    if (room.kind != 'entrance')
                      IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: _saving ? null : () => _removeRoom(room)),
                  ]),
                  const SizedBox(height: AppDesign.space2),
                  SizedBox(
                    height: 76,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final m in room.media)
                          Padding(
                            padding: const EdgeInsets.only(right: AppDesign.space2),
                            child: Stack(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                                child: SizedBox(width: 76, height: 76, child: AppNetworkImage(url: m.url, decodeSize: const Size(76, 76))),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: () => _deleteMedia(m),
                                  child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                                ),
                              ),
                            ]),
                          ),
                        InkWell(
                          onTap: _saving ? null : () => _addPhotos(room),
                          borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                          child: Container(
                            width: 76,
                            decoration: BoxDecoration(
                              color: AppDesign.accentSubtle,
                              borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                              border: Border.all(color: AppDesign.accentBorder),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined, color: AppDesign.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDesign.space3),
          ],
          AppButton(label: 'landlord.editor.add_room'.tr, icon: Icons.add_rounded, variant: AppButtonVariant.secondary,
              onPressed: _saving ? null : _addRoom),
          _label(context, 'landlord.editor.video_title'.tr),
          AppCard(
            onTap: _saving ? null : _addVideo,
            color: _video == null ? null : AppDesign.successSubtle,
            padding: const EdgeInsets.all(AppDesign.space4),
            child: Row(children: [
              Icon(_video == null ? Icons.videocam_outlined : Icons.check_circle_rounded, color: _video == null ? AppDesign.accent : AppDesign.success),
              const SizedBox(width: AppDesign.space3),
              Expanded(child: Text(_video == null ? 'landlord.editor.video_add'.tr : 'landlord.editor.video_replace'.tr,
                  style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600, color: context.ds.textPrimary))),
            ]),
          ),
          if (_saving) const Padding(padding: EdgeInsets.all(AppDesign.space4), child: Center(child: CircularProgressIndicator())),
        ],
      );

  Widget _reviewStep(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_rejection != null && _status == 'rejected')
            AppCard(
              color: AppDesign.dangerSubtle,
              showBorder: false,
              padding: const EdgeInsets.all(AppDesign.space3),
              child: Text('landlord.status.reason'.trParams({'reason': _rejection!}),
                  style: context.textStyle(FontSizeType.body2, color: AppDesign.dangerText)),
            ),
          if (_missing.isNotEmpty) ...[
            const SizedBox(height: AppDesign.space3),
            AppCard(
              color: AppDesign.warningSubtle,
              showBorder: false,
              padding: const EdgeInsets.all(AppDesign.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('landlord.editor.missing_title'.tr,
                      style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: AppDesign.warningText)),
                  for (final m in _missing)
                    Text('• ${'landlord.missing.$m'.tr}', style: context.textStyle(FontSizeType.body2, color: AppDesign.warningText)),
                ],
              ),
            ),
          ],
          _label(context, 'landlord.editor.generated_description'.tr),
          Text(_description ?? '', style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary, height: 1.5)),
          const SizedBox(height: AppDesign.space4),
          Text('landlord.editor.review_help'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
        ],
      );
}
