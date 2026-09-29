import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/scan_result.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../data/services/product_label_scanner.dart';

enum ScanStage { starting, scanning, analysing, searching, unavailable }

/// Viseur « Remplir automatiquement » de l'ajout de produit.
///
/// Le code-barres est lu en direct dans le flux caméra ; la capture (ou une
/// photo importée) est ensuite analysée en entier : texte de l'étiquette et
/// labels. Le serveur propose une fiche, rendue au formulaire avec la photo
/// via `Get.back(result: ScanResult)`.
///
/// Argument optionnel `{'source': 'gallery'}` : ouvre directement la galerie.
class ProductScanController extends GetxController with WidgetsBindingObserver {
  final stage = ScanStage.starting.obs;
  final unavailableMessage = ''.obs;
  final detectedBarcode = Rxn<String>();
  final camera = Rxn<CameraController>();

  final _scanner = ProductLabelScanner();
  final _picker = ImagePicker();
  String? _detectedFormat;
  bool _frameBusy = false;
  // La galerie met l'application en arrière-plan : la caméra ne doit pas
  // redémarrer pendant ce temps.
  bool _picking = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  late final bool galleryOnly;

  bool get isBusy =>
      stage.value == ScanStage.analysing || stage.value == ScanStage.searching;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    galleryOnly = args is Map && args['source'] == 'gallery';
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onReady() {
    super.onReady();
    if (galleryOnly) {
      pickFromGallery();
    } else {
      _startCamera();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _scanner.close();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // La caméra est libérée en arrière-plan puis rouverte au retour.
    if (galleryOnly || isBusy || _picking) return;
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && camera.value == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    stage.value = ScanStage.starting;
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhereOrNull(
            (c) => c.lensDirection == CameraLensDirection.back,
          ) ??
          cameras.firstOrNull;
      if (back == null) {
        _unavailable('Aucune caméra disponible. Importez une photo depuis la galerie.');
        return;
      }
      final controller = CameraController(
        back,
        // Assez fin pour lire une étiquette, sans alourdir la photo produit.
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ProductLabelScanner.cameraImageFormat,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (isClosed) {
        await controller.dispose();
        return;
      }
      camera.value = controller;
      stage.value = ScanStage.scanning;
      await controller.startImageStream(
        (image) => _onFrame(image, controller),
      );
    } on CameraException catch (e) {
      final denied = e.code.contains('Denied') || e.code.contains('denied');
      _unavailable(
        denied
            ? 'Autorisez l\'accès à la caméra dans les réglages du téléphone, '
                'ou importez une photo depuis la galerie.'
            : 'La caméra n\'a pas pu démarrer. Importez une photo depuis la galerie.',
      );
    }
  }

  void _unavailable(String message) {
    unavailableMessage.value = message;
    stage.value = ScanStage.unavailable;
  }

  Future<void> _stopCamera() async {
    final controller = camera.value;
    camera.value = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}
    await controller.dispose();
  }

  /// Lecture du code-barres en direct : une image à la fois, 4 par seconde
  /// au plus, et plus rien une fois le code trouvé.
  Future<void> _onFrame(CameraImage image, CameraController controller) async {
    if (_frameBusy || detectedBarcode.value != null || isBusy) return;
    final now = DateTime.now();
    if (now.difference(_lastFrame) < const Duration(milliseconds: 250)) return;
    _lastFrame = now;
    _frameBusy = true;
    try {
      final input = ProductLabelScanner.fromCameraImage(
        image,
        controller.description,
        controller.value.deviceOrientation,
      );
      if (input == null) return;
      final barcode = await _scanner.readBarcode(input);
      if (barcode != null && detectedBarcode.value == null) {
        detectedBarcode.value = barcode.value;
        _detectedFormat = barcode.format;
        HapticFeedback.mediumImpact();
      }
    } finally {
      _frameBusy = false;
    }
  }

  /// Photo de l'étiquette depuis le viseur.
  Future<void> capture() async {
    final controller = camera.value;
    if (controller == null || isBusy || controller.value.isTakingPicture) return;
    stage.value = ScanStage.analysing;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final photo = await controller.takePicture();
      await _process(photo.path);
    } on CameraException {
      Get.snackbar('Photo impossible', 'Réessayez ou importez une photo.',
          snackPosition: SnackPosition.BOTTOM);
      await _resumeScanning();
    }
  }

  Future<void> _resumeScanning() async {
    final controller = camera.value;
    stage.value = ScanStage.scanning;
    if (controller != null && !controller.value.isStreamingImages) {
      await controller.startImageStream((image) => _onFrame(image, controller));
    }
  }

  Future<void> pickFromGallery() async {
    if (isBusy || _picking) return;
    _picking = true;
    final XFile? photo;
    try {
      photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
    } finally {
      _picking = false;
    }
    if (photo == null) {
      if (galleryOnly) Get.back();
      return;
    }
    stage.value = ScanStage.analysing;
    final controller = camera.value;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await _process(photo.path);
  }

  Future<void> _process(String path) async {
    var extraction = await _scanner.analyzeFile(path);
    // Le code vu en direct vaut mieux qu'un code flou sur la capture.
    if (detectedBarcode.value != null) {
      extraction = extraction.copyWith(
        barcode: detectedBarcode.value,
        barcodeFormat: _detectedFormat,
      );
    }

    ScanSuggestion? suggestion;
    if (!extraction.isEmpty && !ConnectivityService.isOffline) {
      stage.value = ScanStage.searching;
      final response = await ProductService.scanLookup(extraction.toPayload());
      final data = response.data?['data'];
      if (response.success && data is Map) {
        suggestion = ScanSuggestion.fromApi(Map<String, dynamic>.from(data));
      }
    }

    await _stopCamera();
    Get.back(result: ScanResult(extraction: extraction, suggestion: suggestion));
  }
}
