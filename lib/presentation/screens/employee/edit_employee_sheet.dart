import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/employee_providers.dart';

class EditEmployeeSheet extends ConsumerStatefulWidget {
  final Employee employee;

  const EditEmployeeSheet({super.key, required this.employee});

  static Future<void> show(BuildContext context, Employee employee) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditEmployeeSheet(employee: employee),
    );
  }

  @override
  ConsumerState<EditEmployeeSheet> createState() => _EditEmployeeSheetState();
}

class _EditEmployeeSheetState extends ConsumerState<EditEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _designationController;
  late DateTime _selectedJoiningDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _phoneController = TextEditingController(text: widget.employee.phone ?? '');
    _designationController = TextEditingController(text: widget.employee.designation ?? '');
    _selectedJoiningDate = widget.employee.joiningDate != null
        ? AppDateUtils.parseIsoDateString(widget.employee.joiningDate!)
        : DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedJoiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedJoiningDate = picked);
    }
  }

  Future<void> _saveChanges() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final updated = widget.employee.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        designation: _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        joiningDate: AppDateUtils.toIsoDateString(_selectedJoiningDate),
      );

      await ref.read(employeeListProvider.notifier).updateEmployee(updated);
      ref.invalidate(employeeDetailProvider(widget.employee.id));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee updated successfully'),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
              Text(
                'Edit ${widget.employee.employeeCode}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Full Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: AppStrings.fullName,
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Name cannot be empty';
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
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              // Designation
              TextFormField(
                controller: _designationController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: AppStrings.designation,
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              // Joining Date
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
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _saveChanges,
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

