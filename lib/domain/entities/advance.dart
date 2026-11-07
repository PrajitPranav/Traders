/// Business entity representing a prepaid salary advance payment.
class Advance {
  final String id;
  final String employeeId;
  final int amountPaise; // Integer paise
  final String transactionDate; // ISO-8601 YYYY-MM-DD
  final String salaryPeriod; // YYYY-MM
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Advance({
    required this.id,
    required this.employeeId,
    required this.amountPaise,
    required this.transactionDate,
    required this.salaryPeriod,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Advance copyWith({
    String? id,
    String? employeeId,
    int? amountPaise,
    String? transactionDate,
    String? salaryPeriod,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Advance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      amountPaise: amountPaise ?? this.amountPaise,
      transactionDate: transactionDate ?? this.transactionDate,
      salaryPeriod: salaryPeriod ?? this.salaryPeriod,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

