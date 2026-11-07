import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/database_helper.dart';
import '../models/employee_model.dart';

class SqliteEmployeeRepository implements EmployeeRepository {
  final DatabaseHelper _databaseHelper;
  final Uuid _uuid = const Uuid();

  SqliteEmployeeRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Employee>> getAllEmployees({bool includeInactive = false}) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps;

    if (includeInactive) {
      maps = await db.query(
        'employees',
        orderBy: 'created_at ASC',
      );
    } else {
      maps = await db.query(
        'employees',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'created_at ASC',
      );
    }

    return maps.map((m) => EmployeeModel.fromMap(m).toEntity()).toList();
  }

  @override
  Future<Employee?> getEmployeeById(String id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return EmployeeModel.fromMap(maps.first).toEntity();
  }

  @override
  Future<Employee?> getEmployeeByCode(String code) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'employees',
      where: 'employee_code = ?',
      whereArgs: [code],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return EmployeeModel.fromMap(maps.first).toEntity();
  }

  @override
  Future<String> getNextEmployeeCode() async {
    final db = await _databaseHelper.database;
    // Find all employee codes in the database, including deactivated ones
    final result = await db.rawQuery('SELECT employee_code FROM employees');
    int maxNumber = 0;

    for (final row in result) {
      final code = row['employee_code'] as String?;
      if (code != null && code.startsWith('EMP')) {
        final numPart = code.substring(3);
        final val = int.tryParse(numPart);
        if (val != null && val > maxNumber) {
          maxNumber = val;
        }
      }
    }

    final nextNumber = maxNumber + 1;
    return 'EMP${nextNumber.toString().padLeft(4, '0')}';
  }

  @override
  Future<Employee> createEmployee({
    required String name,
    String? phone,
    String? designation,
    String? joiningDate,
    required int initialSalaryPaise,
  }) async {
    final db = await _databaseHelper.database;
    final employeeId = _uuid.v4();
    final salaryId = _uuid.v4();
    final code = await getNextEmployeeCode();
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final effectiveFrom = joiningDate ?? AppDateUtils.toIsoDateString(now);

    final employee = Employee(
      id: employeeId,
      employeeCode: code,
      name: name.trim(),
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      designation: designation?.trim().isEmpty == true ? null : designation?.trim(),
      joiningDate: effectiveFrom,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // Insert employee
      await txn.insert(
        'employees',
        EmployeeModel.fromEntity(employee).toMap(),
      );

      // Insert initial salary record
      await txn.insert('salary_records', {
        'id': salaryId,
        'employee_id': employeeId,
        'monthly_salary_paise': initialSalaryPaise,
        'effective_from': effectiveFrom,
        'created_at': nowIso,
      });
    });

    return employee;
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    final db = await _databaseHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'employees',
      {
        'name': employee.name.trim(),
        'phone': employee.phone?.trim(),
        'designation': employee.designation?.trim(),
        'joining_date': employee.joiningDate,
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  @override
  Future<void> setEmployeeActiveStatus(String id, bool isActive) async {
    final db = await _databaseHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'employees',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> getActiveEmployeeCount() async {
    final db = await _databaseHelper.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM employees WHERE is_active = 1'),
    );
    return count ?? 0;
  }
}
