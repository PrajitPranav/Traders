import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../providers/salary_providers.dart';

class AddAdvanceSheet extends ConsumerStatefulWidget {
  final String employeeId;
  final String currentSalaryPeriod;
  final int maxAllowedPaise;

  const AddAdvanceSheet({
    super.key,
    required this.employeeId,
    required this.currentSalaryPeriod,
    required this.maxAllowedPaise,
  });

  static Future<void> show(
    BuildContext context, {
    required String employeeId,
    required String currentSalaryPeriod,
    required int maxAllowedPaise,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddAdvanceSheet(
        employeeId: employeeId,
        currentSalaryPeriod: currentSalaryPeriod,
        maxAllowedPaise: maxAllowedPaise,
      ),
    );
  }

  @override
  ConsumerState<AddAdvanceSheet> createState() => _AddAdvanceSheetState();
}

class _AddAdvanceSheetState extends ConsumerState<AddAdvanceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Advances are recorded on or before today
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitAdvance() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final amountPaise = CurrencyFormatter.parseInputToPaise(_amountController.text);

    if (widget.maxAllowedPaise > 0 && amountPaise > widget.maxAllowedPaise) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Advance cannot exceed remaining salary of ${CurrencyFormatter.formatPaise(widget.maxAllowedPaise)} for this period.',
          ),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dateIso = AppDateUtils.toIsoDateString(_selectedDate);
      final period = AppDateUtils.toSalaryPeriod(_selectedDate);

      await ref.read(salaryActionNotifierProvider.notifier).recordAdvance(
            employeeId: widget.employeeId,
            amountPaise: amountPaise,
            transactionDateIso: dateIso,
            salaryPeriod: period,
            description: _descriptionController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded advance of ${CurrencyFormatter.formatPaise(amountPaise)} successfully.',
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
            content: Text('Failed to record advance: $e'),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                  const Text(
                    AppStrings.recordAdvance,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.maxAllowedPaise > 0)
                    Text(
                      'Max: ${CurrencyFormatter.formatPaise(widget.maxAllowedPaise)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentTeal,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Advance Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.advanceAmount,
                  hintText: 'e.g. 5000',
                  prefixIcon: Icon(Icons.currency_rupee, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter the advance amount';
                  }
                  final amount = int.tryParse(val.trim());
                  if (amount == null || amount <= 0) {
                    return 'Amount must be greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Transaction Date Picker
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            AppStrings.advanceDate,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppDateUtils.formatDisplayDate(_selectedDate),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description / Reason
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: AppStrings.description,
                  hintText: 'e.g. Festival advance, Medical emergency',
                  prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAdvance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm & Save Advance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

