class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String employeeDirectory = '/employees';
  static const String employeeDetail = '/employee/:id';
  static const String leaveReport = '/leave-report';
  static const String attendance = '/attendance';
  static const String markAttendance = '/attendance/mark';
  static const String employeeReports = '/employee-reports';
  static const String salary = '/salary';
  static const String adminProfile = '/admin';
  static const String backupRestore = '/admin/backup-restore';

  static String employeeDetailPath(String id) => '/employee/$id';
}


