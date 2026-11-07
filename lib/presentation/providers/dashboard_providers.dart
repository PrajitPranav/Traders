import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_formatter.dart';
import 'employee_providers.dart';
import 'repository_providers.dart';

class DashboardStats {
  final int totalEmployees;
  final int presentToday;
  final int absentToday;

  const DashboardStats({
    required this.totalEmployees,
    required this.presentToday,
    required this.absentToday,
  });
}

/// Computes live dashboard metrics strictly from SQLite
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  // Watch employeeListProvider so dashboard automatically updates when employees change
  ref.watch(employeeListProvider);

  final employeeRepo = ref.watch(employeeRepositoryProvider);
  final attendanceRepo = ref.watch(attendanceRepositoryProvider);

  final todayIso = AppDateUtils.toIsoDateString(DateTime.now());

  final total = await employeeRepo.getActiveEmployeeCount();
  final present = await attendanceRepo.getTodayPresentCount(todayIso);
  final absent = await attendanceRepo.getTodayAbsentCount(todayIso);

  return DashboardStats(
    totalEmployees: total,
    presentToday: present,
    absentToday: absent,
  );
});

