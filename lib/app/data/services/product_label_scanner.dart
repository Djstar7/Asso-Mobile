import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/scan_result.dart';

/// Lecture d'une photo de produit avec Google ML Kit, entièrement sur le
/// téléphone (gratuit, sans réseau) : code-barres, texte de l'étiquette et
/// labels d'image. Non disponible sur le web.
class ProductLabelScanner {
  /// Codes-barres des produits de grande consommation (EAN/UPC).
  static const _formats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upca,
  ];

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final _barcodes = BarcodeScanner(formats: _formats);
  final _text = TextRecognizer(script: TextRecognitionScript.latin);
  final _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.6),
  );

  /// Premier code-barres lisible de l'image, ou null.
  Future<({String value, String format})?> readBarcode(InputImage image) async {
    try {
      for (final barcode in await _barcodes.processImage(image)) {
        final value = barcode.rawValue?.trim() ?? '';
        if (RegExp(r'^\d{8,14}$').hasMatch(value)) {
          return (value: value, format: barcode.format.name);
        }
      }
    } catch (e) {
      debugPrint('ProductLabelScanner: code-barres illisible ($e)');
    }
    return null;
  }

  /// Analyse complète d'une photo (capturée ou importée).
  Future<ScanExtraction> analyzeFile(String path) async {
    final image = InputImage.fromFilePath(path);
    final barcode = await readBarcode(image);

    var ocrText = '';
    var ocrLines = <String>[];
    try {
      final recognized = await _text.processImage(image);
      ocrText = recognized.text;
      final lines = [
        for (final block in recognized.blocks) ...block.lines,
      ]..removeWhere((line) => line.text.trim().isEmpty);
      // Plus grande hauteur d'abord : marque et nom sont les plus gros
      // caractères de l'étiquette.
      lines.sort(
        (a, b) => b.boundingBox.height.compareTo(a.boundingBox.height),
      );
      ocrLines = lines.map((line) => line.text.trim()).toList();
    } catch (e) {
      debugPrint('ProductLabelScanner: texte illisible ($e)');
    }

    var labels = <({String text, double confidence})>[];
    try {
      labels = (await _labeler.processImage(image))
          .map((l) => (text: l.label, confidence: l.confidence))
          .toList();
    } catch (e) {
      debugPrint('ProductLabelScanner: labels indisponibles ($e)');
    }

    return ScanExtraction(
      imagePath: path,
      barcode: barcode?.value,
      barcodeFormat: barcode?.format,
      ocrText: ocrText,
      ocrLines: ocrLines,
      labels: labels,
    );
  }

  /// Image du flux caméra convertie pour ML Kit (NV21 sur Android, BGRA sur
  /// iOS, voir [cameraImageFormat]). Null si le format n'est pas pris en
  /// charge.
  static InputImage? fromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    } else {
      final device = const {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      }[deviceOrientation] ?? 0;
      final degrees = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + device) % 360
          : (camera.sensorOrientation - device + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(degrees);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final expected =
        Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;
    if (format != expected || image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Format du flux caméra attendu par [fromCameraImage].
  static ImageFormatGroup get cameraImageFormat =>
      Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

  Future<void> close() async {
    await Future.wait([_barcodes.close(), _text.close(), _labeler.close()]);
  }
}
