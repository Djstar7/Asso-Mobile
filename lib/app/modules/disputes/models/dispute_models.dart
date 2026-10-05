import 'package:get/get.dart';

/// Motifs d'une réclamation, dans l'ordre affiché au client.
const disputeReasons = ['different', 'damaged', 'defective', 'incomplete', 'wrong_variant', 'other'];

double _double(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

int _int(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;

DateTime? _date(dynamic value) => value == null ? null : DateTime.tryParse('$value')?.toLocal();

/// Fenêtre de contrôle de 48 h d'une commande livrée.
class OrderControlInfo {
  final bool windowOpen;
  final DateTime? until;
  final bool validated;

  const OrderControlInfo({this.windowOpen = false, this.until, this.validated = false});

  static OrderControlInfo? fromMap(dynamic map) {
    if (map is! Map) return null;
    return OrderControlInfo(
      windowOpen: map['window_open'] == true,
      until: _date(map['until']),
      validated: map['validated'] == true,
    );
  }
}

/// Réclamation rattachée à un article dans la liste des commandes.
class OrderItemDisputeRef {
  final int id;
  final String number;
  final String status;

  const OrderItemDisputeRef({required this.id, required this.number, required this.status});

  static OrderItemDisputeRef? fromMap(dynamic map) {
    if (map is! Map) return null;
    return OrderItemDisputeRef(
      id: _int(map['id']),
      number: '${map['number'] ?? ''}',
      status: '${map['status'] ?? ''}',
    );
  }

  String get statusLabel => 'disputes.status.$status'.tr;
}

class DisputeEventInfo {
  final String label;
  final String? note;
  final String actorType;
  final DateTime? occurredAt;

  const DisputeEventInfo({required this.label, this.note, required this.actorType, this.occurredAt});

  factory DisputeEventInfo.fromMap(Map<String, dynamic> map) => DisputeEventInfo(
        label: '${map['label'] ?? ''}',
        note: map['note']?.toString(),
        actorType: '${map['actor_type'] ?? ''}',
        occurredAt: _date(map['occurred_at']),
      );
}

/// Course de remplacement (Cas A) ou de retour (Cas B), payée par le vendeur.
class DisputeShipmentInfo {
  final int id;
  final String type;
  final String? companyName;
  final double price;
  final String payer;
  final String paymentStatus;
  final String status;
  final String statusLabel;
  final List<MapEntry<String, String>> steps;
  final String? trackingNumber;

  const DisputeShipmentInfo({
    required this.id,
    required this.type,
    this.companyName,
    required this.price,
    required this.payer,
    required this.paymentStatus,
    required this.status,
    required this.statusLabel,
    required this.steps,
    this.trackingNumber,
  });

  bool get isReturn => type == 'return';
  bool get isPaid => paymentStatus == 'paid';

  /// Index de l'étape courante dans [steps] (-1 si inconnue).
  int get currentIndex => steps.indexWhere((s) => s.key == status);

  static DisputeShipmentInfo? fromMap(dynamic map) {
    if (map is! Map) return null;
    return DisputeShipmentInfo(
      id: _int(map['id']),
      type: '${map['type'] ?? ''}',
      companyName: map['company_name']?.toString(),
      price: _double(map['price']),
      payer: '${map['payer'] ?? 'vendor'}',
      paymentStatus: '${map['payment_status'] ?? 'pending'}',
      status: '${map['status'] ?? ''}',
      statusLabel: '${map['status_label'] ?? ''}',
      steps: ((map['steps'] as List?) ?? const [])
          .whereType<Map>()
          .map((s) => MapEntry('${s['key']}', '${s['label']}'))
          .toList(),
      trackingNumber: map['carrier_tracking_number']?.toString(),
    );
  }
}

/// Litige complet, tel que le voit le client ou le vendeur.
class Dispute {
  final int id;
  final String number;
  final int orderId;
  final String? orderNumber;
  final String productName;
  final String? productImage;
  final int quantity;
  final double totalPrice;
  final String reason;
  final String description;
  final String status;
  final String? decision;
  final String? decisionNote;
  final int replacementCount;
  final double? heldAmount;
  final double? refundAmount;
  final DateTime? replacementControlUntil;
  final List<String> attachments;
  final List<DisputeEventInfo> events;
  final DisputeShipmentInfo? replacement;
  final DisputeShipmentInfo? returnShipment;
  final Map<String, dynamic> actions;
  final DateTime? createdAt;

  const Dispute({
    required this.id,
    required this.number,
    required this.orderId,
    this.orderNumber,
    required this.productName,
    this.productImage,
    required this.quantity,
    required this.totalPrice,
    required this.reason,
    required this.description,
    required this.status,
    this.decision,
    this.decisionNote,
    this.replacementCount = 0,
    this.heldAmount,
    this.refundAmount,
    this.replacementControlUntil,
    this.attachments = const [],
    this.events = const [],
    this.replacement,
    this.returnShipment,
    this.actions = const {},
    this.createdAt,
  });

  factory Dispute.fromMap(Map<String, dynamic> map) {
    final product = Map<String, dynamic>.from(map['product'] as Map? ?? const {});
    return Dispute(
      id: _int(map['id']),
      number: '${map['number'] ?? ''}',
      orderId: _int(map['order_id']),
      orderNumber: map['order_number']?.toString(),
      productName: product['name']?.toString() ?? 'my_order.default_product'.tr,
      productImage: product['image']?.toString(),
      quantity: _int(product['quantity']),
      totalPrice: _double(product['total_price']),
      reason: '${map['reason'] ?? 'other'}',
      description: '${map['description'] ?? ''}',
      status: '${map['status'] ?? 'new'}',
      decision: map['decision']?.toString(),
      decisionNote: map['decision_note']?.toString(),
      replacementCount: _int(map['replacement_count']),
      heldAmount: map['held_amount'] == null ? null : _double(map['held_amount']),
      refundAmount: map['refund_amount'] == null ? null : _double(map['refund_amount']),
      replacementControlUntil: _date(map['replacement_control_until']),
      attachments: ((map['attachments'] as List?) ?? const [])
          .whereType<Map>()
          .map((a) => '${a['url'] ?? ''}')
          .where((url) => url.isNotEmpty)
          .toList(),
      events: ((map['events'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => DisputeEventInfo.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      replacement: DisputeShipmentInfo.fromMap(map['replacement']),
      returnShipment: DisputeShipmentInfo.fromMap(map['return']),
      actions: Map<String, dynamic>.from(map['actions'] as Map? ?? const {}),
      createdAt: _date(map['created_at']),
    );
  }

  String get statusLabel => 'disputes.status.$status'.tr;
  String get reasonLabel => 'disputes.reasons.$reason'.tr;

  bool action(String key) => actions[key] == true;

  /// Course que le vendeur doit encore payer (null sinon).
  int? get pendingShipmentId {
    final id = actions['pending_shipment_id'];
    return id == null ? null : _int(id);
  }

  bool get isOpen => const ['new', 'in_review', 'vendor_contacted', 'replacement', 'return'].contains(status);
}
