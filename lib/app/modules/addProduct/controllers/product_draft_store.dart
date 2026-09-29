import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Brouillon local d'une fiche produit en cours de rédaction.
///
/// Créer un produit demande plusieurs minutes : photos, description, prix,
/// déclinaisons. Un appel entrant ou un retour arrière effaçait tout. Le
/// brouillon est donc réécrit à chaque étape franchie, puis proposé au vendeur
/// à sa prochaine visite.
///
/// Seule la création est concernée : une modification de produit existant part
/// toujours des données du serveur, qui font foi.
class ProductDraft {
  ProductDraft({
    required this.savedAt,
    required this.step,
    required this.fields,
    required this.imagePaths,
    required this.primaryImageIndex,
    required this.variants,
  });

  final DateTime savedAt;

  /// Dernière étape atteinte, pour rouvrir le formulaire au bon endroit.
  final int step;

  /// Champs texte du formulaire (nom, prix, description…).
  final Map<String, String> fields;

  /// Chemins locaux des photos choisies.
  final List<String> imagePaths;

  final int primaryImageIndex;

  /// État complet de l'éditeur de déclinaisons.
  final Map<String, dynamic> variants;

  /// Libellé court pour la reprise (« Chaussures en cuir », ou l'étape en cours).
  String get label {
    final name = fields['name']?.trim() ?? '';
    return name.isNotEmpty ? name : 'add_product.draft.unnamed'.tr;
  }

  /// Ne garde que les photos encore présentes sur l'appareil : une image
  /// supprimée de la galerie entre deux sessions ferait échouer l'envoi.
  List<String> get existingImagePaths =>
      imagePaths.where((path) => File(path).existsSync()).toList();

  Map<String, dynamic> toJson() => {
        'savedAt': savedAt.toIso8601String(),
        'step': step,
        'fields': fields,
        'imagePaths': imagePaths,
        'primaryImageIndex': primaryImageIndex,
        'variants': variants,
      };

  static ProductDraft? fromJson(Map<String, dynamic> json) {
    final savedAt = DateTime.tryParse(json['savedAt']?.toString() ?? '');
    if (savedAt == null) return null;
    return ProductDraft(
      savedAt: savedAt,
      step: (json['step'] as num?)?.toInt() ?? 0,
      fields: Map<String, String>.from(
        (json['fields'] as Map?)?.map(
              (key, value) => MapEntry('$key', '${value ?? ''}'),
            ) ??
            const {},
      ),
      imagePaths: (json['imagePaths'] as List?)
              ?.map((e) => '$e')
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      primaryImageIndex: (json['primaryImageIndex'] as num?)?.toInt() ?? 0,
      variants: Map<String, dynamic>.from(
        (json['variants'] as Map?) ?? const {},
      ),
    );
  }
}

/// Persistance du brouillon, isolée pour rester testable et remplaçable.
class ProductDraftStore {
  ProductDraftStore._();

  static const _key = 'add_product_draft_v1';

  /// Au-delà, le brouillon est considéré comme périmé : reprendre une fiche
  /// vieille de plusieurs semaines apporte plus de confusion que d'aide.
  static const _maxAge = Duration(days: 14);

  static GetStorage get _box => GetStorage();

  static Future<void> init() => GetStorage.init();

  static void save(ProductDraft draft) {
    try {
      _box.write(_key, jsonEncode(draft.toJson()));
    } catch (_) {
      // Un brouillon est un confort : son échec ne doit jamais interrompre
      // la saisie en cours.
    }
  }

  /// Renvoie le brouillon exploitable, ou `null` s'il est absent, illisible,
  /// périmé, ou si toutes ses photos ont disparu de l'appareil.
  static ProductDraft? read() {
    try {
      final raw = _box.read<String>(_key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final draft = ProductDraft.fromJson(Map<String, dynamic>.from(decoded));
      if (draft == null) return null;

      if (DateTime.now().difference(draft.savedAt) > _maxAge) {
        clear();
        return null;
      }
      return draft;
    } catch (_) {
      clear();
      return null;
    }
  }

  static bool get hasDraft => read() != null;

  static void clear() {
    try {
      _box.remove(_key);
    } catch (_) {
      // Rien à faire : le brouillon sera écrasé au prochain enregistrement.
    }
  }
}
