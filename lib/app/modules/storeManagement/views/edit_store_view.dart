import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/store_management_controller.dart';

class EditStoreView extends GetView<StoreManagementController> {
  const EditStoreView({super.key});

  @override
  Widget build(BuildContext context) {
    // Text editing controllers - Initialize once
    final nameController = TextEditingController(
      text: controller.storeInfo.value?.name ?? '',
    );
    final descriptionController = TextEditingController(
      text: controller.storeInfo.value?.description ?? '',
    );
    final phoneController = TextEditingController(
      text: controller.storeInfo.value?.phone ?? '',
    );
    final addressController = TextEditingController(
      text: controller.storeInfo.value?.address ?? '',
    );

    // Position GPS - Initialize once, will be updated via map interaction
    final selectedPosition = Rx<LatLng>(
      LatLng(
        controller.storeInfo.value?.latitude ?? 4.0511,
        controller.storeInfo.value?.longitude ?? 9.7679,
      ),
    );

    // Vérifier la zone de livraison au chargement
    Future.delayed(Duration.zero, () {
      final oldLat = controller.storeInfo.value?.latitude ?? 0.0;
      final oldLng = controller.storeInfo.value?.longitude ?? 0.0;
      if (oldLat != 0.0 && oldLng != 0.0) {
        controller.checkDeliveryAvailability(oldLat, oldLng);
      }
    });

    final mapController = MapController();

    // Catégories disponibles
    final availableCategories = [
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

    // Pré-sélectionner les catégories actuelles de la boutique
    final selectedCategories = RxList<String>(
      controller.storeInfo.value?.categories ?? [],
    );

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: context.primaryTextColor,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Modifier la boutique',
          style: context.h5.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // Force rebuild when storeInfo changes by using a unique key
        final storeKey = '${controller.storeInfo.value?.id ?? ''}_${controller.storeInfo.value?.name ?? ''}_${controller.storeInfo.value?.description ?? ''}_${controller.storeInfo.value?.phone ?? ''}';

        return SingleChildScrollView(
          key: ValueKey(storeKey),
          padding: EdgeInsets.all(context.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ========== SECTION LOGO ==========
              _buildSectionTitle(context, 'Logo de la boutique'),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: controller.pickLogo,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppThemeSystem.grey200,
                          borderRadius:
                              context.borderRadius(BorderRadiusType.medium),
                          border: Border.all(
                            color: AppThemeSystem.primaryColor,
                            width: 2,
                          ),
                          image: controller.selectedLogo.value != null
                              ? DecorationImage(
                                  image: FileImage(
                                    controller.selectedLogo.value!,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : controller.storeInfo.value?.logoUrl != null &&
                                      controller.storeInfo.value!.logoUrl!
                                          .isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        controller.storeInfo.value!.logoUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: controller.selectedLogo.value == null &&
                                (controller.storeInfo.value?.logoUrl == null ||
                                    controller.storeInfo.value!.logoUrl!.isEmpty)
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
                ),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableCategories.map((category) {
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
                      selectedColor:
                          AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                      checkmarkColor: AppThemeSystem.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppThemeSystem.primaryColor
                            : context.primaryTextColor,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  });
                }).toList(),
              ),

              SizedBox(height: context.sectionSpacing),

              // ========== SECTION LOCALISATION ==========
              _buildSectionTitle(context, 'Localisation'),
              const SizedBox(height: 12),

              // Adresse
              _buildTextFieldWithController(
                context,
                controller: addressController,
                label: 'Adresse complète *',
                hint: 'Ex: Avenue de la République, Douala',
                icon: Icons.location_on,
              ),

              SizedBox(height: context.elementSpacing),

              // Map avec sélection de position
              Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: context.borderRadius(BorderRadiusType.medium),
                  border: Border.all(color: context.borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Obx(() => Stack(
                      children: [
                        FlutterMap(
                          mapController: mapController,
                          options: MapOptions(
                            initialCenter: selectedPosition.value,
                            initialZoom: 15.0,
                            onTap: (tapPosition, point) {
                              selectedPosition.value = point;
                              // Vérifier la zone de livraison quand l'utilisateur change la position
                              controller.checkDeliveryAvailability(
                                point.latitude,
                                point.longitude,
                              );
                            },
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
                            onPressed: () async {
                              // Obtenir la position actuelle
                              try {
                                bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                if (!serviceEnabled) {
                                  Get.snackbar(
                                    'Erreur',
                                    'Les services de localisation sont désactivés',
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                  return;
                                }

                                LocationPermission permission = await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission = await Geolocator.requestPermission();
                                  if (permission == LocationPermission.denied) {
                                    Get.snackbar(
                                      'Erreur',
                                      'Permission de localisation refusée',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                    return;
                                  }
                                }

                                Position position = await Geolocator.getCurrentPosition();
                                selectedPosition.value = LatLng(
                                  position.latitude,
                                  position.longitude,
                                );
                                mapController.move(
                                  selectedPosition.value,
                                  15.0,
                                );
                                // Vérifier la zone de livraison
                                controller.checkDeliveryAvailability(
                                  position.latitude,
                                  position.longitude,
                                );
                              } catch (e) {
                                Get.snackbar(
                                  'Erreur',
                                  'Impossible d\'obtenir votre position',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              }
                            },
                            child: Icon(
                              Icons.my_location,
                              color: AppThemeSystem.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    )),
              ),

              const SizedBox(height: 8),
              Obx(() => Text(
                    'Latitude: ${selectedPosition.value.latitude.toStringAsFixed(6)}, '
                    'Longitude: ${selectedPosition.value.longitude.toStringAsFixed(6)}',
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  )),

              SizedBox(height: context.elementSpacing),

              // Pending location request warning
              Obx(() {
                if (controller.hasLocationUpdatePending.value) {
                  return Container(
                    margin: EdgeInsets.only(bottom: context.elementSpacing),
                    padding: EdgeInsets.all(context.verticalPadding),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.warningColor.withValues(alpha: 0.1),
                      borderRadius: context.borderRadius(BorderRadiusType.medium),
                      border: Border.all(
                        color: AppThemeSystem.warningColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pending_actions,
                          color: AppThemeSystem.warningColor,
                          size: 20,
                        ),
                        SizedBox(width: context.elementSpacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Demande de changement de localisation en attente',
                                style: context.body2.copyWith(
                                  color: AppThemeSystem.warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Votre nouvelle localisation sera effective après validation par un administrateur.',
                                style: context.caption.copyWith(
                                  color: AppThemeSystem.warningColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox.shrink();
              }),

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
                } else if (controller.deliveryAvailabilityMessage.value.isNotEmpty) {
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
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
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
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        if (address.isEmpty) {
                          Get.snackbar(
                            'Erreur',
                            'L\'adresse est requise',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        if (phone.isEmpty) {
                          Get.snackbar(
                            'Erreur',
                            'Le téléphone est requis',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        print('');
                        print('🚀 Calling controller.saveStoreInfo...');
                        print('========================================');

                        controller.saveStoreInfo(
                          name: name,
                          description: description.isEmpty ? null : description,
                          address: address,
                          city: '', // Sera extrait de l'adresse
                          phone: phone,
                          latitude: selectedPosition.value.latitude,
                          longitude: selectedPosition.value.longitude,
                          categories: selectedCategories.toList(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeSystem.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Enregistrer les modifications'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sectionSpacing),
            ],
          ),
        );
      }),
    );
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
        Text(
          title,
          style: context.h6.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String initialValue,
    required String label,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.body2.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(initialValue),
          initialValue: initialValue,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
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

  Widget _buildTextFieldWithController(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.body2.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
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
