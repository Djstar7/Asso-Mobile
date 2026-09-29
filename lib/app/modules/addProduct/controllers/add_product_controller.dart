import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/vendor_service.dart';
import '../../../data/providers/shop_service.dart';
import '../../../core/widgets/free_delivery_widgets.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/models/category_catalog.dart';
import '../../../data/models/scan_result.dart';
import '../../../data/services/product_label_scanner.dart';
import '../../../data/models/currency_model.dart';
import '../../../data/providers/offline_store.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../data/services/offline_product_sync_service.dart';
import '../../vendorDashboard/controllers/vendor_dashboard_controller.dart';
import 'product_draft_store.dart';
import 'variant_editor_state.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../routes/app_pages.dart';

class AddProductController extends GetxController {
  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController weightKgController = TextEditingController();
  // Lus au scan de l'étiquette, modifiables par le vendeur.
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController brandController = TextEditingController();

  // Images — XFile pour compatibilité web ET mobile (pas de dart:io).
  final productImages = <XFile>[].obs;
  final primaryImageIndex = 0.obs;

  // Track existing images (from server) vs new images (added by user)
  final existingImageIds = <int>[].obs; // IDs des images déjà sur le serveur
  final newImageStartIndex =
      0.obs; // Index à partir duquel les images sont nouvelles
  final deletedImageIds =
      <int>[].obs; // IDs des images supprimées par l'utilisateur

  final existingImages = <Map<String, dynamic>>[].obs; // {id, url, isPrimary}
  final newImages = <XFile>[].obs;

  // Catégorie et sous-catégorie
  final selectedCategory = Rx<String?>(null);
  final selectedSubcategory = Rx<String?>(null);
  final selectedSubcategoryId = Rx<String?>(null);

  // Liste de toutes les sous-catégories (pour affichage direct)
  final allSubcategories = <Map<String, String>>[].obs;

  // Type d'article
  final articleType = 'article'.obs; // 'article' ou 'service'

  // Type de prix
  final priceType = 'fixed'.obs; // 'fixed', 'discover', 'visit'

  // Devise dans laquelle le vendeur fixe le prix (défaut = sa devise d'affichage).
  // Le prix est envoyé tel quel au backend avec ce code devise ; le backend calcule
  // la valeur canonique XAF (price_xaf). Plus de reconversion forcée vers XOF ici.
  final selectedCurrency = 'XAF'.obs;

  /// Prix affiché aux clients (prix vendeur + commission ASSO), calculé par le serveur.
  final buyerPricePreview = Rxn<double>();
  Timer? _previewDebounce;
  final availableCurrencies = <CurrencyModel>[].obs;

  // Poids du produit
  final selectedWeightType = Rx<String?>(
    null,
  ); // 'X-small', '30 Deep', '50 Deep', '60 Deep', 'Rainbow XL', 'Pallet', 'custom'
  final customWeightValue =
      ''.obs; // Pour suivre les changements du poids personnalisé
  final weightTypes = <String, String>{
    'X-small': '~5 kg',
    '30 Deep': '~30 kg',
    '50 Deep': '~50 kg',
    '60 Deep': '~60 kg',
    'Rainbow XL': '~100 kg',
    'Pallet': '~500 kg',
    'custom': 'Poids personnalisé (KG)',
  };

  static const sizeGroups = <String, List<String>>{
    'Vêtements': [
      'XXS',
      'XS',
      'S',
      'M',
      'L',
      'XL',
      'XXL',
      'XXXL',
      '4XL',
      '5XL',
      '6XL',
    ],
    'Tailles numériques': [
      '28',
      '30',
      '32',
      '34',
      '36',
      '38',
      '40',
      '42',
      '44',
      '46',
      '48',
      '50',
      '52',
      '54',
      '56',
      '58',
      '60',
    ],
    'Pointures': [
      '35',
      '36',
      '37',
      '38',
      '39',
      '40',
      '41',
      '42',
      '43',
      '44',
      '45',
      '46',
      '47',
      '48',
    ],
    'Tailles bébé': [
      '0-3M',
      '3-6M',
      '6-9M',
      '9-12M',
      '12-18M',
      '18-24M',
      '2-3A',
      '3-4A',
      '4-5A',
      '5-6A',
    ],
    'Dimensions': ['S', 'M', 'L'],
  };
  final selectedSizes = <String>[].obs;

  /// Couleurs, tailles, pointures… et quantité par combinaison.
  final variantEditor = VariantEditorState();

  /// Avec des variantes, la quantité générale = somme des combinaisons.
  void syncStockFromVariants() {
    if (variantEditor.hasVariants) {
      stockController.text = '${variantEditor.totalStock}';
    }
  }

  Map<String, List<String>> get sizeGroupsForCategory {
    final category =
        '${selectedCategory.value ?? ''} ${selectedSubcategory.value ?? ''}'
            .toLowerCase();
    if (category.contains('chauss') || category.contains('shoe')) {
      return {'Pointures': sizeGroups['Pointures']!};
    }
    if (category.contains('bébé') ||
        category.contains('bebe') ||
        category.contains('enfant')) {
      return {'Tailles bébé': sizeGroups['Tailles bébé']!};
    }
    if (category.contains('meuble') ||
        category.contains('mobilier') ||
        category.contains('furniture')) {
      return {'Dimensions': sizeGroups['Dimensions']!};
    }
    if (category.contains('mode') ||
        category.contains('vêtement') ||
        category.contains('vetement') ||
        category.contains('fashion')) {
      return {
        'Vêtements': sizeGroups['Vêtements']!,
        'Tailles numériques': sizeGroups['Tailles numériques']!,
      };
    }
    return {};
  }

  // Stockage
  final selectedStorage = Rx<Map<String, dynamic>?>(null);
  final storageList = <Map<String, dynamic>>[].obs;

  // Loading
  final isLoading = false.obs;

  // Edit mode
  final isEditMode = false.obs;

  /// Ouvert depuis la gestion des produits (qui attend notre fermeture pour
  /// se rafraîchir), plutôt que depuis le tableau de bord.
  bool _openedFromProductManagement = false;
  final editProductId = Rx<int?>(null);

  // Livraison gratuite : réglage de la boutique, et choix propre au produit
  // (null = suit la boutique).
  final shopFreeDelivery = false.obs;
  final freeDeliveryOverride = Rxn<bool>();

  bool get freeDeliveryEffective =>
      freeDeliveryOverride.value ?? shopFreeDelivery.value;

  /// Le produit ne garde un choix propre que s'il diffère de la boutique :
  /// revenir au réglage de la boutique le fait de nouveau suivre.
  void setFreeDelivery(bool value) {
    freeDeliveryOverride.value = value == shopFreeDelivery.value ? null : value;
  }

  Future<void> _loadShopFreeDelivery() async {
    if (!ConnectivityService.isOffline) {
      try {
        final response = await ShopService.getShop();
        final shop = response.data?['shop'];
        if (response.success && shop is Map) {
          shopFreeDelivery.value = readFreeDelivery(shop['free_delivery']);
          OfflineStore.saveSnapshot(
            _shopFreeDeliveryKey,
            shopFreeDelivery.value,
          );
          return;
        }
      } catch (_) {
        // Repli sur la dernière valeur connue ci-dessous.
      }
    }
    // Réglage inconnu : l'interrupteur part de « désactivé ».
    shopFreeDelivery.value =
        OfflineStore.readSnapshot(_shopFreeDeliveryKey) == true;
  }

  // ───────────── Mode hors ligne ─────────────

    static const _shopFreeDeliveryKey = 'shop_free_delivery';

  /// Joignabilité du serveur (badge, envoi différé).
  bool get isOffline => ConnectivityService.isOffline;

