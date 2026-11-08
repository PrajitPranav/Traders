import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/excel_report_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/employee_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/salary_providers.dart';
import '../../widgets/employee_avatar.dart';

final reportPreviewProvider = FutureProvider.family<
    List<EmployeeMonthlyReportItem>,
    ({int year, int month, String? employeeId})>((ref, arg) async {
  // Watch data mutations so preview refreshes automatically
  ref.watch(employeeListProvider);
  ref.watch(allMonthAttendanceByDateProvider((year: arg.year, month: arg.month)));
  final period = '${arg.year}-${arg.month.toString().padLeft(2, '0')}';
  ref.watch(allPeriodAdvancesProvider(period));

  final service = ref.watch(excelReportServiceProvider);
  return await service.collectReportData(
    year: arg.year,
    month: arg.month,
    employeeId: arg.employeeId,
  );
});

class EmployeeReportScreen extends ConsumerStatefulWidget {
  const EmployeeReportScreen({super.key});

  @override
  ConsumerState<EmployeeReportScreen> createState() =>
      _EmployeeReportScreenState();
}

class _EmployeeReportScreenState extends ConsumerState<EmployeeReportScreen> {
  late int _selectedMonth;
  late int _selectedYear;
  bool _isAllEmployees = true;
  Employee? _selectedEmployee;

