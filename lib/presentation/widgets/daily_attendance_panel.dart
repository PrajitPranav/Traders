import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../providers/attendance_providers.dart';
import 'confirm_dialog.dart';
import 'employee_avatar.dart';

/// Status label with icon AND text (never color alone).
class AttendanceStatusChip extends StatelessWidget {
  final AttendanceStatus? status;
  final double fontSize;

  const AttendanceStatusChip({super.key, required this.status, this.fontSize = 15});

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData icon;
    final Color fg;
    final Color bg;
    switch (status) {
      case AttendanceStatus.present:
        label = 'PRESENT';
        icon = Icons.check_circle_rounded;
        fg = const Color(0xFF166534);
        bg = AppColors.successGreenLight;
      case AttendanceStatus.absent:
        label = 'ABSENT';
        icon = Icons.cancel_rounded;
        fg = const Color(0xFF991B1B);
        bg = AppColors.dangerRedLight;
      case null:
        label = 'NOT MARKED';
        icon = Icons.remove_circle_outline_rounded;
        fg = AppColors.textSecondary;
        bg = AppColors.divider;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 3, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Opens a large bottom sheet to correct one employee's attendance for one date.
/// Saves immediately to SQLite through the shared attendance repository and
/// reports honestly whether the save worked.
Future<void> showChangeAttendanceSheet(
  BuildContext context,
  WidgetRef ref, {
  required Employee employee,
  required String dateIso,
  required AttendanceStatus? current,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final date = AppDateUtils.parseIsoDateString(dateIso);
  final prettyDate = AppDateUtils.formatDisplayDate(date);

  Future<void> apply(AttendanceStatus status) async {
    final ok = await ref.read(attendanceActionNotifierProvider.notifier).record(
          employeeId: employee.id,
          dateIso: dateIso,
          status: status,
        );
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Saved: ${employee.name} is ${status == AttendanceStatus.present ? 'PRESENT' : 'ABSENT'} on $prettyDate.'
              : 'Could not save attendance. Please try again.',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: ok ? AppColors.successGreen : AppColors.dangerRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      Widget bigButton({
        required String label,
        required IconData icon,
        required Color color,
        required bool isCurrent,
        required VoidCallback onTap,
      }) {
        return SizedBox(
          height: 60,
          child: ElevatedButton.icon(
            key: Key('change_to_${label.toLowerCase().split(' ').first}'),
            onPressed: onTap,
            icon: Icon(isCurrent ? Icons.check_circle : icon, size: 26),
            label: Text(
              isCurrent ? '$label (current)' : label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: isCurrent
                    ? const BorderSide(color: AppColors.primaryNavy, width: 3)
                    : BorderSide.none,
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  EmployeeAvatar(initials: employee.initials, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${employee.employeeCode}  •  $prettyDate',
                          style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Now: ',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  AttendanceStatusChip(status: current, fontSize: 16),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Change attendance to:',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              bigButton(
                label: 'Mark PRESENT',
                icon: Icons.check_rounded,
                color: AppColors.successGreen,
                isCurrent: current == AttendanceStatus.present,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  apply(AttendanceStatus.present);
                },
              ),
              const SizedBox(height: 10),
              bigButton(
                label: 'Mark ABSENT',
                icon: Icons.close_rounded,
                color: AppColors.dangerRed,
                isCurrent: current == AttendanceStatus.absent,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  apply(AttendanceStatus.absent);
                },
              ),
              if (current != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    key: const Key('remove_attendance_button'),
                    onPressed: () async {
                      final confirm = await ConfirmDialog.show(
                        sheetContext,
                        title: 'Remove Attendance',
                        message:
                            'Remove the saved attendance of ${employee.name} for $prettyDate? The date will become Not Marked.',
                        confirmLabel: 'Remove',
                        isDestructive: true,
                      );
                      if (confirm == true) {
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        final ok = await ref
                            .read(attendanceActionNotifierProvider.notifier)
                            .remove(employeeId: employee.id, dateIso: dateIso);
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? '${employee.name} is now NOT MARKED on $prettyDate.'
                                  : 'Could not remove attendance. Please try again.',
                              style: const TextStyle(fontSize: 16),
                            ),
                            backgroundColor: ok ? AppColors.primaryNavy : AppColors.dangerRed,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
                    label: const Text(
                      'Remove record (set Not Marked)',
                      style: TextStyle(fontSize: 16, color: AppColors.dangerRed),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.dangerRed),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Cancel', style: TextStyle(fontSize: 17)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Daily attendance summary + per-employee list for ONE selected date.
/// Used by both the Attendance screen and the Leave Report so they always agree.
/// Reads from the single attendance repository via [allDateAttendanceProvider].
class DailyAttendancePanel extends ConsumerWidget {
  final DateTime date;
  final List<Employee> activeEmployees;

  const DailyAttendancePanel({
    super.key,
    required this.date,
    required this.activeEmployees,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateIso = AppDateUtils.toIsoDateString(date);
    final recordsAsync = ref.watch(allDateAttendanceProvider(dateIso));
    final now = DateTime.now();
    final isFuture = DateTime(date.year, date.month, date.day)
        .isAfter(DateTime(now.year, now.month, now.day));

    return recordsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppColors.accentTeal)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not load attendance: $e', style: const TextStyle(fontSize: 16)),
      ),
      data: (records) {
        final statusByEmployee = {for (final r in records) r.employeeId: r.status};

        final present = <Employee>[];
        final absent = <Employee>[];
        final notMarked = <Employee>[];
        for (final e in activeEmployees) {
          final s = statusByEmployee[e.id];
          if (s == AttendanceStatus.present) {
            present.add(e);
          } else if (s == AttendanceStatus.absent) {
            absent.add(e);
          } else {
            notMarked.add(e);
          }
        }

        Widget tile(String label, int count, Color color, Color bg, IconData icon) {
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color),
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget section(String title, List<Employee> list, AttendanceStatus? status, String emptyText) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Text(
                      '${list.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  Text(emptyText, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary))
                else
                  ...list.map(
                    (emp) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              EmployeeAvatar(initials: emp.initials, radius: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      emp.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      emp.employeeCode,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AttendanceStatusChip(status: status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              key: Key('change_attendance_${emp.employeeCode}'),
                              onPressed: isFuture
                                  ? null
                                  : () => showChangeAttendanceSheet(
                                        context,
                                        ref,
                                        employee: emp,
                                        dateIso: dateIso,
                                        current: status,
                                      ),
                              icon: const Icon(Icons.edit_outlined, size: 22),
                              label: Text(
                                status == null ? 'Mark Attendance' : 'Change Attendance',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                tile('Total Staff', activeEmployees.length, AppColors.primaryNavy,
                    AppColors.primaryNavy.withValues(alpha: 0.08), Icons.groups_outlined),
                const SizedBox(width: 8),
                tile('Present', present.length, AppColors.successGreen, AppColors.successGreenLight,
                    Icons.check_circle_outline),
                const SizedBox(width: 8),
                tile('Absent', absent.length, AppColors.dangerRed, AppColors.dangerRedLight,
                    Icons.cancel_outlined),
                const SizedBox(width: 8),
                tile('Not Marked', notMarked.length, AppColors.textSecondary, AppColors.divider,
                    Icons.help_outline),
              ],
            ),
            if (isFuture) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningAmberLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'This date is in the future. Attendance can only be marked for today or earlier dates.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF92400E)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            section('PRESENT EMPLOYEES', present, AttendanceStatus.present,
                'No employees are marked present on this date.'),
            const SizedBox(height: 12),
            section('ABSENT EMPLOYEES', absent, AttendanceStatus.absent,
                'No employees are marked absent on this date.'),
            const SizedBox(height: 12),
            section('NOT MARKED EMPLOYEES', notMarked, null,
                'Every active employee has been marked for this date.'),
          ],
        );
      },
    );
  }
}

