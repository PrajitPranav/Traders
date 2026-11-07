import '../entities/employee.dart';

/// Abstract contract for Employee data operations.
/// Supports both local SQLite and future remote MySQL/API implementations.
abstract class EmployeeRepository {
  /// Retrieves all employees, optionally including deactivated ones.
  Future<List<Employee>> getAllEmployees({bool includeInactive = false});

  /// Retrieves a single employee by their unique UUID.
  Future<Employee?> getEmployeeById(String id);

  /// Retrieves an employee by their unique code (e.g., EMP0001).
  Future<Employee?> getEmployeeByCode(String code);

  /// Generates the next sequential, non-reusable employee code (e.g. EMP0001, EMP0002).
  Future<String> getNextEmployeeCode();

  /// Creates a new employee atomically with initial salary record in a database transaction.
  Future<Employee> createEmployee({
    required String name,
    String? phone,
    String? designation,
    String? joiningDate,
    required int initialSalaryPaise,
  });

  /// Updates editable employee details.
  Future<void> updateEmployee(Employee employee);

  /// Sets active or deactivated status. Soft deactivation preserves all historical data.
  Future<void> setEmployeeActiveStatus(String id, bool isActive);

  /// Gets the total count of active employees.
  Future<int> getActiveEmployeeCount();
}

