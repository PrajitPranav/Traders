import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/attendance.dart';
import 'dashboard_providers.dart';
import 'repository_providers.dart';

/// Currently selected month for calendar viewing
final selectedAttendanceMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Attendance map (ISO date -> AttendanceStatus) for selected employee and month
final employeeAttendanceMapProvider =
    FutureProvider.family<Map<String, AttendanceStatus>, String>((ref, employeeId) async {
  final month = ref.watch(selectedAttendanceMonthProvider);
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getMonthAttendanceMap(employeeId, month.year, month.month);
});

/// Monthly counts (present, absent) for selected employee and month
final employeeAttendanceCountsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, employeeId) async {
  final month = ref.watch(selectedAttendanceMonthProvider);
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getMonthlyAttendanceCounts(employeeId, month.year, month.month);
});

/// Single day attendance for an employee
final dailyAttendanceProvider =
    FutureProvider.family<Attendance?, ({String employeeId, String dateIso})>((ref, arg) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getAttendanceForDate(arg.employeeId, arg.dateIso);
});

/// Company-wide attendance records for a specific month grouped by date ('YYYY-MM-DD')
final allMonthAttendanceByDateProvider = FutureProvider.family<
    Map<String, List<Attendance>>, ({int year, int month})>((ref, arg) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getAllMonthAttendanceByDate(arg.year, arg.month);
});

/// Company-wide attendance records for a specific date ('YYYY-MM-DD')
final allDateAttendanceProvider =
    FutureProvider.family<List<Attendance>, String>((ref, dateIso) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getAllAttendanceForDate(dateIso);
});

/// State notifier for attendance mutation operations
class AttendanceActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AttendanceActionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> record({
    required String employeeId,
    required String dateIso,
    required AttendanceStatus status,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(attendanceRepositoryProvider);
      await repo.recordAttendance(
        employeeId: employeeId,
        dateIso: dateIso,
        status: status,
      );

      // Invalidate relevant providers to trigger immediate UI refresh
      _ref.invalidate(employeeAttendanceMapProvider(employeeId));
      _ref.invalidate(employeeAttendanceCountsProvider(employeeId));
      _ref.invalidate(dailyAttendanceProvider((employeeId: employeeId, dateIso: dateIso)));
      _ref.invalidate(allDateAttendanceProvider(dateIso));
      _ref.invalidate(allMonthAttendanceByDateProvider);
      _ref.invalidate(dashboardStatsProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> remove({
    required String employeeId,
    required String dateIso,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(attendanceRepositoryProvider);
      await repo.deleteAttendance(
        employeeId: employeeId,
        dateIso: dateIso,
      );

      _ref.invalidate(employeeAttendanceMapProvider(employeeId));
      _ref.invalidate(employeeAttendanceCountsProvider(employeeId));
      _ref.invalidate(dailyAttendanceProvider((employeeId: employeeId, dateIso: dateIso)));
      _ref.invalidate(allDateAttendanceProvider(dateIso));
      _ref.invalidate(allMonthAttendanceByDateProvider);
      _ref.invalidate(dashboardStatsProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final attendanceActionNotifierProvider =
    StateNotifierProvider<AttendanceActionNotifier, AsyncValue<void>>((ref) {
  return AttendanceActionNotifier(ref);
});
