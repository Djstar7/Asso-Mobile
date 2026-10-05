import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/device_location.dart';
import '../../../core/utils/location_label.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/delivery_details_widgets.dart';
import '../../../core/widgets/free_delivery_widgets.dart';
import '../../../data/models/delivery_info.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../product/views/map_selection_view.dart';

/// Livraison d'une commande en gros après son arrivée à Douala : adresse du
/// client, puis offre SOLEX (ou autre partenaire) chiffrée depuis l'entrepôt
/// ASSO de Douala jusqu'à cette adresse. Le client paie tout à la commande.
class WholesaleDelivery extends ChangeNotifier {
  WholesaleDelivery({required this.items}) {
    final phone = (StorageService.getUser()?.phone ?? '').trim();
    if (phone.isNotEmpty) phoneController.text = phone;
    // La feuille de commande grise son bouton tant qu'une étape manque : elle
    // doit se redessiner à chaque caractère saisi.
    detailsController.addListener(notifyListeners);
    phoneController.addListener(notifyListeners);
  }

  /// Lignes commandées ({product_id, quantity, price_tier_id}) : le prix
  /// dépend du poids, celui d'une unité du palier.
  final List<Map<String, int>> Function() items;

  final detailsController = TextEditingController();
  final phoneController = TextEditingController();

  String address = '';
  String? city;
  double? latitude;
  double? longitude;
  bool locating = false;
  DeviceLocationResult? locationFailure;

  bool loading = false;
  Map<String, dynamic>? quote;
  List<Map<String, dynamic>> offers = const [];
  Map<String, dynamic>? _selected;
  int _request = 0;
  String _quotedItems = '';

  bool get hasLocation =>
      address.trim().isNotEmpty && latitude != null && longitude != null;

  DeliveryPartnerQuote? get selected =>
      _selected == null ? null : DeliveryPartnerQuote(_selected!);

  /// Prix affiché de la course choisie (barré si elle est offerte).
  double get price => selected?.price ?? 0;

  /// Ce que l'acheteur paie pour la course : rien si le vendeur l'offre.
  double get buyerPrice => selected?.buyerPrice ?? 0;

  bool get isFree => selected?.isFree ?? false;

  double? get weightKg {
    final raw = quote?['weight_kg'];
    return raw is num ? raw.toDouble() : double.tryParse('$raw');
  }

  bool get hasValidPhone {
    final digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 && digits.length <= 15;
  }

  /// Ce qui manque avant de payer ; null quand la livraison est prête.
  String? get missingStep {
    if (!hasLocation) return 'import.delivery.missing_address'.tr;
    if (detailsController.text.trim().isEmpty) {
      return 'import.delivery.missing_details'.tr;
    }
    if (!hasValidPhone) return 'import.delivery.missing_phone'.tr;
    if (loading) return 'import.delivery.computing'.tr;
    if (selected == null) {
      return quote?['message']?.toString() ?? 'import.delivery.choose_offer'.tr;
    }
    return null;
  }

  void select(Map<String, dynamic> offer) {
    _selected = offer;
    notifyListeners();
  }

  Future<void> useCurrentPosition() async {
    locating = true;
    locationFailure = null;
    notifyListeners();
    try {
      final result = await DeviceLocation.current();
      final position = result.position;
      if (position == null) {
        locationFailure = result;
        return;
      }
      await _setPosition(position.latitude, position.longitude);
    } finally {
      locating = false;
      notifyListeners();
    }
    await load();
  }

