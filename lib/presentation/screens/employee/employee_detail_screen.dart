import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/employee_avatar.dart';
import '../attendance/attendance_calendar_view.dart';
import '../salary/salary_view.dart';
import 'edit_employee_sheet.dart';
import 'employee_overview_view.dart';
import 'employee_settings_view.dart';

class EmployeeDetailScreen extends ConsumerStatefulWidget {
  final String employeeId;

  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  ConsumerState<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends ConsumerState<EmployeeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeeAsync = ref.watch(employeeDetailProvider(widget.employeeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: employeeAsync.maybeWhen(
          data: (emp) => Text(
            emp != null ? emp.employeeCode : 'Employee Details',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          orElse: () => const Text('Employee Details'),
        ),
        actions: [
          employeeAsync.maybeWhen(
            data: (emp) => emp != null
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Employee',
                    onPressed: () => EditEmployeeSheet.show(context, emp),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: employeeAsync.when(
        data: (employee) {
          if (employee == null) {
            return const Center(child: Text('Employee not found'));
          }

          return Column(
            children: [
              // Header Card
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    EmployeeAvatar(
                      initials: employee.initials,
                      radius: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  employee.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNavy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  employee.employeeCode,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            employee.designation?.isNotEmpty == true
                                ? employee.designation!
                                : 'Employee',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Navigation Tabs
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: AppStrings.attendance),
                    Tab(text: AppStrings.salary),
                    Tab(text: AppStrings.settings),
                  ],
                ),
              ),
              const Divider(),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    EmployeeOverviewView(employee: employee),
                    AttendanceCalendarView(employeeId: employee.id),
                    SalaryView(employeeId: employee.id),
                    EmployeeSettingsView(employee: employee),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentTeal),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

