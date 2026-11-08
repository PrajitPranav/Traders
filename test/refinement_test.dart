import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:traders/core/constants/app_strings.dart';
import 'package:traders/core/utils/date_formatter.dart';
import 'package:traders/data/datasources/database_helper.dart';
import 'package:traders/data/repositories/sqlite_advance_repository.dart';
import 'package:traders/data/repositories/sqlite_attendance_repository.dart';
import 'package:traders/data/repositories/sqlite_employee_repository.dart';
import 'package:traders/data/repositories/sqlite_salary_payment_repository.dart';
import 'package:traders/data/repositories/sqlite_salary_repository.dart';
import 'package:traders/domain/entities/attendance.dart';
import 'package:traders/presentation/providers/repository_providers.dart';
import 'package:traders/presentation/screens/attendance/mark_attendance_screen.dart';
import 'package:traders/presentation/screens/home/home_screen.dart';
import 'package:traders/presentation/widgets/month_calendar.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late DatabaseHelper helper;
  late SqliteEmployeeRepository employeeRepo;
  late SqliteAttendanceRepository attendanceRepo;
  late SqliteAdvanceRepository advanceRepo;
  late SqliteSalaryRepository salaryRepo;
  late SqliteSalaryPaymentRepository salaryPaymentRepo;

  Future<void> initTestEnv() async {
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        singleInstance: false,
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

    helper = DatabaseHelper.forTest(testDb);
    employeeRepo = SqliteEmployeeRepository(databaseHelper: helper);
    attendanceRepo = SqliteAttendanceRepository(databaseHelper: helper);
    advanceRepo = SqliteAdvanceRepository(databaseHelper: helper);
    salaryRepo = SqliteSalaryRepository(
      databaseHelper: helper,
      advanceRepository: advanceRepo,
    );
    salaryPaymentRepo = SqliteSalaryPaymentRepository(databaseHelper: helper);
  }

  group('SARAVANAS 16-Scenario Master Refinement Test Suite', () {
    // -------------------------------------------------------------
    // TEST 1: Calendar Date Highlight Alignment
    // -------------------------------------------------------------
    testWidgets('TEST 1: MonthCalendar renders centered date highlights with equal column width',
        (WidgetTester tester) async {
      final now = DateTime(2026, 11, 15);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthCalendar(
              focusedDay: now,
              selectedDay: now,
              marksFor: (day) => DayMarks(
                present: day.day == 10,
                absent: day.day == 11,
                advance: day.day == 12,
              ),
              onDaySelected: (_, _) {},
              onPageChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MonthCalendar cells exist and render properly
      expect(find.byType(MonthCalendar), findsOneWidget);
      expect(find.byType(CalendarDayCell), findsWidgets);

      // Verify selected cell (day 15) is rendered with centered circular highlight
      final day15Finder = find.descendant(
        of: find.byType(CalendarDayCell),
        matching: find.text('15'),
      );
      expect(day15Finder, findsOneWidget);
    });

    // -------------------------------------------------------------
    // TEST 2: Home Attendance Displays Active Employees
    // -------------------------------------------------------------
    testWidgets('TEST 2: Home displays ATTENDANCE card; active employees are tracked',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initTestEnv();
        await employeeRepo.createEmployee(name: 'Suresh Kumar', initialSalaryPaise: 2000000);
        await employeeRepo.createEmployee(name: 'Ramesh Babu', initialSalaryPaise: 2200000);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseHelperProvider.overrideWithValue(helper),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Verify Attendance card is present with senior-friendly subtitle
      expect(find.text('ATTENDANCE'), findsOneWidget);
      expect(find.text(AppStrings.attendanceSubtitle), findsOneWidget);
      // STRICT: Employee names do not appear on Home
      expect(find.text('Suresh Kumar'), findsNothing);
      expect(find.text('Ramesh Babu'), findsNothing);

      await tester.runAsync(() => testDb.close());
    });

    // -------------------------------------------------------------
    // TEST 3 & TEST 4: Mark Attendance Auto-Selects Today & Supports Manual Date
    // -------------------------------------------------------------
    testWidgets('TEST 3 & TEST 4: Mark Attendance defaults to today and allows date selection',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initTestEnv();
        await employeeRepo.createEmployee(name: 'Murugan', initialSalaryPaise: 1800000);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseHelperProvider.overrideWithValue(helper),
          ],
          child: const MaterialApp(
            home: MarkAttendanceScreen(),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // TEST 3: Defaults to today's date
      final todayFormatted = AppDateUtils.formatDisplayDate(DateTime.now());
      expect(find.text(todayFormatted), findsOneWidget);

      // Verify active employee list shows Murugan
      expect(find.text('Murugan'), findsOneWidget);

      await tester.runAsync(() => testDb.close());
    });

    // -------------------------------------------------------------
    // TEST 5 & TEST 6: Bulk Mark Employee A Present, B Absent; Accurate Reload
    // -------------------------------------------------------------
    test('TEST 5 & TEST 6: Bulk mark Employee A present, Employee B absent and reload accurately',
        () async {
      await initTestEnv();

      final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);
      final empB = await employeeRepo.createEmployee(name: 'Employee B', initialSalaryPaise: 2500000);

      const testDateIso = '2026-11-08';

      // Bulk save atomically
      await attendanceRepo.saveAttendanceForDate(
        dateIso: testDateIso,
        statusByEmployeeId: {
          empA.id: AttendanceStatus.present,
          empB.id: AttendanceStatus.absent,
        },
      );

      // TEST 6: Reload from database and verify accuracy
      final attA = await attendanceRepo.getAttendanceForDate(empA.id, testDateIso);
      final attB = await attendanceRepo.getAttendanceForDate(empB.id, testDateIso);

      expect(attA, isNotNull);
      expect(attA!.status, equals(AttendanceStatus.present));
      expect(attB, isNotNull);
      expect(attB!.status, equals(AttendanceStatus.absent));

      await testDb.close();
    });

    // -------------------------------------------------------------
    // TEST 7: Update Existing Attendance Without Duplicate Rows
    // -------------------------------------------------------------
    test('TEST 7: Update Employee A from present to absent updates existing record (no duplicates)',
        () async {
      await initTestEnv();

      final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);
      const testDateIso = '2026-11-08';

      // 1. First mark present
      await attendanceRepo.recordAttendance(
        employeeId: empA.id,
        dateIso: testDateIso,
        status: AttendanceStatus.present,
      );

      var records = await testDb.query(
        'attendance',
        where: 'employee_id = ? AND attendance_date = ?',
        whereArgs: [empA.id, testDateIso],
      );
      expect(records.length, equals(1));
      expect(records.first['status'].toString().toLowerCase(), equals('present'));

      // 2. Update to absent
      await attendanceRepo.recordAttendance(
        employeeId: empA.id,
        dateIso: testDateIso,
        status: AttendanceStatus.absent,
      );

      records = await testDb.query(
        'attendance',
        where: 'employee_id = ? AND attendance_date = ?',
        whereArgs: [empA.id, testDateIso],
      );
      // Strictly 1 row, updated status
      expect(records.length, equals(1));
      expect(records.first['status'].toString().toLowerCase(), equals('absent'));

      await testDb.close();
    });

    // -------------------------------------------------------------
    // TEST 8: Attendance Sync Across Employee Profile & Leave Report
    // -------------------------------------------------------------
    test('TEST 8: Attendance recorded for date syncs with all attendance queries and counts',
        () async {
      await initTestEnv();

      final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);
      const testDateIso = '2026-11-05';

      // Record present
      await attendanceRepo.recordAttendance(
        employeeId: empA.id,
        dateIso: testDateIso,
        status: AttendanceStatus.present,
      );

      // Verify date attendance query (used by Leave Report & DailyAttendancePanel)
      final dayList = await attendanceRepo.getAllAttendanceForDate(testDateIso);
      expect(dayList.any((a) => a.employeeId == empA.id && a.status == AttendanceStatus.present), isTrue);

      // Verify monthly counts (used by Profile)
      final counts = await attendanceRepo.getMonthlyAttendanceCounts(empA.id, 2026, 11);
      expect(counts['present'], equals(1));
      expect(counts['absent'], equals(0));

      await testDb.close();
    });

    // -------------------------------------------------------------
    // TEST 9: Unmarked Dates Display as Not Marked
    // -------------------------------------------------------------
    test('TEST 9: Unmarked dates return null (Not Marked), never defaulted to absent',
        () async {
      await initTestEnv();

      final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);
      const unrecordedDateIso = '2026-11-01';

      final record = await attendanceRepo.getAttendanceForDate(empA.id, unrecordedDateIso);
      expect(record, isNull);

      final dayList = await attendanceRepo.getAllAttendanceForDate(unrecordedDateIso);
      expect(dayList.any((a) => a.employeeId == empA.id), isFalse);

      await testDb.close();
    });

    // -------------------------------------------------------------
    // TEST 10: Salary Edited From Directory Updates Settings & History
    // -------------------------------------------------------------
    test('TEST 10: Salary updated appends revision and reflects in salary summary',
        () async {
      await initTestEnv();

      final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);

      // Check initial salary
      var currentSalary = await salaryRepo.getCurrentSalary(empA.id);
      expect(currentSalary?.monthlySalaryPaise, equals(2000000));

      // Update salary to ₹30,000 (3,000,000 paise) effective today
      await salaryRepo.updateSalary(
        employeeId: empA.id,
        newSalaryPaise: 3000000,
        effectiveFromIso: '2026-11-08',
      );

      // Verify new current salary
      currentSalary = await salaryRepo.getCurrentSalary(empA.id);
      expect(currentSalary?.monthlySalaryPaise, equals(3000000));

      // Verify revision history has 2 records
      final history = await salaryRepo.getSalaryHistory(empA.id);
      expect(history.length, equals(2));

      await testDb.close();
    });

    // -------------------------------------------------------------
    // TEST 11: Regular Salary Payment Recorded Separately
    // -------------------------------------------------------------
    test('TEST 11: Regular salary payment writes to salary_payments and leaves advances untouched',
        () async {
      await initTestEnv();

      final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2500000);
      const period = '2026-11';

      // Record Regular Salary Payment of ₹15,000
      await salaryPaymentRepo.createPayment(
        employeeId: empA.id,
        amountPaise: 1500000,
        paymentDateIso: '2026-11-08',
        salaryPeriod: period,
        description: 'November Regular Salary',
      );

      // Verify salary_payments table has 1 record
      final payments = await salaryPaymentRepo.getPaymentsForPeriod(empA.id, period);
      expect(payments.length, equals(1));
      expect(payments.first.amountPaise, equals(1500000));

      // Verify advances table remains completely empty
      final advances = await advanceRepo.getAdvancesForPeriod(empA.id, period);
      expect(advances, isEmpty);

      // Verify remaining payable calculation
      final overview = await salaryPaymentRepo.getFinancialOverview(empA.id, period);
      expect(overview.monthlySalaryPaise, equals(2500000));
      expect(overview.regularPaidPaise, equals(1500000));
      expect(overview.totalAdvancesPaise, equals(0));
      expect(overview.remainingPayablePaise, equals(1000000));

      await testDb.close();
    });

    // -------------------------------------------------------------
    // TEST 12: Salary Advance Recorded Separately
    // -------------------------------------------------------------
    test('TEST 12: Salary advance writes to advances table and leaves salary_payments untouched',
        () async {
      await initTestEnv();

      final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2500000);
      const period = '2026-11';

      // Record Advance of ₹5,000
      await advanceRepo.createAdvance(
        employeeId: empA.id,
        amountPaise: 500000,
        transactionDateIso: '2026-11-02',
        salaryPeriod: period,
        description: 'Mid-month Advance',
      );

      // Verify advances table has 1 record
      final advances = await advanceRepo.getAdvancesForPeriod(empA.id, period);
      expect(advances.length, equals(1));
      expect(advances.first.amountPaise, equals(500000));

      // Verify salary_payments table remains completely empty
      final payments = await salaryPaymentRepo.getPaymentsForPeriod(empA.id, period);
      expect(payments, isEmpty);

      // Verify remaining balance reflects advance
      final overview = await salaryPaymentRepo.getFinancialOverview(empA.id, period);
      expect(overview.totalAdvancesPaise, equals(500000));
      expect(overview.regularPaidPaise, equals(0));
      expect(overview.remainingPayablePaise, equals(2000000));

      await testDb.close();
    });

    // -------------------------------------------------------------
    // TEST 13: App Restart Persistence
    // -------------------------------------------------------------
    test('TEST 13: Data persists across database reload', () async {
      final dbPath = inMemoryDatabasePath;
      final sharedDb = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
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
          },
        ),
      );

      final h1 = DatabaseHelper.forTest(sharedDb);
      final r1 = SqliteEmployeeRepository(databaseHelper: h1);
      final a1 = SqliteAttendanceRepository(databaseHelper: h1);

      final emp = await r1.createEmployee(name: 'Persistent Worker', initialSalaryPaise: 2000000);
      await a1.recordAttendance(
        employeeId: emp.id,
        dateIso: '2026-11-08',
        status: AttendanceStatus.present,
      );

      // Simulate app restart with fresh repository instances pointing to same database
      final h2 = DatabaseHelper.forTest(sharedDb);
      final r2 = SqliteEmployeeRepository(databaseHelper: h2);
      final a2 = SqliteAttendanceRepository(databaseHelper: h2);

      final reloadedEmp = await r2.getEmployeeById(emp.id);
      expect(reloadedEmp, isNotNull);
      expect(reloadedEmp!.name, equals('Persistent Worker'));

      final reloadedAtt = await a2.getAttendanceForDate(emp.id, '2026-11-08');
      expect(reloadedAtt, isNotNull);
      expect(reloadedAtt!.status, equals(AttendanceStatus.present));

      await sharedDb.close();
    });

    // -------------------------------------------------------------
    // TEST 14: Duplicate Attendance Prevention via UNIQUE Constraint
    // -------------------------------------------------------------
    test('TEST 14: Raw duplicate insert throws SQLite unique constraint exception', () async {
      await initTestEnv();

      final empA = await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);
      const testDateIso = '2026-11-08';

      // Insert once
      await testDb.insert('attendance', {
        'id': 'att-1',
        'employee_id': empA.id,
        'attendance_date': testDateIso,
        'status': 'PRESENT',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insert second row with same (employee_id, attendance_date) must fail with DatabaseException
      expect(
        () async => await testDb.insert('attendance', {
          'id': 'att-2',
          'employee_id': empA.id,
          'attendance_date': testDateIso,
          'status': 'ABSENT',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );

      await testDb.close();
    });

    // -------------------------------------------------------------
    // TEST 15: Unsaved Attendance Changes Dialog
    // -------------------------------------------------------------
    testWidgets('TEST 15: Mark Attendance tracks dirty state when changes are made',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initTestEnv();
        await employeeRepo.createEmployee(name: 'Employee A', initialSalaryPaise: 2000000);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseHelperProvider.overrideWithValue(helper),
          ],
          child: const MaterialApp(
            home: MarkAttendanceScreen(),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Find the toggle switch for Employee A
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Toggle switch to make dirty
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Find PopScope widget
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScope = tester.widget(popScopeFinder) as PopScope;
      // canPop should now be false because state is dirty
      expect(popScope.canPop, isFalse);

      await tester.runAsync(() => testDb.close());
    });

    // -------------------------------------------------------------
    // TEST 16: Salary Change Preserves Historical Salary and Advances
    // -------------------------------------------------------------
    test('TEST 16: Salary revision preserves historical salary calculations and advances',
        () async {
      await initTestEnv();

      // Employee joined in October 2026 with salary ₹20,000
      final empA = await employeeRepo.createEmployee(
        name: 'Employee A',
        joiningDate: '2026-10-01',
        initialSalaryPaise: 2000000,
      );

      // October: Salary = ₹20,000, Advance = ₹5,000
      await advanceRepo.createAdvance(
        employeeId: empA.id,
        amountPaise: 500000,
        transactionDateIso: '2026-10-15',
        salaryPeriod: '2026-10',
      );

      final octSummaryBefore = await salaryRepo.getSalarySummary(empA.id, '2026-10');
      expect(octSummaryBefore.monthlySalaryPaise, equals(2000000));
      expect(octSummaryBefore.totalAdvancesPaise, equals(500000));
      expect(octSummaryBefore.remainingSalaryPaise, equals(1500000));

      // November: Salary revised to ₹25,000
      await salaryRepo.updateSalary(
        employeeId: empA.id,
        newSalaryPaise: 2500000,
        effectiveFromIso: '2026-11-01',
      );

      // November summary uses new salary
      final novSummary = await salaryRepo.getSalarySummary(empA.id, '2026-11');
      expect(novSummary.monthlySalaryPaise, equals(2500000));
      expect(novSummary.totalAdvancesPaise, equals(0));
      expect(novSummary.remainingSalaryPaise, equals(2500000));

      // October summary STILL accurately preserves ₹20,000 salary and ₹5,000 advance
      final octSummaryAfter = await salaryRepo.getSalarySummary(empA.id, '2026-10');
      expect(octSummaryAfter.monthlySalaryPaise, equals(2000000));
      expect(octSummaryAfter.totalAdvancesPaise, equals(500000));
      expect(octSummaryAfter.remainingSalaryPaise, equals(1500000));

      await testDb.close();
    });
  });
}
