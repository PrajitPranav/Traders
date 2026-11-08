import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_routes.dart';
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
import '../../widgets/employee_avatar.dart';

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
    _selectedDay = DateTime(initial.year, initial.month, initial.day);
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDay = DateTime(now.year, now.month, now.day);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateIso = AppDateUtils.toIsoDateString(_selectedDay);
    final monthArg = (year: _focusedDay.year, month: _focusedDay.month);

    final employeesAsync = ref.watch(employeeListProvider);
    final monthAttendanceAsync =
        ref.watch(allMonthAttendanceByDateProvider(monthArg));
    final monthAdvancesAsync =
        ref.watch(allMonthAdvancesByDateProvider(monthArg));
    final dateAttendanceAsync =
        ref.watch(allDateAttendanceProvider(selectedDateIso));
    final dateAdvancesAsync =
        ref.watch(allDateAdvancesProvider(selectedDateIso));

    final monthAttendanceMap = monthAttendanceAsync.asData?.value ?? {};
    final monthAdvancesMap = monthAdvancesAsync.asData?.value ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.leaveReport,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Daily Attendance & Prepaid Activity',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: OutlinedButton.icon(
              onPressed: _jumpToToday,
              icon: const Icon(Icons.today_rounded, size: 16),
              label: const Text('Today'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: employeesAsync.when(
        data: (activeEmployees) {
          final employeeById = {
            for (final emp in activeEmployees) emp.id: emp,
          };

          final dateAttendances = dateAttendanceAsync.asData?.value ?? [];
          final attendanceByEmpId = {
            for (final att in dateAttendances) att.employeeId: att,
          };

          final presentEmployees = <Employee>[];
          final absentEmployees = <Employee>[];
          final unmarkedEmployees = <Employee>[];

          for (final emp in activeEmployees) {
            final att = attendanceByEmpId[emp.id];
            if (att == null) {
              unmarkedEmployees.add(emp);
            } else if (att.status == AttendanceStatus.present) {
              presentEmployees.add(emp);
            } else if (att.status == AttendanceStatus.absent) {
              absentEmployees.add(emp);
            }
          }

          final dateAdvances = dateAdvancesAsync.asData?.value ?? [];
          final totalPrepaidPaise = dateAdvances.fold<int>(
            0,
            (sum, item) => sum + item.amountPaise,
          );

          return RefreshIndicator(
            color: AppColors.accentTeal,
            onRefresh: () async {
              ref.invalidate(allMonthAttendanceByDateProvider(monthArg));
              ref.invalidate(allMonthAdvancesByDateProvider(monthArg));
              ref.invalidate(allDateAttendanceProvider(selectedDateIso));
              ref.invalidate(allDateAdvancesProvider(selectedDateIso));
              await ref.read(employeeListProvider.notifier).loadEmployees();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // A. Monthly Calendar Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2035),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: AppColors.primaryNavy,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                        isTodayHighlighted: false,
                      ),
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = DateTime(
                            selectedDay.year,
                            selectedDay.month,
                            selectedDay.day,
                          );
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          return _buildCalendarCell(
                            day,
                            monthAttendanceMap,
                            monthAdvancesMap,
                            isSelected: false,
                          );
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return _buildCalendarCell(
                            day,
                            monthAttendanceMap,
                            monthAdvancesMap,
                            isSelected: true,
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _buildCalendarCell(
                            day,
                            monthAttendanceMap,
                            monthAdvancesMap,
                            isSelected: isSameDay(_selectedDay, day),
                            isToday: true,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Calendar Legend
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _buildLegendItem(AppColors.successGreen, 'Present'),
                        _buildLegendItem(AppColors.dangerRed, 'Absent'),
                        _buildLegendItem(
                          Colors.transparent,
                          'Not Marked',
                          borderColor: AppColors.cardBorder,
                        ),
                        _buildLegendDot(AppColors.advanceDot, 'Prepaid (₹)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Selected Date Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Selected Date: ${AppDateUtils.formatDisplayDate(_selectedDay)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // C. Daily Attendance Summary (4 KPIs)
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryTile(
                          label: 'Total Staff',
                          count: activeEmployees.length,
                          color: AppColors.primaryNavy,
                          bgColor: AppColors.primaryNavy.withValues(alpha: 0.08),
                          icon: Icons.groups_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryTile(
                          label: 'Present',
                          count: presentEmployees.length,
                          color: AppColors.successGreen,
                          bgColor: AppColors.successGreenLight,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryTile(
                          label: 'Absent',
                          count: absentEmployees.length,
                          color: AppColors.dangerRed,
                          bgColor: AppColors.dangerRedLight,
                          icon: Icons.cancel_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryTile(
                          label: 'Not Marked',
                          count: unmarkedEmployees.length,
                          color: AppColors.textSecondary,
                          bgColor: AppColors.divider,
                          icon: Icons.help_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // B. Daily Attendance Lists (Present, Absent, Not Marked)
                  _AttendanceCategorySection(
                    title: 'PRESENT EMPLOYEES',
                    count: presentEmployees.length,
                    employees: presentEmployees,
                    statusLabel: AppStrings.present,
                    statusColor: AppColors.successGreen,
                    statusBgColor: AppColors.successGreenLight,
                    statusIcon: Icons.check_circle_rounded,
                    emptyText: 'No employees marked present for this date.',
                    selectedDateIso: selectedDateIso,
                  ),
                  const SizedBox(height: 12),

                  _AttendanceCategorySection(
                    title: 'ABSENT EMPLOYEES',
                    count: absentEmployees.length,
                    employees: absentEmployees,
                    statusLabel: AppStrings.absent,
                    statusColor: AppColors.dangerRed,
                    statusBgColor: AppColors.dangerRedLight,
                    statusIcon: Icons.cancel_rounded,
                    emptyText: 'No employees marked absent for this date.',
                    selectedDateIso: selectedDateIso,
                  ),
                  const SizedBox(height: 12),

                  _AttendanceCategorySection(
                    title: 'NOT MARKED EMPLOYEES',
                    count: unmarkedEmployees.length,
                    employees: unmarkedEmployees,
                    statusLabel: AppStrings.notMarked,
                    statusColor: AppColors.textSecondary,
                    statusBgColor: AppColors.divider,
                    statusIcon: Icons.remove_circle_outline,
                    emptyText:
                        'All active employees have been marked for this date.',
                    selectedDateIso: selectedDateIso,
                    allowQuickMark: true,
                  ),
                  const SizedBox(height: 20),

                  // D. Prepaid Transactions Below the Calendar (for Selected Date)
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentTeal),
        ),
        error: (err, _) => Center(
          child: Text('Error loading Leave Report: $err'),
        ),
      ),
    );
  }

  Widget _buildCalendarCell(
    DateTime day,
    Map<String, List<Attendance>> monthAttendanceMap,
    Map<String, List<Advance>> monthAdvancesMap, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    final dateIso = AppDateUtils.toIsoDateString(day);
    final dayAttendances = monthAttendanceMap[dateIso] ?? [];
    final dayAdvances = monthAdvancesMap[dateIso] ?? [];

    final hasPresent =
        dayAttendances.any((a) => a.status == AttendanceStatus.present);
    final hasAbsent =
        dayAttendances.any((a) => a.status == AttendanceStatus.absent);
    final hasAdvances = dayAdvances.isNotEmpty;

    Color cellBg = Colors.transparent;
    Color textColor = AppColors.textPrimary;

    if (hasPresent && !hasAbsent) {
      cellBg = AppColors.successGreen.withValues(alpha: 0.16);
      textColor = AppColors.successGreen;
    } else if (hasAbsent && !hasPresent) {
      cellBg = AppColors.dangerRed.withValues(alpha: 0.16);
      textColor = AppColors.dangerRed;
    } else if (hasPresent && hasAbsent) {
      cellBg = AppColors.successGreen.withValues(alpha: 0.14);
      textColor = AppColors.primaryNavy;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cellBg,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: AppColors.primaryNavy, width: 2)
            : (isToday
                ? Border.all(color: AppColors.accentTeal, width: 1.5)
                : null),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  isSelected || isToday || dayAttendances.isNotEmpty
                      ? FontWeight.w700
                      : FontWeight.w500,
              color: textColor,
            ),
          ),
          // Independent indicators at bottom of cell
          Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPresent && hasAbsent) ...[
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: AppColors.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: AppColors.dangerRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                if (hasAdvances)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: AppColors.advanceDot,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {Color? borderColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color == Colors.transparent
                ? Colors.white
                : color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor ?? color, width: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Attendance Category Card (Present / Absent / Not Marked)
class _AttendanceCategorySection extends ConsumerWidget {
  final String title;
  final int count;
  final List<Employee> employees;
  final String statusLabel;
  final Color statusColor;
  final Color statusBgColor;
  final IconData statusIcon;
  final String emptyText;
  final String selectedDateIso;
  final bool allowQuickMark;

  const _AttendanceCategorySection({
    required this.title,
    required this.count,
    required this.employees,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBgColor,
    required this.statusIcon,
    required this.emptyText,
    required this.selectedDateIso,
    this.allowQuickMark = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          children: [
            if (employees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  emptyText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...employees.map((emp) {
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: InkWell(
                    onTap: () => context.push(
                      AppRoutes.employeeDetailPath(emp.id),
                    ),
                    child: Row(
                      children: [
                        EmployeeAvatar(initials: emp.initials, radius: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emp.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                emp.employeeCode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (allowQuickMark) ...[
                          IconButton(
                            tooltip: AppStrings.markPresent,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.successGreen,
                              size: 22,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(
                                      attendanceActionNotifierProvider.notifier)
                                  .record(
                                    employeeId: emp.id,
                                    dateIso: selectedDateIso,
                                    status: AttendanceStatus.present,
                                  );
                            },
                          ),
                          IconButton(
                            tooltip: AppStrings.markAbsent,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: AppColors.dangerRed,
                              size: 22,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(
                                      attendanceActionNotifierProvider.notifier)
                                  .record(
                                    employeeId: emp.id,
                                    dateIso: selectedDateIso,
                                    status: AttendanceStatus.absent,
                                  );
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// D. Prepaid Transactions Section for the Selected Date
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
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppColors.accentTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PREPAID SALARY GIVEN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      'Selected Date: $formattedDate',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
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
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 28,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppStrings.noAdvancesForDate,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...advances.map((adv) {
              final emp = employeeById[adv.employeeId];
              final empName = emp?.name ?? 'Employee';
              final empCode = emp?.employeeCode ?? '';

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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  empName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (empCode.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryNavy
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    empCode,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adv.description?.isNotEmpty == true
                                ? '${adv.description!} • $formattedDate'
                                : 'Salary Advance • $formattedDate',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      CurrencyFormatter.formatPaise(adv.amountPaise),
                      style: const TextStyle(
                        fontSize: 15,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryNavy.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total prepaid on this date:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatPaise(totalPrepaidPaise),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
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

