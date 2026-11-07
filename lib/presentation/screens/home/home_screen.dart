import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/employee_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/saravanas_logo.dart';
import '../../widgets/stat_card.dart';
import '../employee/add_employee_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
    final filteredEmployeesAsync = ref.watch(filteredEmployeesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const SaravanasLogo(size: 34),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SARAVANAS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  'Employee Management',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // STRICT REQUIREMENT: Add Member button must appear immediately to the LEFT of the profile icon
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => AddEmployeeSheet.show(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(AppStrings.addMember),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Admin Profile Icon (Immediately to the right of Add Member)
          IconButton(
            tooltip: AppStrings.adminProfile,
            icon: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder, width: 1.5),
              ),
              child: const CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.person, size: 18, color: Colors.white),
              ),
            ),
            onPressed: () => context.push(AppRoutes.adminProfile),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentTeal,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          await ref.read(employeeListProvider.notifier).loadEmployees();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Dashboard KPI Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: dashboardStatsAsync.when(
                  data: (stats) => Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: AppStrings.totalEmployees,
                          value: '${stats.totalEmployees}',
                          icon: Icons.people_outline,
                          accentColor: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: AppStrings.presentToday,
                          value: '${stats.presentToday}',
                          icon: Icons.check_circle_outline,
                          accentColor: AppColors.successGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: AppStrings.absentToday,
                          value: '${stats.absentToday}',
                          icon: Icons.cancel_outlined,
                          accentColor: AppColors.dangerRed,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: AppStrings.totalEmployees,
                          value: '-',
                          icon: Icons.people_outline,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: AppStrings.presentToday,
                          value: '-',
                          icon: Icons.check_circle_outline,
                          accentColor: AppColors.successGreen,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: AppStrings.absentToday,
                          value: '-',
                          icon: Icons.cancel_outlined,
                          accentColor: AppColors.dangerRed,
                        ),
                      ),
                    ],
                  ),
                  error: (e, s) => const SizedBox.shrink(),
                ),
              ),
            ),

            // Employee Directory Header & Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          AppStrings.employees,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        filteredEmployeesAsync.maybeWhen(
                          data: (list) => Text(
                            '${list.length} active',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        ref.read(employeeSearchQueryProvider.notifier).state = val;
                      },
                      decoration: InputDecoration(
                        hintText: AppStrings.searchEmployees,
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(employeeSearchQueryProvider.notifier).state = '';
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Employee List Content
            filteredEmployeesAsync.when(
              data: (employees) {
                if (employees.isEmpty) {
                  final isSearching = ref.watch(employeeSearchQueryProvider).isNotEmpty;
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: isSearching ? AppStrings.noEmployeesFound : AppStrings.noEmployeesYet,
                      message: isSearching
                          ? 'Try searching with a different name or employee code.'
                          : AppStrings.getStartedAdding,
                      buttonText: isSearching ? null : AppStrings.addMember,
                      buttonIcon: Icons.person_add_outlined,
                      onButtonPressed: isSearching ? null : () => AddEmployeeSheet.show(context),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final employee = employees[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => context.push(AppRoutes.employeeDetailPath(employee.id)),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.cardBorder, width: 1),
                              ),
                              child: Row(
                                children: [
                                  EmployeeAvatar(
                                    initials: employee.initials,
                                    radius: 24,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                employee.name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
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
                                        Row(
                                          children: [
                                            if (employee.designation != null && employee.designation!.isNotEmpty)
                                              Expanded(
                                                child: Text(
                                                  employee.designation!,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              )
                                            else
                                              const Text(
                                                'Employee',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            if (employee.phone != null && employee.phone!.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                '•  ${employee.phone}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: employees.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accentTeal),
                ),
              ),
              error: (err, _) => SliverFillRemaining(
                child: Center(
                  child: Text('Error loading directory: $err'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
