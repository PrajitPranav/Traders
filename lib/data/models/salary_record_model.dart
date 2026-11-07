import '../../domain/entities/salary_record.dart';

class SalaryRecordModel {
  final String id;
  final String employeeId;
  final int monthlySalaryPaise;
  final String effectiveFrom;
  final String createdAt;

  SalaryRecordModel({
    required this.id,
    required this.employeeId,
    required this.monthlySalaryPaise,
    required this.effectiveFrom,
    required this.createdAt,
  });

  factory SalaryRecordModel.fromMap(Map<String, dynamic> map) {
    return SalaryRecordModel(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      monthlySalaryPaise: map['monthly_salary_paise'] as int,
      effectiveFrom: map['effective_from'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'monthly_salary_paise': monthlySalaryPaise,
      'effective_from': effectiveFrom,
      'created_at': createdAt,
    };
  }

  SalaryRecord toEntity() {
    return SalaryRecord(
      id: id,
      employeeId: employeeId,
      monthlySalaryPaise: monthlySalaryPaise,
      effectiveFrom: effectiveFrom,
      createdAt: DateTime.parse(createdAt),
    );
  }

  factory SalaryRecordModel.fromEntity(SalaryRecord entity) {
    return SalaryRecordModel(
      id: entity.id,
      employeeId: entity.employeeId,
      monthlySalaryPaise: entity.monthlySalaryPaise,
      effectiveFrom: entity.effectiveFrom,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }
}