  /// Garde en local ce que le formulaire lit sur le serveur, pour qu'il
  /// reste utilisable hors ligne. Appelé par le tableau de bord quand il se
  /// charge en ligne ; silencieux en cas d'échec.
  static Future<void> warmOfflineCache() async {
    try {
      final categories = await ProductService.getCategories();
      final list = categories.data?['categories'];
      if (categories.success && list is List && list.isNotEmpty) {
        await OfflineStore.saveSnapshot(CategoryCatalog.snapshotKey, list);
      }
      final shop = await ShopService.getShop();
      final shopData = shop.data?['shop'];
      if (shop.success && shopData is Map) {
        await OfflineStore.saveSnapshot(
          _shopFreeDeliveryKey,
          readFreeDelivery(shopData['free_delivery']),
        );
      }
    } catch (_) {
      // Le cache sera complété au prochain passage en ligne.
    }
  }

  // ───────────── Parcours en étapes ─────────────

  /// Étapes du formulaire, dans l'ordre où un vendeur pense sa fiche.
  static const stepTitles = <String>[
    'Photos',
    'Description',
    'Prix & stock',
    'Déclinaisons',
    'Vérification',
  ];

  static const stepCount = 5;

  /// Nature du produit, déclarée par le vendeur.
  ///
  /// Le type était jusqu'ici déduit de la présence de déclinaisons : un vendeur
  /// ouvrait l'éditeur sans savoir qu'il changeait la nature de sa fiche, et
  /// l'étape s'affichait même pour un article qui n'aura jamais de variante.
  /// Le choix est désormais explicite, comme « produit simple / variable »
  /// dans les boutiques en ligne classiques.
  final isVariableProduct = false.obs;

  void setProductKind({required bool variable}) {
    if (isVariableProduct.value == variable) return;
    isVariableProduct.value = variable;
    if (!variable) {
      // Repasser en produit simple retire les déclinaisons : le stock
      // redevient celui saisi à l'étape précédente.
      variantEditor.clear();
    }
    saveDraft();
  }

  final currentStep = 0.obs;

  /// Sentinelle réactive des champs texte qui conditionnent les étapes.
  ///
  /// Les `TextEditingController` ne sont pas observables : sans ce compteur,
  /// la barre du bas gardait « Donnez un nom à votre produit » alors que le
  /// nom venait d'être saisi.
  final formRevision = 0.obs;

  void _watchStepFields() {
    for (final controller in [
      nameController,
      descriptionController,
      priceController,
      barcodeController,
      brandController,
      weightKgController,
    ]) {
      controller.addListener(() => formRevision.value++);
    }
  }

  /// Étape la plus avancée déjà atteinte : permet de revenir en arrière puis
  /// de ressauter directement à la fin sans refranchir chaque écran.
  final furthestStep = 0.obs;

  /// Une fiche existante n'est jamais un brouillon : elle est déjà publiée.
  bool get supportsDraft => !isEditMode.value;

  /// Chaque étape ne laisse passer que si ses champs obligatoires sont remplis.
  bool isStepValid(int step) {
    // Lecture volontaire : abonne les Obx aux saisies clavier.
    formRevision.value;
    switch (step) {
      case 0:
        // En modification, les photos déjà en ligne comptent : ne regarder que
        // les nouvelles bloquait l'étape sur une fiche pourtant illustrée.
        return totalImagesCount > 0;
      case 1:
        return nameController.text.trim().isNotEmpty &&
            selectedSubcategoryId.value != null &&
            selectedSubcategoryId.value!.isNotEmpty &&
            descriptionController.text.trim().isNotEmpty &&
            barcodeError == null;
      case 2:
        final price = double.tryParse(
          priceController.text.trim().replaceAll(',', '.'),
        );
        return price != null && price > 0;
      case 3:
        // Les déclinaisons sont facultatives.
        return true;
      default:
        return true;
    }
  }

  /// Message affiché lorsque l'étape n'est pas franchissable.
  String? blockingReason(int step) {
    if (isStepValid(step)) return null;
    switch (step) {
      case 0:
        return 'Ajoutez au moins une photo du produit.';
      case 1:
        if (nameController.text.trim().isEmpty) {
          return 'Donnez un nom à votre produit.';
        }
        if (selectedSubcategoryId.value == null ||
            selectedSubcategoryId.value!.isEmpty) {
          return 'Choisissez une catégorie et une sous-catégorie.';
        }
        if (descriptionController.text.trim().isEmpty) {
          return 'Décrivez votre produit.';
        }
        return barcodeError;
      case 2:
        return 'Indiquez un prix supérieur à zéro.';
      default:
        return null;
    }
  }

  bool get canGoNext => isStepValid(currentStep.value);

  void goToStep(int step) {
    if (step < 0 || step >= stepCount) return;
    // On n'autorise le saut en avant que vers une étape déjà atteinte.
    if (step > furthestStep.value) return;
    currentStep.value = step;
    saveDraft();
  }

  void nextStep() {
    if (!canGoNext) return;
    if (currentStep.value >= stepCount - 1) return;
    currentStep.value++;
    if (currentStep.value > furthestStep.value) {
      furthestStep.value = currentStep.value;
    }
    saveDraft();
  }

  void previousStep() {
    if (currentStep.value == 0) return;
    currentStep.value--;
  }

  // ───────────── Brouillon ─────────────

  /// Enregistre l'état courant pour pouvoir quitter puis reprendre.
  void saveDraft() {
    if (!supportsDraft) return;
    if (totalImagesCount == 0 && nameController.text.trim().isEmpty) return;

    ProductDraftStore.save(
      ProductDraft(
        savedAt: DateTime.now(),
        step: currentStep.value,
        fields: {
          'name': nameController.text,
          'description': descriptionController.text,
          'price': priceController.text,
          'stock': stockController.text,
          'weight': weightKgController.text,
          'barcode': barcodeController.text,
          'brand': brandController.text,
          'category': selectedCategory.value ?? '',
          'subcategoryId': selectedSubcategoryId.value ?? '',
          'subcategory': selectedSubcategory.value ?? '',
          'isVariable': isVariableProduct.value ? '1' : '0',
        },
        imagePaths: productImages.map((image) => image.path).toList(),
        primaryImageIndex: primaryImageIndex.value,
        variants: variantEditor.toDraftJson(),
      ),
    );
  }

  /// Restaure un brouillon choisi par le vendeur.
  void restoreDraft(ProductDraft draft) {
    nameController.text = draft.fields['name'] ?? '';
    descriptionController.text = draft.fields['description'] ?? '';
    priceController.text = draft.fields['price'] ?? '';
    stockController.text = draft.fields['stock'] ?? '';
    weightKgController.text = draft.fields['weight'] ?? '';
    barcodeController.text = draft.fields['barcode'] ?? '';
    brandController.text = draft.fields['brand'] ?? '';

    final category = draft.fields['category'] ?? '';
    if (category.isNotEmpty) selectedCategory.value = category;

    final subcategoryId = draft.fields['subcategoryId'] ?? '';
    if (subcategoryId.isNotEmpty) {
      selectedSubcategoryId.value = subcategoryId;
      selectedSubcategory.value = draft.fields['subcategory'];
    }
    // Un brouillon peut dater d'une autre liste de catégories.
    if (_catalog != null) _reconcileSelectedCategory();

    productImages.assignAll(
      draft.existingImagePaths.map((path) => XFile(path)),
    );
    primaryImageIndex.value =
        draft.primaryImageIndex < productImages.length
            ? draft.primaryImageIndex
            : 0;

    variantEditor.loadFromDraftJson(draft.variants);
    isVariableProduct.value =
        draft.fields['isVariable'] == '1' || variantEditor.hasVariants;

    // Une photo disparue de la galerie peut invalider la première étape.
    final target = draft.step.clamp(0, stepCount - 1);
    furthestStep.value = target;
    currentStep.value = isStepValid(0) ? target : 0;
  }

  void discardDraft() {
    ProductDraftStore.clear();
  }
  final Map<String, dynamic>? editProductData = Get.arguments?['product'];

