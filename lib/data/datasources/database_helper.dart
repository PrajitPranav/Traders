import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// DatabaseHelper manages SQLite initialization, versioning, constraints,
/// transactions, and migrations for Saravanas.
class DatabaseHelper {
  static const String _databaseName = 'saravanas_traders.db';
  static const int _databaseVersion = 1;

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Constructor for testing with an injected database instance
  DatabaseHelper.forTest(this._database);

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _databaseName);

    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Ensures Foreign Key constraints are actively enforced in SQLite
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      // 1. Employees Table
      await txn.execute('''
        CREATE TABLE employees (
          id TEXT PRIMARY KEY,
          employee_code TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          designation TEXT,
          joining_date TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');

      // 2. Attendance Table with strict uniqueness constraint per employee per date
      await txn.execute('''
        CREATE TABLE attendance (
          id TEXT PRIMARY KEY,
          employee_id TEXT NOT NULL,
          attendance_date TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
          CONSTRAINT uq_employee_date UNIQUE (employee_id, attendance_date)
        );
      ''');

      // 3. Salary Records Table (preserves historical revisions)
      await txn.execute('''
        CREATE TABLE salary_records (
          id TEXT PRIMARY KEY,
          employee_id TEXT NOT NULL,
          monthly_salary_paise INTEGER NOT NULL,
          effective_from TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
        );
      ''');

      // 4. Advances Table (isolated by employee and salary period)
      await txn.execute('''
        CREATE TABLE advances (
          id TEXT PRIMARY KEY,
          employee_id TEXT NOT NULL,
          amount_paise INTEGER NOT NULL,
          transaction_date TEXT NOT NULL,
          salary_period TEXT NOT NULL,
          description TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
        );
      ''');

      // 5. App Settings Table
      await txn.execute('''
        CREATE TABLE app_settings (
          id TEXT PRIMARY KEY,
          setting_key TEXT UNIQUE NOT NULL,
          setting_value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');

      // Useful query indexes
      await txn.execute('CREATE INDEX idx_attendance_employee_date ON attendance(employee_id, attendance_date);');
      await txn.execute('CREATE INDEX idx_attendance_date ON attendance(attendance_date);');
      await txn.execute('CREATE INDEX idx_advances_employee_period ON advances(employee_id, salary_period);');
      await txn.execute('CREATE INDEX idx_advances_date ON advances(transaction_date);');
      await txn.execute('CREATE INDEX idx_salary_records_employee ON salary_records(employee_id, effective_from);');

      // Initial default admin settings
      final now = DateTime.now().toIso8601String();
      await txn.insert('app_settings', {
        'id': 'setting-admin-name',
        'setting_key': 'admin_name',
        'setting_value': 'Business Administrator',
        'updated_at': now,
      });
      await txn.insert('app_settings', {
        'id': 'setting-company-name',
        'setting_key': 'company_name',
        'setting_value': 'Saravanas',
        'updated_at': now,
      });
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Schema migration logic for future versions
  }

  /// Closes database connection cleanly
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
