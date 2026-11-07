import '../../domain/entities/app_setting.dart';

class AppSettingModel {
  final String id;
  final String settingKey;
  final String settingValue;
  final String updatedAt;

  AppSettingModel({
    required this.id,
    required this.settingKey,
    required this.settingValue,
    required this.updatedAt,
  });

  factory AppSettingModel.fromMap(Map<String, dynamic> map) {
    return AppSettingModel(
      id: map['id'] as String,
      settingKey: map['setting_key'] as String,
      settingValue: map['setting_value'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'setting_key': settingKey,
      'setting_value': settingValue,
      'updated_at': updatedAt,
    };
  }

  AppSetting toEntity() {
    return AppSetting(
      id: id,
      settingKey: settingKey,
      settingValue: settingValue,
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}

