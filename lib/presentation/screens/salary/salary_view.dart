import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../providers/salary_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/stat_card.dart';
import 'add_advance_sheet.dart';

class SalaryView extends ConsumerWidget {
  final String employeeId;

  const SalaryView({super.key, required this.employeeId});

  void _changePeriod(WidgetRef ref, int monthDelta) {
    final currentPeriod = ref.read(selectedSalaryPeriodProvider);
    final parts = currentPeriod.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final newDate = DateTime(year, month + monthDelta, 1);
    ref.read(selectedSalaryPeriodProvider.notifier).state = AppDateUtils.toSalaryPeriod(newDate);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedSalaryPeriodProvider);
    final salarySummaryAsync = ref.watch(salarySummaryProvider(employeeId));
    final advancesAsync = ref.watch(employeeAdvancesForPeriodProvider(employeeId));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period Navigator (e.g. < October 2026 >)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.primaryNavy),
                  onPressed: () => _changePeriod(ref, -1),
                  tooltip: 'Previous Month',
                ),
                Text(
                  AppDateUtils.formatPeriodDisplay(period),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.primaryNavy),
                  onPressed: () => _changePeriod(ref, 1),
                  tooltip: 'Next Month',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial Summary Cards
          salarySummaryAsync.when(
            data: (summary) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: AppStrings.totalMonthlySalary,
                        value: CurrencyFormatter.formatPaise(summary.monthlySalaryPaise),
                        icon: Icons.account_balance_wallet_outlined,
                        accentColor: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        title: AppStrings.prepaidAdvances,
                        value: CurrencyFormatter.formatPaise(summary.totalAdvancesPaise),
                        icon: Icons.payments_outlined,
                        accentColor: AppColors.accentTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Remaining Salary Banner Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryNavy.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            AppStrings.remainingSalary,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.formatPaise(summary.remainingSalaryPaise),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          AddAdvanceSheet.show(
                            context,
                            employeeId: employeeId,
                            currentSalaryPeriod: period,
                            maxAllowedPaise: summary.remainingSalaryPaise,
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(AppStrings.addAdvance),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.accentTeal),
              ),
            ),
            error: (e, _) => Center(child: Text('Error loading salary: $e')),
          ),
          const SizedBox(height: 24),

          // Advance Transaction History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                AppStrings.advanceHistory,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              advancesAsync.maybeWhen(
                data: (list) => Text(
                  '${list.length} transactions',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          advancesAsync.when(
            data: (advances) {
              if (advances.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: advances.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final adv = advances[index];
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentTealLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_upward,
                            size: 18,
                            color: AppColors.accentTeal,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adv.description?.isNotEmpty == true
                                    ? adv.description!
                                    : 'Salary Advance',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
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
                              '- ${CurrencyFormatter.formatPaise(adv.amountPaise)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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
                                      'Are you sure you want to delete this advance payment of ${CurrencyFormatter.formatPaise(adv.amountPaise)} dated $formattedDate?',
                                  confirmLabel: 'Delete',
                                  isDestructive: true,
                                );
                                if (confirm == true) {
                                  await ref
                                      .read(salaryActionNotifierProvider.notifier)
                                      .deleteAdvance(
                                        advanceId: adv.id,
                                        employeeId: employeeId,
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
                child: CircularProgressIndicator(color: AppColors.accentTeal),
              ),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}
