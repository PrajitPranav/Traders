import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/employee.dart';
import 'repository_providers.dart';

/// Search query provider for filtering employee list
final employeeSearchQueryProvider = StateProvider<String>((ref) => '');

/// State notifier managing employee list state and refreshes
class EmployeeListNotifier extends StateNotifier<AsyncValue<List<Employee>>> {
  final Ref _ref;

  EmployeeListNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(employeeRepositoryProvider);
      final list = await repo.getAllEmployees(includeInactive: false);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Employee> addEmployee({
    required String name,
    String? phone,
    String? designation,
    String? joiningDate,
    required int initialSalaryPaise,
  }) async {
    final repo = _ref.read(employeeRepositoryProvider);
    final created = await repo.createEmployee(
      name: name,
      phone: phone,
      designation: designation,
      joiningDate: joiningDate,
      initialSalaryPaise: initialSalaryPaise,
    );
    await loadEmployees();
    return created;
  }

  Future<void> updateEmployee(Employee employee) async {
    final repo = _ref.read(employeeRepositoryProvider);
    await repo.updateEmployee(employee);
    await loadEmployees();
  }

  Future<void> setEmployeeActive(String id, bool isActive) async {
    final repo = _ref.read(employeeRepositoryProvider);
    await repo.setEmployeeActiveStatus(id, isActive);
    await loadEmployees();
  }
}

final employeeListProvider =
    StateNotifierProvider<EmployeeListNotifier, AsyncValue<List<Employee>>>((ref) {
  return EmployeeListNotifier(ref);
});

/// Filtered employee list reacting to search queries
final filteredEmployeesProvider = Provider<AsyncValue<List<Employee>>>((ref) {
  final employeesAsync = ref.watch(employeeListProvider);
  final query = ref.watch(employeeSearchQueryProvider).toLowerCase().trim();

  return employeesAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((emp) {
      final nameMatches = emp.name.toLowerCase().contains(query);
      final codeMatches = emp.employeeCode.toLowerCase().contains(query);
      final designationMatches = emp.designation?.toLowerCase().contains(query) ?? false;
      return nameMatches || codeMatches || designationMatches;
    }).toList();
  });
});

/// Single employee detail provider
final employeeDetailProvider = FutureProvider.family<Employee?, String>((ref, id) async {
  final repo = ref.watch(employeeRepositoryProvider);
  return await repo.getEmployeeById(id);
});

/// Next available employee code provider
final nextEmployeeCodeProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(employeeRepositoryProvider);
  return await repo.getNextEmployeeCode();
});

