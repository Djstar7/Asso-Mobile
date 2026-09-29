/// Produit créé hors ligne, en attente d'envoi au serveur.
///
/// Il garde exactement ce que le formulaire aurait envoyé (champs du
/// multipart `POST /v1/products`) et les chemins de ses photos, copiées dans
/// le dossier de l'application pour survivre au nettoyage du cache système.
class PendingProduct {
  PendingProduct({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.fields,
    required this.imagePaths,
    this.labels = const {},
    this.status = PendingProductStatus.pending,
    this.error,
    this.attempts = 0,
  });

  final String id;

  /// Vendeur qui l'a saisi : seul lui peut l'envoyer.
  final int userId;
  final DateTime createdAt;
  final Map<String, String> fields;
  final List<String> imagePaths;

  /// Libellés de la catégorie choisie (`category_name`, `subcategory_name`).
  /// Jamais envoyés : ils servent à retrouver les bons identifiants si la
  /// liste des catégories a changé entre la saisie et l'envoi.
  final Map<String, String> labels;

  String status;

  /// Motif du refus par le serveur, affiché au vendeur.
  String? error;
  int attempts;

  String get name {
    final value = fields['name']?.trim() ?? '';
    return value.isNotEmpty ? value : 'Produit sans nom';
  }

  bool get isFailed => status == PendingProductStatus.failed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'created_at': createdAt.toIso8601String(),
        'fields': fields,
        'image_paths': imagePaths,
        'labels': labels,
        'status': status,
        'error': error,
        'attempts': attempts,
      };

  static PendingProduct? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final userId = (json['user_id'] as num?)?.toInt();
    final createdAt = DateTime.tryParse('${json['created_at']}');
    if (id == null || userId == null || createdAt == null) return null;

    var status = '${json['status'] ?? PendingProductStatus.pending}';
    // Un envoi interrompu (application tuée) repart en attente.
    if (status == PendingProductStatus.syncing) {
      status = PendingProductStatus.pending;
    }

    return PendingProduct(
      id: id,
      userId: userId,
      createdAt: createdAt,
      fields: Map<String, String>.from(
        (json['fields'] as Map? ?? const {})
            .map((key, value) => MapEntry('$key', '${value ?? ''}')),
      ),
      imagePaths: (json['image_paths'] as List? ?? const [])
          .map((e) => '$e')
          .toList(),
      labels: Map<String, String>.from(
        (json['labels'] as Map? ?? const {})
            .map((key, value) => MapEntry('$key', '${value ?? ''}')),
      ),
      status: status,
      error: json['error']?.toString(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

class PendingProductStatus {
  PendingProductStatus._();

  static const pending = 'pending';
  static const syncing = 'syncing';

  /// Refusé par le serveur (données invalides, forfait…) : n'est plus
  /// renvoyé automatiquement, le vendeur choisit de réessayer ou de retirer.
  static const failed = 'failed';
}
