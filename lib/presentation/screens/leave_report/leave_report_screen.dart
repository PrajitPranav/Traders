import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/advance.dart';
import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/employee_providers.dart';
import '../../providers/salary_providers.dart';
import '../../widgets/daily_attendance_panel.dart';
import '../../widgets/month_calendar.dart';

/// Leave Report: monthly calendar + selected-date attendance (editable) and
/// the prepaid salary transactions of that date.
class LeaveReportScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const LeaveReportScreen({super.key, this.initialDate});

  @override
  ConsumerState<LeaveReportScreen> createState() => _LeaveReportScreenState();
}

class _LeaveReportScreenState extends ConsumerState<LeaveReportScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _focusedDay = DateTime(initial.year, initial.month, initial.day);
    _selectedDay = _focusedDay;
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDay = DateTime(now.year, now.month, now.day);
      _selectedDay = _focusedDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateIso = AppDateUtils.toIsoDateString(_selectedDay);
    final monthArg = (year: _focusedDay.year, month: _focusedDay.month);

    final employeesAsync = ref.watch(employeeListProvider);
    final monthAttendance =
        ref.watch(allMonthAttendanceByDateProvider(monthArg)).asData?.value ?? {};
    final monthAdvances =
        ref.watch(allMonthAdvancesByDateProvider(monthArg)).asData?.value ?? {};
    final dateAdvances = ref.watch(allDateAdvancesProvider(selectedDateIso)).asData?.value ?? [];

    DayMarks marksFor(DateTime day) {
      final iso = AppDateUtils.toIsoDateString(day);
      final list = monthAttendance[iso] ?? const <Attendance>[];
      return DayMarks(
        present: list.any((a) => a.status == AttendanceStatus.present),
        absent: list.any((a) => a.status == AttendanceStatus.absent),
        advance: (monthAdvances[iso] ?? const <Advance>[]).isNotEmpty,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.leaveReport,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(
              'Daily attendance & prepaid activity',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              key: const Key('today_button'),
              onPressed: _jumpToToday,
              icon: const Icon(Icons.today_rounded, size: 22),
              label: const Text('Today'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.primaryNavy,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: employeesAsync.when(
        data: (activeEmployees) {
          final employeeById = {for (final e in activeEmployees) e.id: e};
          final totalPrepaidPaise = dateAdvances.fold<int>(0, (s, a) => s + a.amountPaise);

          return RefreshIndicator(
            color: AppColors.accentTeal,
            onRefresh: () async {
              ref.invalidate(allMonthAttendanceByDateProvider);
              ref.invalidate(allMonthAdvancesByDateProvider);
              ref.invalidate(allDateAttendanceProvider);
              ref.invalidate(allDateAdvancesProvider);
              await ref.read(employeeListProvider.notifier).loadEmployees();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonthCalendar(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    marksFor: marksFor,
                    onPageChanged: (focused) => setState(() => _focusedDay = focused),
                    onDaySelected: (selected, focused) => setState(() {
                      _selectedDay = DateTime(selected.year, selected.month, selected.day);
                      _focusedDay = focused;
                    }),
                  ),
                  const SizedBox(height: 10),
                  const CalendarLegend(),
                  const SizedBox(height: 16),

                  // Selected date banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: Colors.white, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Selected Date: ${AppDateUtils.formatDisplayDate(_selectedDay)}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  DailyAttendancePanel(date: _selectedDay, activeEmployees: activeEmployees),
                  const SizedBox(height: 20),

                  _PrepaidTransactionsSection(
                    selectedDay: _selectedDay,
                    advances: dateAdvances,
                    employeeById: employeeById,
                    totalPrepaidPaise: totalPrepaidPaise,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentTeal)),
        error: (err, _) => Center(child: Text('Error loading Leave Report: $err')),
      ),
    );
  }
}

/// Prepaid salary transactions of the selected date only.
class _PrepaidTransactionsSection extends StatelessWidget {
  final DateTime selectedDay;
  final List<Advance> advances;
  final Map<String, Employee> employeeById;
  final int totalPrepaidPaise;

  const _PrepaidTransactionsSection({
    required this.selectedDay,
    required this.advances,
    required this.employeeById,
    required this.totalPrepaidPaise,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = AppDateUtils.formatDisplayDate(selectedDay);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentTealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_outlined, color: AppColors.accentTeal, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PREPAID SALARY GIVEN',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (advances.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                AppStrings.noAdvancesForDate,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            )
          else ...[
            ...advances.map((adv) {
              final emp = employeeById[adv.employeeId];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${emp?.name ?? 'Employee'}  ${emp?.employeeCode ?? ''}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            adv.description?.isNotEmpty == true
                                ? '${adv.description!} • $formattedDate'
                                : 'Salary Advance • $formattedDate',
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      CurrencyFormatter.formatPaise(adv.amountPaise),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentTeal,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total prepaid on this date:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryNavy),
                  ),
                  Text(
                    CurrencyFormatter.formatPaise(totalPrepaidPaise),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
