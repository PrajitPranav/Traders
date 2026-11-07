import 'package:uuid/uuid.dart';
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

    await db.insert('advances', AdvanceModel.fromEntity(advance).toMap());
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
}

