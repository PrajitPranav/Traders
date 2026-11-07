import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/salary_providers.dart';
import '../../widgets/stat_card.dart';

class EmployeeOverviewView extends ConsumerWidget {
  final Employee employee;

  const EmployeeOverviewView({super.key, required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayIso = AppDateUtils.toIsoDateString(DateTime.now());
    final currentPeriod = AppDateUtils.toSalaryPeriod(DateTime.now());

    final todayAttendanceAsync = ref.watch(
      dailyAttendanceProvider((employeeId: employee.id, dateIso: todayIso)),
    );
    final salarySummaryAsync = ref.watch(salarySummaryProvider(employee.id));
    final recentAdvancesAsync = ref.watch(employeeAdvancesForPeriodProvider(employee.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Today's Attendance Quick Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.today_outlined, color: AppColors.primaryNavy, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Attendance",
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      todayAttendanceAsync.when(
                        data: (attendance) {
                          if (attendance == null) {
                            return const Text(
                              AppStrings.notMarked,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            );
                          }
                          return Text(
                            attendance.isPresent ? AppStrings.present : AppStrings.absent,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: attendance.isPresent ? AppColors.successGreen : AppColors.dangerRed,
                            ),
                          );
                        },
                        loading: () => const Text('Loading...'),
                        error: (e, s) => const Text('Error'),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final current = todayAttendanceAsync.asData?.value;
                    final newStatus = current?.isPresent == true
                        ? AttendanceStatus.absent
                        : AttendanceStatus.present;

                    await ref.read(attendanceActionNotifierProvider.notifier).record(
                          employeeId: employee.id,
                          dateIso: todayIso,
                          status: newStatus,
                        );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  child: Text(
                    todayAttendanceAsync.asData?.value == null
                        ? 'Mark Present'
                        : (todayAttendanceAsync.asData?.value?.isPresent == true
                            ? 'Switch to Absent'
                            : 'Switch to Present'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Current Month Financial Snapshot
          salarySummaryAsync.when(
            data: (summary) => Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Current Salary',
                    value: CurrencyFormatter.formatPaise(summary.monthlySalaryPaise),
                    icon: Icons.account_balance_wallet_outlined,
                    accentColor: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    title: 'Remaining (${AppDateUtils.formatPeriodDisplay(currentPeriod)})',
                    value: CurrencyFormatter.formatPaise(summary.remainingSalaryPaise),
                    icon: Icons.savings_outlined,
                    accentColor: AppColors.accentTeal,
                  ),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Quick Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Summary',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (employee.phone != null && employee.phone!.isNotEmpty)
                  _buildQuickItem(Icons.phone_outlined, 'Phone', employee.phone!),
                if (employee.joiningDate != null)
                  _buildQuickItem(
                    Icons.calendar_today_outlined,
                    'Joining Date',
                    AppDateUtils.formatDisplayDate(
                      AppDateUtils.parseIsoDateString(employee.joiningDate!),
                    ),
                  ),
                _buildQuickItem(
                  Icons.badge_outlined,
                  'Designation',
                  employee.designation ?? 'Not specified',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recent Advances Preview
          recentAdvancesAsync.when(
            data: (advances) {
              if (advances.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Advances this Month',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...advances.take(3).map(
                          (adv) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  adv.description?.isNotEmpty == true
                                      ? adv.description!
                                      : 'Salary Advance',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                ),
                                Text(
                                  '- ${CurrencyFormatter.formatPaise(adv.amountPaise)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
