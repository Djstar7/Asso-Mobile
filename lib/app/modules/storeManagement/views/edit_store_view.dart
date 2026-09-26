import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/address_search.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/device_location.dart';
import '../../../core/utils/media_helper.dart';
import '../../../core/utils/location_label.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/map_search_results.dart';
import '../../../data/providers/category_service.dart';
import '../controllers/store_management_controller.dart';
import '../../product/views/map_selection_view.dart';
import '../../../core/utils/app_design.dart';

class EditStoreView extends StatefulWidget {
  const EditStoreView({super.key});

  @override
  State<EditStoreView> createState() => _EditStoreViewState();
}

/// Les champs, le repère et la carte vivent dans l'état de l'écran.
///
/// Ils étaient créés dans `build`, que chaque ouverture ou fermeture du
/// clavier relance (les tailles responsives lisent `MediaQuery`) : l'adresse
/// saisie et le repère déplacé revenaient aux valeurs enregistrées, et
/// « Enregistrer » renvoyait l'ancienne adresse.
class _EditStoreViewState extends State<EditStoreView> {
  StoreManagementController get controller =>
      Get.find<StoreManagementController>();

  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;

  // Position GPS, mise à jour en touchant la carte ou via le bouton de position
  late final Rx<LatLng> selectedPosition;
  final mapController = MapController();

  // « Ville, Pays » recalculé quand le vendeur déplace le repère.
  final resolvedLocation = Rxn<LocationLabel>();
  late final RxnString locationLabel;
  final isResolvingLocation = false.obs;
  final isLocating = false.obs;

  /// Aucun service n'a pu nommer le point choisi : l'adresse reste à saisir.
  final locationFailed = false.obs;

  /// Incrémenté à chaque déplacement du repère : l'adresse d'un point
  /// précédent, arrivée en retard, n'écrase pas celle du point choisi.
  int _positionRequest = 0;

  // Adresses proposées pendant la saisie de l'adresse
  final addressFocus = FocusNode();
  final addressResults = <Map<String, dynamic>>[].obs;
  final isSearchingAddress = false.obs;
  final addressSearchFailed = false.obs;
  final showAddressResults = false.obs;
  Timer? _addressDebounce;

  /// Incrémenté à chaque frappe : une réponse arrivée après une frappe plus
  /// récente n'écrase pas les propositions attendues.
  int _addressRequest = 0;

  /// Logo choisi ici, envoyé avec le formulaire.
  XFile? _pickedLogo;

  /// Catégories proposées : celles du catalogue (les mêmes qu'à l'inscription
  /// du vendeur), sinon cette liste de secours hors connexion.
  final categoryOptions = RxList<String>(_fallbackCategories);

  static const _fallbackCategories = [
    'Alimentation & Boissons',
    'Mode & Vêtements',
    'Électronique',
    'Beauté & Santé',
    'Maison & Décoration',
    'Sports & Loisirs',
    'Livres & Papeterie',
    'Jouets & Enfants',
    'Services',
    'Autres',
  ];

  // Catégories actuelles de la boutique, pré-sélectionnées
  late final RxList<String> selectedCategories;

  @override
  void initState() {
    super.initState();
    final store = controller.storeInfo.value;
    nameController = TextEditingController(text: store?.name ?? '');
    descriptionController = TextEditingController(
      text: store?.description ?? '',
    );
    phoneController = TextEditingController(text: store?.phone ?? '');
    addressController = TextEditingController(text: store?.address ?? '');

    // Boutique sans position (0, 0 : en plein océan) : Douala par défaut.
    final latitude = store?.latitude ?? 0.0;
    final longitude = store?.longitude ?? 0.0;
    final hasPosition = latitude != 0.0 && longitude != 0.0;
    selectedPosition = Rx<LatLng>(
      hasPosition ? LatLng(latitude, longitude) : const LatLng(4.0511, 9.7679),
    );
    locationLabel = RxnString(
      (store?.city.isNotEmpty ?? false) ? store!.city : null,
    );
    selectedCategories = RxList<String>(store?.categories ?? []);
    _loadCategories();

    // Les propositions se referment dès que le champ adresse perd le focus.
    addressFocus.addListener(() {
      if (!addressFocus.hasFocus) _closeAddressSearch();
    });

    // Vérifier la zone de livraison au chargement
    if (hasPosition) {
      Future.delayed(Duration.zero, () {
        controller.checkDeliveryAvailability(latitude, longitude);
      });
    }
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    addressFocus.dispose();
    nameController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    addressController.dispose();
    mapController.dispose();
    super.dispose();
  }

