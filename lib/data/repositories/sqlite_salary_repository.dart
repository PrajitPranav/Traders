import 'package:uuid/uuid.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/salary_record.dart';
import '../../domain/entities/salary_summary.dart';
import '../../domain/repositories/salary_repository.dart';
import '../datasources/database_helper.dart';
import '../models/salary_record_model.dart';
import 'sqlite_advance_repository.dart';

class SqliteSalaryRepository implements SalaryRepository {
  final DatabaseHelper _databaseHelper;
  final SqliteAdvanceRepository _advanceRepository;
  final Uuid _uuid = const Uuid();

  SqliteSalaryRepository({
    DatabaseHelper? databaseHelper,
    SqliteAdvanceRepository? advanceRepository,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _advanceRepository = advanceRepository ?? SqliteAdvanceRepository(databaseHelper: databaseHelper);

  @override
  Future<SalaryRecord?> getCurrentSalary(String employeeId, {String? forDateIso}) async {
    final db = await _databaseHelper.database;
    final date = forDateIso ?? AppDateUtils.toIsoDateString(DateTime.now());

    final maps = await db.query(
      'salary_records',
      where: 'employee_id = ? AND effective_from <= ?',
      whereArgs: [employeeId, date],
      orderBy: 'effective_from DESC, created_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return SalaryRecordModel.fromMap(maps.first).toEntity();
    }

    // Fallback: earliest or latest salary record if date is earlier than effective date
    final fallback = await db.query(
      'salary_records',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'effective_from ASC, created_at ASC',
      limit: 1,
    );

    if (fallback.isNotEmpty) {
      return SalaryRecordModel.fromMap(fallback.first).toEntity();
    }

    return null;
  }

  @override
  Future<List<SalaryRecord>> getSalaryHistory(String employeeId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'salary_records',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'effective_from DESC, created_at DESC',
    );

    return maps.map((m) => SalaryRecordModel.fromMap(m).toEntity()).toList();
  }

  @override
  Future<void> updateSalary({
    required String employeeId,
    required int newSalaryPaise,
    required String effectiveFromIso,
  }) async {
    final db = await _databaseHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.insert(
      'salary_records',
      {
        'id': _uuid.v4(),
        'employee_id': employeeId,
        'monthly_salary_paise': newSalaryPaise,
        'effective_from': effectiveFromIso,
        'created_at': nowIso,
      },
    );
  }

  @override
  Future<SalarySummary> getSalarySummary(String employeeId, String salaryPeriod) async {
    // The target date for salary lookup is the last day of the salary period
    final parts = salaryPeriod.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    // Determine the end of the month
    final lastDay = DateTime(year, month + 1, 0);
    final lastDayIso = AppDateUtils.toIsoDateString(lastDay);

    final salaryRecord = await getCurrentSalary(employeeId, forDateIso: lastDayIso);
    final monthlySalary = salaryRecord?.monthlySalaryPaise ?? 0;

    final totalAdvances = await _advanceRepository.getTotalAdvancesPaiseForPeriod(
      employeeId,
      salaryPeriod,
    );

    return SalarySummary.calculate(
      employeeId: employeeId,
      salaryPeriod: salaryPeriod,
      monthlySalaryPaise: monthlySalary,
      totalAdvancesPaise: totalAdvances,
    );
  }
}

