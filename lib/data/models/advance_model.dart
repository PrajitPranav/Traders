import '../../domain/entities/advance.dart';

class AdvanceModel {
  final String id;
  final String employeeId;
  final int amountPaise;
  final String transactionDate;
  final String salaryPeriod;
  final String? description;
  final String createdAt;
  final String updatedAt;

  AdvanceModel({
    required this.id,
    required this.employeeId,
    required this.amountPaise,
    required this.transactionDate,
    required this.salaryPeriod,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdvanceModel.fromMap(Map<String, dynamic> map) {
    return AdvanceModel(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      amountPaise: map['amount_paise'] as int,
      transactionDate: map['transaction_date'] as String,
      salaryPeriod: map['salary_period'] as String,
      description: map['description'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'amount_paise': amountPaise,
      'transaction_date': transactionDate,
      'salary_period': salaryPeriod,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Advance toEntity() {
    return Advance(
      id: id,
      employeeId: employeeId,
      amountPaise: amountPaise,
      transactionDate: transactionDate,
      salaryPeriod: salaryPeriod,
      description: description,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  factory AdvanceModel.fromEntity(Advance entity) {
    return AdvanceModel(
      id: entity.id,
      employeeId: entity.employeeId,
      amountPaise: entity.amountPaise,
      transactionDate: entity.transactionDate,
      salaryPeriod: entity.salaryPeriod,
      description: entity.description,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }
}

