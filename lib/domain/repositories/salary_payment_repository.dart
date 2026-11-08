import '../entities/salary_payment.dart';

/// Contract for regular salary payments (kept separate from advances).
abstract class SalaryPaymentRepository {
  Future<List<SalaryPayment>> getPaymentsForPeriod(String employeeId, String salaryPeriod);

  Future<List<SalaryPayment>> getAllPayments(String employeeId);

  Future<int> getTotalPaidPaiseForPeriod(String employeeId, String salaryPeriod);

  /// Complete balance (salary, advances, regular paid, remaining payable).
  Future<FinancialOverview> getFinancialOverview(String employeeId, String salaryPeriod);

  /// Records a payment inside a transaction. Throws [StateError] if the amount
  /// exceeds the remaining payable balance for that employee and period.
  Future<SalaryPayment> createPayment({
    required String employeeId,
    required int amountPaise,
    required String paymentDateIso,
    required String salaryPeriod,
    String? description,
  });

  Future<void> deletePayment(String paymentId);
}

