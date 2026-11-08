import 'package:uuid/uuid.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/entities/salary_payment.dart';
import '../../domain/repositories/salary_payment_repository.dart';
import '../datasources/database_helper.dart';
import 'salary_balance_helper.dart';

class SqliteSalaryPaymentRepository implements SalaryPaymentRepository {
  final DatabaseHelper _databaseHelper;
  final Uuid _uuid = const Uuid();

  SqliteSalaryPaymentRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  SalaryPayment _fromMap(Map<String, Object?> m) {
    return SalaryPayment(
      id: m['id'] as String,
      employeeId: m['employee_id'] as String,
      amountPaise: (m['amount_paise'] as num).toInt(),
      paymentDate: m['payment_date'] as String,
      salaryPeriod: m['salary_period'] as String,
      description: m['description'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  @override
  Future<List<SalaryPayment>> getPaymentsForPeriod(
    String employeeId,
    String salaryPeriod,
  ) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'salary_payments',
      where: 'employee_id = ? AND salary_period = ?',
      whereArgs: [employeeId, salaryPeriod],
      orderBy: 'payment_date DESC, created_at DESC',
    );
    return rows.map(_fromMap).toList();
  }

  @override
  Future<List<SalaryPayment>> getAllPayments(String employeeId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'salary_payments',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'payment_date DESC, created_at DESC',
    );
    return rows.map(_fromMap).toList();
  }

  @override
  Future<int> getTotalPaidPaiseForPeriod(String employeeId, String salaryPeriod) async {
    final db = await _databaseHelper.database;
    return SalaryBalanceHelper.totalPaymentsPaise(db, employeeId, salaryPeriod);
  }

  @override
  Future<FinancialOverview> getFinancialOverview(
    String employeeId,
    String salaryPeriod,
  ) async {
    final db = await _databaseHelper.database;
    final salary = await SalaryBalanceHelper.monthlySalaryPaise(db, employeeId, salaryPeriod);
    final advances = await SalaryBalanceHelper.totalAdvancesPaise(db, employeeId, salaryPeriod);
    final paid = await SalaryBalanceHelper.totalPaymentsPaise(db, employeeId, salaryPeriod);
    return FinancialOverview(
      employeeId: employeeId,
      salaryPeriod: salaryPeriod,
      monthlySalaryPaise: salary,
      totalAdvancesPaise: advances,
      regularPaidPaise: paid,
    );
  }

  @override
  Future<SalaryPayment> createPayment({
    required String employeeId,
    required int amountPaise,
    required String paymentDateIso,
    required String salaryPeriod,
    String? description,
  }) async {
    if (amountPaise <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    if (!SalaryBalanceHelper.isValidPeriod(salaryPeriod)) {
      throw ArgumentError('Invalid salary period "$salaryPeriod".');
    }

    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final cleanDescription =
        (description == null || description.trim().isEmpty) ? null : description.trim();

    final payment = SalaryPayment(
      id: _uuid.v4(),
      employeeId: employeeId,
      amountPaise: amountPaise,
      paymentDate: paymentDateIso,
      salaryPeriod: salaryPeriod,
      description: cleanDescription,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      final salary = await SalaryBalanceHelper.monthlySalaryPaise(txn, employeeId, salaryPeriod);
      final advances = await SalaryBalanceHelper.totalAdvancesPaise(txn, employeeId, salaryPeriod);
      final paid = await SalaryBalanceHelper.totalPaymentsPaise(txn, employeeId, salaryPeriod);
      final remaining = salary - advances - paid;

      if (amountPaise > remaining) {
        throw StateError(
          'Payment of ${CurrencyFormatter.formatPaise(amountPaise)} is more than the remaining amount payable '
          '(${CurrencyFormatter.formatPaise(remaining < 0 ? 0 : remaining)}) for $salaryPeriod.',
        );
      }

      await txn.insert('salary_payments', {
        'id': payment.id,
        'employee_id': employeeId,
        'amount_paise': amountPaise,
        'payment_date': paymentDateIso,
        'salary_period': salaryPeriod,
        'description': cleanDescription,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });

    return payment;
  }

  @override
  Future<void> deletePayment(String paymentId) async {
    final db = await _databaseHelper.database;
    await db.delete('salary_payments', where: 'id = ?', whereArgs: [paymentId]);
  }
}

