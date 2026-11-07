enum AttendanceStatus {
  present,
  absent;

  static AttendanceStatus fromString(String value) {
    if (value.toLowerCase() == 'present') return AttendanceStatus.present;
    return AttendanceStatus.absent;
  }

  String toDbString() {
    return name;
  }
}

/// Business entity representing a single day's attendance for an employee.
class Attendance {
  final String id;
  final String employeeId;
  final String attendanceDate; // ISO-8601 YYYY-MM-DD
  final AttendanceStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Attendance({
    required this.id,
    required this.employeeId,
    required this.attendanceDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPresent => status == AttendanceStatus.present;
  bool get isAbsent => status == AttendanceStatus.absent;

  Attendance copyWith({
    String? id,
    String? employeeId,
    String? attendanceDate,
    AttendanceStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Attendance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

