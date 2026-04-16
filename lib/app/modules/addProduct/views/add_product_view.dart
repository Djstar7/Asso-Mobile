import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/add_product_controller.dart';

class AddProductView extends GetView<AddProductController> {
  const AddProductView({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: Obx(() => Text(
          controller.isEditMode.value ? 'Modifier le produit' : 'Ajouter un produit',
          style: context.h5.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animation de chargement
                Container(
                  padding: EdgeInsets.all(context.horizontalPadding * 1.5),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircularProgressIndicator(
                    color: AppThemeSystem.primaryColor,
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: context.sectionSpacing),
                Text(
                  'Chargement des données...',
                  style: context.h6.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.elementSpacing * 0.5),
                Text(
                  'Récupération des catégories et packages',
                  style: context.caption.copyWith(
                    color: context.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
        padding: EdgeInsets.only(
          left: context.horizontalPadding,
          right: context.horizontalPadding,
          top: context.verticalPadding,
          bottom: MediaQuery.of(context).viewPadding.bottom + context.verticalPadding * 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Images
            _buildImagesSection(context),
            SizedBox(height: context.sectionSpacing),
            // Nom du produit
            _buildNameSection(context),
            SizedBox(height: context.sectionSpacing),
            // Catégorie (Bottom sheet)
            _buildCategorySelector(context),
            SizedBox(height: context.sectionSpacing),
            // Sous-catégorie (Bottom sheet)
            _buildSubcategorySelector(context),
            SizedBox(height: context.sectionSpacing),
            // Prix
            _buildPriceSection(context),
            SizedBox(height: context.sectionSpacing),
            // Description
            _buildDescriptionSection(context),
            SizedBox(height: context.sectionSpacing),
            // Poids du produit
            _buildWeightSection(context),
            SizedBox(height: context.sectionSpacing),
            // Stock
            _buildStockSection(context),
            SizedBox(height: context.sectionSpacing),
            // Espace de stockage
            _buildStorageSection(context),
            SizedBox(height: context.sectionSpacing),
            // Bouton de soumission
            _buildSubmitButton(context),
            SizedBox(height: context.elementSpacing),
          ],
        ),
      );
      }),
    );
  }

  /// Section Images avec sélection multiple et choix de l'image primaire
  Widget _buildImagesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Images du produit',
              style: context.h5.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppThemeSystem.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Obligatoire',
                style: context.caption.copyWith(
                  color: AppThemeSystem.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.elementSpacing * 0.5),
        Text(
          'Ajoutez plusieurs images et sélectionnez l\'image principale',
          style: context.caption.copyWith(
            color: context.secondaryTextColor,
          ),
        ),
        SizedBox(height: context.elementSpacing),

        Obx(() {
          return SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Bouton unique pour upload images
                _buildAddImageButton(
                  context,
                  icon: Icons.add_photo_alternate,
                  label: 'Upload Images',
                  onTap: () => _showImageSourceBottomSheet(context),
                ),
                SizedBox(width: context.elementSpacing),

                // Liste des images
                ...List.generate(controller.productImages.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(right: context.elementSpacing),
                    child: _buildImageThumbnail(context, index),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAddImageButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(
            color: AppThemeSystem.primaryColor,
            width: 2,
            style: BorderStyle.none,
          ),
        ),
        child: DottedBorder(
          color: AppThemeSystem.primaryColor,
          strokeWidth: 2,
          dashPattern: const [8, 4],
          borderType: BorderType.RRect,
          radius: const Radius.circular(12),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward,
                    color: AppThemeSystem.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: context.caption.copyWith(
                    color: AppThemeSystem.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(BuildContext context, int index) {
    return Obx(() {
      final isPrimary = controller.primaryImageIndex.value == index;

      return Stack(
        children: [
          GestureDetector(
            onTap: () => controller.setPrimaryImage(index),
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                border: Border.all(
                  color: isPrimary
                      ? AppThemeSystem.successColor
                      : context.borderColor,
                  width: isPrimary ? 3 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                child: Image.file(
                  controller.productImages[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Badge "Principale"
          if (isPrimary)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppThemeSystem.successColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Principale',
                  style: context.caption.copyWith(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Bouton supprimer
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => controller.removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppThemeSystem.errorColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Section Nom du produit
  Widget _buildNameSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nom du produit *',
          style: context.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.elementSpacing),
        TextField(
          controller: controller.nameController,
          decoration: InputDecoration(
            hintText: 'Ex: iPhone 13 Pro Max',
            filled: true,
            fillColor: context.inputFieldColor,
            prefixIcon: const Icon(Icons.inventory_2_outlined),
            border: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: const BorderSide(
                color: AppThemeSystem.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }


  /// Sélecteur de catégorie avec bottom sheet
  Widget _buildCategorySelector(BuildContext context) {
    return Obx(() {
      final category = controller.selectedCategory.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catégorie *',
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          GestureDetector(
            onTap: () => _showCategoryBottomSheet(context),
            child: Container(
              padding: EdgeInsets.all(context.horizontalPadding),
              decoration: BoxDecoration(
                color: category != null
                    ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                    : context.surfaceColor,
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                border: Border.all(
                  color: category != null
                      ? AppThemeSystem.primaryColor
                      : context.borderColor,
                  width: category != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    color: category != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category ?? 'Sélectionnez une catégorie',
                      style: context.body1.copyWith(
                        color: category != null
                            ? AppThemeSystem.primaryColor
                            : context.secondaryTextColor,
                        fontWeight: category != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: category != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Sélecteur de sous-catégorie avec bottom sheet
  Widget _buildSubcategorySelector(BuildContext context) {
    return Obx(() {
      final subcategory = controller.selectedSubcategory.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sous-catégorie *',
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          GestureDetector(
            onTap: () => _showSubcategoryBottomSheet(context),
            child: Container(
              padding: EdgeInsets.all(context.horizontalPadding),
              decoration: BoxDecoration(
                color: subcategory != null
                    ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                    : context.surfaceColor,
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                border: Border.all(
                  color: subcategory != null
                      ? AppThemeSystem.primaryColor
                      : context.borderColor,
                  width: subcategory != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    color: subcategory != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subcategory ?? 'Sélectionnez une sous-catégorie',
                      style: context.body1.copyWith(
                        color: subcategory != null
                            ? AppThemeSystem.primaryColor
                            : context.secondaryTextColor,
                        fontWeight: subcategory != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: subcategory != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Bottom sheet pour choisir la source de l'image (caméra ou galerie)
  void _showImageSourceBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: context.horizontalPadding,
            right: context.horizontalPadding,
            top: context.verticalPadding,
            bottom: context.bottomSheetPadding,
          ),
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: context.elementSpacing),

              // Titre
              Text(
                'Ajouter des images',
                style: context.h5.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.sectionSpacing),

              // Option Caméra
              _buildImageSourceOption(
                context,
                icon: Icons.camera_alt,
                title: 'Appareil photo',
                subtitle: 'Prendre une photo',
                onTap: () {
                  Navigator.pop(context);
                  controller.takePhoto();
                },
              ),
              SizedBox(height: context.elementSpacing),

              // Option Galerie
              _buildImageSourceOption(
                context,
                icon: Icons.photo_library,
                title: 'Galerie',
                subtitle: 'Sélectionner depuis la galerie',
                onTap: () {
                  Navigator.pop(context);
                  controller.pickImages();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Widget pour une option de source d'image
  Widget _buildImageSourceOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: context.borderRadius(BorderRadiusType.medium),
      child: Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(
            color: context.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.elementSpacing),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                borderRadius: context.borderRadius(BorderRadiusType.small),
              ),
              child: Icon(
                icon,
                color: AppThemeSystem.primaryColor,
                size: 28,
              ),
            ),
            SizedBox(width: context.elementSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.subtitle1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet pour sélectionner la catégorie
  void _showCategoryBottomSheet(BuildContext context) {
    final searchController = TextEditingController();
    final categories = controller.categoriesData.keys.toList();
    final filteredCategories = categories.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
              ),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(context.horizontalPadding),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
                    ),
                  ),
                  border: Border(
                    bottom: BorderSide(color: context.borderColor),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: context.elementSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sélectionner une catégorie',
                            style: context.h5.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: context.elementSpacing),
                    // Barre de recherche
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: context.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.horizontalPadding,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          filteredCategories.value = categories;
                        } else {
                          filteredCategories.value = categories
                              .where((cat) => cat.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Liste avec padding bottom pour la barre de navigation
              Expanded(
                child: Obx(() {
                  return ListView.separated(
                    padding: EdgeInsets.only(
                      left: context.horizontalPadding,
                      right: context.horizontalPadding,
                      top: context.horizontalPadding,
                      bottom: context.bottomSheetPadding,
                    ),
                    itemCount: filteredCategories.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: context.borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
                      final isSelected = controller.selectedCategory.value == category;

                      return ListTile(
                        leading: Icon(
                          Icons.folder,
                          color: isSelected
                              ? AppThemeSystem.primaryColor
                              : context.secondaryTextColor,
                        ),
                        title: Text(
                          category,
                          style: context.body1.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? AppThemeSystem.primaryColor
                                : context.primaryTextColor,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: AppThemeSystem.successColor,
                              )
                            : null,
                        onTap: () {
                          controller.selectedCategory.value = category;
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bottom sheet pour sélectionner la sous-catégorie
  void _showSubcategoryBottomSheet(BuildContext context) {
    final searchController = TextEditingController();
    final category = controller.selectedCategory.value;

    // Filtrer les sous-catégories selon la catégorie sélectionnée
    final subcategories = category != null
        ? controller.categoriesData[category] ?? []
        : controller.allSubcategories;

    final filteredSubcategories = <Map<String, String>>[].obs;
    filteredSubcategories.value = subcategories;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
              ),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(context.horizontalPadding),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      AppThemeSystem.getBorderRadius(context, BorderRadiusType.large),
                    ),
                  ),
                  border: Border(
                    bottom: BorderSide(color: context.borderColor),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: context.elementSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category != null
                                ? 'Sous-catégories de $category'
                                : 'Sélectionner une sous-catégorie',
                            style: context.h5.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: context.elementSpacing),
                    // Barre de recherche
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: context.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: context.borderRadius(BorderRadiusType.medium),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.horizontalPadding,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          filteredSubcategories.value = subcategories;
                        } else {
                          filteredSubcategories.value = subcategories
                              .where((sub) =>
                                  sub['name']!.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Liste avec padding bottom pour la barre de navigation
              Expanded(
                child: Obx(() {
                  if (filteredSubcategories.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.horizontalPadding),
                        child: Text(
                          category != null
                              ? 'Aucune sous-catégorie trouvée'
                              : 'Veuillez sélectionner une catégorie d\'abord',
                          style: context.body1.copyWith(
                            color: context.secondaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.only(
                      left: context.horizontalPadding,
                      right: context.horizontalPadding,
                      top: context.horizontalPadding,
                      bottom: context.bottomSheetPadding,
                    ),
                    itemCount: filteredSubcategories.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: context.borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final subcategory = filteredSubcategories[index];
                      final isSelected = controller.selectedSubcategoryId.value == subcategory['id'];

                      return ListTile(
                        leading: Icon(
                          Icons.category,
                          color: isSelected
                              ? AppThemeSystem.primaryColor
                              : context.secondaryTextColor,
                        ),
                        title: Text(
                          subcategory['name']!,
                          style: context.body1.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? AppThemeSystem.primaryColor
                                : context.primaryTextColor,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: AppThemeSystem.successColor,
                              )
                            : null,
                        onTap: () {
                          controller.selectedSubcategory.value = subcategory['name'];
                          controller.selectedSubcategoryId.value = subcategory['id'];
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }


  /// Section Prix
  Widget _buildPriceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prix *',
          style: context.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.elementSpacing),
        TextField(
          controller: controller.priceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Entrez le prix',
            filled: true,
            fillColor: context.inputFieldColor,
            prefixIcon: const Icon(Icons.payments_outlined),
            suffixText: 'XAF',
            border: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: const BorderSide(
                color: AppThemeSystem.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Section Description
  Widget _buildDescriptionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description *',
          style: context.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.elementSpacing),
        TextField(
          controller: controller.descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Décrivez votre produit en détail...',
            filled: true,
            fillColor: context.inputFieldColor,
            border: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: const BorderSide(
                color: AppThemeSystem.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Section Poids du produit
  Widget _buildWeightSection(BuildContext context) {
    return Obx(() {
      final selectedWeight = controller.selectedWeightType.value;
      final weightLabel = selectedWeight != null
          ? (selectedWeight == 'custom'
              ? '${controller.weightKgController.text.trim()} KG'
              : '$selectedWeight (${controller.weightTypes[selectedWeight]})')
          : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Poids du produit *',
            style: context.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.elementSpacing),
          GestureDetector(
            onTap: () => _showWeightBottomSheet(context),
            child: Container(
              padding: EdgeInsets.all(context.horizontalPadding),
              decoration: BoxDecoration(
                color: selectedWeight != null
                    ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                    : context.surfaceColor,
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                border: Border.all(
                  color: selectedWeight != null
                      ? AppThemeSystem.primaryColor
                      : context.borderColor,
                  width: selectedWeight != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.scale_outlined,
                    color: selectedWeight != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      weightLabel ?? 'Sélectionnez le poids',
                      style: context.body1.copyWith(
                        color: selectedWeight != null
                            ? AppThemeSystem.primaryColor
                            : context.secondaryTextColor,
                        fontWeight: selectedWeight != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: selectedWeight != null
                        ? AppThemeSystem.primaryColor
                        : context.secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Bottom sheet pour sélectionner le poids
  void _showWeightBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(context.horizontalPadding),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(color: context.borderColor),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: context.elementSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sélectionner le poids',
                            style: context.h5.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Liste des poids avec padding bottom pour la barre de navigation
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.only(
                    left: context.horizontalPadding,
                    right: context.horizontalPadding,
                    top: context.horizontalPadding,
                    bottom: context.bottomSheetPadding,
                  ),
                  itemCount: controller.weightTypes.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: context.borderColor,
                  ),
                  itemBuilder: (context, index) {
                    final entry = controller.weightTypes.entries.elementAt(index);

                    return Obx(() {
                      final isSelected = controller.selectedWeightType.value == entry.key;

                      return ListTile(
                        leading: Icon(
                          Icons.scale_outlined,
                          color: isSelected
                              ? AppThemeSystem.primaryColor
                              : context.secondaryTextColor,
                        ),
                        title: Text(
                          entry.key,
                          style: context.body1.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? AppThemeSystem.primaryColor
                                : context.primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          entry.value,
                          style: context.caption.copyWith(
                            color: context.secondaryTextColor,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: AppThemeSystem.successColor,
                              )
                            : null,
                        onTap: () {
                          controller.selectedWeightType.value = entry.key;

                          if (entry.key == 'custom') {
                            // Pour le poids personnalisé, garder le bottom sheet ouvert
                            // et afficher un dialogue pour saisir le poids
                            Navigator.pop(context);
                            _showCustomWeightDialog(context);
                          } else {
                            // Pour les autres, fermer le bottom sheet
                            Navigator.pop(context);
                          }
                        },
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Dialogue pour saisir un poids personnalisé
  void _showCustomWeightDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Poids personnalisé'),
        content: TextField(
          controller: controller.weightKgController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Poids en KG',
            hintText: 'Ex: 25.5',
            suffixText: 'KG',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.fitness_center),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.selectedWeightType.value = null;
              controller.weightKgController.clear();
              Get.back();
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.weightKgController.text.trim().isEmpty) {
                Get.snackbar(
                  'Erreur',
                  'Veuillez entrer un poids',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeSystem.primaryColor,
            ),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Section Stock
  Widget _buildStockSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantité en stock *',
          style: context.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.elementSpacing),
        TextField(
          controller: controller.stockController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ex: 200',
            filled: true,
            fillColor: context.inputFieldColor,
            prefixIcon: const Icon(Icons.inventory_outlined),
            suffixText: 'unités',
            border: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              borderSide: const BorderSide(
                color: AppThemeSystem.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Section Espace de stockage
  Widget _buildStorageSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Espace de stockage *',
                style: context.subtitle1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: controller.addNewStorage,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(
                foregroundColor: AppThemeSystem.primaryColor,
              ),
            ),
          ],
        ),
        SizedBox(height: context.elementSpacing),

        Obx(() {
          if (controller.selectedStorage.value == null) {
            return Container(
              padding: EdgeInsets.all(context.horizontalPadding),
              decoration: BoxDecoration(
                color: AppThemeSystem.warningColor.withValues(alpha: 0.1),
                borderRadius: context.borderRadius(BorderRadiusType.medium),
                border: Border.all(
                  color: AppThemeSystem.warningColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppThemeSystem.warningColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aucun package actif. Veuillez souscrire à un package.',
                      style: context.body2.copyWith(
                        color: AppThemeSystem.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final storage = controller.selectedStorage.value!;
          final available = storage['available'] as double;
          final total = storage['total'] as double;
          final used = total - available;
          final percentageUsed = total > 0 ? (used / total * 100) : 0.0;

          return Container(
            padding: EdgeInsets.all(context.horizontalPadding),
            decoration: BoxDecoration(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
              borderRadius: context.borderRadius(BorderRadiusType.medium),
              border: Border.all(
                color: AppThemeSystem.primaryColor,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.storage,
                      color: AppThemeSystem.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        storage['name'],
                        style: context.body1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeSystem.primaryColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: AppThemeSystem.successColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Barre de progression
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentageUsed / 100,
                    backgroundColor: context.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentageUsed > 80
                          ? AppThemeSystem.errorColor
                          : percentageUsed > 50
                              ? AppThemeSystem.warningColor
                              : AppThemeSystem.successColor,
                    ),
                    minHeight: 14,
                  ),
                ),
                const SizedBox(height: 10),

                // Storage stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${used.toStringAsFixed(1)} GB utilisés',
                      style: context.body2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${total.toStringAsFixed(0)} GB',
                      style: context.body2.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: percentageUsed > 80
                          ? AppThemeSystem.errorColor
                          : percentageUsed > 50
                              ? AppThemeSystem.warningColor
                              : AppThemeSystem.successColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${percentageUsed.toStringAsFixed(1)}% utilisé • ${available.toStringAsFixed(1)} GB disponible',
                      style: context.caption.copyWith(
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Bouton de soumission
  Widget _buildSubmitButton(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isLoading.value;

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLoading ? null : controller.submitProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeSystem.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: context.verticalPadding,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Obx(() => Text(
                  controller.isEditMode.value ? 'Modifier le produit' : 'Ajouter le produit',
                  style: context.button.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                )),
        ),
      );
    });
  }
}
