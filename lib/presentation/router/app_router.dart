import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../screens/admin/admin_profile_screen.dart';
import '../screens/admin/backup_restore_screen.dart';
import '../screens/employee/employee_detail_screen.dart';
import '../screens/employee/employee_directory_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/leave_report/leave_report_screen.dart';
import '../screens/reports/employee_report_screen.dart';
import '../screens/salary/salary_advance_screen.dart';
import '../screens/splash/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.employeeDirectory,
        builder: (context, state) => const EmployeeDirectoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.leaveReport,
        builder: (context, state) => const LeaveReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.employeeReports,
        builder: (context, state) => const EmployeeReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.salaryAdvance,
        builder: (context, state) => const SalaryAdvanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.employeeDetail,
        builder: (context, state) {
          final employeeId = state.pathParameters['id']!;
          return EmployeeDetailScreen(employeeId: employeeId);
        },
      ),
      GoRoute(
        path: AppRoutes.adminProfile,
        builder: (context, state) => const AdminProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.backupRestore,
        builder: (context, state) => const BackupRestoreScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});


