/// Financial calculation summary for an employee for a specific salary period (YYYY-MM).
/// All amounts are in integer paise.
class SalarySummary {
  final String employeeId;
  final String salaryPeriod;
  final int monthlySalaryPaise;
  final int totalAdvancesPaise;
  final int remainingSalaryPaise;

  const SalarySummary({
    required this.employeeId,
    required this.salaryPeriod,
    required this.monthlySalaryPaise,
    required this.totalAdvancesPaise,
    required this.remainingSalaryPaise,
  });

  /// Factory that reliably computes remaining salary from monthly salary and advances.
  factory SalarySummary.calculate({
    required String employeeId,
    required String salaryPeriod,
    required int monthlySalaryPaise,
    required int totalAdvancesPaise,
  }) {
    final remaining = monthlySalaryPaise - totalAdvancesPaise;
    return SalarySummary(
      employeeId: employeeId,
      salaryPeriod: salaryPeriod,
      monthlySalaryPaise: monthlySalaryPaise,
      totalAdvancesPaise: totalAdvancesPaise,
      remainingSalaryPaise: remaining,
    );
  }
}

