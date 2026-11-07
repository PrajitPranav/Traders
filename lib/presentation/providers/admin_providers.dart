import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_providers.dart';
import 'employee_providers.dart';
import 'repository_providers.dart';

final adminNameProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return await repo.getSetting('admin_name') ?? 'Business Administrator';
});

class AdminActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AdminActionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateAdminName(String newName) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(settingsRepositoryProvider);
      await repo.setSetting('admin_name', newName.trim());
      _ref.invalidate(adminNameProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String> exportBackup() async {
    final repo = _ref.read(settingsRepositoryProvider);
    return await repo.exportBackupJson();
  }

  Future<bool> restoreBackup(String jsonString) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(settingsRepositoryProvider);
      final success = await repo.restoreBackupJson(jsonString);
      if (success) {
        _ref.invalidate(employeeListProvider);
        _ref.invalidate(dashboardStatsProvider);
        _ref.invalidate(adminNameProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final adminActionNotifierProvider =
    StateNotifierProvider<AdminActionNotifier, AsyncValue<void>>((ref) {
  return AdminActionNotifier(ref);
});

