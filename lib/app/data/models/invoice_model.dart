/// Invoice model matching backend structure
class InvoiceModel {
  final int id;
  final String type;
  final String invoiceNumber;
  final DateTime date;
  final double amount;
  final String status;
  final String description;
  final String paymentMethod;
  final String? downloadUrl;
  final String? pdfUrl;

  InvoiceModel({
    required this.id,
    required this.type,
    required this.invoiceNumber,
    required this.date,
    required this.amount,
    required this.status,
    required this.description,
    required this.paymentMethod,
    this.downloadUrl,
    this.pdfUrl,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as int,
      type: json['type'] as String,
      invoiceNumber: json['invoice_number'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      description: json['description'] as String,
      paymentMethod: json['payment_method'] as String,
      downloadUrl: json['download_url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'invoice_number': invoiceNumber,
      'date': date.toIso8601String(),
      'amount': amount,
      'status': status,
      'description': description,
      'payment_method': paymentMethod,
      'download_url': downloadUrl,
      'pdf_url': pdfUrl,
    };
  }

  String getTypeLabel() {
    switch (type) {
      case 'vendor_package':
        return 'Package Vendeur';
      case 'wallet_recharge':
        return 'Recharge Wallet';
      default:
        return type;
    }
  }

  String getFormattedAmount() {
    return '${amount.toStringAsFixed(0)} FCFA';
  }
}
