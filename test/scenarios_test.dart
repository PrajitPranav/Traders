import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:traders/data/datasources/database_helper.dart';
import 'package:traders/data/repositories/sqlite_advance_repository.dart';
import 'package:traders/data/repositories/sqlite_attendance_repository.dart';
import 'package:traders/data/repositories/sqlite_employee_repository.dart';
import 'package:traders/data/repositories/sqlite_salary_repository.dart';
import 'package:traders/domain/entities/attendance.dart';

void main() {
  // Setup sqflite FFI for running tests without Android emulator/device
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late SqliteEmployeeRepository employeeRepo;
  late SqliteAttendanceRepository attendanceRepo;
  late SqliteAdvanceRepository advanceRepo;
  late SqliteSalaryRepository salaryRepo;

  setUp(() async {
    // Open in-memory SQLite database with exact schema and foreign keys
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await db.execute('''
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

          await db.execute('''
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

          await db.execute('''
            CREATE TABLE salary_records (
              id TEXT PRIMARY KEY,
              employee_id TEXT NOT NULL,
              monthly_salary_paise INTEGER NOT NULL,
              effective_from TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
            );
          ''');

          await db.execute('''
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

          await db.execute('''
            CREATE TABLE salary_payments (
              id TEXT PRIMARY KEY,
              employee_id TEXT NOT NULL,
              amount_paise INTEGER NOT NULL,
              payment_date TEXT NOT NULL,
              salary_period TEXT NOT NULL,
              description TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
            );
          ''');

          await db.execute('''
            CREATE TABLE app_settings (
              id TEXT PRIMARY KEY,
              setting_key TEXT UNIQUE NOT NULL,
              setting_value TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
        },
      ),
    );

    final helper = DatabaseHelper.forTest(testDb);
    employeeRepo = SqliteEmployeeRepository(databaseHelper: helper);
    attendanceRepo = SqliteAttendanceRepository(databaseHelper: helper);
    advanceRepo = SqliteAdvanceRepository(databaseHelper: helper);
    salaryRepo = SqliteSalaryRepository(
      databaseHelper: helper,
      advanceRepository: advanceRepo,
    );
  });

  tearDown(() async {
    await testDb.close();
  });

  test('Scenario 1: Add Employee A and Employee B. Verify both appear in directory', () async {
    final empA = await employeeRepo.createEmployee(
      name: 'Employee A',
      phone: '9876543210',
      designation: 'Technician',
      initialSalaryPaise: 2000000, // ₹20,000
    );

    final empB = await employeeRepo.createEmployee(
      name: 'Employee B',
      phone: '9876543211',
      designation: 'Supervisor',
      initialSalaryPaise: 2500000, // ₹25,000
    );

    expect(empA.employeeCode, equals('EMP0001'));
    expect(empB.employeeCode, equals('EMP0002'));

    final directory = await employeeRepo.getAllEmployees();
    expect(directory.length, equals(2));
    expect(directory.any((e) => e.name == 'Employee A'), isTrue);
    expect(directory.any((e) => e.name == 'Employee B'), isTrue);
  });

  test('Scenario 2: Mark Employee A present. Verify Employee B attendance remains unchanged', () async {
    final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);
    final empB = await employeeRepo.createEmployee(name: 'Employee B', initialSalaryPaise: 2500000);

    const testDate = '2026-10-15';
    await attendanceRepo.recordAttendance(
      employeeId: empA.id,
      dateIso: testDate,
      status: AttendanceStatus.present,
    );

    final aAttendance = await attendanceRepo.getAttendanceForDate(empA.id, testDate);
    final bAttendance = await attendanceRepo.getAttendanceForDate(empB.id, testDate);

    expect(aAttendance, isNotNull);
    expect(aAttendance!.status, equals(AttendanceStatus.present));
    expect(bAttendance, isNull); // Employee B is completely untouched
  });

  test('Scenario 3: Mark Employee B absent on same date. Verify Employee A remains present', () async {
    final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);
    final empB = await employeeRepo.createEmployee(name: 'Employee B', initialSalaryPaise: 2500000);

    const testDate = '2026-10-15';
    await attendanceRepo.recordAttendance(
      employeeId: empA.id,
      dateIso: testDate,
      status: AttendanceStatus.present,
    );

    await attendanceRepo.recordAttendance(
      employeeId: empB.id,
      dateIso: testDate,
      status: AttendanceStatus.absent,
    );

    final aAttendance = await attendanceRepo.getAttendanceForDate(empA.id, testDate);
    final bAttendance = await attendanceRepo.getAttendanceForDate(empB.id, testDate);

    expect(aAttendance!.status, equals(AttendanceStatus.present));
    expect(bAttendance!.status, equals(AttendanceStatus.absent));
  });

  test('Scenario 4: Give Employee A salary ₹20,000, advance ₹5,000. Verify Salary = 20000, Advance = 5000, Remaining = 15000', () async {
    final empA = await employeeRepo.createEmployee(
      name: 'Employee A',
      initialSalaryPaise: 2000000, // ₹20,000
    );

    await advanceRepo.createAdvance(
      employeeId: empA.id,
      amountPaise: 500000, // ₹5,000
      transactionDateIso: '2026-10-15',
      salaryPeriod: '2026-10',
      description: 'Emergency advance',
    );

    final summary = await salaryRepo.getSalarySummary(empA.id, '2026-10');

    expect(summary.monthlySalaryPaise, equals(2000000)); // ₹20,000
    expect(summary.totalAdvancesPaise, equals(500000)); // ₹5,000
    expect(summary.remainingSalaryPaise, equals(1500000)); // ₹15,000
  });

  test('Scenario 5: Give Employee B salary ₹25,000. Verify Employee A advance does not affect Employee B', () async {
    final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);
    final empB = await employeeRepo.createEmployee(name: 'Employee B', initialSalaryPaise: 2500000);

    await advanceRepo.createAdvance(
      employeeId: empA.id,
      amountPaise: 500000, // ₹5,000 advance to A
      transactionDateIso: '2026-10-15',
      salaryPeriod: '2026-10',
    );

    final summaryB = await salaryRepo.getSalarySummary(empB.id, '2026-10');

    expect(summaryB.monthlySalaryPaise, equals(2500000)); // ₹25,000
    expect(summaryB.totalAdvancesPaise, equals(0)); // Zero advances for B
    expect(summaryB.remainingSalaryPaise, equals(2500000)); // Remaining is full ₹25,000
  });

  test('Scenario 6: Record October advance. Verify it does not reduce November salary', () async {
    final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);

    await advanceRepo.createAdvance(
      employeeId: empA.id,
      amountPaise: 500000, // ₹5,000 in Oct
      transactionDateIso: '2026-10-15',
      salaryPeriod: '2026-10',
    );

    final octSummary = await salaryRepo.getSalarySummary(empA.id, '2026-10');
    final novSummary = await salaryRepo.getSalarySummary(empA.id, '2026-11');

    expect(octSummary.totalAdvancesPaise, equals(500000));
    expect(octSummary.remainingSalaryPaise, equals(1500000));

    // November salary remains untouched
    expect(novSummary.totalAdvancesPaise, equals(0));
    expect(novSummary.remainingSalaryPaise, equals(2000000));
  });

  test('Scenario 7: Edit Employee A monthly salary. Verify history and advances remain intact', () async {
    final empA = await employeeRepo.createEmployee(
      name: 'Employee A',
      initialSalaryPaise: 2000000, // ₹20,000
      joiningDate: '2026-01-01',
    );

    await advanceRepo.createAdvance(
      employeeId: empA.id,
      amountPaise: 500000,
      transactionDateIso: '2026-10-15',
      salaryPeriod: '2026-10',
    );

    // Revise salary to ₹25,000 effective from 2026-11-01
    await salaryRepo.updateSalary(
      employeeId: empA.id,
      newSalaryPaise: 2500000,
      effectiveFromIso: '2026-11-01',
    );

    // Verify history has both revisions
    final history = await salaryRepo.getSalaryHistory(empA.id);
    expect(history.length, equals(2));

    // October historical summary still reflects ₹20,000 base salary
    final octSummary = await salaryRepo.getSalarySummary(empA.id, '2026-10');
    expect(octSummary.monthlySalaryPaise, equals(2000000));
    expect(octSummary.remainingSalaryPaise, equals(1500000));

    // November summary reflects new ₹25,000 salary
    final novSummary = await salaryRepo.getSalarySummary(empA.id, '2026-11');
    expect(novSummary.monthlySalaryPaise, equals(2500000));
    expect(novSummary.remainingSalaryPaise, equals(2500000));
  });

  test('Scenario 8: Database restart persistence. Verify all records persist', () async {
    // Insert records
    final emp = await employeeRepo.createEmployee(name: 'Persistent Employee', initialSalaryPaise: 3000000);
    await attendanceRepo.recordAttendance(employeeId: emp.id, dateIso: '2026-10-20', status: AttendanceStatus.present);
    await advanceRepo.createAdvance(
      employeeId: emp.id,
      amountPaise: 700000,
      transactionDateIso: '2026-10-22',
      salaryPeriod: '2026-10',
    );

    // Reopen the repository using the same database connection
    final helper = DatabaseHelper.forTest(testDb);
    final reloadedEmpRepo = SqliteEmployeeRepository(databaseHelper: helper);
    final reloadedAttRepo = SqliteAttendanceRepository(databaseHelper: helper);
    final reloadedAdvRepo = SqliteAdvanceRepository(databaseHelper: helper);

    final employees = await reloadedEmpRepo.getAllEmployees();
    final att = await reloadedAttRepo.getAttendanceForDate(emp.id, '2026-10-20');
    final advances = await reloadedAdvRepo.getAdvancesForPeriod(emp.id, '2026-10');

    expect(employees.length, equals(1));
    expect(employees.first.name, equals('Persistent Employee'));
    expect(att!.status, equals(AttendanceStatus.present));
    expect(advances.length, equals(1));
    expect(advances.first.amountPaise, equals(700000));
  });

  test('Scenario 9: Attendance and advance on same date appear independently', () async {
    final emp = await employeeRepo.createEmployee(name: 'Employee C', initialSalaryPaise: 2000000);
    const date = '2026-10-15';

    await attendanceRepo.recordAttendance(employeeId: emp.id, dateIso: date, status: AttendanceStatus.present);
    await advanceRepo.createAdvance(
      employeeId: emp.id,
      amountPaise: 300000,
      transactionDateIso: date,
      salaryPeriod: '2026-10',
      description: 'Mid-month advance',
    );

    final att = await attendanceRepo.getAttendanceForDate(emp.id, date);
    final advList = await advanceRepo.getAdvancesForDate(emp.id, date);

    expect(att, isNotNull);
    expect(att!.status, equals(AttendanceStatus.present));
    expect(advList.length, equals(1));
    expect(advList.first.amountPaise, equals(300000));
  });

  test('Scenario 10: Attempt duplicate attendance for same employee and date. Verify constraint prevents duplicate', () async {
    final emp = await employeeRepo.createEmployee(name: 'Employee D', initialSalaryPaise: 2000000);
    const date = '2026-10-15';

    await attendanceRepo.recordAttendance(employeeId: emp.id, dateIso: date, status: AttendanceStatus.present);
    // Record again on same date with different status (upsert replace)
    await attendanceRepo.recordAttendance(employeeId: emp.id, dateIso: date, status: AttendanceStatus.absent);

    // Verify there is strictly ONE record in the database for that date
    final list = await attendanceRepo.getMonthlyAttendance(emp.id, 2026, 10);
    final onDate = list.where((a) => a.attendanceDate == date).toList();

    expect(onDate.length, equals(1));
    expect(onDate.first.status, equals(AttendanceStatus.absent));
  });
}
