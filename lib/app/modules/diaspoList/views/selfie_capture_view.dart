import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/app_design.dart';

/// Selfie de vérification Diaspo, pris en direct avec la caméra frontale (pas
/// de galerie). ML Kit vérifie sur l'appareil qu'il y a un seul visage, assez
/// grand et les yeux ouverts ; l'admin compare ensuite le selfie à la pièce.
class SelfieCaptureView extends StatefulWidget {
  const SelfieCaptureView({super.key});

  /// Ouvre la caméra et renvoie le selfie validé (null si annulé).
  /// Sur le web, ML Kit n'existe pas : repli sur la caméra du navigateur.
  static Future<XFile?> capture() async {
    if (kIsWeb) {
      return ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
    }
    return Get.to<XFile>(() => const SelfieCaptureView(), fullscreenDialog: true);
  }

  @override
  State<SelfieCaptureView> createState() => _SelfieCaptureViewState();
}

class _SelfieCaptureViewState extends State<SelfieCaptureView> {
  CameraController? _camera;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(front, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (_) {
      setState(() => _message = 'selfie.camera_unavailable'.tr);
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _detector.close();
    super.dispose();
  }

  Future<void> _shoot() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final photo = await camera.takePicture();
      final faces = await _detector.processImage(InputImage.fromFilePath(photo.path));
      final error = _check(faces);
      if (error != null) {
        setState(() => _message = error);
        return;
      }
      Get.back(result: photo);
    } catch (_) {
      setState(() => _message = 'selfie.retry'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Motif de refus, ou null si le selfie est exploitable.
  String? _check(List<Face> faces) {
    if (faces.isEmpty) return 'selfie.no_face'.tr;
    if (faces.length > 1) return 'selfie.several_faces'.tr;
    final face = faces.first;
    // Visage trop petit : la personne est trop loin pour être comparée à la pièce.
    if (face.boundingBox.width < 200) return 'selfie.too_far'.tr;
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left != null && right != null && (left < 0.4 || right < 0.4)) {
      return 'selfie.eyes_closed'.tr;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('selfie.title'.tr),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: camera == null || !camera.value.isInitialized
                  ? (_message != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_message!, textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white)),
                        )
                      : const CircularProgressIndicator())
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        CameraPreview(camera),
                        // Gabarit ovale pour cadrer le visage.
                        IgnorePointer(
                          child: Container(
                            width: 240,
                            height: 320,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white70, width: 3),
                              borderRadius: const BorderRadius.all(Radius.elliptical(120, 160)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Text(
              _message ?? 'selfie.hint'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: _message != null ? AppDesign.accent : Colors.white70),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: SizedBox(
                width: 76,
                height: 76,
                child: ElevatedButton(
                  onPressed: camera == null || _busy ? null : _shoot,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  child: _busy
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(Icons.camera_alt, color: Colors.black, size: 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
