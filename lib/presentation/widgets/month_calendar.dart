import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/app_colors.dart';

/// Independent indicators for one calendar day.
/// Attendance and prepaid indicators never overwrite each other.
class DayMarks {
  final bool present;
  final bool absent;
  final bool advance;

  const DayMarks({this.present = false, this.absent = false, this.advance = false});

  static const none = DayMarks();
}

/// Shared monthly calendar used by Attendance, Leave Report and the
/// Employee Profile so they always look and align identically.
///
/// - Every cell has a fixed row height and equal column width.
/// - The date number is centered both horizontally and vertically.
/// - The selected date gets a large solid navy circle that always fits its cell.
/// - Previous/next month dates are shown muted and cannot be mistaken for
///   dates of the visible month.
class MonthCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final DayMarks Function(DateTime day) marksFor;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  const MonthCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.marksFor,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  static const double rowHeight = 56;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: TableCalendar(
        firstDay: DateTime(2020),
        lastDay: DateTime(2035),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => selectedDay != null && isSameDay(selectedDay, day),
        startingDayOfWeek: StartingDayOfWeek.monday,
        rowHeight: rowHeight,
        daysOfWeekHeight: 36,
        availableGestures: AvailableGestures.horizontalSwipe,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          headerPadding: EdgeInsets.symmetric(vertical: 8),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          leftChevronIcon: Icon(Icons.chevron_left_rounded, size: 34, color: AppColors.primaryNavy),
          rightChevronIcon: Icon(Icons.chevron_right_rounded, size: 34, color: AppColors.primaryNavy),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
          weekendStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: true,
          isTodayHighlighted: false,
          cellMargin: EdgeInsets.zero,
          cellPadding: EdgeInsets.zero,
        ),
        onPageChanged: onPageChanged,
        onDaySelected: onDaySelected,
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focused) => CalendarDayCell(
            day: day,
            marks: marksFor(day),
            isSelected: false,
            isToday: false,
          ),
          selectedBuilder: (context, day, focused) => CalendarDayCell(
            day: day,
            marks: marksFor(day),
            isSelected: true,
            isToday: isSameDay(day, DateTime.now()),
          ),
          todayBuilder: (context, day, focused) => CalendarDayCell(
            day: day,
            marks: marksFor(day),
            isSelected: false,
            isToday: true,
          ),
          outsideBuilder: (context, day, focused) => CalendarDayCell(
            day: day,
            marks: DayMarks.none,
            isSelected: false,
            isToday: false,
            isOutside: true,
          ),
        ),
      ),
    );
  }
}

/// A single date cell. Public so it can be verified in tests.
class CalendarDayCell extends StatelessWidget {
  final DateTime day;
  final DayMarks marks;
  final bool isSelected;
  final bool isToday;
  final bool isOutside;

  const CalendarDayCell({
    super.key,
    required this.day,
    required this.marks,
    required this.isSelected,
    required this.isToday,
    this.isOutside = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Highlight always fits inside the cell (no overflow on small screens)
        // but stays large: 38-48 logical pixels.
        final available = math.min(
          constraints.hasBoundedWidth ? constraints.maxWidth : 48.0,
          constraints.hasBoundedHeight ? constraints.maxHeight : 48.0,
        );
        final size = (available - 4).clamp(38.0, 48.0).toDouble();

        Color fill = Colors.transparent;
        Color textColor = AppColors.textPrimary;
        FontWeight weight = FontWeight.w600;
        Border? border;

        if (isOutside) {
          textColor = AppColors.textMuted;
          weight = FontWeight.w400;
        } else if (isSelected) {
          fill = AppColors.primaryNavy;
          textColor = Colors.white;
          weight = FontWeight.w800;
        } else {
          if (marks.present && !marks.absent) {
            fill = AppColors.successGreen.withValues(alpha: 0.18);
            textColor = const Color(0xFF166534);
            weight = FontWeight.w800;
          } else if (marks.absent && !marks.present) {
            fill = AppColors.dangerRed.withValues(alpha: 0.16);
            textColor = const Color(0xFF991B1B);
            weight = FontWeight.w800;
          } else if (marks.present && marks.absent) {
            fill = AppColors.infoBlueLight;
            weight = FontWeight.w800;
          }
          if (isToday) {
            border = Border.all(color: AppColors.accentTeal, width: 2);
            weight = FontWeight.w800;
          }
        }

        final dots = <Widget>[];
        if (!isOutside) {
          if (marks.present) dots.add(_dot(AppColors.successGreen));
          if (marks.absent) dots.add(_dot(AppColors.dangerRed));
          if (marks.advance) dots.add(_dot(AppColors.advanceDot));
        }

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  key: isSelected ? const Key('selected_day_highlight') : null,
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: border,
                  ),
                  child: Text(
                    '${day.day}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.0,
                      fontWeight: weight,
                      color: textColor,
                    ),
                  ),
                ),
                if (dots.isNotEmpty)
                  Positioned(
                    bottom: 3,
                    child: Row(mainAxisSize: MainAxisSize.min, children: dots),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }
}

/// Text legend shown under every calendar (never relies on color alone).
class CalendarLegend extends StatelessWidget {
  final bool showPrepaid;

  const CalendarLegend({super.key, this.showPrepaid = true});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          item(AppColors.successGreen, 'Present'),
          item(AppColors.dangerRed, 'Absent'),
          item(AppColors.textMuted, 'Not Marked'),
          if (showPrepaid) item(AppColors.advanceDot, 'Prepaid (₹)'),
        ],
      ),
    );
  }
}

