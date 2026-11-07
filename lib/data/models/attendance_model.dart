import '../../domain/entities/attendance.dart';

class AttendanceModel {
  final String id;
  final String employeeId;
  final String attendanceDate;
  final String status;
  final String createdAt;
  final String updatedAt;

  AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.attendanceDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      attendanceDate: map['attendance_date'] as String,
      status: map['status'] as String,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'attendance_date': attendanceDate,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Attendance toEntity() {
    return Attendance(
      id: id,
      employeeId: employeeId,
      attendanceDate: attendanceDate,
      status: AttendanceStatus.fromString(status),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  factory AttendanceModel.fromEntity(Attendance entity) {
    return AttendanceModel(
      id: entity.id,
      employeeId: entity.employeeId,
      attendanceDate: entity.attendanceDate,
      status: entity.status.toDbString(),
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }
}

