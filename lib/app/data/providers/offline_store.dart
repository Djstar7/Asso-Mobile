import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import 'storage_service.dart';

/// Base locale Hive du mode hors ligne vendeur.
///
/// Deux boîtes, toutes deux en JSON texte (pas d'adaptateur généré à
/// maintenir, et une donnée illisible se jette sans casser la boîte) :
/// - `offline_cache` : dernières réponses du serveur utiles au chemin
///   tableau de bord → ajout de produit (tableau de bord, catégories…),
///   rangées par vendeur pour qu'un changement de compte n'affiche jamais
///   les données d'un autre ;
/// - `offline_products` : produits créés sans réseau, en attente d'envoi.
///
/// Les photos de ces produits vont dans une troisième boîte, en octets et
/// chargée à la demande (`offline_product_images`) : elle marche sur le web
/// comme sur téléphone, sans système de fichiers.
class OfflineStore {
  OfflineStore._();

  static const _cacheBoxName = 'offline_cache';
  static const _productsBoxName = 'offline_products';
  static const _imagesBoxName = 'offline_product_images';

  static Box<String>? _cache;
  static Box<String>? _products;
  static LazyBox<Uint8List>? _images;

  static bool get isReady =>
      _cache != null && _products != null && _images != null;

  /// À appeler une fois au démarrage, avant tout écran.
  static Future<void> init() async {
    if (isReady) return;
    await Hive.initFlutter();
    _cache = await _openBox(_cacheBoxName);
    _products = await _openBox(_productsBoxName);
    _images = await _openImageBox();
  }

  static Future<LazyBox<Uint8List>> _openImageBox() async {
    try {
      return await Hive.openLazyBox<Uint8List>(_imagesBoxName);
    } catch (_) {
      await Hive.deleteBoxFromDisk(_imagesBoxName);
      return Hive.openLazyBox<Uint8List>(_imagesBoxName);
    }
  }

  /// Une boîte corrompue (écriture interrompue) ne doit pas empêcher
  /// l'application de démarrer : on la recrée vide.
  static Future<Box<String>> _openBox(String name) async {
    try {
      return await Hive.openBox<String>(name);
    } catch (_) {
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<String>(name);
    }
  }

  // ── Instantanés du serveur ────────────────────────────────────────────

  static String? get _userScope {
    final id = StorageService.getUser()?.id;
    return id == null ? null : 'u$id';
  }

  /// Mémorise la dernière réponse [data] connue pour [key], pour le vendeur
  /// connecté.
  static Future<void> saveSnapshot(String key, Object? data) async {
    final scope = _userScope;
    final box = _cache;
    if (scope == null || box == null || data == null) return;
    try {
      await box.put(
        '$scope:$key',
        jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'data': data,
        }),
      );
    } catch (_) {
      // Un instantané est un confort : son échec n'interrompt rien.
    }
  }

  /// Dernière réponse connue pour [key], ou null.
  static dynamic readSnapshot(String key) {
    final scope = _userScope;
    final raw = scope == null ? null : _cache?.get('$scope:$key');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map)['data'];
    } catch (_) {
      _cache?.delete('$scope:$key');
      return null;
    }
  }

  // ── File des produits en attente ──────────────────────────────────────

  static Iterable<Map<String, dynamic>> readPendingProducts() sync* {
    final box = _products;
    if (box == null) return;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        yield Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        box.delete(key);
      }
    }
  }

  static Future<void> putPendingProduct(String id, Map<String, dynamic> json) async {
    await _products?.put(id, jsonEncode(json));
  }

  static Future<void> deletePendingProduct(String id) async {
    await _products?.delete(id);
  }

  // ── Photos des produits en attente ────────────────────────────────────

  static Future<void> putPendingImage(String key, Uint8List bytes) async {
    final box = _images;
    if (box == null) throw StateError('Offline store not ready');
    await box.put(key, bytes);
  }

  static Future<Uint8List?> readPendingImage(String key) async {
    try {
      return await _images?.get(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deletePendingImages(Iterable<String> keys) async {
    await _images?.deleteAll(keys);
  }
}
