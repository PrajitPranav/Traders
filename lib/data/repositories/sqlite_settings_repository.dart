import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/database_helper.dart';

class SqliteSettingsRepository implements SettingsRepository {
  final DatabaseHelper _databaseHelper;

  SqliteSettingsRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  @override
  Future<String?> getSetting(String key) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first['setting_value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    final db = await _databaseHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.insert(
      'app_settings',
      {
        'id': 'setting-$key',
        'setting_key': key,
        'setting_value': value,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<String> exportBackupJson() async {
    final db = await _databaseHelper.database;

    final employees = await db.query('employees');
    final attendance = await db.query('attendance');
    final salaryRecords = await db.query('salary_records');
    final advances = await db.query('advances');
    final settings = await db.query('app_settings');

    final backupData = {
      'app': 'Saravanas',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': {
        'employees': employees,
        'attendance': attendance,
        'salary_records': salaryRecords,
        'advances': advances,
        'app_settings': settings,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  @override
  Future<bool> restoreBackupJson(String jsonString) async {
    final db = await _databaseHelper.database;

    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      if (decoded['app'] != 'Saravanas' || !decoded.containsKey('tables')) {
        throw FormatException('Invalid backup format: Not a Saravanas backup file.');
      }

      final tables = decoded['tables'] as Map<String, dynamic>;
      final employees = (tables['employees'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final attendance = (tables['attendance'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final salaryRecords = (tables['salary_records'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final advances = (tables['advances'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final settings = (tables['app_settings'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      await db.transaction((txn) async {
        // Safe replace into each table
        for (final row in employees) {
          await txn.insert('employees', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in salaryRecords) {
          await txn.insert('salary_records', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in attendance) {
          await txn.insert('attendance', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in advances) {
          await txn.insert('advances', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in settings) {
          await txn.insert('app_settings', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }
}

