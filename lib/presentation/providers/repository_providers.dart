import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/excel_report_service.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/repositories/sqlite_advance_repository.dart';
import '../../data/repositories/sqlite_attendance_repository.dart';
import '../../data/repositories/sqlite_employee_repository.dart';
import '../../data/repositories/sqlite_salary_payment_repository.dart';
import '../../data/repositories/sqlite_salary_repository.dart';
import '../../data/repositories/sqlite_settings_repository.dart';
import '../../domain/repositories/advance_repository.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/repositories/salary_payment_repository.dart';
import '../../domain/repositories/salary_repository.dart';
import '../../domain/repositories/settings_repository.dart';

/// Database Helper singleton provider
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Employee Repository Provider
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SqliteEmployeeRepository(databaseHelper: dbHelper);
});

/// Attendance Repository Provider
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SqliteAttendanceRepository(databaseHelper: dbHelper);
});

/// Advance Repository Provider
final advanceRepositoryProvider = Provider<AdvanceRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SqliteAdvanceRepository(databaseHelper: dbHelper);
});

/// Salary Repository Provider
final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final advanceRepo = ref.watch(advanceRepositoryProvider) as SqliteAdvanceRepository;
  return SqliteSalaryRepository(
    databaseHelper: dbHelper,
    advanceRepository: advanceRepo,
  );
});

/// Salary Payment (regular salary, separate from advances) Repository Provider
final salaryPaymentRepositoryProvider = Provider<SalaryPaymentRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SqliteSalaryPaymentRepository(databaseHelper: dbHelper);
});

/// Settings & Backup Repository Provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SqliteSettingsRepository(databaseHelper: dbHelper);
});

/// Excel Report Service Provider
final excelReportServiceProvider = Provider<ExcelReportService>((ref) {
  return ExcelReportService(
    employeeRepository: ref.watch(employeeRepositoryProvider),
    attendanceRepository: ref.watch(attendanceRepositoryProvider),
    salaryRepository: ref.watch(salaryRepositoryProvider),
    advanceRepository: ref.watch(advanceRepositoryProvider),
  );
});


