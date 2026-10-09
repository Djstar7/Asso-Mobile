import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/wholesale_models.dart';
import '../../../data/providers/api_provider.dart';

enum ProductVideoPhase { none, uploading, processing, ready, failed }

/// Vidéo de présentation du formulaire produit (facultative).
///
/// Comme sur le formulaire admin, la vidéo part dès qu'elle est choisie, par
/// morceaux de 4 Mo : une barre de progression réelle, un morceau perdu se
/// renvoie seul, et aucune limite d'envoi PHP ne s'applique. Seul son
/// identifiant (`video_id`) accompagne ensuite l'enregistrement du produit ;
/// le serveur la convertit (ffmpeg) et ne l'expose qu'une fois prête.
class ProductVideoUpload {
  /// Limites du serveur (ProductVideo::MAX_SIZE_MB / EXTENSIONS).
  static const int maxSizeMb = 100;
  static const List<String> extensions = [
    'mp4',
    'mov',
    'm4v',
    'webm',
    '3gp',
    'mkv',
  ];
  static const int _chunkSize = 4 * 1024 * 1024;
  static const int _attemptsPerChunk = 3;
  static const String _endpoint = '/v1/vendor/product-videos';

  final phase = ProductVideoPhase.none.obs;

  /// Avancement de l'envoi, de 0 à 1.
  final progress = 0.0.obs;

  /// Clé de traduction de la dernière erreur, et ses paramètres.
  final errorKey = RxnString();
  final errorParams = Rxn<Map<String, String>>();

  /// Vidéo déjà rattachée au produit modifié (affiche, durée).
  final existing = Rxn<WholesaleVideo>();

  /// Fichier choisi sur ce téléphone, en cours d'envoi ou envoyé.
  final picked = Rxn<XFile>();

  /// Vidéo envoyée pendant cette saisie, à rattacher à l'enregistrement.
  int? _uploadedId;

  /// Le produit modifié a déjà une vidéo sur le serveur (prête ou non).
  bool _hasServerVideo = false;

  /// La vidéo existante a été retirée par le vendeur.
  bool _removeExisting = false;

  /// Incrémenté à chaque nouveau choix ou retrait : un envoi dépassé s'arrête.
  int _generation = 0;
  Timer? _pollTimer;

  bool get isUploading => phase.value == ProductVideoPhase.uploading;

  /// Fiche en modification : la vidéo actuelle, telle que l'API la renvoie.
  void loadExisting(Map<String, dynamic> product) {
    final video = WholesaleVideo.fromJson(product['video']);
    existing.value = video;
    _hasServerVideo = video != null || product['video_status'] != null;
    if (video != null) {
      phase.value = ProductVideoPhase.ready;
    } else if (product['video_status'] == 'pending' ||
        product['video_status'] == 'processing') {
      // Envoyée mais pas encore convertie : on ne la propose pas comme
      // manquante, le vendeur peut toujours la remplacer.
      phase.value = ProductVideoPhase.processing;
    }
  }

  /// Champs à joindre à l'enregistrement du produit.
  Map<String, String> toFields() {
    final id = _uploadedId;
    if (id != null) return {'video_id': '$id'};
    if (_removeExisting) return {'remove_video': '1'};
    return const {};
  }

