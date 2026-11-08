import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/attendance.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/employee_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/employee_avatar.dart';

/// Bulk attendance for ONE date.
///
/// - Date defaults to the real current local date and can be changed.
/// - Existing saved attendance is loaded for the chosen date.
/// - Switch ON = PRESENT, OFF = ABSENT. Employees without a saved record start
///   as NOT MARKED and are never saved until the administrator chooses a status
///   and presses SAVE CHANGES.
/// - Saving is one SQLite transaction (update existing, insert new).
/// - Leaving with unsaved changes asks for confirmation.
class MarkAttendanceScreen extends ConsumerStatefulWidget {
  /// Optional date to open (defaults to today).
  final DateTime? initialDate;

  const MarkAttendanceScreen({super.key, this.initialDate});

  @override
  ConsumerState<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  late DateTime _date;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  /// Saved statuses currently in SQLite for [_date] (missing = Not Marked).
  Map<String, AttendanceStatus> _baseline = {};

  /// What the administrator currently sees on screen.
  Map<String, AttendanceStatus?> _selection = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _date = DateTime(initial.year, initial.month, initial.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDate());
  }

  String get _dateIso => AppDateUtils.toIsoDateString(_date);

  bool get _isDirty {
    for (final entry in _selection.entries) {
      if (entry.value != _baseline[entry.key]) return true;
    }
    return false;
  }

  Future<void> _loadDate() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final records =
          await ref.read(attendanceRepositoryProvider).getAllAttendanceForDate(_dateIso);
      if (!mounted) return;
      setState(() {
        _baseline = {for (final r in records) r.employeeId: r.status};
        _selection = {for (final r in records) r.employeeId: r.status};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load saved attendance: $e';
        _loading = false;
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    final leave = await ConfirmDialog.show(
      context,
      title: 'Unsaved Changes',
      message:
          'You have unsaved attendance changes. Do you want to leave without saving?',
      confirmLabel: 'Discard Changes',
      cancelLabel: 'Continue Editing',
      isDestructive: true,
    );
    return leave == true;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2020),
      lastDate: today, // attendance can only be marked up to today
      helpText: 'SELECT ATTENDANCE DATE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryNavy,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    final newDate = DateTime(picked.year, picked.month, picked.day);
    if (newDate == _date) return;

    if (_isDirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    setState(() => _date = newDate);
    await _loadDate();
  }

  void _setAll(AttendanceStatus status, List<Employee> employees) {
    setState(() {
      for (final e in employees) {
        _selection[e.id] = status;
      }
    });
  }

  void _snack(String message, {required bool success}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 16)),
          backgroundColor: success ? AppColors.successGreen : AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _save(List<Employee> employees) async {
    if (_saving || _loading) return;

    // 1. Validate the selected date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_date.isAfter(today)) {
      _snack('Attendance cannot be marked for a future date.', success: false);
      return;
    }

    // 2. Validate selections: only employees explicitly marked are saved.
    final toSave = <String, AttendanceStatus>{};
    for (final e in employees) {
      final chosen = _selection[e.id];
      if (chosen != null && chosen != _baseline[e.id]) {
        toSave[e.id] = chosen;
      }
    }
    final stillNotMarked = employees.where((e) => _selection[e.id] == null).length;

    if (toSave.isEmpty) {
      _snack(
        stillNotMarked == employees.length
            ? 'Nothing to save yet. Please mark at least one employee Present or Absent.'
            : 'No changes to save.',
        success: false,
      );
      return;
    }

    if (stillNotMarked > 0) {
      final proceed = await ConfirmDialog.show(
        context,
        title: 'Some employees are Not Marked',
        message:
            '$stillNotMarked employee(s) are still NOT MARKED and will stay Not Marked.\n\nSave the other ${toSave.length} change(s)?',
        confirmLabel: 'Save Anyway',
        cancelLabel: 'Continue Editing',
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      // 3-8. Atomic bulk upsert through the shared repository.
      await ref.read(attendanceActionNotifierProvider.notifier).saveBulk(
            dateIso: _dateIso,
            statusByEmployeeId: toSave,
          );
      if (!mounted) return;

      // Saved: baseline now equals what is on screen, so nothing is "unsaved".
      setState(() {
        for (final entry in toSave.entries) {
          _baseline[entry.key] = entry.value;
        }
        _saving = false;
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Attendance saved for ${AppDateUtils.formatDisplayDate(_date)} (${toSave.length} employee${toSave.length == 1 ? '' : 's'}).',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Attendance was NOT saved. Please try again. ($e)', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListProvider);
    final employees = employeesAsync.asData?.value ?? const <Employee>[];

    final presentCount =
        employees.where((e) => _selection[e.id] == AttendanceStatus.present).length;
    final absentCount =
        employees.where((e) => _selection[e.id] == AttendanceStatus.absent).length;
    final notMarkedCount = employees.length - presentCount - absentCount;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscard();
        if (shouldDiscard && mounted) {
          if (!context.mounted) return;
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 68,
          title: const Text(
            'Mark Attendance',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                key: const Key('save_attendance_button'),
                onPressed: (_saving || _loading) ? null : () => _save(employees),
                icon: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 26),
                label: Text(_saving ? 'SAVING...' : 'SAVE CHANGES'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ),
        body: _buildBody(employeesAsync, employees, presentCount, absentCount, notMarkedCount),
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<Employee>> employeesAsync,
    List<Employee> employees,
    int presentCount,
    int absentCount,
    int notMarkedCount,
  ) {
    if (_loading || employeesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentTeal));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, style: const TextStyle(fontSize: 17), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadDate, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // A. Date selection
        const Text(
          'Attendance Date',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        InkWell(
          key: const Key('attendance_date_button'),
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryNavy, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 30, color: AppColors.primaryNavy),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppDateUtils.formatDisplayDate(_date),
                    key: const Key('attendance_date_text'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Text(
                  'Change',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accentTeal),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // How the switch works
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.infoBlueLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Switch ON = PRESENT.  Switch OFF = ABSENT.\n'
            'Employees showing NOT MARKED have no saved attendance yet. '
            'Check every employee, then press SAVE CHANGES.',
            style: TextStyle(fontSize: 16, height: 1.4, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 12),

        // Quick actions (explicit administrator choice)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  key: const Key('set_all_present_button'),
                  onPressed: employees.isEmpty
                      ? null
                      : () => _setAll(AttendanceStatus.present, employees),
                  icon: const Icon(Icons.check_circle_outline, color: AppColors.successGreen),
                  label: const Text('All PRESENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  key: const Key('set_all_absent_button'),
                  onPressed: employees.isEmpty
                      ? null
                      : () => _setAll(AttendanceStatus.absent, employees),
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.dangerRed),
                  label: const Text('All ABSENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Live counts
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text('Present: $presentCount',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
            Text('Absent: $absentCount',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
            Text('Not Marked: $notMarkedCount',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),

        if (employees.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Text(
              'There are no active employees yet. Add a member first.',
              style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
            ),
          )
        else
          ...employees.map(_buildEmployeeRow),
      ],
    );
  }

  Widget _buildEmployeeRow(Employee emp) {
    final status = _selection[emp.id];
    final isPresent = status == AttendanceStatus.present;
    final Color trackColor = status == null
        ? AppColors.textMuted
        : (isPresent ? AppColors.successGreen : AppColors.dangerRed);
    final String label = status == null ? 'NOT MARKED' : (isPresent ? 'PRESENT' : 'ABSENT');
    final Color labelColor = status == null
        ? AppColors.textSecondary
        : (isPresent ? const Color(0xFF166534) : const Color(0xFF991B1B));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == null ? AppColors.cardBorder : trackColor.withValues(alpha: 0.6),
          width: status == null ? 1 : 2,
        ),
      ),
      child: Row(
        children: [
          EmployeeAvatar(initials: emp.initials, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                Text(
                  emp.employeeCode,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  key: Key('attendance_label_${emp.employeeCode}'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: labelColor),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 1.4,
                child: Switch(
                  key: Key('attendance_switch_${emp.employeeCode}'),
                  value: isPresent,
                  onChanged: (v) => setState(() {
                    _selection[emp.id] = v ? AttendanceStatus.present : AttendanceStatus.absent;
                  }),
                  thumbColor: const WidgetStatePropertyAll(Colors.white),
                  trackColor: WidgetStatePropertyAll(trackColor),
                  trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                  thumbIcon: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? const Icon(Icons.check, color: AppColors.successGreen)
                        : Icon(Icons.close, color: status == null ? AppColors.textMuted : AppColors.dangerRed);
                  }),
                ),
              ),
              if (status == null)
                TextButton(
                  key: Key('mark_absent_${emp.employeeCode}'),
                  onPressed: () => setState(() => _selection[emp.id] = AttendanceStatus.absent),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
                  child: const Text('Mark ABSENT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

