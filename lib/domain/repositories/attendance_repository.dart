import '../entities/attendance.dart';

/// Abstract contract for Employee Attendance operations.
abstract class AttendanceRepository {
  /// Retrieves all attendance records for an employee for a specific month and year.
  Future<List<Attendance>> getMonthlyAttendance(String employeeId, int year, int month);

  /// Retrieves a map of date string ('YYYY-MM-DD') to AttendanceStatus for calendar rendering.
  Future<Map<String, AttendanceStatus>> getMonthAttendanceMap(String employeeId, int year, int month);

  /// Retrieves attendance for an employee on a specific date, or null if unmarked.
  Future<Attendance?> getAttendanceForDate(String employeeId, String dateIso);

  /// Upserts attendance (inserts if not present, updates if exists) enforcing uniqueness.
  Future<void> recordAttendance({
    required String employeeId,
    required String dateIso,
    required AttendanceStatus status,
  });

  /// Deletes attendance record for the date (reverts to unmarked).
  Future<void> deleteAttendance({
    required String employeeId,
    required String dateIso,
  });

  /// Counts of present and absent days for an employee in a given month.
  Future<Map<String, int>> getMonthlyAttendanceCounts(String employeeId, int year, int month);

  /// Today's present count across all active employees.
  Future<int> getTodayPresentCount(String todayIso);

  /// Today's absent count across all active employees.
  Future<int> getTodayAbsentCount(String todayIso);

  /// Retrieves all attendance records across active employees for a specific date ('YYYY-MM-DD').
  Future<List<Attendance>> getAllAttendanceForDate(String dateIso);

  /// Retrieves all attendance records across active employees for a specific month, grouped by date ('YYYY-MM-DD').
  Future<Map<String, List<Attendance>>> getAllMonthAttendanceByDate(int year, int month);
}

