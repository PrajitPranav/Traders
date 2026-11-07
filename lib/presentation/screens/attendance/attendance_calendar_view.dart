import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/advance.dart';
import '../../../domain/entities/attendance.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/salary_providers.dart';
import '../../widgets/confirm_dialog.dart';

class AttendanceCalendarView extends ConsumerStatefulWidget {
  final String employeeId;

  const AttendanceCalendarView({super.key, required this.employeeId});

  @override
  ConsumerState<AttendanceCalendarView> createState() => _AttendanceCalendarViewState();
}

class _AttendanceCalendarViewState extends ConsumerState<AttendanceCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  void _onDaySelected(
    BuildContext context,
    DateTime selectedDay,
    Map<String, AttendanceStatus> attendanceMap,
    Map<String, List<Advance>> advancesMap,
  ) {
    setState(() {
      _selectedDay = selectedDay;
    });

    final dateIso = AppDateUtils.toIsoDateString(selectedDay);
    final status = attendanceMap[dateIso];
    final advances = advancesMap[dateIso] ?? [];

    _showDayDetailsSheet(context, selectedDay, dateIso, status, advances);
  }

  void _showDayDetailsSheet(
    BuildContext context,
    DateTime day,
    String dateIso,
    AttendanceStatus? currentStatus,
    List<Advance> advances,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();
            final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppDateUtils.formatDisplayDate(day),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (currentStatus != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: currentStatus == AttendanceStatus.present
                                ? AppColors.successGreenLight
                                : AppColors.dangerRedLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            currentStatus == AttendanceStatus.present
                                ? AppStrings.present
                                : AppStrings.absent,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: currentStatus == AttendanceStatus.present
                                  ? AppColors.successGreen
                                  : AppColors.dangerRed,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            AppStrings.notMarked,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Attendance Actions (Present, Absent, Remove)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isFuture
                              ? null
                              : () async {
                                  Navigator.of(ctx).pop();
                                  await ref.read(attendanceActionNotifierProvider.notifier).record(
                                        employeeId: widget.employeeId,
                                        dateIso: dateIso,
                                        status: AttendanceStatus.present,
                                      );
                                },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text(AppStrings.markPresent),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isFuture
                              ? null
                              : () async {
                                  Navigator.of(ctx).pop();
                                  await ref.read(attendanceActionNotifierProvider.notifier).record(
                                        employeeId: widget.employeeId,
                                        dateIso: dateIso,
                                        status: AttendanceStatus.absent,
                                      );
                                },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text(AppStrings.markAbsent),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dangerRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (currentStatus != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await ConfirmDialog.show(
                          context,
                          title: 'Remove Attendance',
                          message: 'Are you sure you want to revert attendance for ${AppDateUtils.formatDisplayDate(day)} to Not Marked?',
                          confirmLabel: 'Remove',
                          isDestructive: true,
                        );
                        if (confirm == true) {
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          await ref.read(attendanceActionNotifierProvider.notifier).remove(
                                employeeId: widget.employeeId,
                                dateIso: dateIso,
                              );
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.dangerRed),
                      label: const Text(
                        AppStrings.removeAttendance,
                        style: TextStyle(color: AppColors.dangerRed),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.dangerRedLight),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ],

                  // Advances on this day, if any
                  if (advances.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 18, color: AppColors.accentTeal),
                        const SizedBox(width: 8),
                        Text(
                          'Prepaid Advances on this Day (${advances.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...advances.map(
                      (adv) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentTealLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              adv.description ?? 'Advance',
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            ),
                            Text(
                              CurrencyFormatter.formatPaise(adv.amountPaise),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceMapAsync = ref.watch(employeeAttendanceMapProvider(widget.employeeId));
    final advancesMapAsync = ref.watch(employeeMonthAdvancesMapProvider(widget.employeeId));
    final countsAsync = ref.watch(employeeAttendanceCountsProvider(widget.employeeId));

    return attendanceMapAsync.when(
      data: (attendanceMap) {
        final advancesMap = advancesMapAsync.asData?.value ?? {};

        // Calculate unmarked days up to today in the focused month
        final now = DateTime.now();
        final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
        final isCurrentMonth = _focusedDay.year == now.year && _focusedDay.month == now.month;
        final elapsedDays = isCurrentMonth ? now.day : (_focusedDay.isBefore(now) ? daysInMonth : 0);

        final presentCount = countsAsync.asData?.value['present'] ?? 0;
        final absentCount = countsAsync.asData?.value['absent'] ?? 0;
        final markedTotal = presentCount + absentCount;
        final unmarkedCount = (elapsedDays - markedTotal).clamp(0, daysInMonth);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Monthly Summary KPI Row
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Present',
                      '$presentCount days',
                      AppColors.successGreen,
                      AppColors.successGreenLight,
                      Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      'Absent',
                      '$absentCount days',
                      AppColors.dangerRed,
                      AppColors.dangerRedLight,
                      Icons.cancel_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      'Unmarked',
                      '$unmarkedCount days',
                      AppColors.textSecondary,
                      AppColors.divider,
                      Icons.help_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Calendar Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2035),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.primaryNavy),
                    rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.primaryNavy),
                  ),
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                    isTodayHighlighted: false,
                  ),
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                    ref.read(selectedAttendanceMonthProvider.notifier).state = DateTime(
                      focusedDay.year,
                      focusedDay.month,
                      1,
                    );
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                    _onDaySelected(context, selectedDay, attendanceMap, advancesMap);
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildCalendarCell(day, attendanceMap, advancesMap, isSelected: false);
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return _buildCalendarCell(day, attendanceMap, advancesMap, isSelected: true);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return _buildCalendarCell(day, attendanceMap, advancesMap, isSelected: isSameDay(_selectedDay, day), isToday: true);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Calendar Legend
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(AppColors.successGreen, 'Present'),
                    _buildLegendItem(AppColors.dangerRed, 'Absent'),
                    _buildLegendItem(Colors.transparent, 'Not Marked', borderColor: AppColors.cardBorder),
                    _buildLegendDot(AppColors.advanceDot, 'Advance (₹)'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.accentTeal),
        ),
      ),
      error: (e, _) => Center(
        child: Text('Error loading calendar: $e'),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCell(
    DateTime day,
    Map<String, AttendanceStatus> attendanceMap,
    Map<String, List<Advance>> advancesMap, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    final dateIso = AppDateUtils.toIsoDateString(day);
    final status = attendanceMap[dateIso];
    final hasAdvances = advancesMap.containsKey(dateIso) && advancesMap[dateIso]!.isNotEmpty;

    Color cellBg = Colors.transparent;
    Color textColor = AppColors.textPrimary;

    if (status == AttendanceStatus.present) {
      cellBg = AppColors.successGreen.withValues(alpha: 0.16);
      textColor = AppColors.successGreen;
    } else if (status == AttendanceStatus.absent) {
      cellBg = AppColors.dangerRed.withValues(alpha: 0.16);
      textColor = AppColors.dangerRed;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cellBg,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: AppColors.primaryNavy, width: 2)
            : (isToday ? Border.all(color: AppColors.accentTeal, width: 1.5) : null),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected || isToday || status != null ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
          // Advance financial dot indicator
          if (hasAdvances)
            Positioned(
              bottom: 4,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.advanceDot,
                  shape: BoxShape.circle,
                ),
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
            color: color == Colors.transparent ? Colors.white : color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor ?? color, width: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

