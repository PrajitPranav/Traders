import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../screens/admin/admin_profile_screen.dart';
import '../screens/admin/backup_restore_screen.dart';
import '../screens/employee/employee_detail_screen.dart';
import '../screens/home/home_screen.dart';
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

