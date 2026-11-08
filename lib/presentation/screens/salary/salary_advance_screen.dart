import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/employee_providers.dart';
import '../../providers/salary_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/employee_avatar.dart';

class SalaryAdvanceScreen extends ConsumerStatefulWidget {
  const SalaryAdvanceScreen({super.key});

  @override
  ConsumerState<SalaryAdvanceScreen> createState() =>
      _SalaryAdvanceScreenState();
}

class _SalaryAdvanceScreenState extends ConsumerState<SalaryAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  Employee? _selectedEmployee;
  late DateTime _transactionDate;
  late String _salaryPeriod;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _transactionDate = DateTime.now();
    _salaryPeriod = AppDateUtils.toSalaryPeriod(_transactionDate);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _changeSalaryPeriod(int monthDelta) {
    final parts = _salaryPeriod.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final nextDate = DateTime(year, month + monthDelta, 1);
    setState(() {
      _salaryPeriod = AppDateUtils.toSalaryPeriod(nextDate);
    });
  }

  Future<void> _selectTransactionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
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

    if (picked != null) {
      setState(() {
        _transactionDate = picked;
        // Automatically align salary period to the picked date's month
        _salaryPeriod = AppDateUtils.toSalaryPeriod(picked);
      });
    }
  }

  Future<void> _openEmployeeSelector(List<Employee> employees) async {
    final selected = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchableEmployeeSheet(
        employees: employees,
        selectedEmployeeId: _selectedEmployee?.id,
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedEmployee = selected;
      });
    }
  }

  Future<void> _handleSaveAdvance({
    required int monthlySalaryPaise,
    required int alreadyReceivedPaise,
    required int remainingEligiblePaise,
  }) async {
    if (_isSubmitting) return;

    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee first.'),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final newAdvancePaise =
        CurrencyFormatter.parseInputToPaise(_amountController.text);

    if (newAdvancePaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Advance amount must be greater than zero.'),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (monthlySalaryPaise > 0 && newAdvancePaise > remainingEligiblePaise) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rejected: Advance (${CurrencyFormatter.formatPaise(newAdvancePaise)}) cannot exceed remaining eligible salary of ${CurrencyFormatter.formatPaise(remainingEligiblePaise)} for ${AppDateUtils.formatPeriodDisplay(_salaryPeriod)}.',
          ),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final afterTotalAdvancesPaise = alreadyReceivedPaise + newAdvancePaise;
    final afterRemainingPaise = remainingEligiblePaise - newAdvancePaise;

    // Ask for confirmation before final saving
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Confirm Salary Advance',
      message:
          'Record prepaid advance of ${CurrencyFormatter.formatPaise(newAdvancePaise)} for ${_selectedEmployee!.name} (${_selectedEmployee!.employeeCode})?\n\n'
          'Salary Period: ${AppDateUtils.formatPeriodDisplay(_salaryPeriod)}\n'
          'Total Advances After Saving: ${CurrencyFormatter.formatPaise(afterTotalAdvancesPaise)}\n'
          'Remaining Salary Balance: ${CurrencyFormatter.formatPaise(afterRemainingPaise)}',
      confirmLabel: 'Confirm & Save',
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dateIso = AppDateUtils.toIsoDateString(_transactionDate);

      await ref.read(salaryActionNotifierProvider.notifier).recordAdvance(
            employeeId: _selectedEmployee!.id,
            amountPaise: newAdvancePaise,
            transactionDateIso: dateIso,
            salaryPeriod: _salaryPeriod,
            description: _descriptionController.text.trim(),
          );

      if (mounted) {
        _amountController.clear();
        _descriptionController.clear();
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved ${CurrencyFormatter.formatPaise(newAdvancePaise)} advance for ${_selectedEmployee!.name}. Remaining salary: ${CurrencyFormatter.formatPaise(afterRemainingPaise)}.',
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save advance: $e'),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListProvider);
    final activeEmployees = employeesAsync.asData?.value ?? [];

    // Ensure _selectedEmployee stays valid if activeEmployees loaded
    if (_selectedEmployee != null && activeEmployees.isNotEmpty) {
      final match = activeEmployees
          .where((e) => e.id == _selectedEmployee!.id)
          .firstOrNull;
      if (match != null) {
        _selectedEmployee = match;
      }
    }

    final enteredAdvancePaise =
        CurrencyFormatter.parseInputToPaise(_amountController.text);

    final summaryAsync = _selectedEmployee != null
        ? ref.watch(
            employeePeriodSalarySummaryProvider((
              employeeId: _selectedEmployee!.id,
              salaryPeriod: _salaryPeriod,
            )),
          )
        : null;

    final periodAdvancesAsync =
        ref.watch(allPeriodAdvancesProvider(_salaryPeriod));

    final employeeById = {
      for (final emp in activeEmployees) emp.id: emp,
    };

    final monthlySalaryPaise =
        summaryAsync?.asData?.value.monthlySalaryPaise ?? 0;
    final alreadyReceivedPaise =
        summaryAsync?.asData?.value.totalAdvancesPaise ?? 0;
    final remainingEligiblePaise =
        summaryAsync?.asData?.value.remainingSalaryPaise ?? 0;

    final projectedTotalAdvancesPaise =
        alreadyReceivedPaise + enteredAdvancePaise;
    final projectedRemainingPaise =
        remainingEligiblePaise - enteredAdvancePaise;
    final exceedsRemaining = monthlySalaryPaise > 0 &&
        enteredAdvancePaise > remainingEligiblePaise;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.salaryAndAdvance,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Record & Manage Prepaid Salary Advances',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Record Salary Advance Form Card
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
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RECORD PREPAID SALARY ADVANCE',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryNavy,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Deducts from the employee\'s monthly salary for the selected period',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. Select Employee (Searchable Selector)
                    const Text(
                      '1. Select Employee *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      key: const Key('select_employee_button'),
                      onTap: activeEmployees.isEmpty
                          ? null
                          : () => _openEmployeeSelector(activeEmployees),
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
                            color: _selectedEmployee != null
                                ? AppColors.primaryNavy
                                : AppColors.cardBorder,
                            width: _selectedEmployee != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedEmployee != null) ...[
                              EmployeeAvatar(
                                initials: _selectedEmployee!.initials,
                                radius: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const Icon(
                                Icons.person_search_outlined,
                                color: AppColors.primaryNavy,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  activeEmployees.isEmpty
                                      ? 'No active employees available'
                                      : 'Tap to search & select employee...',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                            const Icon(
                              Icons.arrow_drop_down_circle_outlined,
                              color: AppColors.primaryNavy,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Salary Period Selector
                    const Text(
                      '2. Salary Period *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: AppColors.primaryNavy,
                            ),
                            onPressed: () => _changeSalaryPeriod(-1),
                            tooltip: 'Previous Period',
                          ),
                          Column(
                            children: [
                              Text(
                                AppDateUtils.formatPeriodDisplay(_salaryPeriod),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              Text(
                                'Period: $_salaryPeriod',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: AppColors.primaryNavy,
                            ),
                            onPressed: () => _changeSalaryPeriod(1),
                            tooltip: 'Next Period',
                          ),
                        ],
                      ),
                    ),

                    // Live Financial Balance Preview for Selected Employee
                    if (_selectedEmployee != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: exceedsRemaining
                                ? AppColors.dangerRed
                                : AppColors.primaryNavy.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Monthly Salary:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatPaise(
                                    monthlySalaryPaise,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Already Received:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatPaise(
                                    alreadyReceivedPaise,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentTeal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Remaining Eligible Amount:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatPaise(
                                    remainingEligiblePaise,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.successGreen,
                                  ),
                                ),
                              ],
                            ),
                            if (enteredAdvancePaise > 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'New Advance:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatPaise(
                                      enteredAdvancePaise,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: exceedsRemaining
                                          ? AppColors.dangerRed
                                          : AppColors.accentTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'After Saving — Total Advances:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatPaise(
                                      projectedTotalAdvancesPaise,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'After Saving — Remaining Salary:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatPaise(
                                      projectedRemainingPaise,
                                    ),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: exceedsRemaining
                                          ? AppColors.dangerRed
                                          : AppColors.primaryNavy,
                                    ),
                                  ),
                                ],
                              ),
                              if (exceedsRemaining) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Advance exceeds remaining eligible amount (${CurrencyFormatter.formatPaise(remainingEligiblePaise)}).',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dangerRed,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 2. Advance Amount Field
                    const Text(
                      '3. Advance Amount (₹) *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('advance_amount_field'),
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Enter amount in rupees, e.g. 3000',
                        prefixIcon: Icon(Icons.currency_rupee, size: 20),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter the advance amount';
                        }
                        final parsed = int.tryParse(val.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Amount must be greater than zero';
                        }
                        final paise = CurrencyFormatter.rupeesToPaise(parsed);
                        if (_selectedEmployee != null &&
                            monthlySalaryPaise > 0 &&
                            paise > remainingEligiblePaise) {
                          return 'Cannot exceed remaining salary (${CurrencyFormatter.formatPaise(remainingEligiblePaise)})';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 3. Transaction Date Picker
                    const Text(
                      '4. Transaction Date *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectTransactionDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.cardBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 20,
                              color: AppColors.primaryNavy,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppDateUtils.formatDisplayDate(_transactionDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Optional Description
                    const Text(
                      '5. Description (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('advance_description_field'),
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Festival advance, Medical expense',
                        prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Submit Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        key: const Key('save_advance_button'),
                        onPressed: _isSubmitting
                            ? null
                            : () => _handleSaveAdvance(
                                  monthlySalaryPaise: monthlySalaryPaise,
                                  alreadyReceivedPaise: alreadyReceivedPaise,
                                  remainingEligiblePaise:
                                      remainingEligiblePaise,
                                ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(
                          _isSubmitting
                              ? 'Saving Advance...'
                              : 'Confirm & Save Advance',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
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
              const SizedBox(height: 24),

              // Period Advance Transaction History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ADVANCES IN ${AppDateUtils.formatPeriodDisplay(_salaryPeriod).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  periodAdvancesAsync.maybeWhen(
                    data: (list) => Text(
                      '${list.length} records',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              periodAdvancesAsync.when(
                data: (advances) {
                  if (advances.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Center(
                        child: Text(
                          AppStrings.noAdvancesForPeriod,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }

                  // Show newest first
                  final reversed = advances.reversed.toList();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reversed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final adv = reversed[idx];
                      final emp = employeeById[adv.employeeId];
                      final empName = emp?.name ?? 'Employee';
                      final empCode = emp?.employeeCode ?? '';
                      final formattedDate = AppDateUtils.formatDisplayDate(
                        AppDateUtils.parseIsoDateString(adv.transactionDate),
                      );

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            EmployeeAvatar(
                              initials: emp?.initials ?? 'EM',
                              radius: 20,
                            ),
                            const SizedBox(width: 12),
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
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryNavy
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(5),
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
                                  const SizedBox(height: 3),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatPaise(
                                    adv.amountPaise,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentTeal,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final confirm = await ConfirmDialog.show(
                                      context,
                                      title: 'Delete Advance Record',
                                      message:
                                          'Are you sure you want to delete this advance of ${CurrencyFormatter.formatPaise(adv.amountPaise)} for $empName dated $formattedDate?',
                                      confirmLabel: 'Delete',
                                      isDestructive: true,
                                    );
                                    if (confirm == true) {
                                      await ref
                                          .read(
                                            salaryActionNotifierProvider
                                                .notifier,
                                          )
                                          .deleteAdvance(
                                            advanceId: adv.id,
                                            employeeId: adv.employeeId,
                                          );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        CircularProgressIndicator(color: AppColors.accentTeal),
                  ),
                ),
                error: (e, _) => Text('Error loading advances: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searchable Bottom Sheet for selecting an employee by name or code
class _SearchableEmployeeSheet extends StatefulWidget {
  final List<Employee> employees;
  final String? selectedEmployeeId;

  const _SearchableEmployeeSheet({
    required this.employees,
    this.selectedEmployeeId,
  });

  @override
  State<_SearchableEmployeeSheet> createState() =>
      _SearchableEmployeeSheetState();
}

class _SearchableEmployeeSheetState extends State<_SearchableEmployeeSheet> {
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