  /// Catégories du catalogue ; la liste de secours reste en cas d'échec.
  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryService.getCategories();
      final names = categories
          .map((category) => category.name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (mounted && names.isNotEmpty) categoryOptions.assignAll(names);
    } catch (_) {}
  }

  /// Puces affichées : le catalogue, plus les catégories déjà enregistrées
  /// qui n'y figurent pas (anciennes valeurs), pour pouvoir les retirer.
  List<String> get _visibleCategories => [
    ...categoryOptions,
    ...selectedCategories.where((c) => !categoryOptions.contains(c)),
  ];

  Future<void> _pickLogo() async {
    final image = await controller.pickLogoImage();
    if (image != null && mounted) setState(() => _pickedLogo = image);
  }

  Future<void> onPositionChanged(LatLng point) async {
    final request = ++_positionRequest;
    selectedPosition.value = point;
    controller.checkDeliveryAvailability(point.latitude, point.longitude);
    isResolvingLocation.value = true;
    locationFailed.value = false;
    final location = await LocationLabel.reverseGeocode(
      point.latitude,
      point.longitude,
    );
    if (!mounted || request != _positionRequest) return;
    isResolvingLocation.value = false;
    if (location == null) {
      // Ville et pays d'un point précédent ne doivent pas partir avec
      // celui-ci : le serveur les déduira de l'adresse saisie.
      resolvedLocation.value = null;
      locationLabel.value = null;
      locationFailed.value = true;
      return;
    }
    resolvedLocation.value = location;
    locationLabel.value = location.label;
    addressController.text = location.address;
  }

  /// Relance la recherche d'adresse après une pause dans la frappe.
  void _onAddressChanged(String value) {
    _addressDebounce?.cancel();
    if (value.trim().length <= 2) {
      _closeAddressSearch();
      return;
    }
    _addressRequest++;
    showAddressResults.value = true;
    isSearchingAddress.value = true;
    addressSearchFailed.value = false;
    _addressDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchAddress(value),
    );
  }

  Future<void> _searchAddress(String query) async {
    final request = ++_addressRequest;
    var results = <Map<String, dynamic>>[];
    var failed = false;
    try {
      // Les lieux proches du repère passent devant.
      results = await AddressSearch.search(
        query,
        nearLatitude: selectedPosition.value.latitude,
        nearLongitude: selectedPosition.value.longitude,
      );
    } on AddressSearchException {
      failed = true;
    }
    if (!mounted || request != _addressRequest) return;
    addressResults.assignAll(results);
    addressSearchFailed.value = failed;
    isSearchingAddress.value = false;
  }

  void _closeAddressSearch() {
    _addressDebounce?.cancel();
    _addressRequest++;
    isSearchingAddress.value = false;
    showAddressResults.value = false;
  }

  /// Adresse proposée choisie : le repère, la ville et le pays la suivent,
  /// comme si le vendeur avait touché ce point sur la carte.
  void _selectAddress(Map<String, dynamic> result) {
    final point = LatLng(
      (result['lat'] as num).toDouble(),
      (result['lon'] as num).toDouble(),
    );
    final location = LocationLabel.fromNominatim(
      result,
      latitude: point.latitude,
      longitude: point.longitude,
    );
    _closeAddressSearch();
    addressFocus.unfocus();

    // Un géocodage inverse encore en cours ne doit plus rien écraser.
    _positionRequest++;
    isResolvingLocation.value = false;
    locationFailed.value = false;
    selectedPosition.value = point;
    resolvedLocation.value = location;
    locationLabel.value = location.label;
    addressController.text = location.address;
    try {
      mapController.move(point, 16.0);
    } catch (_) {
      // Carte pas encore affichée : le repère suffit.
    }
    controller.checkDeliveryAvailability(point.latitude, point.longitude);
  }

  /// Place la boutique sur la position actuelle du téléphone.
  Future<void> locateStore() async {
    if (isLocating.value) return;
    final request = _positionRequest;
    isLocating.value = true;
    final result = await DeviceLocation.current();
    isLocating.value = false;
    // Le vendeur a touché la carte entre-temps : son choix l'emporte.
    if (!mounted || request != _positionRequest) return;

    final position = result.position;
    if (position == null) {
      DeviceLocation.showFailure(
        result,
        hint: 'Touchez la carte pour placer votre boutique.',
      );
      return;
    }
    final point = LatLng(position.latitude, position.longitude);
    mapController.move(point, 15.0);
    await onPositionChanged(point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Modifier la boutique',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      // Le formulaire reste monté du début à la fin : le remplacer par un
      // indicateur pendant l'enregistrement, ou le recréer sous une nouvelle
      // clé quand la boutique change, lui retirait le focus (le clavier se
      // refermait) et le ramenait en haut de page.
      body: SingleChildScrollView(
        // Formulaire long : faire défiler pour relire referme le clavier
        // plutôt que de le laisser masquer la moitié des champs.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(context.horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== SECTION LOGO ==========
            _buildSectionTitle(context, 'Logo de la boutique'),
            const SizedBox(height: 12),
            Center(
              child: Obx(() {
                // Lu d'emblée : un logo choisi ne doit pas laisser ce bloc
                // sans valeur observée (GetX le refuse).
                final logoUrl = controller.storeInfo.value?.logoUrl;
                final hasLogoUrl = logoUrl != null && logoUrl.isNotEmpty;
                return GestureDetector(
                  onTap: _pickLogo,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppThemeSystem.grey200,
                          borderRadius: context.borderRadius(
                            BorderRadiusType.medium,
                          ),
                          border: Border.all(
                            color: AppThemeSystem.primaryColor,
                            width: 2,
                          ),
                          image: _pickedLogo != null
                              ? DecorationImage(
                                  image: MediaHelper.imageProviderFor(
                                    _pickedLogo!,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : hasLogoUrl
                              ? DecorationImage(
                                  image: NetworkImage(logoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _pickedLogo == null && !hasLogoUrl
                            ? Icon(
                                Icons.store,
                                size: 60,
                                color: AppThemeSystem.primaryColor,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppThemeSystem.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),

            SizedBox(height: context.sectionSpacing),

            // ========== SECTION INFORMATIONS ==========
            _buildSectionTitle(context, 'Informations générales'),
            const SizedBox(height: 12),

            // Nom de la boutique
            _buildTextFieldWithController(
              context,
              controller: nameController,
              label: 'Nom de la boutique *',
              hint: 'Ex: Ma Super Boutique',
              icon: Icons.store,
            ),

            SizedBox(height: context.elementSpacing),

            // Description
            _buildTextFieldWithController(
              context,
              controller: descriptionController,
              label: 'Description',
              hint: 'Décrivez votre boutique...',
              icon: Icons.description,
              maxLines: 3,
            ),

            SizedBox(height: context.elementSpacing),

            // Téléphone
            _buildTextFieldWithController(
              context,
              controller: phoneController,
              label: 'Téléphone *',
              hint: 'Ex: +237 690000000',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),

            SizedBox(height: context.sectionSpacing),

            // ========== SECTION CATÉGORIES ==========
            _buildSectionTitle(context, 'Catégories'),
            const SizedBox(height: 12),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _visibleCategories.map((category) {
                  return Obx(() {
                    final isSelected = selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          selectedCategories.add(category);
                        } else {
                          selectedCategories.remove(category);
                        }
                      },
                      backgroundColor: AppThemeSystem.grey100,
                      selectedColor: AppThemeSystem.primaryColor.withValues(
                        alpha: 0.2,
                      ),
                      checkmarkColor: AppThemeSystem.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppThemeSystem.primaryColor
                            : context.primaryTextColor,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    );
                  });
                }).toList(),
              ),
            ),

            SizedBox(height: context.sectionSpacing),

            // ========== SECTION LOCALISATION ==========
            _buildSectionTitle(context, 'Localisation'),
            const SizedBox(height: 12),

            // Boutique placée : emplacement en lecture seule, il change par une
            // demande validée par ASSO. Sinon, premier placement libre.
            Obx(
              () => controller.isShopPlaced
                  ? _buildLockedLocation(context)
                  : _buildLocationEditor(context),
            ),
            SizedBox(height: context.elementSpacing),

            // Statut de la zone de livraison
            Obx(() {
              if (controller.isCheckingDeliveryAvailability.value) {
                return Container(
                  padding: EdgeInsets.all(context.verticalPadding),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    borderRadius: context.borderRadius(BorderRadiusType.medium),
                    border: Border.all(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppThemeSystem.primaryColor,
                          ),
                        ),
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: Text(
                          'Vérification de la zone de livraison...',
                          style: context.body2.copyWith(
                            color: AppThemeSystem.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (controller.isDeliveryAvailable.value) {
                return Container(
                  padding: EdgeInsets.all(context.verticalPadding),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.successColor.withValues(alpha: 0.1),
                    borderRadius: context.borderRadius(BorderRadiusType.medium),
                    border: Border.all(
                      color: AppThemeSystem.successColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppThemeSystem.successColor,
                        size: 20,
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: Text(
                          'Zone de livraison disponible',
                          style: context.body2.copyWith(
                            color: AppThemeSystem.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (controller
                  .deliveryAvailabilityMessage
                  .value
                  .isNotEmpty) {
                return Container(
                  padding: EdgeInsets.all(context.verticalPadding),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.errorColor.withValues(alpha: 0.1),
                    borderRadius: context.borderRadius(BorderRadiusType.medium),
                    border: Border.all(
                      color: AppThemeSystem.errorColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error,
                        color: AppThemeSystem.errorColor,
                        size: 20,
                      ),
                      SizedBox(width: context.elementSpacing),
                      Expanded(
                        child: Text(
                          'Hors zone de livraison - Veuillez choisir un autre emplacement',
                          style: context.body2.copyWith(
                            color: AppThemeSystem.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SizedBox.shrink();
            }),

            SizedBox(height: context.sectionSpacing),

            // ========== BOUTONS D'ACTION ==========
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppNavigation.back(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Obx(() {
                    final saving = controller.isSaving.value;
                    // Tant que l'adresse du repère se calcule, l'enregistrer
                    // enverrait la nouvelle position avec l'ancienne adresse.
                    final locating =
                        isLocating.value || isResolvingLocation.value;
                    return ElevatedButton(
                      onPressed: saving || locating ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeSystem.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Enregistrer les modifications'),
                    );
                  }),
                ),
              ],
            ),
            SizedBox(height: context.sectionSpacing),
          ],
        ),
      ),
    );
  }

  /// Adresse, carte et repère : premier placement de la boutique.
  Widget _buildLocationEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Adresse
        _buildTextFieldWithController(
          context,
          controller: addressController,
          label: 'Adresse complète *',
          hint: 'Quartier, rue, ville…',
          icon: Icons.location_on,
          focusNode: addressFocus,
          onChanged: _onAddressChanged,
        ),

        // Propositions pendant la saisie : en choisir une place le
        // repère, la ville et le pays.
        Obx(() {
          if (!showAddressResults.value) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AddressSuggestionList(
              isSearching: isSearchingAddress.value,
              failed: addressSearchFailed.value,
              results: addressResults.toList(),
              onSelected: _selectAddress,
              scrollable: false,
            ),
          );
        }),

        SizedBox(height: context.elementSpacing),

        // Map avec sélection de position
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            border: Border.all(color: context.borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Obx(
            () => Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: selectedPosition.value,
                    initialZoom: 15.0,
                    onTap: (tapPosition, point) => onPositionChanged(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.asso.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: selectedPosition.value,
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.location_pin,
                            size: 40,
                            color: AppThemeSystem.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white,
                    onPressed: locateStore,
                    child: isLocating.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppThemeSystem.primaryColor,
                            ),
                          )
                        : Icon(
                            Icons.my_location,
                            color: AppThemeSystem.primaryColor,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        Obx(
          () => Row(
            children: [
              const Icon(
                Icons.place_rounded,
                size: 20,
                color: AppThemeSystem.primaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isResolvingLocation.value
                      ? 'Recherche de la ville…'
                      : locationFailed.value
                      ? 'Ville introuvable pour ce point : précisez l’adresse'
                      : (locationLabel.value ??
                            'Touchez la carte pour placer votre boutique'),
                  style: context.body1.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tapez l’adresse et choisissez une proposition, ou touchez la carte : le repère, l’adresse et la ville se mettent à jour ensemble.',
          style: context.caption.copyWith(color: context.secondaryTextColor),
        ),
      ],
    );
  }

  /// Emplacement d'une boutique déjà placée : lecture seule, avec l'état de la
  /// demande de changement et le bouton pour en faire une.
  Widget _buildLockedLocation(BuildContext context) {
    final ds = context.ds;
    final store = controller.storeInfo.value!;
    final point = LatLng(store.latitude, store.longitude);
    final pending = controller.pendingLocationRequest.value;
    final rejected = controller.rejectedLocationRequest.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          clipContent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 160,
                child: IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.asso.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: AppDesign.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(AppDesign.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.storefront_outlined, size: 20, color: ds.icon),
                    SizedBox(width: AppDesign.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.address.isNotEmpty
                                ? store.address
                                : 'Adresse non renseignée',
                            style: context.body1.copyWith(
                              fontWeight: FontWeight.w600,
                              color: ds.textPrimary,
                            ),
                          ),
                          if (store.city.isNotEmpty) ...[
                            SizedBox(height: 2),
                            Text(
                              store.city,
                              style: context.body2.copyWith(
                                color: ds.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppDesign.space2),
        Text(
          'L’emplacement est vérifié par ASSO : pour déménager, envoyez une demande. La boutique change d’adresse une fois la demande validée.',
          style: context.caption.copyWith(color: ds.textSecondary),
        ),
        if (pending != null) ...[
          SizedBox(height: AppDesign.space3),
          _RequestNotice(
            icon: Icons.schedule_outlined,
            title: 'Demande en attente de validation',
            message:
                '${pending['address'] ?? 'Nouvel emplacement'} · envoyée le ${_formatDate(pending['created_at'])}',
            background: AppDesign.warningSubtle,
            foreground: AppDesign.warningText,
          ),
        ] else if (rejected != null) ...[
          SizedBox(height: AppDesign.space3),
          _RequestNotice(
            icon: Icons.block_outlined,
            title: 'Dernière demande refusée',
            message: rejected['rejection_reason']?.toString().isNotEmpty == true
                ? rejected['rejection_reason'].toString()
                : 'Contactez le support pour en savoir plus.',
            background: AppDesign.dangerSubtle,
            foreground: AppDesign.dangerText,
          ),
        ],
        SizedBox(height: AppDesign.space3),
        AppButton(
          label: pending != null
              ? 'Modifier ma demande'
              : 'Demander un changement d’emplacement',
          icon: Icons.edit_location_alt_outlined,
          variant: AppButtonVariant.secondary,
          isLoading: controller.isRequestingLocation.value,
          onPressed: _requestLocationChange,
        ),
      ],
    );
  }

  static String _formatDate(dynamic iso) {
    final date = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (date == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  /// Nouvel emplacement choisi sur la carte, puis demande envoyée à ASSO.
  Future<void> _requestLocationChange() async {
    AppNavigation.dismissKeyboard();
    if (!await controller.canMoveShop()) return;

    final pending = controller.pendingLocationRequest.value;
    final store = controller.storeInfo.value;
    final startLatitude =
        double.tryParse('${pending?['latitude']}') ?? store?.latitude;
    final startLongitude =
        double.tryParse('${pending?['longitude']}') ?? store?.longitude;

    final result = await Get.to<Map<String, dynamic>>(
      () => MapSelectionView(
        initialLatitude: startLatitude,
        initialLongitude: startLongitude,
        locationName: pending?['address']?.toString() ?? store?.address,
      ),
      transition: Transition.rightToLeft,
    );
    final latitude = (result?['latitude'] as num?)?.toDouble();
    final longitude = (result?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null || !mounted) return;

    final sent = await AppSheet.show<bool>(
      _LocationRequestSheet(
        latitude: latitude,
        longitude: longitude,
        fallbackAddress: result?['address']?.toString(),
        initialReason: pending?['reason']?.toString(),
      ),
    );
    if (sent == true) {
      Get.snackbar(
        'Demande envoyée',
        'ASSO vérifie le nouvel emplacement. Vous serez prévenu de la décision.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _save() async {
    print('');
    print('========================================');
    print('🔘 EDIT STORE VIEW: Save button clicked');
    print('========================================');

    // Get values from controllers
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    final address = addressController.text.trim();
    final phone = phoneController.text.trim();

    print('');
    print('📝 Values to be sent to saveStoreInfo:');
    print('  ├─ Name: $name');
    print('  ├─ Description: $description');
    print('  ├─ Address: $address');
    print('  ├─ Phone: $phone');
    print('  ├─ Categories: ${selectedCategories.toList()}');
    print('  ├─ Latitude: ${selectedPosition.value.latitude}');
    print('  └─ Longitude: ${selectedPosition.value.longitude}');

    if (name.isEmpty) {
      Get.snackbar(
        'Erreur',
        'Le nom de la boutique est requis',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return;
    }

    if (!controller.isShopPlaced && address.isEmpty) {
      Get.snackbar(
        'Erreur',
        'L\'adresse est requise',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return;
    }

    if (phone.isEmpty) {
      Get.snackbar(
        'Erreur',
        'Le téléphone est requis',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return;
    }

    // Limite du serveur : au-delà, il refusait tout l'enregistrement.
    if (phone.length > 20) {
      Get.snackbar(
        'Erreur',
        'Le téléphone ne doit pas dépasser 20 caractères',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return;
    }

    print('');
    print('🚀 Calling controller.saveStoreInfo...');
    print('========================================');

    AppNavigation.dismissKeyboard();
    _closeAddressSearch();
    final saved = await controller.saveStoreInfo(
      name: name,
      // Vide compris : le vendeur peut effacer sa description.
      description: description,
      address: address,
      city: locationLabel.value ?? '',
      locationCity: resolvedLocation.value?.city,
      locationCountry: resolvedLocation.value?.country,
      phone: phone,
      latitude: selectedPosition.value.latitude,
      longitude: selectedPosition.value.longitude,
      categories: selectedCategories.toList(),
      logo: _pickedLogo,
    );

    // Pas `Get.back()` : un snackbar encore affiché (champ manquant, hors
    // zone…) aurait été fermé à la place de l'écran, laissant croire que
    // l'enregistrement n'avait pas abouti.
    if (saved && mounted) AppNavigation.closeRoute(context);
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppThemeSystem.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: context.h6.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextFieldWithController(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.body2.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.small),
            ),
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: context.inputFieldColor,
          ),
        ),
      ],
    );
  }
}

/// Bandeau d'état d'une demande de changement d'emplacement.
class _RequestNotice extends StatelessWidget {
  const _RequestNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          SizedBox(width: AppDesign.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
                SizedBox(height: 2),
                Text(message, style: context.body2.copyWith(color: foreground)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation de la demande : adresse lue sur la carte (modifiable), motif
/// facultatif pour l'équipe ASSO, puis envoi.
class _LocationRequestSheet extends StatefulWidget {
  const _LocationRequestSheet({
    required this.latitude,
    required this.longitude,
    this.fallbackAddress,
    this.initialReason,
  });

  final double latitude;
  final double longitude;
  final String? fallbackAddress;
  final String? initialReason;

  @override
  State<_LocationRequestSheet> createState() => _LocationRequestSheetState();
}

class _LocationRequestSheetState extends State<_LocationRequestSheet> {
  StoreManagementController get controller =>
      Get.find<StoreManagementController>();

  final addressController = TextEditingController();
  late final reasonController = TextEditingController(
    text: widget.initialReason ?? '',
  );
  LocationLabel? _location;
  bool _resolving = true;

  @override
  void initState() {
    super.initState();
    addressController.text = widget.fallbackAddress ?? '';
    _resolve();
  }

  /// Ville et pays du point choisi, repris par ASSO à la validation.
  Future<void> _resolve() async {
    LocationLabel? location;
    try {
      location = await LocationLabel.reverseGeocode(
        widget.latitude,
        widget.longitude,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _location = location;
      _resolving = false;
      if (location != null && addressController.text.trim().isEmpty) {
        addressController.text = location.address;
      }
    });
  }

  @override
  void dispose() {
    addressController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final address = addressController.text.trim();
    if (address.isEmpty) {
      Get.snackbar(
        'Adresse manquante',
        'Indiquez l’adresse du nouvel emplacement.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final ok = await controller.requestLocationChange(
      latitude: widget.latitude,
      longitude: widget.longitude,
      address: address,
      city: _location?.city,
      country: _location?.country,
      reason: reasonController.text,
    );
    // Pas `Get.back()` : il fermerait d'abord un snackbar encore affiché.
    if (ok && mounted) AppNavigation.closeRoute(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return AppSheet(
      title: 'Nouvel emplacement',
      subtitle: 'ASSO vérifie la demande avant de déplacer votre boutique.',
      footer: Obx(
        () => AppButton(
          label: 'Envoyer la demande',
          icon: Icons.send_rounded,
          size: AppButtonSize.large,
          isLoading: controller.isRequestingLocation.value,
          onPressed: _resolving ? null : _send,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: ds.icon),
              SizedBox(width: AppDesign.space2),
              Expanded(
                child: Text(
                  _resolving
                      ? 'Recherche de la ville…'
                      : (_location?.label ??
                            'Ville introuvable : précisez l’adresse'),
                  style: context.body2.copyWith(color: ds.textSecondary),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDesign.space3),
          AppTextField(
            controller: addressController,
            label: 'Adresse',
            hint: 'Quartier, rue, repère…',
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: AppDesign.space3),
          AppTextField(
            controller: reasonController,
            label: 'Motif (facultatif)',
            hint: 'Ex. nouveau local, repère mal placé…',
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
