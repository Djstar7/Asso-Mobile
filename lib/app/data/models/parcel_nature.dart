/// Nature d'un colis Diaspo (téléphone, bijoux, document administratif…),
/// choisie dans la liste gérée par ASSO pour calculer l'assurance.
class ParcelNature {
  final int id;
  final String name;

  /// Taux en % de la valeur déclarée.
  final double insuranceRate;

  /// Supplément minimum, en FCFA.
  final double minInsuranceAmount;

  ParcelNature({
    required this.id,
    required this.name,
    required this.insuranceRate,
    required this.minInsuranceAmount,
  });

  factory ParcelNature.fromJson(Map<String, dynamic> json) => ParcelNature(
        id: json['id'] as int,
        name: json['name']?.toString() ?? '',
        insuranceRate: double.tryParse(json['insurance_rate'].toString()) ?? 0,
        minInsuranceAmount:
            double.tryParse(json['min_insurance_amount'].toString()) ?? 0,
      );
}