  bool _isGenerating = false;
  GeneratedExcelReport? _lastGeneratedReport;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(11, (i) => currentYear - 5 + i);
  }

  Future<void> _pickEmployee(List<Employee> employees) async {
    final chosen = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmployeePickerSheet(
        employees: employees,
        selectedEmployeeId: _selectedEmployee?.id,
      ),
    );

    if (chosen != null) {
      setState(() {
        _selectedEmployee = chosen;
        _lastGeneratedReport = null;
      });
    }
  }

  Future<void> _downloadExcelReport() async {
    if (_isGenerating) return;
    if (!_isAllEmployees && _selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee for the individual report.'),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final service = ref.read(excelReportServiceProvider);
      final generated = await service.generateAndSaveReport(
        year: _selectedYear,
        month: _selectedMonth,
        employeeId: _isAllEmployees ? null : _selectedEmployee?.id,
      );

      if (mounted) {
        setState(() {
          _lastGeneratedReport = generated;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Excel report saved: ${generated.fileName}',
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'SHARE / OPEN',
              textColor: Colors.white,
              onPressed: () {
                service.shareGeneratedReport(generated);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate Excel report: $e'),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListProvider);
    final activeEmployees = employeesAsync.asData?.value ?? [];

    final targetEmployeeId = _isAllEmployees ? null : _selectedEmployee?.id;
    final previewArg = (
      year: _selectedYear,
      month: _selectedMonth,
      employeeId: targetEmployeeId,
    );
    final previewAsync = ref.watch(reportPreviewProvider(previewArg));

    final expectedFileName = ExcelReportService.buildFileName(
      year: _selectedYear,
      month: _selectedMonth,
      employeeCode: _isAllEmployees ? null : _selectedEmployee?.employeeCode,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.employeeReport,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Monthly Attendance & Salary Excel Export',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Report Configuration Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: AppColors.primaryNavy,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'REPORT OPTIONS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1 & 2. Month and Year Selectors
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            prefixIcon:
                                Icon(Icons.calendar_month_outlined, size: 20),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: List.generate(12, (idx) {
                            final m = idx + 1;
                            return DropdownMenuItem(
                              value: m,
                              child: Text(_monthNames[idx]),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedMonth = val;
                                _lastGeneratedReport = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: _availableYears.map((yr) {
                            return DropdownMenuItem(
                              value: yr,
                              child: Text('$yr'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedYear = val;
                                _lastGeneratedReport = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3. Report Type Selector (All Employees vs Individual Employee)
                  const Text(
                    'Report Type',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ReportScopeOptionCard(
                          title: 'All Employees',
                          subtitle: 'Consolidated report',
                          icon: Icons.groups_rounded,
                          isSelected: _isAllEmployees,
                          onTap: () {
                            setState(() {
                              _isAllEmployees = true;
                              _lastGeneratedReport = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ReportScopeOptionCard(
                          title: 'Single Employee',
                          subtitle: 'Individual report',
                          icon: Icons.person_rounded,
                          isSelected: !_isAllEmployees,
                          onTap: () {
                            setState(() {
                              _isAllEmployees = false;
                              if (_selectedEmployee == null &&
                                  activeEmployees.isNotEmpty) {
                                _selectedEmployee = activeEmployees.first;
                              }
                              _lastGeneratedReport = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  // Individual Employee Picker (when Single Employee is chosen)
                  if (!_isAllEmployees) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: activeEmployees.isEmpty
                          ? null
                          : () => _pickEmployee(activeEmployees),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryNavy.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              color: AppColors.primaryNavy,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _selectedEmployee != null
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedEmployee!.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${_selectedEmployee!.employeeCode} • ${_selectedEmployee!.designation ?? "Employee"}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Tap to select an employee...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                            ),
                            const Icon(
                              Icons.search_rounded,
                              color: AppColors.primaryNavy,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Target File Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentTealLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accentTeal.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: AppColors.accentTeal,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Output Excel Workbook (.xlsx) — 4 Sheets:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                expectedFileName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Download Excel Report Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _downloadExcelReport,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 22),
                      label: Text(
                        _isGenerating
                            ? 'Generating Excel Report...'
                            : AppStrings.downloadExcelReport,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Success Download Card (if generated)
            if (_lastGeneratedReport != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successGreenLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.successGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.successGreen,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Excel Report Ready!',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.successGreen,
                                ),
                              ),
                              Text(
                                _lastGeneratedReport!.fileName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_lastGeneratedReport!.filePath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Saved to: ${_lastGeneratedReport!.filePath}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref
                            .read(excelReportServiceProvider)
                            .shareGeneratedReport(_lastGeneratedReport!);
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Open / Share Excel File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Live Report Data Preview
            const Text(
              'REPORT PREVIEW SUMMARY',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),

            previewAsync.when(
              data: (items) {
                if (!_isAllEmployees && _selectedEmployee == null) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Center(
                      child: Text(
                        'Select an employee above to preview their monthly report.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                if (items.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Center(
                      child: Text(
                        'No active employees found for this report.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                final totalSalaryPaise = items.fold<int>(
                  0,
                  (s, e) => s + e.salarySummary.monthlySalaryPaise,
                );
                final totalAdvancePaise = items.fold<int>(
                  0,
                  (s, e) => s + e.salarySummary.totalAdvancesPaise,
                );
                final totalRemainingPaise = items.fold<int>(
                  0,
                  (s, e) => s + e.salarySummary.remainingSalaryPaise,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Aggregate Financial Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth, 1))} • ${items.length} ${items.length == 1 ? "Employee" : "Employees"}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _PreviewMetricItem(
                                  label: 'Monthly Salary',
                                  value: CurrencyFormatter.formatPaise(
                                    totalSalaryPaise,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _PreviewMetricItem(
                                  label: 'Total Prepaid',
                                  value: CurrencyFormatter.formatPaise(
                                    totalAdvancePaise,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _PreviewMetricItem(
                                  label: 'Remaining',
                                  value: CurrencyFormatter.formatPaise(
                                    totalRemainingPaise,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Employee Row Cards
                    ...items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                EmployeeAvatar(
                                  initials: item.employee.initials,
                                  radius: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.employee.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${item.employee.employeeCode} • ${item.employee.designation ?? "Employee"}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Remaining',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.formatPaise(
                                        item.salarySummary.remainingSalaryPaise,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _MiniChip(
                                  label: 'Present: ${item.presentDays}d',
                                  color: AppColors.successGreen,
                                  bg: AppColors.successGreenLight,
                                ),
                                _MiniChip(
                                  label: 'Absent: ${item.absentDays}d',
                                  color: AppColors.dangerRed,
                                  bg: AppColors.dangerRedLight,
                                ),
                                _MiniChip(
                                  label: 'Unmarked: ${item.unmarkedDays}d',
                                  color: AppColors.textSecondary,
                                  bg: AppColors.divider,
                                ),
                                _MiniChip(
                                  label:
                                      'Salary: ${CurrencyFormatter.formatPaise(item.salarySummary.monthlySalaryPaise)}',
                                  color: AppColors.primaryNavy,
                                  bg: AppColors.primaryNavy
                                      .withValues(alpha: 0.08),
                                ),
                                _MiniChip(
                                  label:
                                      'Advance (${item.advances.length}): ${CurrencyFormatter.formatPaise(item.salarySummary.totalAdvancesPaise)}',
                                  color: AppColors.accentTeal,
                                  bg: AppColors.accentTealLight,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.accentTeal),
                ),
              ),
              error: (err, _) => Text('Error loading preview: $err'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportScopeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReportScopeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryNavy.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.cardBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primaryNavy
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewMetricItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _MiniChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Searchable Modal Sheet for selecting an Employee
class _EmployeePickerSheet extends StatefulWidget {
  final List<Employee> employees;
  final String? selectedEmployeeId;

  const _EmployeePickerSheet({
    required this.employees,
    this.selectedEmployeeId,
  });

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.employees.where((e) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase().trim();
      return e.name.toLowerCase().contains(q) ||
          e.employeeCode.toLowerCase().contains(q) ||
          (e.designation?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
          const Text(
            'Select Employee',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search by employee name or code...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No matching employees found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final emp = filtered[i];
                      final isSelected = emp.id == widget.selectedEmployeeId;
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(emp),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryNavy.withValues(alpha: 0.08)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryNavy
                                  : AppColors.cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              EmployeeAvatar(
                                initials: emp.initials,
                                radius: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      emp.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${emp.employeeCode} • ${emp.designation ?? "Employee"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primaryNavy,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

