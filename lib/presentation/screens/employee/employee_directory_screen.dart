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
import 'add_employee_sheet.dart';

class EmployeeDirectoryScreen extends ConsumerStatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  ConsumerState<EmployeeDirectoryScreen> createState() =>
      _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState
    extends ConsumerState<EmployeeDirectoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset search query when entering directory so all active employees are visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(employeeSearchQueryProvider.notifier).state = '';
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployeesAsync = ref.watch(filteredEmployeesProvider);
    final allEmployeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.employeeDirectory,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            allEmployeesAsync.maybeWhen(
              data: (list) => Text(
                '${list.length} active ${list.length == 1 ? 'employee' : 'employees'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: () => AddEmployeeSheet.show(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(AppStrings.addMember),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
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
            // Salary entry (salary payments & advances live here, not on Home)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Material(
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: const Key('open_salary_button'),
                    onTap: () => context.push(AppRoutes.salary),
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 30),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Salary',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Record salary payments and advances',
                                  style: TextStyle(fontSize: 15, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 26),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {});
                    ref.read(employeeSearchQueryProvider.notifier).state = val;
                  },
                  decoration: InputDecoration(
                    hintText: AppStrings.searchEmployees,
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              ref
                                  .read(employeeSearchQueryProvider.notifier)
                                  .state = '';
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            // Employee List Content
            filteredEmployeesAsync.when(
              data: (employees) {
                if (employees.isEmpty) {
                  final isSearching =
                      ref.watch(employeeSearchQueryProvider).isNotEmpty;
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: isSearching
                          ? AppStrings.noEmployeesFound
                          : AppStrings.noEmployeesYet,
                      message: isSearching
                          ? 'Try searching with a different name or employee code.'
                          : AppStrings.getStartedAdding,
                      buttonText: isSearching ? null : AppStrings.addMember,
                      buttonIcon: Icons.person_add_outlined,
                      onButtonPressed: isSearching
                          ? null
                          : () => AddEmployeeSheet.show(context),
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
                            onTap: () => context.push(
                              AppRoutes.employeeDetailPath(employee.id),
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.cardBorder,
                                  width: 1,
                                ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
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
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryNavy
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                employee.employeeCode,
                                                style: const TextStyle(
                                                  fontSize: 14,
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
                                            if (employee.designation != null &&
                                                employee
                                                    .designation!.isNotEmpty)
                                              Expanded(
                                                child: Text(
                                                  employee.designation!,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                            if (employee.phone != null &&
                                                employee.phone!.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                '•  ${employee.phone}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
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

