/// Business entity representing an employee in Saravanas.
class Employee {
  final String id;
  final String employeeCode;
  final String name;
  final String? phone;
  final String? designation;
  final String? joiningDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Employee({
    required this.id,
    required this.employeeCode,
    required this.name,
    this.phone,
    this.designation,
    this.joiningDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Initials generated from name for avatar display
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Employee copyWith({
    String? id,
    String? employeeCode,
    String? name,
    String? phone,
    String? designation,
    String? joiningDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      designation: designation ?? this.designation,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

