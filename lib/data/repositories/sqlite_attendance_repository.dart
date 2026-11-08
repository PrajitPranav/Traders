import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/database_helper.dart';
import '../models/attendance_model.dart';

class SqliteAttendanceRepository implements AttendanceRepository {
  final DatabaseHelper _databaseHelper;
  final Uuid _uuid = const Uuid();

  SqliteAttendanceRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Attendance>> getMonthlyAttendance(String employeeId, int year, int month) async {
    final db = await _databaseHelper.database;
    final monthStr = month.toString().padLeft(2, '0');
    final startPrefix = '$year-$monthStr';

    final maps = await db.query(
      'attendance',
      where: 'employee_id = ? AND attendance_date LIKE ?',
      whereArgs: [employeeId, '$startPrefix%'],
      orderBy: 'attendance_date ASC',
    );

    return maps.map((m) => AttendanceModel.fromMap(m).toEntity()).toList();
  }

  @override
  Future<Map<String, AttendanceStatus>> getMonthAttendanceMap(String employeeId, int year, int month) async {
    final list = await getMonthlyAttendance(employeeId, year, month);
    final map = <String, AttendanceStatus>{};
    for (final item in list) {
      map[item.attendanceDate] = item.status;
    }
    return map;
  }

  @override
  Future<Attendance?> getAttendanceForDate(String employeeId, String dateIso) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'attendance',
      where: 'employee_id = ? AND attendance_date = ?',
      whereArgs: [employeeId, dateIso],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return AttendanceModel.fromMap(maps.first).toEntity();
  }

  @override
  Future<void> recordAttendance({
    required String employeeId,
    required String dateIso,
    required AttendanceStatus status,
  }) async {
    final db = await _databaseHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    // Upsert using SQLite REPLACE conflict resolution
    await db.insert(
      'attendance',
      {
        'id': _uuid.v4(),
        'employee_id': employeeId,
        'attendance_date': dateIso,
        'status': status.toDbString(),
        'created_at': nowIso,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteAttendance({
    required String employeeId,
    required String dateIso,
  }) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'attendance',
      where: 'employee_id = ? AND attendance_date = ?',
      whereArgs: [employeeId, dateIso],
    );
  }

  @override
  Future<Map<String, int>> getMonthlyAttendanceCounts(String employeeId, int year, int month) async {
    final db = await _databaseHelper.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final presentCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM attendance WHERE employee_id = ? AND attendance_date LIKE ? AND status = 'present'",
      [employeeId, pattern],
    )) ?? 0;

    final absentCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM attendance WHERE employee_id = ? AND attendance_date LIKE ? AND status = 'absent'",
      [employeeId, pattern],
    )) ?? 0;

    return {
      'present': presentCount,
      'absent': absentCount,
    };
  }

  @override
  Future<int> getTodayPresentCount(String todayIso) async {
    final db = await _databaseHelper.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT a.employee_id) 
      FROM attendance a
      JOIN employees e ON a.employee_id = e.id
      WHERE a.attendance_date = ? AND a.status = 'present' AND e.is_active = 1
      ''',
      [todayIso],
    ));
    return count ?? 0;
  }

  @override
  Future<int> getTodayAbsentCount(String todayIso) async {
    final db = await _databaseHelper.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT a.employee_id) 
      FROM attendance a
      JOIN employees e ON a.employee_id = e.id
      WHERE a.attendance_date = ? AND a.status = 'absent' AND e.is_active = 1
      ''',
      [todayIso],
    ));
    return count ?? 0;
  }

  @override
  Future<List<Attendance>> getAllAttendanceForDate(String dateIso) async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT a.* 
      FROM attendance a
      JOIN employees e ON a.employee_id = e.id
      WHERE a.attendance_date = ? AND e.is_active = 1
      ORDER BY e.employee_code ASC
      ''',
      [dateIso],
    );
    return maps.map((m) => AttendanceModel.fromMap(m).toEntity()).toList();
  }

  @override
  Future<Map<String, List<Attendance>>> getAllMonthAttendanceByDate(int year, int month) async {
    final db = await _databaseHelper.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final maps = await db.rawQuery(
      '''
      SELECT a.* 
      FROM attendance a
      JOIN employees e ON a.employee_id = e.id
      WHERE a.attendance_date LIKE ? AND e.is_active = 1
      ORDER BY a.attendance_date ASC, e.employee_code ASC
      ''',
      [pattern],
    );

    final result = <String, List<Attendance>>{};
    for (final m in maps) {
      final entity = AttendanceModel.fromMap(m).toEntity();
      result.putIfAbsent(entity.attendanceDate, () => []).add(entity);
    }
    return result;
  }
}

