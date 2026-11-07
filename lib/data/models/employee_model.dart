import '../../domain/entities/employee.dart';

class EmployeeModel {
  final String id;
  final String employeeCode;
  final String name;
  final String? phone;
  final String? designation;
  final String? joiningDate;
  final int isActive;
  final String createdAt;
  final String updatedAt;

  EmployeeModel({
    required this.id,
    required this.employeeCode,
    required this.name,
    this.phone,
    this.designation,
    this.joiningDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id'] as String,
      employeeCode: map['employee_code'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      designation: map['designation'] as String?,
      joiningDate: map['joining_date'] as String?,
      isActive: (map['is_active'] as int?) ?? 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_code': employeeCode,
      'name': name,
      'phone': phone,
      'designation': designation,
      'joining_date': joiningDate,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Employee toEntity() {
    return Employee(
      id: id,
      employeeCode: employeeCode,
      name: name,
      phone: phone,
      designation: designation,
      joiningDate: joiningDate,
      isActive: isActive == 1,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  factory EmployeeModel.fromEntity(Employee entity) {
    return EmployeeModel(
      id: entity.id,
      employeeCode: entity.employeeCode,
      name: entity.name,
      phone: entity.phone,
      designation: entity.designation,
      joiningDate: entity.joiningDate,
      isActive: entity.isActive ? 1 : 0,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }
}

