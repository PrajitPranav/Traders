import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/advance.dart';
import '../../domain/entities/salary_record.dart';
import '../../domain/entities/salary_summary.dart';
import 'attendance_providers.dart';
import 'repository_providers.dart';

/// Currently selected salary period (YYYY-MM), defaulting to current month
final selectedSalaryPeriodProvider = StateProvider<String>((ref) {
  return AppDateUtils.toSalaryPeriod(DateTime.now());
});

/// Financial summary (monthly salary, prepaid advances, remaining) for selected employee and period
final salarySummaryProvider =
    FutureProvider.family<SalarySummary, String>((ref, employeeId) async {
  final period = ref.watch(selectedSalaryPeriodProvider);
  final repo = ref.watch(salaryRepositoryProvider);
  return await repo.getSalarySummary(employeeId, period);
});

/// Advances for selected employee and selected salary period
final employeeAdvancesForPeriodProvider =
    FutureProvider.family<List<Advance>, String>((ref, employeeId) async {
  final period = ref.watch(selectedSalaryPeriodProvider);
  final repo = ref.watch(advanceRepositoryProvider);
  return await repo.getAdvancesForPeriod(employeeId, period);
});

/// All historical advances for an employee
final employeeAllAdvancesProvider =
    FutureProvider.family<List<Advance>, String>((ref, employeeId) async {
  final repo = ref.watch(advanceRepositoryProvider);
  return await repo.getAllAdvances(employeeId);
});

/// Full salary revision history for an employee
final employeeSalaryHistoryProvider =
    FutureProvider.family<List<SalaryRecord>, String>((ref, employeeId) async {
  final repo = ref.watch(salaryRepositoryProvider);
  return await repo.getSalaryHistory(employeeId);
});

/// Advances grouped by date for calendar visual indicators (blue/teal dot)
final employeeMonthAdvancesMapProvider =
    FutureProvider.family<Map<String, List<Advance>>, String>((ref, employeeId) async {
  final month = ref.watch(selectedAttendanceMonthProvider);
  final repo = ref.watch(advanceRepositoryProvider);
  return await repo.getMonthAdvancesMap(employeeId, month.year, month.month);
});

/// State notifier for salary revisions and advance payments
class SalaryActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SalaryActionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> recordAdvance({
    required String employeeId,
    required int amountPaise,
    required String transactionDateIso,
    required String salaryPeriod,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final advanceRepo = _ref.read(advanceRepositoryProvider);
      await advanceRepo.createAdvance(
        employeeId: employeeId,
        amountPaise: amountPaise,
        transactionDateIso: transactionDateIso,
        salaryPeriod: salaryPeriod,
        description: description,
      );

      // Refresh financial and calendar providers
      _ref.invalidate(salarySummaryProvider(employeeId));
      _ref.invalidate(employeeAdvancesForPeriodProvider(employeeId));
      _ref.invalidate(employeeAllAdvancesProvider(employeeId));
      _ref.invalidate(employeeMonthAdvancesMapProvider(employeeId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAdvance({
    required String advanceId,
    required String employeeId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final advanceRepo = _ref.read(advanceRepositoryProvider);
      await advanceRepo.deleteAdvance(advanceId);

      _ref.invalidate(salarySummaryProvider(employeeId));
      _ref.invalidate(employeeAdvancesForPeriodProvider(employeeId));
      _ref.invalidate(employeeAllAdvancesProvider(employeeId));
      _ref.invalidate(employeeMonthAdvancesMapProvider(employeeId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSalary({
    required String employeeId,
    required int newSalaryPaise,
    required String effectiveFromIso,
  }) async {
    state = const AsyncValue.loading();
    try {
      final salaryRepo = _ref.read(salaryRepositoryProvider);
      await salaryRepo.updateSalary(
        employeeId: employeeId,
        newSalaryPaise: newSalaryPaise,
        effectiveFromIso: effectiveFromIso,
      );

      _ref.invalidate(salarySummaryProvider(employeeId));
      _ref.invalidate(employeeSalaryHistoryProvider(employeeId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final salaryActionNotifierProvider =
    StateNotifierProvider<SalaryActionNotifier, AsyncValue<void>>((ref) {
  return SalaryActionNotifier(ref);
});

