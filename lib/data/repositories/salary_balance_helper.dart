import 'package:sqflite/sqflite.dart';
import '../../core/utils/date_formatter.dart';

/// Shared, transaction-safe balance lookups used by the advance and salary
/// payment repositories so both enforce the exact same rule:
///
///   monthly salary (for the period) - advances - regular salary paid >= 0
///
/// All values are integer paise and strictly scoped by employee ID + period.
class SalaryBalanceHelper {
  SalaryBalanceHelper._();

  static final RegExp _periodPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

  static bool isValidPeriod(String period) => _periodPattern.hasMatch(period);

  /// Applicable monthly salary for [salaryPeriod], using salary history
  /// (the latest revision effective on or before the last day of the period).
  static Future<int> monthlySalaryPaise(
    DatabaseExecutor db,
    String employeeId,
    String salaryPeriod,
  ) async {
    if (!isValidPeriod(salaryPeriod)) {
      throw ArgumentError('Invalid salary period "$salaryPeriod". Expected YYYY-MM.');
    }
    final parts = salaryPeriod.split('-');
    final lastDay = DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1, 0);
    final lastDayIso = AppDateUtils.toIsoDateString(lastDay);

    var rows = await db.query(
      'salary_records',
      where: 'employee_id = ? AND effective_from <= ?',
      whereArgs: [employeeId, lastDayIso],
      orderBy: 'effective_from DESC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      rows = await db.query(
        'salary_records',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'effective_from ASC, created_at ASC',
        limit: 1,
      );
    }
    if (rows.isEmpty) return 0;
    return (rows.first['monthly_salary_paise'] as num).toInt();
  }

  static Future<int> totalAdvancesPaise(
    DatabaseExecutor db,
    String employeeId,
    String salaryPeriod,
  ) async {
    final rows = await db.rawQuery(
      'SELECT SUM(amount_paise) AS total FROM advances WHERE employee_id = ? AND salary_period = ?',
      [employeeId, salaryPeriod],
    );
    final total = rows.isEmpty ? null : rows.first['total'];
    return total == null ? 0 : (total as num).toInt();
  }

  static Future<int> totalPaymentsPaise(
    DatabaseExecutor db,
    String employeeId,
    String salaryPeriod,
  ) async {
    final rows = await db.rawQuery(
      'SELECT SUM(amount_paise) AS total FROM salary_payments WHERE employee_id = ? AND salary_period = ?',
      [employeeId, salaryPeriod],
    );
    final total = rows.isEmpty ? null : rows.first['total'];
    return total == null ? 0 : (total as num).toInt();
  }
}

