import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:traders/core/constants/app_strings.dart';
import 'package:traders/core/services/excel_report_service.dart';
import 'package:traders/data/datasources/database_helper.dart';
import 'package:traders/data/repositories/sqlite_advance_repository.dart';
import 'package:traders/data/repositories/sqlite_attendance_repository.dart';
import 'package:traders/data/repositories/sqlite_employee_repository.dart';
import 'package:traders/data/repositories/sqlite_salary_repository.dart';
import 'package:traders/domain/entities/attendance.dart';
import 'package:traders/presentation/providers/repository_providers.dart';
import 'package:traders/presentation/screens/employee/employee_directory_screen.dart';
import 'package:traders/presentation/screens/home/home_screen.dart';
import 'package:traders/presentation/screens/leave_report/leave_report_screen.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late DatabaseHelper helper;
  late SqliteEmployeeRepository employeeRepo;
  late SqliteAttendanceRepository attendanceRepo;
  late SqliteAdvanceRepository advanceRepo;
  late SqliteSalaryRepository salaryRepo;
  late ExcelReportService excelService;

  Future<void> initTestEnv() async {
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
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
    excelService = ExcelReportService(
      employeeRepository: employeeRepo,
      attendanceRepository: attendanceRepo,
      salaryRepository: salaryRepo,
      advanceRepository: advanceRepo,
    );
  }

  testWidgets(
      'TEST 1 & TEST 2: Add three employees. Home screen displays ONLY total employee count (3) and NO employee names; Employee Directory displays all three employees',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await initTestEnv();
      await employeeRepo.createEmployee(
        name: 'Arun Kumar',
        designation: 'Manager',
        initialSalaryPaise: 2500000,
      );
      await employeeRepo.createEmployee(
        name: 'Bala Murugan',
        designation: 'Supervisor',
        initialSalaryPaise: 2000000,
      );
      await employeeRepo.createEmployee(
        name: 'Chandra Sekar',
        designation: 'Operator',
        initialSalaryPaise: 1800000,
      );
    });

    // Render HomeScreen
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
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // Verify dashboard sections and count '3' are shown on HomeScreen
    expect(find.text('Leave Report'), findsOneWidget);
    expect(find.text('TOTAL EMPLOYEES'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('EMPLOYEE REPORT'), findsOneWidget);
    expect(find.text('SALARY / SALARY ADVANCE'), findsOneWidget);
    expect(find.text('EMPLOYEES'), findsOneWidget);

    // STRICT REQUIREMENT: Employee names MUST NOT appear on the HomeScreen
    expect(find.text('Arun Kumar'), findsNothing);
    expect(find.text('Bala Murugan'), findsNothing);
    expect(find.text('Chandra Sekar'), findsNothing);

    // TEST 2: Render EmployeeDirectoryScreen and verify all 3 appear
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseHelperProvider.overrideWithValue(helper),
        ],
        child: const MaterialApp(
          home: EmployeeDirectoryScreen(),
        ),
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Arun Kumar'), findsOneWidget);
    expect(find.text('Bala Murugan'), findsOneWidget);
    expect(find.text('Chandra Sekar'), findsOneWidget);
    expect(find.text('EMP0001'), findsOneWidget);
    expect(find.text('EMP0002'), findsOneWidget);
    expect(find.text('EMP0003'), findsOneWidget);

    await tester.runAsync(() async {
      await testDb.close();
    });
  });

  testWidgets(
      'TEST 3 & TEST 6: Leave Report displays selected date Present, Absent, Not Marked employees and empty advance state when no advances exist on that date',
      (WidgetTester tester) async {
    const targetDateIso = '2026-10-15';
    final targetDate = DateTime(2026, 10, 15);

    await tester.runAsync(() async {
      await initTestEnv();
      final empA = await employeeRepo.createEmployee(
        name: 'Arun Kumar',
        initialSalaryPaise: 2000000,
      );
      final empB = await employeeRepo.createEmployee(
        name: 'Bala Murugan',
        initialSalaryPaise: 2000000,
      );
      await employeeRepo.createEmployee(
        name: 'Chandra Sekar',
        initialSalaryPaise: 2000000,
      );

      await attendanceRepo.recordAttendance(
        employeeId: empA.id,
        dateIso: targetDateIso,
        status: AttendanceStatus.present,
      );
      await attendanceRepo.recordAttendance(
        employeeId: empB.id,
        dateIso: targetDateIso,
        status: AttendanceStatus.absent,
      );
    });
    // Chandra Sekar is left Not Marked

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseHelperProvider.overrideWithValue(helper),
        ],
        child: MaterialApp(
          home: LeaveReportScreen(initialDate: targetDate),
        ),
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // Verify all three employees appear under their respective categories
    expect(find.text('PRESENT EMPLOYEES'), findsOneWidget);
    expect(find.text('ABSENT EMPLOYEES'), findsOneWidget);
    expect(find.text('NOT MARKED EMPLOYEES'), findsOneWidget);
    expect(find.text('Arun Kumar'), findsOneWidget);
    expect(find.text('Bala Murugan'), findsOneWidget);
    expect(find.text('Chandra Sekar'), findsOneWidget);

    // TEST 6: Verify empty state for date without advance transactions
    expect(find.text(AppStrings.noAdvancesForDate), findsOneWidget);

    await tester.runAsync(() async {
      await testDb.close();
    });
  });

  test(
      'TEST 4 & TEST 5: Record advance for Employee A and Employee B; verify synchronization across profile, Leave Report, salary summary, and monthly Employee Report, with full isolation',
      () async {
    await initTestEnv();
    addTearDown(() async => await testDb.close());
    final empA = await employeeRepo.createEmployee(
      name: 'Employee A',
      initialSalaryPaise: 2000000, // ₹20,000
    );
    final empB = await employeeRepo.createEmployee(
      name: 'Employee B',
      initialSalaryPaise: 2500000, // ₹25,000
    );

    // Record ₹5,000 advance for Employee A on 2026-11-10
    await advanceRepo.createAdvance(
      employeeId: empA.id,
      amountPaise: 500000,
      transactionDateIso: '2026-11-10',
      salaryPeriod: '2026-11',
      description: 'Festival Advance',
    );

    // 1. Verify in Employee Profile advance list
    final empAAdvances =
        await advanceRepo.getAdvancesForPeriod(empA.id, '2026-11');
    expect(empAAdvances.length, equals(1));
    expect(empAAdvances.first.amountPaise, equals(500000));

    // 2. Verify in selected-date Leave Report query
    final dateAdvances = await advanceRepo.getAllAdvancesForDate('2026-11-10');
    expect(dateAdvances.length, equals(1));
    expect(dateAdvances.first.employeeId, equals(empA.id));
    expect(dateAdvances.first.amountPaise, equals(500000));

    // 3. Verify in Salary Summary
    final summaryA = await salaryRepo.getSalarySummary(empA.id, '2026-11');
    expect(summaryA.monthlySalaryPaise, equals(2000000));
    expect(summaryA.totalAdvancesPaise, equals(500000));
    expect(summaryA.remainingSalaryPaise, equals(1500000));

    // 4. Verify in Monthly Employee Report data
    final reportItems = await excelService.collectReportData(
      year: 2026,
      month: 11,
      employeeId: empA.id,
    );
    expect(reportItems.length, equals(1));
    expect(reportItems.first.salarySummary.totalAdvancesPaise, equals(500000));
    expect(
        reportItems.first.salarySummary.remainingSalaryPaise, equals(1500000));

    // TEST 5: Record advance for Employee B (₹4,000) and verify Employee A's salary is unchanged
    await advanceRepo.createAdvance(
      employeeId: empB.id,
      amountPaise: 400000,
      transactionDateIso: '2026-11-12',
      salaryPeriod: '2026-11',
      description: 'Personal Advance',
    );

    final summaryAAfterB =
        await salaryRepo.getSalarySummary(empA.id, '2026-11');
    final summaryB = await salaryRepo.getSalarySummary(empB.id, '2026-11');

    expect(summaryAAfterB.totalAdvancesPaise, equals(500000));
    expect(summaryAAfterB.remainingSalaryPaise, equals(1500000));
    expect(summaryB.totalAdvancesPaise, equals(400000));
    expect(summaryB.remainingSalaryPaise, equals(2100000));
  });

  test(
      'TEST 7 & TEST 8: Generate consolidated and individual monthly Excel (.xlsx) reports and verify all 4 sheets, headers, values, and employee isolation',
      () async {
    await initTestEnv();
    addTearDown(() async => await testDb.close());
    final empA = await employeeRepo.createEmployee(
      name: 'Employee A',
      designation: 'Technician',
      initialSalaryPaise: 2000000, // ₹20,000
    );
    await employeeRepo.createEmployee(
      name: 'Employee B',
      designation: 'Supervisor',
      initialSalaryPaise: 2500000, // ₹25,000
    );

    await attendanceRepo.recordAttendance(
      employeeId: empA.id,
      dateIso: '2026-11-01',
      status: AttendanceStatus.present,
    );
    await attendanceRepo.recordAttendance(
      employeeId: empA.id,
      dateIso: '2026-11-02',
      status: AttendanceStatus.absent,
    );
    await advanceRepo.createAdvance(
      employeeId: empA.id,
      amountPaise: 500000, // ₹5,000
      transactionDateIso: '2026-11-05',
      salaryPeriod: '2026-11',
      description: 'Medical Advance',
    );

    // TEST 7: Consolidated Report
    final consolidated = await excelService.generateExcelReport(
      year: 2026,
      month: 11,
    );

    expect(
      consolidated.fileName,
      equals('Saravanas_Employee_Report_November_2026.xlsx'),
    );
    expect(consolidated.bytes.isNotEmpty, isTrue);

    final decodedConsolidated = Excel.decodeBytes(consolidated.bytes);
    expect(
      decodedConsolidated.tables.keys,
      containsAll([
        ExcelReportService.sheetMonthlySummary,
        ExcelReportService.sheetAttendanceDetails,
        ExcelReportService.sheetPrepaidHistory,
        ExcelReportService.sheetFinancialSummary,
      ]),
    );

    // Verify Monthly Summary sheet has header + 2 employee rows + 1 total row
    final summarySheet =
        decodedConsolidated[ExcelReportService.sheetMonthlySummary];
    // Row 0: Title, Row 1: Subtitle, Row 2: Blank, Row 3: Header, Row 4: EMP0001, Row 5: EMP0002, Row 6: TOTAL
    expect(
      summarySheet.rows[3][0]?.value.toString(),
      equals('Employee Code'),
    );
    expect(summarySheet.rows[4][0]?.value.toString(), equals('EMP0001'));
    expect(summarySheet.rows[4][1]?.value.toString(), equals('Employee A'));
    expect(summarySheet.rows[4][4]?.value.toString(), equals('1')); // Present
    expect(summarySheet.rows[4][5]?.value.toString(), equals('1')); // Absent
    expect(
      summarySheet.rows[4][6]?.value.toString(),
      equals('28'),
    ); // 30 - 2 = 28 Not Marked
    expect(summarySheet.rows[5][0]?.value.toString(), equals('EMP0002'));

    // TEST 8: Individual Employee Report for Employee A
    final individual = await excelService.generateExcelReport(
      year: 2026,
      month: 11,
      employeeId: empA.id,
    );

    expect(
      individual.fileName,
      equals('Saravanas_EMP0001_November_2026.xlsx'),
    );

    final decodedIndividual = Excel.decodeBytes(individual.bytes);
    final indSummarySheet =
        decodedIndividual[ExcelReportService.sheetMonthlySummary];

    // Verify EMP0001 is present and EMP0002 is NOT included anywhere in the individual workbook
    final allSummaryText = indSummarySheet.rows
        .expand((r) => r)
        .map((c) => c?.value?.toString() ?? '')
        .join(' ');
    expect(allSummaryText.contains('EMP0001'), isTrue);
    expect(allSummaryText.contains('EMP0002'), isFalse);
    expect(allSummaryText.contains('Employee B'), isFalse);
  });

  test(
      'TEST 9, TEST 10, TEST 11, TEST 12: Persistence across restart, simultaneous attendance + advance on same date, multi-month isolation, and rejection of advance exceeding remaining salary',
      () async {
    await initTestEnv();
    addTearDown(() async => await testDb.close());
    final emp = await employeeRepo.createEmployee(
      name: 'Employee X',
      initialSalaryPaise: 2000000, // ₹20,000
    );

    // TEST 10: Record attendance and advance on the exact same date (2026-10-15)
    await attendanceRepo.recordAttendance(
      employeeId: emp.id,
      dateIso: '2026-10-15',
      status: AttendanceStatus.present,
    );
    await advanceRepo.createAdvance(
      employeeId: emp.id,
      amountPaise: 600000, // ₹6,000
      transactionDateIso: '2026-10-15',
      salaryPeriod: '2026-10',
      description: 'Same-day Advance',
    );

    final octAttByDate =
        await attendanceRepo.getAllMonthAttendanceByDate(2026, 10);
    final octAdvByDate =
        await advanceRepo.getAllMonthAdvancesByDate(2026, 10);
    expect(octAttByDate['2026-10-15']?.first.status,
        equals(AttendanceStatus.present));
    expect(octAdvByDate['2026-10-15']?.first.amountPaise, equals(600000));

    // TEST 11: Navigate to November (2026-11) and verify October indicators do not bleed into November
    final novAttByDate =
        await attendanceRepo.getAllMonthAttendanceByDate(2026, 11);
    final novAdvByDate =
        await advanceRepo.getAllMonthAdvancesByDate(2026, 11);
    expect(novAttByDate.isEmpty, isTrue);
    expect(novAdvByDate.isEmpty, isTrue);

    // TEST 12: Attempt to enter an advance greater than remaining salary
    // Remaining salary for 2026-10 is ₹20,000 - ₹6,000 = ₹14,000 (1,400,000 paise).
    // Attempting ₹15,000 (1,500,000 paise) must throw StateError with clear message.
    expect(
      () => advanceRepo.createAdvance(
        employeeId: emp.id,
        amountPaise: 1500000, // ₹15,000 > ₹14,000 remaining
        transactionDateIso: '2026-10-20',
        salaryPeriod: '2026-10',
      ),
      throwsA(isA<StateError>()),
    );

    // TEST 9: Re-instantiate repositories simulating application restart and verify persistence
    final restartedHelper = DatabaseHelper.forTest(testDb);
    final restartedEmpRepo =
        SqliteEmployeeRepository(databaseHelper: restartedHelper);
    final restartedSalaryRepo =
        SqliteSalaryRepository(databaseHelper: restartedHelper);

    final employeesAfterRestart = await restartedEmpRepo.getAllEmployees();
    final octSummaryAfterRestart =
        await restartedSalaryRepo.getSalarySummary(emp.id, '2026-10');

    expect(employeesAfterRestart.length, equals(1));
    expect(octSummaryAfterRestart.totalAdvancesPaise, equals(600000));
    expect(octSummaryAfterRestart.remainingSalaryPaise, equals(1400000));
  });
}
