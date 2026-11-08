import 'package:uuid/uuid.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/advance.dart';
import '../../domain/repositories/advance_repository.dart';
import '../datasources/database_helper.dart';
import '../models/advance_model.dart';

class SqliteAdvanceRepository implements AdvanceRepository {
  final DatabaseHelper _databaseHelper;
  final Uuid _uuid = const Uuid();

  SqliteAdvanceRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Advance>> getAdvancesForPeriod(String employeeId, String salaryPeriod) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'advances',
      where: 'employee_id = ? AND salary_period = ?',
      whereArgs: [employeeId, salaryPeriod],
      orderBy: 'transaction_date DESC, created_at DESC',
    );

    return maps.map((m) => AdvanceModel.fromMap(m).toEntity()).toList();
  }

  @override
  Future<List<Advance>> getAllAdvances(String employeeId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'advances',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'transaction_date DESC, created_at DESC',
    );

    return maps.map((m) => AdvanceModel.fromMap(m).toEntity()).toList();
  }

  @override
  Future<List<Advance>> getAdvancesForDate(String employeeId, String dateIso) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'advances',
      where: 'employee_id = ? AND transaction_date = ?',
      whereArgs: [employeeId, dateIso],
      orderBy: 'created_at ASC',
    );

    return maps.map((m) => AdvanceModel.fromMap(m).toEntity()).toList();
  }

  @override
  Future<Map<String, List<Advance>>> getMonthAdvancesMap(String employeeId, int year, int month) async {
    final db = await _databaseHelper.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final maps = await db.query(
      'advances',
      where: 'employee_id = ? AND transaction_date LIKE ?',
      whereArgs: [employeeId, pattern],
      orderBy: 'transaction_date ASC, created_at ASC',
    );

    final map = <String, List<Advance>>{};
    for (final m in maps) {
      final advance = AdvanceModel.fromMap(m).toEntity();
      final dateKey = advance.transactionDate;
      if (!map.containsKey(dateKey)) {
        map[dateKey] = [];
      }
      map[dateKey]!.add(advance);
    }
    return map;
  }

  @override
  Future<int> getTotalAdvancesPaiseForPeriod(String employeeId, String salaryPeriod) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount_paise) as total FROM advances WHERE employee_id = ? AND salary_period = ?',
      [employeeId, salaryPeriod],
    );

    if (result.isEmpty || result.first['total'] == null) {
      return 0;
    }
    return (result.first['total'] as num).toInt();
  }

  @override
  Future<Advance> createAdvance({
    required String employeeId,
    required int amountPaise,
    required String transactionDateIso,
    required String salaryPeriod,
    String? description,
  }) async {
    if (amountPaise <= 0) {
      throw ArgumentError('Advance amount must be greater than zero.');
    }

    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final advanceId = _uuid.v4();

    final advance = Advance(
      id: advanceId,
      employeeId: employeeId,
      amountPaise: amountPaise,
      transactionDate: transactionDateIso,
      salaryPeriod: salaryPeriod,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // Determine applicable monthly salary for the period
      final parts = salaryPeriod.split('-');
      String lastDayIso = transactionDateIso;
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null) {
          final lastDay = DateTime(year, month + 1, 0);
          lastDayIso = AppDateUtils.toIsoDateString(lastDay);
        }
      }

      var salaryRows = await txn.query(
        'salary_records',
        where: 'employee_id = ? AND effective_from <= ?',
        whereArgs: [employeeId, lastDayIso],
        orderBy: 'effective_from DESC, created_at DESC',
        limit: 1,
      );

      if (salaryRows.isEmpty) {
        salaryRows = await txn.query(
          'salary_records',
          where: 'employee_id = ?',
          whereArgs: [employeeId],
          orderBy: 'effective_from ASC, created_at ASC',
          limit: 1,
        );
      }

      final monthlySalaryPaise = salaryRows.isNotEmpty
          ? (salaryRows.first['monthly_salary_paise'] as num).toInt()
          : 0;

      final existingResult = await txn.rawQuery(
        'SELECT SUM(amount_paise) as total FROM advances WHERE employee_id = ? AND salary_period = ?',
        [employeeId, salaryPeriod],
      );
      final existingAdvancesPaise =
          (existingResult.isNotEmpty && existingResult.first['total'] != null)
              ? (existingResult.first['total'] as num).toInt()
              : 0;

      final remainingPaise = monthlySalaryPaise - existingAdvancesPaise;

      if (monthlySalaryPaise > 0 && amountPaise > remainingPaise) {
        throw StateError(
          'Advance of ${CurrencyFormatter.formatPaise(amountPaise)} exceeds the remaining salary balance of ${CurrencyFormatter.formatPaise(remainingPaise)} for period $salaryPeriod.',
        );
      }

      await txn.insert('advances', AdvanceModel.fromEntity(advance).toMap());
    });
    return advance;
  }

  @override
  Future<void> updateAdvance({
    required String advanceId,
    required int amountPaise,
    required String transactionDateIso,
    required String salaryPeriod,
    String? description,
  }) async {
    final db = await _databaseHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'advances',
      {
        'amount_paise': amountPaise,
        'transaction_date': transactionDateIso,
        'salary_period': salaryPeriod,
        'description': description?.trim().isEmpty == true ? null : description?.trim(),
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [advanceId],
    );
  }

  @override
  Future<void> deleteAdvance(String advanceId) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'advances',
      where: 'id = ?',
      whereArgs: [advanceId],
    );
  }

  @override
  Future<List<Advance>> getAllAdvancesForDate(String dateIso) async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT adv.* 
      FROM advances adv
      JOIN employees e ON adv.employee_id = e.id
      WHERE adv.transaction_date = ? AND e.is_active = 1
      ORDER BY adv.created_at ASC
      ''',
      [dateIso],
    );
    return maps.map((m) => AdvanceModel.fromMap(m).toEntity()).toList();
  }

  @override
  Future<Map<String, List<Advance>>> getAllMonthAdvancesByDate(int year, int month) async {
    final db = await _databaseHelper.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final maps = await db.rawQuery(
      '''
      SELECT adv.* 
      FROM advances adv
      JOIN employees e ON adv.employee_id = e.id
      WHERE adv.transaction_date LIKE ? AND e.is_active = 1
      ORDER BY adv.transaction_date ASC, adv.created_at ASC
      ''',
      [pattern],
    );

    final map = <String, List<Advance>>{};
    for (final m in maps) {
      final advance = AdvanceModel.fromMap(m).toEntity();
      map.putIfAbsent(advance.transactionDate, () => []).add(advance);
    }
    return map;
  }

  @override
  Future<List<Advance>> getAllAdvancesForPeriod(String salaryPeriod) async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT adv.* 
      FROM advances adv
      JOIN employees e ON adv.employee_id = e.id
      WHERE adv.salary_period = ? AND e.is_active = 1
      ORDER BY adv.transaction_date ASC, adv.created_at ASC
      ''',
      [salaryPeriod],
    );
    return maps.map((m) => AdvanceModel.fromMap(m).toEntity()).toList();
  }
}

