import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/advance.dart';
import '../../domain/entities/salary_record.dart';
import '../../domain/entities/salary_payment.dart';
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

/// Company-wide advances for a specific month grouped by transaction date ('YYYY-MM-DD')
final allMonthAdvancesByDateProvider = FutureProvider.family<
    Map<String, List<Advance>>, ({int year, int month})>((ref, arg) async {
  final repo = ref.watch(advanceRepositoryProvider);
  return await repo.getAllMonthAdvancesByDate(arg.year, arg.month);
});

/// Company-wide advances recorded on a specific date ('YYYY-MM-DD')
final allDateAdvancesProvider =
    FutureProvider.family<List<Advance>, String>((ref, dateIso) async {
  final repo = ref.watch(advanceRepositoryProvider);
  return await repo.getAllAdvancesForDate(dateIso);
});

/// Company-wide advances for a specific salary period ('YYYY-MM')
final allPeriodAdvancesProvider =
    FutureProvider.family<List<Advance>, String>((ref, salaryPeriod) async {
  final repo = ref.watch(advanceRepositoryProvider);
  return await repo.getAllAdvancesForPeriod(salaryPeriod);
});

/// Salary summary by (employeeId, salaryPeriod) tuple for flexible querying across screens
final employeePeriodSalarySummaryProvider = FutureProvider.family<
    SalarySummary, ({String employeeId, String salaryPeriod})>((ref, arg) async {
  final repo = ref.watch(salaryRepositoryProvider);
  return await repo.getSalarySummary(arg.employeeId, arg.salaryPeriod);
});

/// Full financial position (salary, advances, regular paid, remaining payable)
final financialOverviewProvider = FutureProvider.family<FinancialOverview,
    ({String employeeId, String salaryPeriod})>((ref, arg) async {
  final repo = ref.watch(salaryPaymentRepositoryProvider);
  return await repo.getFinancialOverview(arg.employeeId, arg.salaryPeriod);
});

/// Regular salary payments for an employee in a salary period
final employeePeriodPaymentsProvider = FutureProvider.family<List<SalaryPayment>,
    ({String employeeId, String salaryPeriod})>((ref, arg) async {
  final repo = ref.watch(salaryPaymentRepositoryProvider);
  return await repo.getPaymentsForPeriod(arg.employeeId, arg.salaryPeriod);
});

/// Advances for an employee in a salary period (tuple-keyed, used by Salary screen)
final employeePeriodAdvancesProvider = FutureProvider.family<List<Advance>,
    ({String employeeId, String salaryPeriod})>((ref, arg) async {
  final repo = ref.watch(advanceRepositoryProvider);
  return await repo.getAdvancesForPeriod(arg.employeeId, arg.salaryPeriod);
});

/// State notifier for salary revisions and advance payments
class SalaryActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SalaryActionNotifier(this._ref) : super(const AsyncValue.data(null));

  void _refreshFinancials() {
    _ref.invalidate(salarySummaryProvider);
    _ref.invalidate(employeePeriodSalarySummaryProvider);
    _ref.invalidate(financialOverviewProvider);
    _ref.invalidate(employeePeriodPaymentsProvider);
    _ref.invalidate(employeePeriodAdvancesProvider);
    _ref.invalidate(employeeAdvancesForPeriodProvider);
    _ref.invalidate(employeeAllAdvancesProvider);
    _ref.invalidate(employeeMonthAdvancesMapProvider);
    _ref.invalidate(allDateAdvancesProvider);
    _ref.invalidate(allMonthAdvancesByDateProvider);
    _ref.invalidate(allPeriodAdvancesProvider);
  }

  /// Records a REGULAR salary payment (separate from advances). Rethrows on failure.
  Future<void> recordPayment({
    required String employeeId,
    required int amountPaise,
    required String paymentDateIso,
    required String salaryPeriod,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(salaryPaymentRepositoryProvider);
      await repo.createPayment(
        employeeId: employeeId,
        amountPaise: amountPaise,
        paymentDateIso: paymentDateIso,
        salaryPeriod: salaryPeriod,
        description: description,
      );
      _refreshFinancials();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deletePayment({required String paymentId}) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(salaryPaymentRepositoryProvider);
      await repo.deletePayment(paymentId);
      _refreshFinancials();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

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

      // Refresh financial and calendar providers across the entire app
      _ref.invalidate(salarySummaryProvider(employeeId));
      _ref.invalidate(employeePeriodSalarySummaryProvider);
      _ref.invalidate(financialOverviewProvider);
      _ref.invalidate(employeeAdvancesForPeriodProvider(employeeId));
      _ref.invalidate(employeeAllAdvancesProvider(employeeId));
      _ref.invalidate(employeeMonthAdvancesMapProvider(employeeId));
      _ref.invalidate(allDateAdvancesProvider(transactionDateIso));
      _ref.invalidate(allMonthAdvancesByDateProvider);
      _ref.invalidate(allPeriodAdvancesProvider(salaryPeriod));
      _refreshFinancials();

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
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
      _ref.invalidate(employeePeriodSalarySummaryProvider);
      _ref.invalidate(financialOverviewProvider);
      _ref.invalidate(employeeAdvancesForPeriodProvider(employeeId));
      _ref.invalidate(employeeAllAdvancesProvider(employeeId));
      _ref.invalidate(employeeMonthAdvancesMapProvider(employeeId));
      _ref.invalidate(allDateAdvancesProvider);
      _ref.invalidate(allMonthAdvancesByDateProvider);
      _ref.invalidate(allPeriodAdvancesProvider);
      _refreshFinancials();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
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
      _ref.invalidate(employeePeriodSalarySummaryProvider);
      _ref.invalidate(financialOverviewProvider);
      _ref.invalidate(employeeSalaryHistoryProvider(employeeId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final salaryActionNotifierProvider =
    StateNotifierProvider<SalaryActionNotifier, AsyncValue<void>>((ref) {
  return SalaryActionNotifier(ref);
});

