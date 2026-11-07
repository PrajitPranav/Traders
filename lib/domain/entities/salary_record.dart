/// Business entity representing a salary tier or salary revision for an employee.
class SalaryRecord {
  final String id;
  final String employeeId;
  final int monthlySalaryPaise; // Integer paise
  final String effectiveFrom; // ISO-8601 YYYY-MM-DD
  final DateTime createdAt;

  const SalaryRecord({
    required this.id,
    required this.employeeId,
    required this.monthlySalaryPaise,
    required this.effectiveFrom,
    required this.createdAt,
  });

  SalaryRecord copyWith({
    String? id,
    String? employeeId,
    int? monthlySalaryPaise,
    String? effectiveFrom,
    DateTime? createdAt,
  }) {
    return SalaryRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      monthlySalaryPaise: monthlySalaryPaise ?? this.monthlySalaryPaise,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

