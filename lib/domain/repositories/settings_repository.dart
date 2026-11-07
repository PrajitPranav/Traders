/// Abstract contract for app configuration, admin profile, and data backup/restore.
abstract class SettingsRepository {
  /// Gets a setting by key.
  Future<String?> getSetting(String key);

  /// Sets or updates a setting.
  Future<void> setSetting(String key, String value);

  /// Exports all tables to a structured JSON string.
  Future<String> exportBackupJson();

  /// Restores database records from a verified JSON string.
  Future<bool> restoreBackupJson(String jsonString);
}