  final ImagePicker _picker = ImagePicker();

  /// Catégories du serveur par nom, avec leurs sous-catégories.
  final Map<String, List<Map<String, String>>> categoriesData = {};

  /// Nombre total d'images (existantes + nouvelles)
  int get totalImagesCount => existingImages.length + productImages.length;

  /// Supprimer une image (existante ou nouvelle) via un index combiné
  void removeImage(int index) {
    print('🗑️ Removing image at combined index $index');

    if (index < existingImages.length) {
      // C'est une image existante (déjà sur le serveur)
      final removed = existingImages.removeAt(index);
      final id = removed['id'] as int?;
      if (id != null) {
        deletedImageIds.add(id);
        existingImageIds.remove(id);
        print(
          '   └─ Image existante supprimée, ID $id ajouté à deletedImageIds',
        );
      }
      // Les nouvelles images "démarrent" toujours juste après les existantes restantes
      newImageStartIndex.value = existingImages.length;
    } else {
      // C'est une nouvelle image (XFile local, pas encore uploadée)
      final newIndex = index - existingImages.length;
      productImages.removeAt(newIndex);
      print('   └─ Nouvelle image supprimée (index local $newIndex)');
    }

    // Réajuster l'image primaire si nécessaire
    final total = totalImagesCount;
    if (total == 0) {
      primaryImageIndex.value = 0;
    } else if (primaryImageIndex.value >= total ||
        primaryImageIndex.value == index) {
      primaryImageIndex.value = 0;
    }

    print(
      '   └─ Images restantes: $total (existantes: ${existingImages.length}, nouvelles: ${productImages.length})',
    );
  }

  /// Définir l'image primaire (index combiné)
  void setPrimaryImage(int index) {
    primaryImageIndex.value = index;
  }

  @override
  void onInit() {
    super.onInit();

    _watchStepFields();

    // Ajouter un listener au weightKgController pour suivre les changements
    weightKgController.addListener(() {
      customWeightValue.value = weightKgController.text.trim();
    });

    // Aperçu du prix client à chaque saisie du prix ou changement de devise.
    priceController.addListener(_schedulePricePreview);
    ever(selectedCurrency, (_) => _schedulePricePreview());

    // Check if we're in edit mode
    final args = Get.arguments as Map<String, dynamic>?;
    _openedFromProductManagement = args?['fromProductManagement'] == true;
    if (args != null && args['isEdit'] == true && args['product'] != null) {
      isEditMode.value = true;
      final product = args['product'] as Map<String, dynamic>;
      editProductId.value = product['id'] as int?;
      print(
        '📝 ADD_PRODUCT: Edit mode detected for product ID: ${editProductId.value}',
      );
    } else {
      // Mode création - s'assurer que les listes sont vides
      existingImageIds.clear();
      deletedImageIds.clear();
      newImageStartIndex.value = 0;
      print('📝 ADD_PRODUCT: Create mode - starting fresh');
    }

    // Catégories du serveur (ou leur copie locale hors ligne).
    _initializeData();
    _refreshCategoriesWhenOnline();
    // Charger les devises disponibles pour le sélecteur de prix
    _loadCurrencies();

    // Une saisie laissée en plan est proposée à la reprise, une fois l'écran
    // affiché (un dialogue ne peut pas s'ouvrir pendant le build initial).
    if (supportsDraft) {
      pendingDraft.value = ProductDraftStore.read();
    }
  }

  /// Brouillon trouvé au démarrage, en attente du choix du vendeur.
  final pendingDraft = Rx<ProductDraft?>(null);

  void acceptPendingDraft() {
    final draft = pendingDraft.value;
    if (draft == null) return;
    restoreDraft(draft);
    pendingDraft.value = null;
  }

  void rejectPendingDraft() {
    pendingDraft.value = null;
    discardDraft();
  }

  /// Charge les devises actives et fixe la devise par défaut du formulaire.
  /// En création : la devise d'affichage du vendeur ; en édition : celle du produit.
  Future<void> _loadCurrencies() async {
    // Défaut immédiat = devise du vendeur (avant même le retour de l'API)
    if (!isEditMode.value) {
      final userCode = Get.isRegistered<CurrencyService>()
          ? CurrencyService.to.currencyCode
          : 'XAF';
      selectedCurrency.value = userCode.isNotEmpty ? userCode : 'XAF';
    }

    if (Get.isRegistered<CurrencyService>() && !isOffline) {
      final list = await CurrencyService.to.getAllCurrencies();
      if (list.isNotEmpty) {
        availableCurrencies.assignAll(list.where((c) => c.isActive));
        // Sécuriser : si la devise sélectionnée n'est pas dans la liste, retomber sur XAF
        if (!availableCurrencies.any((c) => c.code == selectedCurrency.value)) {
          final hasXaf = availableCurrencies.any((c) => c.code == 'XAF');
          selectedCurrency.value = hasXaf
              ? 'XAF'
              : (availableCurrencies.first.code);
        }
      }
    }
  }

  /// Initialise les données (catégories et stockage)
  Future<void> _initializeData() async {
    isLoading.value = true;

    await Future.wait([
      _loadCategories(),
      _loadStorages(),
      _loadShopFreeDelivery(),
    ]);

    // If in edit mode, populate fields with product data
    if (isEditMode.value && editProductData != null) {
      await _populateEditData(editProductData!);
    }

    isLoading.value = false;
  }

  @override
  void onClose() {
    _previewDebounce?.cancel();
    _onlineWorker?.dispose();
    // Les images sont des XFile (mémoire/cache géré par la plateforme) :
    // aucun nettoyage manuel de fichiers n'est nécessaire (et impossible sur le web).
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockController.dispose();
    weightKgController.dispose();
    barcodeController.dispose();
    brandController.dispose();
    super.onClose();
  }

  /// Catégories telles que la base du serveur les connaît (réponse du
  /// serveur ou sa dernière copie locale). Vide tant qu'aucune n'a été lue.
  CategoryCatalog? _catalog;

  /// Les catégories affichées viennent d'une réponse fraîche du serveur.
  bool _categoriesFromServer = false;

  /// Faux quand aucune liste du serveur n'est disponible (hors ligne sans
  /// passage préalable en ligne) : le choix de catégorie est alors bloqué
  /// plutôt que de proposer des identifiants inconnus de la base.
  final categoriesAvailable = false.obs;

  /// Charge les catégories depuis l'API, sinon depuis la dernière réponse
  /// gardée en local. Jamais depuis une liste inventée : ses identifiants
  /// n'existeraient pas en base.
  Future<void> _loadCategories() async {
    if (!isOffline) {
      try {
        final response = await ProductService.getCategories();
        final list = response.data?['categories'];
        if (response.success && list is List && list.isNotEmpty) {
          OfflineStore.saveSnapshot(CategoryCatalog.snapshotKey, list);
          _applyCategories(list);
          _categoriesFromServer = true;
          return;
        }
        print('⚠️ ADD_PRODUCT: Catégories indisponibles: ${response.message}');
      } catch (e) {
        print('❌ ADD_PRODUCT: Erreur lors du chargement des catégories: $e');
      }
    }
    _applyCachedCategories();
  }

