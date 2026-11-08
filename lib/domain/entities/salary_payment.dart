/// A regular salary payment made to an employee (NOT a prepaid advance).
/// Amounts are integer paise.
class SalaryPayment {
  final String id;
  final String employeeId;
  final int amountPaise;
  final String paymentDate; // ISO-8601 YYYY-MM-DD
  final String salaryPeriod; // YYYY-MM
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalaryPayment({
    required this.id,
    required this.employeeId,
    required this.amountPaise,
    required this.paymentDate,
    required this.salaryPeriod,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Complete financial position of one employee for one salary period.
///
/// remainingPayable = monthly salary - advances (already given) - regular salary paid.
/// Advances are subtracted exactly once.
class FinancialOverview {
  final String employeeId;
  final String salaryPeriod;
  final int monthlySalaryPaise;
  final int totalAdvancesPaise;
  final int regularPaidPaise;

  const FinancialOverview({
    required this.employeeId,
    required this.salaryPeriod,
    required this.monthlySalaryPaise,
    required this.totalAdvancesPaise,
    required this.regularPaidPaise,
  });

  int get remainingPayablePaise =>
      monthlySalaryPaise - totalAdvancesPaise - regularPaidPaise;
}