  /// Envoie [file] au serveur, morceau par morceau.
  Future<void> upload(XFile file) async {
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';
    if (!extensions.contains(extension)) {
      _fail('add_product.video.unsupported_format');
      return;
    }
    final size = await file.length();
    if (size > maxSizeMb * 1024 * 1024) {
      _fail('add_product.video.too_large');
      return;
    }

    _discardUploaded();
    final generation = ++_generation;
    picked.value = file;
    progress.value = 0;
    errorKey.value = null;
    phase.value = ProductVideoPhase.uploading;

    final uploadId = _uuidV4();
    final total = (size / _chunkSize).ceil().clamp(1, 500);

    for (var index = 0; index < total; index++) {
      final start = index * _chunkSize;
      final end = min(start + _chunkSize, size);
      final bytes = await _readRange(file, start, end);

      ApiResponse? response;
      for (var attempt = 0; attempt < _attemptsPerChunk; attempt++) {
        if (generation != _generation) return;
        response = await ApiProvider.multipart(
          '$_endpoint/chunks',
          fields: {
            'upload_id': uploadId,
            'index': '$index',
            'total': '$total',
            'size': '$size',
            'name': file.name,
          },
          mediaFiles: {
            'chunk': XFile.fromData(bytes, name: 'chunk-$index.part'),
          },
        );
        // Une erreur de saisie (422) ne se corrige pas en renvoyant.
        if (response.success ||
            (response.statusCode >= 400 && response.statusCode < 500)) {
          break;
        }
      }
      if (generation != _generation) return;

      if (response == null || !response.success) {
        _failFromResponse(response);
        return;
      }
      progress.value = (index + 1) / total;

      final video = response.data?['video'];
      if (response.data?['complete'] == true && video is Map) {
        _uploadedId = (video['id'] as num?)?.toInt();
        _applyStatus(video['status']?.toString());
        _pollUntilReady(generation);
      }
    }
  }

  /// Retire la vidéo : un envoi en cours s'arrête, une vidéo envoyée pendant
  /// cette saisie est supprimée, la vidéo existante le sera à l'enregistrement.
  void remove() {
    _generation++;
    _discardUploaded();
    if (_hasServerVideo) _removeExisting = true;
    existing.value = null;
    picked.value = null;
    progress.value = 0;
    errorKey.value = null;
    phase.value = ProductVideoPhase.none;
  }

  void dispose() {
    _generation++;
    _pollTimer?.cancel();
  }

  /// Suit la conversion pour afficher « prête » : l'enregistrement du produit
  /// n'a pas besoin de l'attendre.
  void _pollUntilReady(int generation) {
    _pollTimer?.cancel();
    if (phase.value != ProductVideoPhase.processing) return;
    var remaining = 60;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final id = _uploadedId;
      if (generation != _generation || id == null || --remaining < 0) {
        timer.cancel();
        return;
      }
      final response = await ApiProvider.get('$_endpoint/$id');
      if (generation != _generation) return;
      final video = response.data?['video'];
      if (response.success && video is Map) {
        _applyStatus(video['status']?.toString());
        if (phase.value != ProductVideoPhase.processing) timer.cancel();
      }
    });
  }

  void _applyStatus(String? status) {
    switch (status) {
      case 'ready':
        phase.value = ProductVideoPhase.ready;
      case 'failed':
        _fail('add_product.video.processing_failed');
      default:
        phase.value = ProductVideoPhase.processing;
    }
  }

  void _fail(String key, [Map<String, String>? params]) {
    errorKey.value = key;
    errorParams.value = params;
    phase.value = ProductVideoPhase.failed;
  }

  /// La vidéo est décomptée de l'espace du forfait, comme les photos : le
  /// serveur refuse l'envoi d'emblée quand elle n'y tient pas.
  void _failFromResponse(ApiResponse? response) {
    switch (response?.data?['error_code']) {
      case 'INSUFFICIENT_STORAGE':
        final required = response?.data?['required_mb'];
        final available = response?.data?['available_mb'];
        _fail('add_product.video.storage_insufficient', {
          'required': '${required ?? ''}',
          'available': '${available ?? ''}',
        });
      case 'NO_ACTIVE_PACKAGE':
        _fail('add_product.video.package_required');
      default:
        _fail('add_product.video.upload_failed');
    }
  }

  /// Supprime côté serveur la vidéo envoyée pendant cette saisie et pas
  /// encore rattachée (sinon le ménage quotidien s'en charge).
  void _discardUploaded() {
    _pollTimer?.cancel();
    final id = _uploadedId;
    _uploadedId = null;
    if (id != null) ApiProvider.delete('$_endpoint/$id');
  }

  static Future<Uint8List> _readRange(XFile file, int start, int end) async {
    final builder = BytesBuilder(copy: false);
    await for (final part in file.openRead(start, end)) {
      builder.add(part);
    }
    return builder.takeBytes();
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
