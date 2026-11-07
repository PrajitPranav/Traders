import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../providers/employee_providers.dart';

class AddEmployeeSheet extends ConsumerStatefulWidget {
  const AddEmployeeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddEmployeeSheet(),
    );
  }

  @override
  ConsumerState<AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends ConsumerState<AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _designationController = TextEditingController();
  final _salaryController = TextEditingController();

  DateTime _selectedJoiningDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedJoiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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
        _selectedJoiningDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final designation = _designationController.text.trim();
      final salaryPaise = CurrencyFormatter.parseInputToPaise(_salaryController.text);
      final joiningDateIso = AppDateUtils.toIsoDateString(_selectedJoiningDate);

      final employee = await ref.read(employeeListProvider.notifier).addEmployee(
            name: name,
            phone: phone.isEmpty ? null : phone,
            designation: designation.isEmpty ? null : designation,
            joiningDate: joiningDateIso,
            initialSalaryPaise: salaryPaise,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${employee.name} (${employee.employeeCode}) added successfully!'),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add employee: $e'),
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
    final nextCodeAsync = ref.watch(nextEmployeeCodeProvider);
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
                    AppStrings.addEmployee,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  nextCodeAsync.when(
                    data: (code) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Full Name (Required)
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: AppStrings.fullName,
                  hintText: AppStrings.fullNameHint,
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter the employee full name';
                  }
                  if (val.trim().length < 2) {
                    return 'Name is too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: AppStrings.phoneNumber,
                  hintText: AppStrings.phoneNumberHint,
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length != 10) {
                    return 'Please enter a valid 10-digit mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Designation
              TextFormField(
                controller: _designationController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: AppStrings.designation,
                  hintText: AppStrings.designationHint,
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              // Joining Date Picker
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
                      const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            AppStrings.joiningDate,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppDateUtils.formatDisplayDate(_selectedJoiningDate),
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

              // Monthly Salary
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: AppStrings.monthlySalary,
                  hintText: AppStrings.monthlySalaryHint,
                  prefixIcon: Icon(Icons.currency_rupee, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please specify the monthly salary';
                  }
                  final amount = int.tryParse(val.trim());
                  if (amount == null || amount < 0) {
                    return 'Please enter a valid salary amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(AppStrings.saveEmployee),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
