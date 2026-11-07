import '../entities/advance.dart';

/// Abstract contract for prepaid salary advance operations.
abstract class AdvanceRepository {
  /// Retrieves advances recorded for an employee for a specific salary period (YYYY-MM).
  Future<List<Advance>> getAdvancesForPeriod(String employeeId, String salaryPeriod);

  /// Retrieves all advances for an employee ordered by transaction date descending.
  Future<List<Advance>> getAllAdvances(String employeeId);

  /// Retrieves advances that occurred on a specific date (for combined calendar view).
  Future<List<Advance>> getAdvancesForDate(String employeeId, String dateIso);

  /// Retrieves a map of date string ('YYYY-MM-DD') to list of advances in a given month.
  Future<Map<String, List<Advance>>> getMonthAdvancesMap(String employeeId, int year, int month);

  /// Computes the sum of advances in paise for an employee in a given salary period.
  Future<int> getTotalAdvancesPaiseForPeriod(String employeeId, String salaryPeriod);

  /// Records a new advance within a database transaction.
  Future<Advance> createAdvance({
    required String employeeId,
    required int amountPaise,
    required String transactionDateIso,
    required String salaryPeriod,
    String? description,
  });

  /// Updates an existing advance transaction with confirmation.
  Future<void> updateAdvance({
    required String advanceId,
    required int amountPaise,
    required String transactionDateIso,
    required String salaryPeriod,
    String? description,
  });

  /// Deletes an advance record.
  Future<void> deleteAdvance(String advanceId);
}

