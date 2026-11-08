import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/advance.dart';
import '../../../domain/entities/attendance.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/employee_providers.dart';
import '../../providers/salary_providers.dart';
import '../../widgets/daily_attendance_panel.dart';
import '../../widgets/month_calendar.dart';

/// Home > Attendance: monthly calendar, selected-date summary and the
/// "Mark Attendance" bulk workflow.
class AttendanceScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const AttendanceScreen({super.key, this.initialDate});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
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
    final monthArg = (year: _focusedDay.year, month: _focusedDay.month);
    final employeesAsync = ref.watch(employeeListProvider);
    final monthAttendance =
        ref.watch(allMonthAttendanceByDateProvider(monthArg)).asData?.value ?? {};
    final monthAdvances =
        ref.watch(allMonthAdvancesByDateProvider(monthArg)).asData?.value ?? {};

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
        title: const Text(
          'Attendance',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              key: const Key('mark_attendance_button'),
              onPressed: () => context.push(AppRoutes.markAttendance),
              icon: const Icon(Icons.fact_check_rounded, size: 24),
              label: const Text('Mark Attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 52),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: employeesAsync.when(
        data: (activeEmployees) => RefreshIndicator(
          color: AppColors.accentTeal,
          onRefresh: () async {
            ref.invalidate(allMonthAttendanceByDateProvider);
            ref.invalidate(allMonthAdvancesByDateProvider);
            ref.invalidate(allDateAttendanceProvider);
            await ref.read(employeeListProvider.notifier).loadEmployees();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Manage daily employee attendance.',
                    style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                  ),
                ),
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
                Row(
                  children: [
                    const Expanded(child: CalendarLegend()),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const Key('attendance_today_button'),
                        onPressed: _jumpToToday,
                        icon: const Icon(Icons.today_rounded, size: 22),
                        label: const Text('Today'),
                        style: OutlinedButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DailyAttendancePanel(date: _selectedDay, activeEmployees: activeEmployees),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentTeal)),
        error: (err, _) => Center(child: Text('Error loading attendance: $err')),
      ),
    );
  }
}