  Future<void> pickOnMap() async {
    final result = await Get.to<Map<String, dynamic>>(
      () => MapSelectionView(
        initialLatitude: latitude,
        initialLongitude: longitude,
        locationName: hasLocation ? address : null,
      ),
      transition: Transition.rightToLeft,
    );
    final lat = (result?['latitude'] as num?)?.toDouble();
    final lng = (result?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    locating = true;
    notifyListeners();
    try {
      await _setPosition(lat, lng, fallback: result?['address']?.toString());
    } finally {
      locating = false;
      notifyListeners();
    }
    await load();
  }

  Future<void> _setPosition(double lat, double lng, {String? fallback}) async {
    latitude = lat;
    longitude = lng;
    locationFailure = null;
    LocationLabel? label;
    try {
      // Borné : sans réponse du géocodeur, les boutons restaient grisés.
      label = await LocationLabel.reverseGeocode(
        lat,
        lng,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
    city = label?.city;
    address =
        label?.address ??
        (fallback?.trim().isNotEmpty == true
            ? fallback!.trim()
            : 'import.delivery.gps_position'.trParams({
                'lat': lat.toStringAsFixed(4),
                'lng': lng.toStringAsFixed(4),
              }));
  }

  /// Recalcule les offres si les quantités ont changé depuis le dernier devis.
  void refreshIfItemsChanged() {
    if (hasLocation && _itemsKey() != _quotedItems) load();
  }

  String _itemsKey() => items().map((line) => line.values.join(':')).join(',');

  Future<void> load() async {
    if (!hasLocation) return;
    final lines = items();
    if (lines.isEmpty) return;

    final request = ++_request;
    final previousKey = selected?.key;
    _quotedItems = _itemsKey();
    loading = true;
    notifyListeners();

    try {
      final response = await DeliveryService.getDeliveryQuotesForItems(
        items: lines,
        latitude: latitude,
        longitude: longitude,
        city: city ?? address,
        address: address,
      );
      if (request != _request) return; // devis périmé

      final rawQuote = response.data?['quote'];
      quote = rawQuote is Map ? Map<String, dynamic>.from(rawQuote) : null;
      final rawPartners = response.data?['partners'];
      offers = rawPartners is List
          ? rawPartners
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const [];
      // Garder l'offre choisie si le nouveau devis la propose encore.
      _selected =
          offers.firstWhereOrNull(
            (o) => DeliveryPartnerQuote(o).key == previousKey,
          ) ??
          offers.firstOrNull;
      if (!response.success && offers.isEmpty) {
        quote = {...?quote, 'message': response.message};
      }
    } catch (_) {
      if (request != _request) return;
      offers = const [];
      _selected = null;
      quote = {'message': 'import.delivery.quote_failed'.tr};
    } finally {
      if (request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Champs de la commande en gros (POST /v1/import/orders).
  Map<String, dynamic> orderFields() {
    final offer = selected!;
    final details = detailsController.text.trim();
    final country = quote?['destination'] is Map
        ? quote!['destination']['country']?.toString()
        : null;
    return {
      'delivery_company_id': offer.companyId,
      if (offer.zoneId != null) 'delivery_zone_id': offer.zoneId,
      if (offer.routeId != null) 'delivery_route_id': offer.routeId,
      if (offer.gridId != null) 'delivery_grid_id': offer.gridId,
      if (offer.vehicle != null) 'delivery_vehicle': offer.vehicle,
      'delivery_city': city ?? address,
      if (country != null && country.isNotEmpty) 'delivery_country': country,
      'delivery_address': address,
      if (details.isNotEmpty) 'delivery_address_details': details,
      'customer_phone': phoneController.text.trim(),
      'delivery_latitude': latitude,
      'delivery_longitude': longitude,
    };
  }

  @override
  void dispose() {
    detailsController.removeListener(notifyListeners);
    phoneController.removeListener(notifyListeners);
    detailsController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}

/// Carte « Livraison depuis Douala » de la fiche gros.
class WholesaleDeliverySection extends StatelessWidget {
  const WholesaleDeliverySection({
    super.key,
    required this.delivery,
    required this.formatPrice,
  });

  final WholesaleDelivery delivery;
  final PriceFormatter formatPrice;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: delivery,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _address(context),
          const SizedBox(height: AppDesign.space3),
          AppTextField(
            controller: delivery.detailsController,
            label: 'import.delivery.details_label'.tr,
            hint: 'import.delivery.details_hint'.tr,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDesign.space3),
          AppTextField(
            controller: delivery.phoneController,
            label: 'import.delivery.phone_label'.tr,
            hint: 'import.delivery.phone_hint'.tr,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
          const SizedBox(height: AppDesign.space4),
          _offers(context),
        ],
      ),
    );
  }

  Widget _address(BuildContext context) {
    final failure = delivery.locationFailure;
    return Container(
      padding: const EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(
        color: context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        border: Border.all(
          color: delivery.hasLocation || delivery.locating
              ? context.ds.border
              : AppThemeSystem.warningColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              delivery.locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.location_on_rounded,
                      color: AppDesign.accent,
                    ),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                child: Text(
                  delivery.locating
                      ? 'import.delivery.locating'.tr
                      : delivery.hasLocation
                      ? delivery.address
                      : 'import.delivery.where_to_deliver'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w600,
                    color: context.ds.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (!delivery.locating && failure?.message != null) ...[
            const SizedBox(height: AppDesign.space2),
            Text(
              failure!.message!,
              style: context.textStyle(
                FontSizeType.caption,
                color: AppThemeSystem.warningColor,
              ),
            ),
          ],
          const SizedBox(height: AppDesign.space3),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: failure?.needsSettings == true
                      ? 'import.delivery.settings'.tr
                      : 'import.delivery.my_position'.tr,
                  icon: Icons.my_location_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: delivery.locating
                      ? null
                      : failure?.needsSettings == true
                      ? () => DeviceLocation.openSettings(failure!.failure)
                      : delivery.useCurrentPosition,
                ),
              ),
              const SizedBox(width: AppDesign.space2),
              Expanded(
                child: AppButton(
                  label: delivery.hasLocation
                      ? 'import.delivery.edit'.tr
                      : 'import.delivery.on_map'.tr,
                  icon: Icons.edit_location_alt_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: delivery.locating ? null : delivery.pickOnMap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _offers(BuildContext context) {
    if (!delivery.hasLocation) {
      return DeliveryNotice(
        'import.delivery.address_needed'.tr,
        icon: Icons.local_shipping_outlined,
      );
    }
    if (delivery.loading) {
      return const Padding(
        padding: EdgeInsets.all(AppDesign.space4),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (delivery.offers.isEmpty) {
      final grid = delivery.quote?['city_grid'];
      final outOfZone = grid is Map && grid['quarter_required'] == true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeliveryNotice(
            outOfZone
                ? 'import.delivery.out_of_zone'.trParams({
                    'city': '${grid['city']}',
                  })
                : delivery.quote?['message']?.toString() ??
                      'import.delivery.no_offer'.tr,
            icon: Icons.info_outline_rounded,
            color: AppThemeSystem.warningColor,
          ),
          if (outOfZone) ...[
            const SizedBox(height: AppDesign.space2),
            AppButton(
              label: 'import.delivery.see_zones'.tr,
              icon: Icons.map_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: delivery.pickOnMap,
            ),
          ],
        ],
      );
    }

    final weight = delivery.weightKg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (weight != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDesign.space2),
            child: Text(
              'import.delivery.parcel_weight'.trParams({
                'weight': formatKg(weight),
              }),
              style: context.textStyle(
                FontSizeType.caption,
                color: context.ds.textSecondary,
              ),
            ),
          ),
        for (final raw in delivery.offers)
          _offerTile(context, DeliveryPartnerQuote(raw)),
      ],
    );
  }

  Widget _offerTile(BuildContext context, DeliveryPartnerQuote offer) {
    final isSelected = delivery.selected?.key == offer.key;
    final lines = [
      ?offer.routeOrZone,
      if (offer.leadTime != null)
        'import.delivery.lead_time'.trParams({'time': '${offer.leadTime}'}),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space2),
      child: Material(
        color: isSelected ? AppDesign.accentSubtle : context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        child: InkWell(
          onTap: () => delivery.select(offer.raw),
          borderRadius: BorderRadius.circular(AppDesign.radiusSm),
          child: Container(
            padding: const EdgeInsets.all(AppDesign.space3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              border: Border.all(
                color: isSelected ? AppDesign.accent : context.ds.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        offer.companyName,
                        style: context.textStyle(
                          FontSizeType.body2,
                          fontWeight: FontWeight.w700,
                          color: context.ds.textPrimary,
                        ),
                      ),
                    ),
                    DeliveryPriceText(
                      price: formatPrice(offer.price),
                      isFree: offer.isFree,
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.w800,
                        color: AppDesign.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesign.space1),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    DeliveryChip(
                      offer.deliveryOptionLabel,
                      color: AppThemeSystem.grey700,
                      icon: offer.isAgencyPickup
                          ? Icons.store_mall_directory_outlined
                          : Icons.home_outlined,
                    ),
                    if (offer.vehicleLabel != null)
                      DeliveryChip(
                        offer.vehicleLabel!,
                        color: AppDesign.accent,
                        icon: Icons.local_shipping_outlined,
                      ),
                  ],
                ),
                for (final line in lines) ...[
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: context.ds.textSecondary,
                    ),
                  ),
                ],
                if (offer.pickupNotice != null) ...[
                  const SizedBox(height: AppDesign.space2),
                  DeliveryNotice(
                    offer.pickupNotice!,
                    icon: Icons.store_mall_directory_outlined,
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => showDeliveryQuoteDetails(
                      context,
                      offer,
                      formatPrice: formatPrice,
                      weightKg: delivery.weightKg,
                      onChoose: () => delivery.select(offer.raw),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text('import.delivery.details'.tr),
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesign.accent,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
