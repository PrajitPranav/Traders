import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/advance.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/entities/salary_payment.dart';
import '../../providers/employee_providers.dart';
import '../../providers/salary_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/employee_avatar.dart';
import '../../widgets/employee_picker_sheet.dart';

enum SalaryTransactionType { regularPayment, advance }

/// Salary Management: record a REGULAR salary payment or a salary ADVANCE
/// (prepaid) for an employee, see the balance before saving, and review the
/// full financial history. The two transaction types are stored separately
/// (salary_payments vs advances) and are never mixed up.
class SalaryManagementScreen extends ConsumerStatefulWidget {
  /// Optionally pre-select an employee (e.g. when opened from a profile).
  final String? initialEmployeeId;

  const SalaryManagementScreen({super.key, this.initialEmployeeId});

  @override
  ConsumerState<SalaryManagementScreen> createState() => _SalaryManagementScreenState();
}

class _SalaryManagementScreenState extends ConsumerState<SalaryManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  Employee? _employee;
  SalaryTransactionType? _type;
  late DateTime _date;
  late String _period;
  bool _saving = false;
  bool _initialEmployeeApplied = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _period = AppDateUtils.toSalaryPeriod(_date);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _changePeriod(int delta) {
    final parts = _period.split('-');
    final next = DateTime(int.parse(parts[0]), int.parse(parts[1]) + delta, 1);
    setState(() => _period = AppDateUtils.toSalaryPeriod(next));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryNavy,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _period = AppDateUtils.toSalaryPeriod(picked);
      });
    }
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

  String _errorText(Object e) => e is StateError ? e.message : '$e';

  Future<void> _record(FinancialOverview? overview) async {
    if (_saving) return;

    if (_employee == null) {
      _snack('Please select an employee first.', success: false);
      return;
    }
    if (_type == null) {
      _snack('Please choose what you are recording: Regular Salary or Salary Advance.', success: false);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (overview == null) {
      _snack('Please wait while the salary details load.', success: false);
      return;
    }

    final amountPaise = CurrencyFormatter.parseInputToPaise(_amountController.text);
    final remaining = overview.remainingPayablePaise;
    final isAdvance = _type == SalaryTransactionType.advance;
    final typeLabel = isAdvance ? 'SALARY ADVANCE (prepaid)' : 'REGULAR SALARY PAYMENT';

    if (overview.monthlySalaryPaise <= 0) {
      _snack('This employee has no monthly salary set. Set the salary first.', success: false);
      return;
    }
    if (amountPaise > remaining) {
      _snack(
        'Amount is more than the remaining ${CurrencyFormatter.formatPaise(remaining < 0 ? 0 : remaining)} for ${AppDateUtils.formatPeriodDisplay(_period)}.',
        success: false,
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Please confirm',
      message:
          'Type: $typeLabel\n'
          'Employee: ${_employee!.name} (${_employee!.employeeCode})\n'
          'Amount: ${CurrencyFormatter.formatPaise(amountPaise)}\n'
          'Date: ${AppDateUtils.formatDisplayDate(_date)}\n'
          'Salary period: ${AppDateUtils.formatPeriodDisplay(_period)}\n\n'
          'Remaining after this: ${CurrencyFormatter.formatPaise(remaining - amountPaise)}',
      confirmLabel: 'Yes, Record',
      cancelLabel: 'Go Back',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final notifier = ref.read(salaryActionNotifierProvider.notifier);
      final dateIso = AppDateUtils.toIsoDateString(_date);
      if (isAdvance) {
        await notifier.recordAdvance(
          employeeId: _employee!.id,
          amountPaise: amountPaise,
          transactionDateIso: dateIso,
          salaryPeriod: _period,
          description: _descriptionController.text.trim(),
        );
      } else {
        await notifier.recordPayment(
          employeeId: _employee!.id,
          amountPaise: amountPaise,
          paymentDateIso: dateIso,
          salaryPeriod: _period,
          description: _descriptionController.text.trim(),
        );
      }
      if (!mounted) return;
      _amountController.clear();
      _descriptionController.clear();
      setState(() => _saving = false);
      _snack(
        'Saved: ${isAdvance ? 'Advance' : 'Salary payment'} of ${CurrencyFormatter.formatPaise(amountPaise)} for ${_employee!.name}.',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('NOT saved: ${_errorText(e)}', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListProvider);
    final employees = employeesAsync.asData?.value ?? const <Employee>[];

    if (!_initialEmployeeApplied && widget.initialEmployeeId != null && employees.isNotEmpty) {
      _initialEmployeeApplied = true;
      for (final e in employees) {
        if (e.id == widget.initialEmployeeId) {
          _employee = e;
        }
      }
    }

    final key = _employee == null
        ? null
        : (employeeId: _employee!.id, salaryPeriod: _period);
    final overviewAsync = key == null ? null : ref.watch(financialOverviewProvider(key));
    final advancesAsync = key == null ? null : ref.watch(employeePeriodAdvancesProvider(key));
    final paymentsAsync = key == null ? null : ref.watch(employeePeriodPaymentsProvider(key));
    final overview = overviewAsync?.asData?.value;

    final enteredPaise = CurrencyFormatter.parseInputToPaise(_amountController.text);
    final remaining = overview?.remainingPayablePaise ?? 0;
    final exceeds = overview != null && enteredPaise > remaining;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text(
          'Salary',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'Record salary payments and salary advances.',
                  style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                ),
              ),

              // 1. Employee
              _stepLabel('1. Select Employee'),
              InkWell(
                key: const Key('select_employee_button'),
                onTap: employees.isEmpty
                    ? null
                    : () async {
                        final picked = await EmployeePickerSheet.show(
                          context,
                          employees: employees,
                          selectedEmployeeId: _employee?.id,
                        );
                        if (picked != null) setState(() => _employee = picked);
                      },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 68),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _employee != null ? AppColors.primaryNavy : AppColors.cardBorder,
                      width: _employee != null ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_employee != null) ...[
                        EmployeeAvatar(initials: _employee!.initials, radius: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _employee!.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${_employee!.employeeCode} • ${_employee!.designation ?? "Employee"}',
                                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Expanded(
                          child: Text(
                            employees.isEmpty ? 'No active employees' : 'Tap here to choose an employee',
                            style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                          ),
                        ),
                      const Icon(Icons.search_rounded, size: 28, color: AppColors.primaryNavy),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Salary period
              _stepLabel('2. Salary Month'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      key: const Key('period_previous'),
                      iconSize: 34,
                      onPressed: () => _changePeriod(-1),
                      icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primaryNavy),
                      tooltip: 'Previous month',
                    ),
                    Text(
                      AppDateUtils.formatPeriodDisplay(_period),
                      key: const Key('period_text'),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    IconButton(
                      key: const Key('period_next'),
                      iconSize: 34,
                      onPressed: () => _changePeriod(1),
                      icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryNavy),
                      tooltip: 'Next month',
                    ),
                  ],
                ),
              ),

              // Financial position
              if (_employee != null) ...[
                const SizedBox(height: 16),
                _FinancialBox(overviewAsync: overviewAsync!),
              ],
              const SizedBox(height: 20),

              // 3. Transaction type (explicit choice)
              _stepLabel('3. What are you recording?'),
              _TypeCard(
                key: const Key('type_regular'),
                title: 'Regular Salary Payment',
                subtitle: 'Salary paid to the employee on pay day.',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.primaryNavy,
                selected: _type == SalaryTransactionType.regularPayment,
                onTap: () => setState(() => _type = SalaryTransactionType.regularPayment),
              ),
              const SizedBox(height: 10),
              _TypeCard(
                key: const Key('type_advance'),
                title: 'Salary Advance / Prepaid',
                subtitle: 'Money given BEFORE pay day. It is deducted from the salary.',
                icon: Icons.fast_forward_rounded,
                color: AppColors.accentTeal,
                selected: _type == SalaryTransactionType.advance,
                onTap: () => setState(() => _type = SalaryTransactionType.advance),
              ),
              const SizedBox(height: 20),

              // 4. Date
              _stepLabel(_type == SalaryTransactionType.advance
                  ? '4. Advance Date'
                  : '4. Payment Date'),
              InkWell(
                key: const Key('transaction_date_button'),
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 28, color: AppColors.primaryNavy),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppDateUtils.formatDisplayDate(_date),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
              const SizedBox(height: 20),

              // 5. Amount
              _stepLabel('5. Amount (₹)'),
              TextFormField(
                key: const Key('amount_field'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'e.g. 5000',
                  hintStyle: TextStyle(fontSize: 18),
                  prefixIcon: Icon(Icons.currency_rupee_rounded, size: 28),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter the amount';
                  final parsed = int.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) return 'Amount must be more than zero';
                  return null;
                },
              ),
              if (overview != null && remaining > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('fill_remaining_button'),
                    onPressed: () => setState(() {
                      _amountController.text = (remaining ~/ 100).toString();
                    }),
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(
                      'Fill remaining ${CurrencyFormatter.formatPaise(remaining)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              if (overview != null && enteredPaise > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: exceeds ? AppColors.dangerRedLight : AppColors.accentTealLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    exceeds
                        ? 'This is MORE than the remaining ${CurrencyFormatter.formatPaise(remaining < 0 ? 0 : remaining)}. It cannot be saved.'
                        : 'After saving, remaining payable will be ${CurrencyFormatter.formatPaise(remaining - enteredPaise)}.',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: exceeds ? const Color(0xFF991B1B) : AppColors.primaryNavy,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 6. Description
              _stepLabel('6. Note (optional)'),
              TextFormField(
                key: const Key('description_field'),
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'e.g. Festival advance',
                  hintStyle: TextStyle(fontSize: 16),
                  prefixIcon: Icon(Icons.note_alt_outlined, size: 26),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  key: const Key('record_payment_button'),
                  onPressed: _saving ? null : () => _record(overview),
                  icon: _saving
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 28),
                  label: Text(_saving ? 'SAVING...' : 'RECORD PAYMENT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              // History
              if (_employee != null) ...[
                const SizedBox(height: 30),
                Text(
                  'HISTORY — ${AppDateUtils.formatPeriodDisplay(_period).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                _HistoryList(
                  advances: advancesAsync?.asData?.value ?? const [],
                  payments: paymentsAsync?.asData?.value ?? const [],
                  loading: (advancesAsync?.isLoading ?? false) || (paymentsAsync?.isLoading ?? false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.09) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : AppColors.cardBorder, width: selected ? 3 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 30,
              color: selected ? color : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialBox extends StatelessWidget {
  final AsyncValue<FinancialOverview> overviewAsync;

  const _FinancialBox({required this.overviewAsync});

  @override
  Widget build(BuildContext context) {
    return overviewAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: AppColors.accentTeal)),
      ),
      error: (e, _) => Text('Could not load salary details: $e', style: const TextStyle(fontSize: 16)),
      data: (o) {
        Widget row(String label, int paise, {Color? color, bool bold = false, Key? key}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  CurrencyFormatter.formatPaise(paise),
                  key: key,
                  style: TextStyle(
                    fontSize: bold ? 22 : 18,
                    fontWeight: FontWeight.w800,
                    color: color ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Column(
            children: [
              row('Monthly Salary', o.monthlySalaryPaise, color: AppColors.primaryNavy, key: const Key('fin_salary')),
              row('Advances given (prepaid)', o.totalAdvancesPaise, color: AppColors.accentTeal, key: const Key('fin_advances')),
              row('Regular salary paid', o.regularPaidPaise, color: AppColors.primaryNavy, key: const Key('fin_paid')),
              const Divider(height: 18),
              row('Remaining payable', o.remainingPayablePaise,
                  color: o.remainingPayablePaise < 0 ? AppColors.dangerRed : AppColors.successGreen,
                  bold: true,
                  key: const Key('fin_remaining')),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryList extends ConsumerWidget {
  final List<Advance> advances;
  final List<SalaryPayment> payments;
  final bool loading;

  const _HistoryList({required this.advances, required this.payments, required this.loading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading && advances.isEmpty && payments.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentTeal));
    }

    final items = <_HistoryItem>[
      for (final a in advances)
        _HistoryItem(
          isAdvance: true,
          id: a.id,
          employeeId: a.employeeId,
          amountPaise: a.amountPaise,
          dateIso: a.transactionDate,
          description: a.description,
          createdAt: a.createdAt,
        ),
      for (final p in payments)
        _HistoryItem(
          isAdvance: false,
          id: p.id,
          employeeId: p.employeeId,
          amountPaise: p.amountPaise,
          dateIso: p.paymentDate,
          description: p.description,
          createdAt: p.createdAt,
        ),
    ]..sort((a, b) {
        final c = b.dateIso.compareTo(a.dateIso);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Text(
          'No salary payments or advances recorded for this month.',
          style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        final color = item.isAdvance ? AppColors.accentTeal : AppColors.primaryNavy;
        final date = AppDateUtils.formatDisplayDate(AppDateUtils.parseIsoDateString(item.dateIso));
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.isAdvance ? 'ADVANCE (PREPAID)' : 'REGULAR SALARY PAID',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    if (item.description?.isNotEmpty == true)
                      Text(
                        item.description!,
                        style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatPaise(item.amountPaise),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
                  ),
                  IconButton(
                    tooltip: 'Delete this record',
                    iconSize: 26,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
                    onPressed: () async {
                      final ok = await ConfirmDialog.show(
                        context,
                        title: 'Delete this record?',
                        message:
                            'Delete the ${item.isAdvance ? 'advance' : 'salary payment'} of ${CurrencyFormatter.formatPaise(item.amountPaise)} dated $date? This cannot be undone.',
                        confirmLabel: 'Delete',
                        isDestructive: true,
                      );
                      if (ok != true) return;
                      final notifier = ref.read(salaryActionNotifierProvider.notifier);
                      if (item.isAdvance) {
                        await notifier.deleteAdvance(advanceId: item.id, employeeId: item.employeeId);
                      } else {
                        await notifier.deletePayment(paymentId: item.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _HistoryItem {
  final bool isAdvance;
  final String id;
  final String employeeId;
  final int amountPaise;
  final String dateIso;
  final String? description;
  final DateTime createdAt;

  const _HistoryItem({
    required this.isAdvance,
    required this.id,
    required this.employeeId,
    required this.amountPaise,
    required this.dateIso,
    required this.description,
    required this.createdAt,
  });
}

