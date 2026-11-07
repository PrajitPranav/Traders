/// Entity for application-level settings stored in SQLite.
class AppSetting {
  final String id;
  final String settingKey;
  final String settingValue;
  final DateTime updatedAt;

  const AppSetting({
    required this.id,
    required this.settingKey,
    required this.settingValue,
    required this.updatedAt,
  });
}

