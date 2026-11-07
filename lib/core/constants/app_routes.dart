class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String employeeDetail = '/employee/:id';
  static const String adminProfile = '/admin';
  static const String backupRestore = '/admin/backup-restore';

  static String employeeDetailPath(String id) => '/employee/$id';
}

