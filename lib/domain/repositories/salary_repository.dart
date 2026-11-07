import '../entities/salary_record.dart';
import '../entities/salary_summary.dart';

/// Abstract contract for Salary definitions and summaries.
abstract class SalaryRepository {
  /// Gets the currently effective salary record for an employee.
  Future<SalaryRecord?> getCurrentSalary(String employeeId, {String? forDateIso});

  /// Gets all salary revisions for an employee.
  Future<List<SalaryRecord>> getSalaryHistory(String employeeId);

  /// Appends a new salary record without modifying historical records.
  Future<void> updateSalary({
    required String employeeId,
    required int newSalaryPaise,
    required String effectiveFromIso,
  });

  /// Calculates salary, advances, and remaining salary for an employee and period (YYYY-MM).
  Future<SalarySummary> getSalarySummary(String employeeId, String salaryPeriod);
}

