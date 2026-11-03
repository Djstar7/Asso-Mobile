import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';

/// Lit un QR avec la caméra arrière et renvoie son contenu.
///
/// Sans caméra exploitable, la photo reste possible : elle passe par l'appareil
/// photo du système, sans dépendre du format des images du flux vidéo.
class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  final BarcodeScanner _scanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );

  CameraController? _camera;
  bool _permissionDenied = false;
  bool _cameraFailed = false;
  bool _processing = false;
  bool _done = false;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    setState(() {
      _permissionDenied = false;
      _cameraFailed = false;
    });
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.startImageStream(_onFrame);
      setState(() => _camera = controller);
    } on CameraException catch (e) {
      debugPrint('[QrScanner] caméra indisponible : ${e.code}');
      if (!mounted) return;
      setState(() {
        if (e.code.contains('AccessDenied') ||
            e.code.contains('AccessRestricted')) {
          _permissionDenied = true;
        } else {
          _cameraFailed = true;
        }
      });
    } catch (e) {
      debugPrint('[QrScanner] caméra indisponible : $e');
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processing || _done) return;
    final input = _inputFrom(image);
    if (input == null) return;

    _processing = true;
    try {
      _report(await _scanner.processImage(input));
    } catch (e) {
      debugPrint('[QrScanner] image illisible : $e');
    } finally {
      _processing = false;
    }
  }

  InputImage? _inputFrom(CameraImage image) {
    final camera = _camera;
    if (camera == null || image.planes.length != 1) return null;

    final sensor = camera.description.sensorOrientation;
    final InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      final device = _orientations[camera.value.deviceOrientation];
      if (device == null) return null;
      rotation = InputImageRotationValue.fromRawValue(
        (sensor - device + 360) % 360,
      );
    }
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _scanFromPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo == null || !mounted) return;
    try {
      final codes = await _scanner.processImage(
        InputImage.fromFilePath(photo.path),
      );
      _report(codes);
      if (!_done && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('web_login.scanner.no_code'.tr)));
      }
    } catch (e) {
      debugPrint('[QrScanner] photo illisible : $e');
    }
  }

  void _report(List<Barcode> codes) {
    if (_done || !mounted) return;
    for (final code in codes) {
      final value = code.rawValue;
      if (value != null && value.isNotEmpty) {
        _done = true;
        Navigator.of(context).pop<String>(value);
        return;
      }
    }
  }

  @override
  void dispose() {
    final camera = _camera;
    _camera = null;
    camera?.dispose();
    _scanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: const AppBackButton(color: Colors.white),
        title: Text('web_login.scanner.title'.tr),
      ),
      body: _permissionDenied || _cameraFailed
          ? _buildCameraProblem(context)
          : camera == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                Center(child: CameraPreview(camera)),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(AppDesign.radiusLg),
                    ),
                  ),
                ),
                Positioned(
                  left: AppDesign.space4,
                  right: AppDesign.space4,
                  bottom: AppDesign.space6,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'web_login.scanner.hint'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: AppDesign.space2),
                        TextButton.icon(
                          onPressed: _scanFromPhoto,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text('web_login.scanner.use_photo'.tr),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCameraProblem(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesign.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: AppDesign.space3),
            Text(
              _permissionDenied
                  ? 'web_login.scanner.permission_denied'.tr
                  : 'web_login.scanner.camera_failed'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: AppDesign.space4),
            if (_permissionDenied)
              TextButton(
                onPressed: openAppSettings,
                child: Text('web_login.scanner.open_settings'.tr),
              ),
            TextButton(
              onPressed: _scanFromPhoto,
              child: Text('web_login.scanner.use_photo'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
