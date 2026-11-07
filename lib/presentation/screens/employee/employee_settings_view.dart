import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/employee.dart';
import '../../providers/employee_providers.dart';
import '../../providers/salary_providers.dart';
import '../../widgets/confirm_dialog.dart';
import 'edit_employee_sheet.dart';

class EmployeeSettingsView extends ConsumerWidget {
  final Employee employee;

  const EmployeeSettingsView({super.key, required this.employee});

  void _showUpdateSalaryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    DateTime effectiveDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Monthly Salary'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historical salary records and previous advance payments will be preserved.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'New Monthly Salary (₹)',
                      hintText: 'e.g. 25000',
                      prefixIcon: Icon(Icons.currency_rupee, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: effectiveDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => effectiveDate = picked);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Effective from: ${AppDateUtils.formatDisplayDate(effectiveDate)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final paise = CurrencyFormatter.parseInputToPaise(controller.text);
                    if (paise <= 0) return;

                    Navigator.of(ctx).pop();
                    await ref.read(salaryActionNotifierProvider.notifier).updateSalary(
                          employeeId: employee.id,
                          newSalaryPaise: paise,
                          effectiveFromIso: AppDateUtils.toIsoDateString(effectiveDate),
                        );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Updated salary to ${CurrencyFormatter.formatPaise(paise)} effective ${AppDateUtils.formatDisplayDate(effectiveDate)}',
                          ),
                          backgroundColor: AppColors.successGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Salary'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Employee Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => EditEmployeeSheet.show(context, employee),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildInfoRow('Employee Code', employee.employeeCode),
                _buildInfoRow('Full Name', employee.name),
                _buildInfoRow('Designation', employee.designation ?? 'Not specified'),
                _buildInfoRow('Phone', employee.phone ?? 'Not specified'),
                _buildInfoRow(
                  'Joining Date',
                  employee.joiningDate != null
                      ? AppDateUtils.formatDisplayDate(
                          AppDateUtils.parseIsoDateString(employee.joiningDate!),
                        )
                      : 'Not recorded',
                ),
                _buildInfoRow(
                  'Status',
                  employee.isActive ? 'Active' : 'Deactivated',
                  valueColor: employee.isActive ? AppColors.successGreen : AppColors.dangerRed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Salary Actions Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Salary Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Update monthly salary with an effective date. Historical salary and advance transactions will not be modified.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _showUpdateSalaryDialog(context, ref),
                  icon: const Icon(Icons.currency_rupee, size: 18),
                  label: const Text('Update Monthly Salary'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Deactivation / Reactivation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: employee.isActive ? AppColors.dangerRedLight : AppColors.cardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.isActive ? 'Deactivate Employee' : 'Reactivate Employee',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: employee.isActive ? AppColors.dangerRed : AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  employee.isActive
                      ? 'Deactivating hides the employee from active lists but safely preserves all historical attendance, salary records, and advance transactions.'
                      : 'Reactivating restores this employee to the active directory and daily attendance rolls.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await ConfirmDialog.show(
                      context,
                      title: employee.isActive ? 'Deactivate Employee' : 'Reactivate Employee',
                      message: employee.isActive
                          ? 'Are you sure you want to deactivate ${employee.name}? Their financial and attendance history will be safely preserved.'
                          : 'Restore ${employee.name} to active status?',
                      confirmLabel: employee.isActive ? 'Deactivate' : 'Reactivate',
                      isDestructive: employee.isActive,
                    );

                    if (confirm == true) {
                      await ref
                          .read(employeeListProvider.notifier)
                          .setEmployeeActive(employee.id, !employee.isActive);
                      ref.invalidate(employeeDetailProvider(employee.id));
                      if (context.mounted && employee.isActive) {
                        context.pop();
                      }
                    }
                  },
                  icon: Icon(
                    employee.isActive ? Icons.person_off_outlined : Icons.person_add_outlined,
                    size: 18,
                  ),
                  label: Text(
                    employee.isActive ? AppStrings.deactivateEmployee : AppStrings.activateEmployee,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: employee.isActive ? AppColors.dangerRed : AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