  /// Catégories de la dernière réponse du serveur gardée en local. Faux
  /// s'il n'y en a pas.
  bool _applyCachedCategories() {
    final cached = OfflineStore.readSnapshot(CategoryCatalog.snapshotKey);
    if (cached is! List || cached.isEmpty) return false;
    try {
      _applyCategories(cached);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Range les catégories du serveur (liste avec sous-catégories).
  void _applyCategories(List categoriesFromApi) {
    final catalog = CategoryCatalog.fromApi(categoriesFromApi);
    if (catalog.isEmpty) return;

    final Map<String, List<Map<String, String>>> categories = {};
    final List<Map<String, String>> allSubs = [];

    for (final category in catalog.categories) {
      final entries = categories.putIfAbsent(category.name, () => []);
      final catId = '${category.id}';
      if (category.subcategories.isEmpty) {
        // Sans sous-catégorie, la catégorie se choisit elle-même ; elle ne
        // doit pas partir comme subcategory_id.
        final entry = <String, String>{
          'id': catId,
          'name': category.name,
          'category_name': category.name,
          'category_id': catId,
          'category_only': '1',
        };
        entries.add(entry);
        allSubs.add(entry);
        continue;
      }
      for (final sub in category.subcategories) {
        final entry = <String, String>{
          'id': '${sub.id}',
          'name': sub.name,
          'category_name': category.name,
          'category_id': catId,
        };
        entries.add(entry);
        allSubs.add(entry);
      }
    }

    _catalog = catalog;
    categoriesData
      ..clear()
      ..addAll(categories);
    allSubcategories.value = allSubs;
    categoriesAvailable.value = true;
    _reconcileSelectedCategory();

    print(
      '✅ ADD_PRODUCT: ${categories.length} catégories, ${allSubs.length} sous-catégories',
    );
  }

  /// Entrée de la liste affichée pour la sélection courante, si elle y est.
  Map<String, String>? get _selectedEntry {
    final id = selectedSubcategoryId.value;
    if (id == null || id.isEmpty) return null;
    final category = selectedCategory.value;
    return allSubcategories.firstWhereOrNull(
          (entry) => entry['id'] == id && entry['category_name'] == category,
        ) ??
        allSubcategories.firstWhereOrNull((entry) => entry['id'] == id);
  }

  /// Aligne la sélection (brouillon, saisie faite avant la réponse du
  /// serveur…) sur les catégories réelles : retrouvée par son nom, sinon
  /// effacée pour que le vendeur la choisisse à nouveau.
  void _reconcileSelectedCategory() {
    final id = selectedSubcategoryId.value;
    final category = selectedCategory.value;
    if ((id == null || id.isEmpty) && (category == null || category.isEmpty)) {
      return;
    }
    final entry = _resolveSelectedEntry();
    if (entry != null) {
      selectedSubcategoryId.value = entry['id'];
      selectedSubcategory.value = entry['name'];
      selectedCategory.value = entry['category_name'];
      return;
    }
    // Une catégorie connue reste choisie, seule la sous-catégorie est à refaire.
    selectedSubcategoryId.value = null;
    selectedSubcategory.value = null;
    if (category != null && !categoriesData.containsKey(category)) {
      selectedCategory.value = null;
    }
  }

  /// Entrée de la liste qui correspond vraiment à la sélection, d'après
  /// le catalogue du serveur.
  Map<String, String>? _resolveSelectedEntry() {
    final catalog = _catalog;
    if (catalog == null) return null;
    final isCategoryOnly = _selectedEntry?['category_only'] == '1';
    final resolved = catalog.resolve(
      categoryName: selectedCategory.value,
      subcategoryId: isCategoryOnly ? null : selectedSubcategoryId.value,
      subcategoryName: isCategoryOnly ? null : selectedSubcategory.value,
      categoryId: isCategoryOnly ? selectedSubcategoryId.value : null,
    );
    if (resolved == null) return null;
    final subId = resolved.subcategoryId;
    return allSubcategories.firstWhereOrNull(
      (entry) => subId != null
          ? entry['id'] == subId && entry['category_only'] != '1'
          : entry['id'] == resolved.categoryId &&
              entry['category_only'] == '1',
    );
  }

  /// Recharge les catégories au retour du réseau si le formulaire s'était
  /// ouvert sans la liste fraîche du serveur.
  void _refreshCategoriesWhenOnline() {
    if (!Get.isRegistered<ConnectivityService>()) return;
    _onlineWorker = ever<bool>(ConnectivityService.to.isOnline, (online) {
      if (online && !_categoriesFromServer) _loadCategories();
    });
  }

  Worker? _onlineWorker;

  Future<XFile?> _downloadImage(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode == 200) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${url.split('/').last}';
        return XFile.fromData(
          response.bodyBytes,
          name: fileName,
          mimeType: response.headers['content-type'],
        );
      } else {
        print(
          '❌ ADD_PRODUCT: Failed to download image. Status: ${response.statusCode} — URL: $url',
        );
      }
    } catch (e) {
      print('❌ ADD_PRODUCT: Error downloading image: $e — URL: $url');
    }
    return null;
  }

  /// Charge les espaces de stockage depuis l'API
  Future<void> _loadStorages() async {
    // Hors ligne : forfait tel que le tableau de bord l'a vu en dernier.
    if (isOffline) {
      final snapshot = OfflineStore.readSnapshot(
        VendorDashboardController.dashboardSnapshotKey,
      );
      if (snapshot is Map) _applyStorage(snapshot);
      return;
    }
    try {
      final response = await VendorService.getVendorDashboard();

      if (response.success && response.data != null) {
        final data = response.data!['data'] ?? response.data!;
        _applyStorage(data);
      }
    } catch (e) {
      print('Erreur lors du chargement du stockage: $e');
      // Si erreur, on laisse vide - l'utilisateur devra souscrire à un package
    }
  }

  /// Espace du forfait actif, lu dans une réponse du tableau de bord.
  void _applyStorage(Map data) {
    if (data['package'] != null &&
        data['package']['vendor_package'] != null) {
      final vendorPackage = data['package']['vendor_package'];
      final storageTotalMb = (vendorPackage['storage_total_mb'] ?? 0)
          .toDouble();
      final storageRemainingMb =
          (vendorPackage['storage_remaining_mb'] ?? 0).toDouble();
      final packageName =
          vendorPackage['package']?['name'] ?? 'Package actif';

      storageList.value = [
        {
          'id': vendorPackage['id']?.toString() ?? '1',
          'name': packageName,
          'available': storageRemainingMb / 1024, // Convert MB to GB
          'total': storageTotalMb / 1024, // Convert MB to GB
        },
      ];

      // Sélectionner automatiquement
      if (storageList.isNotEmpty) {
        selectedStorage.value = storageList.first;
      }
    }
  }

  /// Populate form with product data for editing

  Future<void> _populateEditData(Map<String, dynamic> product) async {
    try {
      print('📝 ADD_PRODUCT: Populating edit data...');
      print('📝 ADD_PRODUCT: Product data structure: ${product.keys.toList()}');

      // Champs texte
      nameController.text = product['name'] ?? '';
      descriptionController.text = product['description'] ?? '';
      barcodeController.text = product['barcode']?.toString() ?? '';
      brandController.text = product['brand']?.toString() ?? '';

      // Devise + prix source du produit
      final productCurrency = (product['currency']?.toString() ?? 'XAF')
          .toUpperCase();
      selectedCurrency.value = productCurrency.isNotEmpty
          ? productCurrency
          : 'XAF';

      final price = product['price'];
      if (price != null) {
        final sourcePrice = double.tryParse(price.toString()) ?? 0;
        priceController.text = sourcePrice.toStringAsFixed(0);
        print(
          '📝 ADD_PRODUCT: Prix source: $sourcePrice ${selectedCurrency.value}',
        );
      } else {
        print('⚠️ ADD_PRODUCT: No price found in product data');
      }

      // Stock
      final stock =
          product['stock'] ?? product['quantity'] ?? product['stock_quantity'];
      if (stock != null) {
        stockController.text = stock.toString();
        print('📝 ADD_PRODUCT: Stock set: $stock');
      } else {
        print('⚠️ ADD_PRODUCT: No stock/quantity found in product data');
      }

      // Catégorie et sous-catégorie
      final subcategory = product['subcategory'];
      final category = product['category'];

      if (subcategory != null) {
        final subcatId = subcategory['id']?.toString();
        final subcatName = subcategory['name'];
        if (subcatId != null && subcatName != null) {
          selectedSubcategoryId.value = subcatId;
          selectedSubcategory.value = subcatName;
          print('📝 ADD_PRODUCT: Subcategory set: $subcatName (ID: $subcatId)');
        }
      }

      if (category != null) {
        final catName = category['name'];
        // Catégorie sans sous-catégorie : elle se choisit elle-même.
        if (subcategory == null && category['id'] != null) {
          selectedSubcategoryId.value = category['id'].toString();
          selectedSubcategory.value = catName?.toString();
        }
        if (catName != null) {
          selectedCategory.value = catName;
          print('📝 ADD_PRODUCT: Category set: $catName');
        }
      }

      // Type (article physique ou service) : le poids n'est requis que pour un article.
      final productType = product['type']?.toString();
      if (productType == 'article' || productType == 'service') {
        articleType.value = productType!;
      }

      // Livraison gratuite propre au produit (null = suit la boutique).
      final freeSetting = product['free_delivery_setting'];
      freeDeliveryOverride.value = freeSetting == null
          ? null
          : readFreeDelivery(freeSetting);

      // Poids réel en kg (utilisé pour chiffrer la livraison).
      final weightKg = parseWeightKg(product['weight']?.toString());
      if (weightKg != null) {
        weightKgController.text = formatWeightInput(weightKg);
        customWeightValue.value = weightKgController.text;
      } else {
        weightKgController.clear();
        customWeightValue.value = '';
      }

      final sizes = product['sizes'];
      if (sizes is List) {
        selectedSizes.assignAll(sizes.map((size) => size.toString()));
      }

      variantEditor.loadFromApi(
        product['variants'],
        product['variant_options'],
      );
      // Une fiche déjà déclinée s'ouvre en « produit variable ».
      isVariableProduct.value = variantEditor.hasVariants;

      // ===== IMAGES : plus de téléchargement, juste référencer id + url =====
      final images = product['images'] as List?;
      existingImages.clear();
      existingImageIds.clear();

      if (images != null && images.isNotEmpty) {
        int primaryIndex = 0;

        for (int i = 0; i < images.length; i++) {
          final imageData = images[i] as Map<String, dynamic>;
          final id = imageData['id'] as int?;
          final url = imageData['url'] as String?;
          final isPrimary = imageData['is_primary'] == true;

          if (url == null) continue;

          existingImages.add({'id': id, 'url': url, 'isPrimary': isPrimary});

          if (id != null) existingImageIds.add(id);
          if (isPrimary) primaryIndex = existingImages.length - 1;
        }

        primaryImageIndex.value = primaryIndex;
        // Les nouvelles images ajoutées par l'utilisateur commenceront après
        // toutes les images existantes (dans la liste combinée affichée).
        newImageStartIndex.value = existingImages.length;

        print(
          '✅ ADD_PRODUCT: ${existingImages.length} images existantes référencées (aucun téléchargement)',
        );
        print('📝 ADD_PRODUCT: Existing image IDs: $existingImageIds');
        print(
          '📝 ADD_PRODUCT: New images will start at index: ${newImageStartIndex.value}',
        );
      } else {
        newImageStartIndex.value = 0;
        print('⚠️ ADD_PRODUCT: No images found in product data');
      }

      print('✅ ADD_PRODUCT: Edit data populated successfully');
    } catch (e, stackTrace) {
      print('❌ ADD_PRODUCT: Error populating edit data: $e');
      print('Stack trace: $stackTrace');
      Get.snackbar(
        'Erreur',
        'Impossible de charger les données du produit',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Plus grand côté d'une photo produit envoyée, en pixels.
  ///
  /// Les photos partaient telles que prises (12 Mpx et plus) : chaque
  /// acheteur les téléchargeait, puis les décodait à ~48 Mo pièce, ce qui
  /// finissait par faire fermer l'application. 2048 px reste bien au-delà de
  /// ce qu'un écran de téléphone affiche, zoom compris.
  static const double productPhotoMaxSide = 2048;

  /// Ajouter des images (galerie, sélection multiple)
  Future<void> pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: productPhotoMaxSide,
        maxHeight: productPhotoMaxSide,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        productImages.addAll(images);
        print(
          '📷 ADD_PRODUCT: ${images.length} images sélectionnées depuis la galerie',
        );
      }
    } catch (e) {
      print('❌ ADD_PRODUCT: Erreur lors de la sélection des images: $e');
      Get.snackbar(
        'Erreur',
        'Impossible de sélectionner les images',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Ajouter une image depuis la caméra
  Future<void> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: productPhotoMaxSide,
        maxHeight: productPhotoMaxSide,
        imageQuality: 85,
      );

      if (image != null) {
        productImages.add(image);
        print('📷 ADD_PRODUCT: Photo prise depuis la caméra');
      }
    } catch (e) {
      print('❌ ADD_PRODUCT: Erreur lors de la prise de photo: $e');
      Get.snackbar(
        'Erreur',
        'Impossible de prendre une photo',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ───────────── Remplissage automatique (scan ML Kit, sans LLM) ─────────────

  /// Confiance minimale d'une proposition du serveur pour l'appliquer.
  static const _minScanConfidence = 0.3;

  /// Valeur posée par le scan, par champ. Le badge « À vérifier » reste
  /// affiché tant que le vendeur ne l'a pas modifiée.
  final prefilled = <String, String>{}.obs;

  /// Le scan crée une fiche : il n'est pas proposé en modification.
  /// (isEditMode lu en premier : abonne toujours les Obx.)
  bool get canScan => !isEditMode.value && ProductLabelScanner.isSupported;

  bool isPrefilled(String field) {
    // Lecture volontaire : abonne les Obx aux saisies clavier.
    formRevision.value;
    final applied = prefilled[field];
    return applied != null && _fieldValue(field) == applied;
  }

  String? _fieldValue(String field) => switch (field) {
        'name' => nameController.text,
        'description' => descriptionController.text,
        'brand' => brandController.text,
        'barcode' => barcodeController.text,
        'weight' => weightKgController.text,
        'category' => selectedSubcategoryId.value ?? selectedCategory.value,
        _ => null,
      };

  /// Erreur de saisie du code-barres, ou null (vide ou valide).
  String? get barcodeError {
    final text = barcodeController.text.trim();
    if (text.isEmpty || RegExp(r'^\d{8,14}$').hasMatch(text)) return null;
    return 'Le code-barres compte 8 à 14 chiffres (ou laissez-le vide).';
  }

  /// Ouvre le viseur (ou directement la galerie) puis applique le résultat.
  Future<void> openScanner({bool fromGallery = false}) async {
    final result = await Get.toNamed(
      Routes.PRODUCT_SCAN,
      arguments: fromGallery ? {'source': 'gallery'} : null,
    );
    if (result is ScanResult) applyScanResult(result);
  }

  /// Pré-remplit le formulaire. Un champ déjà saisi n'est jamais écrasé.
  void applyScanResult(ScanResult result) {
    final extraction = result.extraction;
    final suggestion = result.suggestion;
    final applied = <String>[];

    void fill(
      String field,
      TextEditingController target,
      String? value,
      double confidence,
    ) {
      final text = value?.trim() ?? '';
      if (text.isEmpty || confidence < _minScanConfidence) return;
      if (target.text.trim().isNotEmpty) return;
      target.text = text;
      prefilled[field] = text;
      applied.add(field);
    }

    // La photo analysée rejoint les photos du produit, en tête.
    if (!productImages.any((image) => image.path == extraction.imagePath)) {
      final hadImages = productImages.isNotEmpty;
      productImages.insert(0, XFile(extraction.imagePath));
      if (hadImages) primaryImageIndex.value++;
    }

    fill('barcode', barcodeController,
        suggestion?.barcode ?? extraction.barcode, 1);
    if (suggestion != null) {
      fill('name', nameController, suggestion.name,
          suggestion.confidenceOf('name'));
      fill('brand', brandController, suggestion.brand,
          suggestion.confidenceOf('brand'));
      fill('description', descriptionController, suggestion.description,
          suggestion.confidenceOf('description'));
      final weight = suggestion.weightKg;
      if (weight != null && weight > 0 && articleType.value == 'article') {
        fill('weight', weightKgController, formatWeightInput(weight),
            suggestion.confidenceOf('weight'));
      }
      if (_applySuggestedCategory(suggestion)) applied.add('category');
    } else {
      // Sans réponse du serveur : la plus grande ligne lisible sert de nom.
      final firstLine = extraction.ocrLines.firstWhereOrNull(
        (line) => RegExp(r'[A-Za-zÀ-ÿ]{3}').hasMatch(line),
      );
      fill('name', nameController, firstLine, 1);
    }

    formRevision.value++;
    saveDraft();
    _announceScan(suggestion, applied);
  }

  /// Catégorie proposée, si le vendeur n'en a pas déjà choisi une.
  bool _applySuggestedCategory(ScanSuggestion suggestion) {
    final categoryId = suggestion.categoryId;
    if (categoryId == null ||
        suggestion.confidenceOf('category') < _minScanConfidence) {
      return false;
    }
    if ((selectedSubcategoryId.value ?? '').isNotEmpty ||
        (selectedCategory.value ?? '').isNotEmpty) {
      return false;
    }
    final subcategoryId = suggestion.subcategoryId;
    final entry = allSubcategories.firstWhereOrNull(
      (e) => subcategoryId != null
          ? e['id'] == subcategoryId &&
              e['category_id'] == categoryId &&
              e['category_only'] != '1'
          : e['category_id'] == categoryId && e['category_only'] == '1',
    );
    if (entry != null) {
      selectedSubcategoryId.value = entry['id'];
      selectedSubcategory.value = entry['name'];
      selectedCategory.value = entry['category_name'];
      prefilled['category'] = entry['id']!;
      return true;
    }
    // Catégorie seule : le vendeur choisit la sous-catégorie.
    final any = allSubcategories.firstWhereOrNull(
      (e) => e['category_id'] == categoryId,
    );
    if (any == null) return false;
    selectedCategory.value = any['category_name'];
    prefilled['category'] = any['category_name']!;
    return true;
  }

  void _announceScan(ScanSuggestion? suggestion, List<String> applied) {
    final String title;
    final String message;
    var color = AppDesign.info;
    if (suggestion == null && isOffline) {
      title = 'Hors ligne';
      message = 'Photo ajoutée. La recherche du produit demande une '
          'connexion : complétez la fiche vous-même.';
      color = AppDesign.warning;
    } else if (applied.isEmpty) {
      title = 'Photo ajoutée';
      message = 'Aucune information exploitable sur cette photo : '
          'complétez la fiche vous-même.';
      color = AppDesign.warning;
    } else {
      title = 'Fiche pré-remplie';
      message = suggestion == null
          ? 'Vérifiez les champs marqués « À vérifier ».'
          : 'Source : ${suggestion.sourceLabel}. Vérifiez les champs '
              'marqués « À vérifier ».';
      color = AppDesign.success;
    }
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: AppDesign.neutral0,
      margin: const EdgeInsets.all(AppDesign.space4),
      borderRadius: AppDesign.radiusMd,
      duration: const Duration(seconds: 4),
    );
  }

  /// Naviguer vers la page de souscription de package
  void addNewStorage() {
    Get.toNamed('/package-subscription');
  }

  /// Poids en kg lu depuis une saisie ou l'API (« 2,5 », « 2.5 kg », « 500 g »).
  /// Null si absent, illisible ou nul.
  static double? parseWeightKg(String? raw) {
    final text = (raw ?? '').trim().toLowerCase();
    final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|g)?').firstMatch(text);
    if (match == null) return null;
    var value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == null) return null;
    if (match.group(2) == 'g') value /= 1000;
    return value > 0 ? value : null;
  }

  /// Valeur saisie strictement numérique (virgule ou point décimal).
  static final _weightInput = RegExp(r'^\d+([.,]\d{1,3})?$');

  /// Affichage d'un poids dans le champ (« 2,5 »).
  static String formatWeightInput(double kg) {
    final text = kg == kg.roundToDouble()
        ? kg.toStringAsFixed(0)
        : kg.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
    return text.replaceAll('.', ',');
  }

  /// Erreur de saisie du poids, ou null si valide.
  String? get weightError {
    final text = weightKgController.text.trim();
    if (articleType.value != 'article' && text.isEmpty) return null;
    if (text.isEmpty) return 'Le poids est obligatoire pour un article';
    if (!_weightInput.hasMatch(text)) return 'Saisissez un nombre, ex. 2,5';
    final value = double.tryParse(text.replaceAll(',', '.')) ?? 0;
    if (value <= 0) return 'Le poids doit être supérieur à 0';
    return null;
  }

  /// Valider et soumettre le produit
  /// Signale un champ obligatoire manquant.
  ///
  /// Les messages de validation partageaient le style par défaut de GetX
  /// (fond neutre) alors que le reste de l'application signale les erreurs
  /// avec la couleur sémantique du design system : l'avertissement passait
  /// inaperçu au bas de l'écran.
  void _warnMissingField(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppDesign.danger,
      colorText: AppDesign.neutral0,
      margin: const EdgeInsets.all(AppDesign.space4),
      borderRadius: AppDesign.radiusMd,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> submitProduct() async {
    // Validation
    if (nameController.text.trim().isEmpty) {
      _warnMissingField(
        'Champ requis',
        'Veuillez entrer le nom du produit',
      );
      return;
    }

    final barcodeProblem = barcodeError;
    if (barcodeProblem != null) {
      _warnMissingField('Code-barres', barcodeProblem);
      return;
    }

    if (productImages.isEmpty) {
      _warnMissingField(
        'Image requise',
        'Veuillez ajouter au moins une image du produit',
      );
      return;
    }

    if (selectedSubcategoryId.value == null ||
        selectedSubcategoryId.value!.isEmpty) {
      _warnMissingField(
        'Catégorie requise',
        'Veuillez sélectionner une catégorie',
      );
      return;
    }

    if (priceController.text.trim().isEmpty) {
      _warnMissingField(
        'Prix requis',
        'Veuillez entrer le prix du produit',
      );
      return;
    }

    if (descriptionController.text.trim().isEmpty) {
      _warnMissingField(
        'Description requise',
        'Veuillez entrer une description du produit',
      );
      return;
    }

    // Poids réel obligatoire pour un article physique : il sert à chiffrer la livraison.
    final weightProblem = weightError;
    if (weightProblem != null) {
      _warnMissingField(
        'Poids requis',
        '$weightProblem (poids réel du colis en kg).',
      );
      return;
    }

    // Le mode hors ligne ne couvre que la création : une modification part
    // des données du serveur, qui font foi.
    if (isEditMode.value && isOffline) {
      _warnMissingField(
        'Hors ligne',
        'La modification d\'un produit demande une connexion.',
      );
      return;
    }

    // Note: Les champs storage et stock ne sont pas encore requis par l'API
    // Ces validations sont commentées pour le moment

    // if (selectedStorage.value == null) {
    //   Get.snackbar(
    //     'Stockage requis',
    //     'Veuillez sélectionner un espace de stockage',
    //     snackPosition: SnackPosition.BOTTOM,
    //   );
    //   return;
    // }

    // if (selectedWeightType.value == null) {
    //   Get.snackbar(
    //     'Poids requis',
    //     'Veuillez sélectionner le poids du produit',
    //     snackPosition: SnackPosition.BOTTOM,
    //   );
    //   return;
    // }

    // if (selectedWeightType.value == 'custom' && weightKgController.text.trim().isEmpty) {
    //   Get.snackbar(
    //     'Poids requis',
    //     'Veuillez entrer le poids en KG',
    //     snackPosition: SnackPosition.BOTTOM,
    //   );
    //   return;
    // }

    // if (stockController.text.trim().isEmpty) {
    //   Get.snackbar(
    //     'Stock requis',
    //     'Veuillez entrer la quantité en stock',
    //     snackPosition: SnackPosition.BOTTOM,
    //   );
    //   return;
    // }

    isLoading.value = true;

    try {
      // Déterminer quelles images envoyer
      List<XFile> imagesToUpload;
      if (isEditMode.value) {
        // En mode édition, n'envoyer que les NOUVELLES images
        imagesToUpload = productImages.sublist(newImageStartIndex.value);
        print('📦 ADD_PRODUCT: Mode EDIT - Sending only NEW images');
        print('   └─ Total images: ${productImages.length}');
        print('   └─ Existing images: ${newImageStartIndex.value}');
        print('   └─ New images to upload: ${imagesToUpload.length}');
      } else {
        // En mode création, envoyer toutes les images
        imagesToUpload = productImages;
        print('📦 ADD_PRODUCT: Mode CREATE - Sending all images');
        print('   └─ Total images to upload: ${imagesToUpload.length}');
      }

      // Calculer la taille estimée des images à uploader
      double totalSizeMb = 0;
      for (var image in imagesToUpload) {
        final bytes = await image.length();
        totalSizeMb += bytes / 1048576;
      }

      print(
        '📦 ADD_PRODUCT: Total images size: ${totalSizeMb.toStringAsFixed(2)} MB',
      );

      // Préparer les fichiers pour l'upload (XFile → octets, web ET mobile)
      final filesMap = <String, XFile>{};
      for (int i = 0; i < imagesToUpload.length; i++) {
        filesMap['images[$i]'] = imagesToUpload[i];
      }

      // Identifiants vérifiés sur les catégories du serveur : ce qui part
      // (tout de suite ou plus tard depuis la file hors ligne) doit exister
      // en base.
      final categoryEntry = _resolveSelectedEntry();
      if (categoryEntry == null) {
        _invalidCategory();
        return;
      }
      final categoryId = categoryEntry['category_id']!;
      final subcategoryId = categoryEntry['category_only'] == '1'
          ? null
          : categoryEntry['id'];

      print('📦 ADD_PRODUCT: category_id = $categoryId');
      print('📦 ADD_PRODUCT: subcategory_id = $subcategoryId');

      // Prix envoyé tel quel dans la devise choisie par le vendeur (plus de conversion
      // XOF côté mobile). Le backend calcule price_xaf (valeur canonique).
      final price = double.tryParse(priceController.text.trim()) ?? 0;

      print('📦 ADD_PRODUCT: Prix envoyé: $price ${selectedCurrency.value}');

      // Préparer les champs (selon ce qu'attend l'API)
      final fieldsMap = <String, String>{
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'type': articleType.value,
        'price': price.toStringAsFixed(0),
        'currency': selectedCurrency.value,
        'condition': 'new', // L'API requiert ce champ
      };

      // Si en mode édition, ajouter _method=PUT pour Laravel
      // Laravel/PHP ne parse pas automatiquement PUT multipart, donc on utilise POST avec _method
      if (isEditMode.value && editProductId.value != null) {
        fieldsMap['_method'] = 'PUT';

        // Ajouter les IDs des images supprimées
        if (deletedImageIds.isNotEmpty) {
          print('📦 ADD_PRODUCT: Deleted image IDs to send: $deletedImageIds');
          for (int i = 0; i < deletedImageIds.length; i++) {
            fieldsMap['deleted_image_ids[$i]'] = deletedImageIds[i].toString();
          }
        } else {
          print('📦 ADD_PRODUCT: No images to delete');
        }
      }

      fieldsMap['category_id'] = categoryId;
      if (subcategoryId != null) fieldsMap['subcategory_id'] = subcategoryId;

      // Ajouter stock si disponible
      if (stockController.text.trim().isNotEmpty) {
        fieldsMap['stock'] = stockController.text.trim();
      }

      for (var i = 0; i < selectedSizes.length; i++) {
        fieldsMap['sizes[$i]'] = selectedSizes[i];
      }

      if (variantEditor.hasVariants) {
        fieldsMap['stock'] = '${variantEditor.totalStock}';
      }
      fieldsMap.addAll(variantEditor.toFields());
      // En modification, on envoie toujours l'état complet (y compris « plus aucune variante »).
      if (isEditMode.value) fieldsMap['replace_variants'] = '1';

      // Livraison gratuite : vide = suit la boutique.
      final freeOverride = freeDeliveryOverride.value;
      fieldsMap['free_delivery'] = freeOverride == null
          ? ''
          : (freeOverride ? '1' : '0');

      // Code-barres et marque : en modification, un champ vidé les efface.
      final barcode = barcodeController.text.trim();
      final brand = brandController.text.trim();
      if (isEditMode.value || barcode.isNotEmpty) fieldsMap['barcode'] = barcode;
      if (isEditMode.value || brand.isNotEmpty) fieldsMap['brand'] = brand;

      // Poids réel en kg, nombre décimal avec point (ex. « 2.5 »).
      final weightText = weightKgController.text.trim();
      if (weightText.isNotEmpty) {
        fieldsMap['weight'] = weightText.replaceAll(',', '.');
      }

      // Pas de storage_id à envoyer : le serveur débite l'espace du forfait
      // actif du vendeur, qui est unique. Le bloc « Espace de stockage » du
      // formulaire est purement informatif.

      if (primaryImageIndex.value > 0 &&
          primaryImageIndex.value < productImages.length) {
        fieldsMap['primary_image_index'] = primaryImageIndex.value.toString();
      }

      // Hors ligne : la fiche est gardée sur le téléphone et partira seule
      // au retour de la connexion.
      if (!isEditMode.value && isOffline) {
        await _saveOffline(
          fieldsMap,
          imagesToUpload,
          labels: {
            'category_name': categoryEntry['category_name'] ?? '',
            if (subcategoryId != null)
              'subcategory_name': categoryEntry['name'] ?? '',
          },
        );
        return;
      }

      print('📦 ADD_PRODUCT: Envoi de la requête au backend...');
      print('📦 ADD_PRODUCT: Mode: ${isEditMode.value ? "EDIT" : "CREATE"}');
      print('📦 ADD_PRODUCT: Fields: $fieldsMap');
      print('📦 ADD_PRODUCT: Files count: ${filesMap.length}');

      // Appel API multipart pour créer ou modifier le produit
      // Note: Pour PUT, on utilise POST avec _method=PUT car PHP ne parse pas PUT multipart nativement
      final response = isEditMode.value && editProductId.value != null
          ? await ApiProvider.multipart(
              '/v1/vendor/products/${editProductId.value}',
              method: 'POST', // POST avec _method=PUT dans les fields
              fields: fieldsMap,
              mediaFiles: filesMap,
            )
          : await ApiProvider.multipart(
              '/v1/products',
              fields: fieldsMap,
              mediaFiles: filesMap,
            );

      print('📦 ADD_PRODUCT: Réponse reçue - success: ${response.success}');
      print('📦 ADD_PRODUCT: Réponse reçue - message: ${response.message}');
      print('📦 ADD_PRODUCT: Réponse reçue - data: ${response.data}');

      // Connexion perdue pendant l'envoi : plutôt que de perdre la saisie,
      // on la garde pour l'envoi différé.
      if (!response.success &&
          response.statusCode == 0 &&
          !isEditMode.value &&
          Get.isRegistered<ConnectivityService>() &&
          !await ConnectivityService.to.check()) {
        await _saveOffline(
          fieldsMap,
          imagesToUpload,
          labels: {
            'category_name': categoryEntry['category_name'] ?? '',
            if (subcategoryId != null)
              'subcategory_name': categoryEntry['name'] ?? '',
          },
        );
        return;
      }

      if (response.success) {
        print('');
        print('✅ ========================================');
        print(
          '✅ PRODUCT ${isEditMode.value ? "UPDATED" : "CREATED"} SUCCESSFULLY!',
        );
        print('✅ ========================================');
        print(
          '📦 Product ID: ${response.data?['product']?['id'] ?? editProductId.value ?? 'N/A'}',
        );
        print(
          '📦 Product Name: ${response.data?['product']?['name'] ?? nameController.text}',
        );

        // Afficher info stockage si disponible
        if (response.data?['storage_info'] != null) {
          final storageInfo = response.data!['storage_info'];
          print('📊 Storage used: ${storageInfo['used_mb']} MB');
          print('📊 Storage remaining: ${storageInfo['remaining_mb']} MB');
        }

        print('🧭 Navigation: Redirecting to /product-management...');
        print('');

        // Toast de succès avec style responsive
        Get.snackbar(
          isEditMode.value ? 'Produit modifié !' : 'Produit créé !',
          isEditMode.value
              ? 'Votre produit a été modifié avec succès. Redirection vers la liste...'
              : 'Votre produit a été ajouté avec succès. Redirection vers la liste...',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppThemeSystem.successColor,
          colorText: Colors.white,
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
            size: 28,
          ),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 3),
          boxShadows: [
            BoxShadow(
              color: AppThemeSystem.successColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        );

        // Navigation vers la page de gestion des produits
        // On utilise offNamed pour remplacer la page actuelle (formulaire) par product-management
        // Cela fait en sorte que le bouton back de product-management retourne au dashboard vendeur
        print(
          '🧭 Using Get.offNamed to replace current route with /product-management',
        );

        // On passe un argument pour indiquer qu'il faut rafraîchir les produits
        // La fiche est publiée : son brouillon n'a plus lieu d'être proposé.
        discardDraft();

        if (_openedFromProductManagement) {
          // La liste est juste en dessous : y revenir, elle se rafraîchit au
          // retour. `offNamed` en empilait une seconde à chaque ajout, et il
          // fallait autant de retours pour en sortir. `AppNavigation.pop` et
          // non `Get.back()`, qui ne fermerait que le snackbar ci-dessus.
          AppNavigation.pop(true);
        } else {
          Get.offNamed('/product-management', arguments: {'refresh': true});
        }
      } else {
        // Gérer les erreurs spécifiques
        if (response.data?['error_code'] == 'NO_ACTIVE_PACKAGE') {
          Get.dialog(
            AlertDialog(
              title: const Text('Package requis'),
              content: Text(
                response.message ??
                    'Vous devez souscrire à un package de stockage',
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Get.back();
                    Get.back(); // Fermer addProduct
                    Get.toNamed('/package-subscription');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesign.accent,
                  ),
                  child: const Text(
                    'Voir les packages',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        } else if (response.data?['error_code'] == 'INSUFFICIENT_STORAGE') {
          final requiredMb = response.data?['required_mb'] ?? 0;
          final availableMb = response.data?['available_mb'] ?? 0;

          Get.dialog(
            AlertDialog(
              title: const Text('Espace insuffisant'),
              content: Text(
                'Espace requis : ${requiredMb.toStringAsFixed(2)} MB\n'
                'Espace disponible : ${availableMb.toStringAsFixed(2)} MB\n\n'
                'Veuillez souscrire à un package supplémentaire.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Get.back();
                    Get.toNamed('/package-subscription');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesign.accent,
                  ),
                  child: const Text(
                    'Voir les packages',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        } else {
          Get.snackbar(
            'Erreur',
            response.message ?? 'Impossible d\'ajouter le produit',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppDesign.danger,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue lors de l\'ajout du produit: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Aucune liste du serveur n'a encore été lue sur ce téléphone.
  void warnCategoriesUnavailable() {
    if (!isOffline) _loadCategories();
    _warnMissingField(
      'Catégories indisponibles',
      isOffline
          ? 'Connectez-vous une fois pour récupérer les catégories : elles resteront ensuite disponibles hors ligne.'
          : 'Chargement des catégories en cours, réessayez dans un instant.',
    );
  }

  /// La catégorie choisie n'existe pas dans la base : le vendeur la choisit
  /// à nouveau dans la liste du serveur.
  void _invalidCategory() {
    selectedSubcategoryId.value = null;
    selectedSubcategory.value = null;
    if (!categoriesData.containsKey(selectedCategory.value)) {
      selectedCategory.value = null;
    }
    currentStep.value = 1;
    _warnMissingField(
      'Catégorie à revoir',
      categoriesAvailable.value
          ? 'Cette catégorie n\'existe plus. Choisissez-en une dans la liste.'
          : 'Les catégories n\'ont pas encore été chargées. Connectez-vous une fois pour les récupérer, puis choisissez la catégorie.',
    );
  }

  /// Met la fiche en file d'envoi (Hive) et ramène le vendeur au tableau
  /// de bord.
  Future<void> _saveOffline(
    Map<String, String> fields,
    List<XFile> images, {
    Map<String, String> labels = const {},
  }) async {
    if (!Get.isRegistered<OfflineProductSyncService>()) {
      _warnMissingField(
        'Hors ligne',
        'Impossible d\'enregistrer le produit sans connexion.',
      );
      return;
    }
    try {
      await OfflineProductSyncService.to.enqueue(
        fields: fields,
        images: images,
        labels: labels,
      );
    } catch (e) {
      _warnMissingField(
        'Enregistrement impossible',
        'Le produit n\'a pas pu être gardé sur le téléphone : $e',
      );
      return;
    }

    // La fiche est en file : son brouillon n'a plus lieu d'être proposé.
    discardDraft();

    Get.snackbar(
      'Enregistré hors ligne',
      'Votre produit sera publié automatiquement dès le retour de la connexion.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppDesign.warning,
      colorText: Colors.white,
      icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
      margin: const EdgeInsets.all(AppDesign.space4),
      borderRadius: AppDesign.radiusMd,
      duration: const Duration(seconds: 4),
    );

    // Retour à l'écran d'où l'on vient (tableau de bord ou liste) ; la
    // liste des produits, elle, demande le réseau.
    if (Get.key.currentState?.canPop() ?? false) {
      AppNavigation.pop(true);
    } else {
      Get.offAllNamed(Routes.VENDOR_DASHBOARD);
    }
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format price with user's currency
  String formatPrice(double priceInXOF, {bool showSymbol = true}) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: showSymbol);
  }

  /// Symbole de la devise actuellement sélectionnée dans le formulaire.
  String get selectedCurrencySymbol {
    final code = selectedCurrency.value.toUpperCase();
    if (code == 'XAF' || code == 'XOF') return 'FCFA';
    final match = availableCurrencies.firstWhereOrNull((c) => c.code == code);
    return match?.symbol ?? code;
  }

  void _schedulePricePreview() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 400), _loadPricePreview);
  }

  Future<void> _loadPricePreview() async {
    final price = double.tryParse(
      priceController.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
    );
    // Hors ligne, le prix client sera calculé par le serveur à l'envoi.
    if (price == null || price <= 0 || isOffline) {
      buyerPricePreview.value = null;
      return;
    }
    try {
      final res = await ApiProvider.get('/v1/pricing/preview', queryParams: {
        'price': price,
        'currency': selectedCurrency.value,
      });
      if (isClosed) return;
      final value = res.data?['data']?['buyer_price'];
      buyerPricePreview.value = res.success && value is num ? value.toDouble() : null;
    } catch (_) {
      buyerPricePreview.value = null;
    }
  }

  /// Montant formaté dans la devise choisie pour le produit (sans conversion).
  String formatInSelectedCurrency(double amount) =>
      CurrencyService.formatAmountInCurrency(amount, selectedCurrency.value);
}
