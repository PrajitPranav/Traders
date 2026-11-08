import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/advance.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/salary_summary.dart';
import '../../domain/repositories/advance_repository.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/repositories/salary_repository.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class EmployeeMonthlyReportItem {
  final Employee employee;
  final SalarySummary salarySummary;
  final Map<String, AttendanceStatus> attendanceMap;
  final List<Advance> advances;
  final int presentDays;
  final int absentDays;
  final int unmarkedDays;

  const EmployeeMonthlyReportItem({
    required this.employee,
    required this.salarySummary,
    required this.attendanceMap,
    required this.advances,
    required this.presentDays,
    required this.absentDays,
    required this.unmarkedDays,
  });
}

class GeneratedExcelReport {
  final String fileName;
  final String? filePath;
  final List<int> bytes;
  final List<EmployeeMonthlyReportItem> items;
  final int year;
  final int month;

  const GeneratedExcelReport({
    required this.fileName,
    this.filePath,
    required this.bytes,
    required this.items,
    required this.year,
    required this.month,
  });
}

class ExcelReportService {
  final EmployeeRepository employeeRepository;
  final AttendanceRepository attendanceRepository;
  final SalaryRepository salaryRepository;
  final AdvanceRepository advanceRepository;

  const ExcelReportService({
    required this.employeeRepository,
    required this.attendanceRepository,
    required this.salaryRepository,
    required this.advanceRepository,
  });

  static const String sheetMonthlySummary = 'Monthly Summary';
  static const String sheetAttendanceDetails = 'Attendance Details';
  static const String sheetPrepaidHistory = 'Prepaid Transaction History';
  static const String sheetFinancialSummary = 'Employee Financial Summary';

  /// Builds the exact file name required by specification:
  /// - Consolidated: Saravanas_Employee_Report_November_2026.xlsx
  /// - Individual: Saravanas_EMP0001_November_2026.xlsx
  static String buildFileName({
    required int year,
    required int month,
    String? employeeCode,
  }) {
    final monthName = DateFormat('MMMM').format(DateTime(year, month, 1));
    if (employeeCode != null && employeeCode.trim().isNotEmpty) {
      return 'Saravanas_${employeeCode.trim()}_${monthName}_$year.xlsx';
    }
    return 'Saravanas_Employee_Report_${monthName}_$year.xlsx';
  }

  /// Collects all database records for the selected month/year and employee scope.
  Future<List<EmployeeMonthlyReportItem>> collectReportData({
    required int year,
    required int month,
    String? employeeId,
  }) async {
    final List<Employee> targetEmployees;
    if (employeeId != null) {
      final emp = await employeeRepository.getEmployeeById(employeeId);
      targetEmployees = emp != null ? [emp] : [];
    } else {
      targetEmployees =
          await employeeRepository.getAllEmployees(includeInactive: false);
    }

    final salaryPeriod =
        '$year-${month.toString().padLeft(2, '0')}';
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final items = <EmployeeMonthlyReportItem>[];
    for (final emp in targetEmployees) {
      final attendanceMap =
          await attendanceRepository.getMonthAttendanceMap(emp.id, year, month);
      final salarySummary =
          await salaryRepository.getSalarySummary(emp.id, salaryPeriod);
      final advances =
          await advanceRepository.getAdvancesForPeriod(emp.id, salaryPeriod);

      // Sort advances chronologically by transactionDate ascending
      final sortedAdvances = List<Advance>.from(advances)
        ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

      int presentDays = 0;
      int absentDays = 0;
      for (final status in attendanceMap.values) {
        if (status == AttendanceStatus.present) {
          presentDays++;
        } else if (status == AttendanceStatus.absent) {
          absentDays++;
        }
      }
      final unmarkedDays =
          (daysInMonth - (presentDays + absentDays)).clamp(0, daysInMonth);

      items.add(
        EmployeeMonthlyReportItem(
          employee: emp,
          salarySummary: salarySummary,
          attendanceMap: attendanceMap,
          advances: sortedAdvances,
          presentDays: presentDays,
          absentDays: absentDays,
          unmarkedDays: unmarkedDays,
        ),
      );
    }

    return items;
  }

  /// Generates a real .xlsx binary workbook in memory containing all 4 sheets.
  Future<GeneratedExcelReport> generateExcelReport({
    required int year,
    required int month,
    String? employeeId,
  }) async {
    final items = await collectReportData(
      year: year,
      month: month,
      employeeId: employeeId,
    );

    final singleEmployeeCode =
        (employeeId != null && items.length == 1) ? items.first.employee.employeeCode : null;

    final fileName = buildFileName(
      year: year,
      month: month,
      employeeCode: singleEmployeeCode,
    );

    final salaryPeriod = '$year-${month.toString().padLeft(2, '0')}';
    final monthYearLabel =
        DateFormat('MMMM yyyy').format(DateTime(year, month, 1));
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final excel = Excel.createExcel();

    // Rename default Sheet1 to Monthly Summary
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    if (defaultSheet != sheetMonthlySummary) {
      excel.rename(defaultSheet, sheetMonthlySummary);
    }

    final sheet1 = excel[sheetMonthlySummary];
    final sheet2 = excel[sheetAttendanceDetails];
    final sheet3 = excel[sheetPrepaidHistory];
    final sheet4 = excel[sheetFinancialSummary];

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: ExcelColor.fromHexString('#142B50'),
    );

    final subtitleStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#087E8B'),
    );

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#142B50'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final boldTotalStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#142B50'),
      backgroundColorHex: ExcelColor.fromHexString('#E0F2F1'),
    );

    // =========================================================================
    // SHEET 1: MONTHLY SUMMARY
    // =========================================================================
    _appendTitleBanner(
      sheet1,
      title: 'SARAVANAS — MONTHLY EMPLOYEE SUMMARY REPORT',
      subtitle: 'Reporting Period: $monthYearLabel ($salaryPeriod)',
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );

    final sheet1Headers = [
      'Employee Code',
      'Employee Name',
      'Designation',
      'Monthly Salary',
      'Total Days Present',
      'Total Days Absent',
      'Total Days Not Marked',
      'Total Prepaid Amount',
      'Number of Advance Transactions',
      'Remaining Salary',
    ];
    _appendStyledHeaderRow(sheet1, sheet1Headers, headerStyle, rowIndex: 3);

    int totalSalaryPaise = 0;
    int totalPrepaidPaise = 0;
    int totalRemainingPaise = 0;
    int totalPresentAll = 0;
    int totalAbsentAll = 0;
    int totalUnmarkedAll = 0;
    int totalAdvanceCountAll = 0;

    for (final item in items) {
      totalSalaryPaise += item.salarySummary.monthlySalaryPaise;
      totalPrepaidPaise += item.salarySummary.totalAdvancesPaise;
      totalRemainingPaise += item.salarySummary.remainingSalaryPaise;
      totalPresentAll += item.presentDays;
      totalAbsentAll += item.absentDays;
      totalUnmarkedAll += item.unmarkedDays;
      totalAdvanceCountAll += item.advances.length;

      sheet1.appendRow([
        TextCellValue(item.employee.employeeCode),
        TextCellValue(item.employee.name),
        TextCellValue(item.employee.designation ?? 'Employee'),
        TextCellValue(
          CurrencyFormatter.formatPaise(item.salarySummary.monthlySalaryPaise),
        ),
        IntCellValue(item.presentDays),
        IntCellValue(item.absentDays),
        IntCellValue(item.unmarkedDays),
        TextCellValue(
          CurrencyFormatter.formatPaise(item.salarySummary.totalAdvancesPaise),
        ),
        IntCellValue(item.advances.length),
        TextCellValue(
          CurrencyFormatter.formatPaise(
            item.salarySummary.remainingSalaryPaise,
          ),
        ),
      ]);
    }

    if (items.isNotEmpty) {
      final totalRowIdx = sheet1.maxRows;
      sheet1.appendRow([
        TextCellValue('TOTAL'),
        TextCellValue('${items.length} Employees'),
        TextCellValue('-'),
        TextCellValue(CurrencyFormatter.formatPaise(totalSalaryPaise)),
        IntCellValue(totalPresentAll),
        IntCellValue(totalAbsentAll),
        IntCellValue(totalUnmarkedAll),
        TextCellValue(CurrencyFormatter.formatPaise(totalPrepaidPaise)),
        IntCellValue(totalAdvanceCountAll),
        TextCellValue(CurrencyFormatter.formatPaise(totalRemainingPaise)),
      ]);
      _styleRow(sheet1, totalRowIdx, sheet1Headers.length, boldTotalStyle);
    }

    _setSheetColumnWidths(sheet1, [16, 24, 20, 18, 18, 18, 20, 20, 26, 18]);

    // =========================================================================
    // SHEET 2: ATTENDANCE DETAILS
    // =========================================================================
    _appendTitleBanner(
      sheet2,
      title: 'SARAVANAS — MONTHLY ATTENDANCE DETAILS',
      subtitle: 'Reporting Period: $monthYearLabel ($salaryPeriod)',
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );

    final sheet2Headers = [
      'Employee Code',
      'Employee Name',
      'Date',
      'Day',
      'Attendance Status',
    ];
    _appendStyledHeaderRow(sheet2, sheet2Headers, headerStyle, rowIndex: 3);

    final dayNameFormat = DateFormat('EEEE');
    for (final item in items) {
      for (int d = 1; d <= daysInMonth; d++) {
        final dateObj = DateTime(year, month, d);
        final dateIso = AppDateUtils.toIsoDateString(dateObj);
        final dayName = dayNameFormat.format(dateObj);
        final status = item.attendanceMap[dateIso];

        final statusLabel = status == AttendanceStatus.present
            ? 'Present'
            : (status == AttendanceStatus.absent ? 'Absent' : 'Not Marked');

        sheet2.appendRow([
          TextCellValue(item.employee.employeeCode),
          TextCellValue(item.employee.name),
          TextCellValue(dateIso),
          TextCellValue(dayName),
          TextCellValue(statusLabel),
        ]);
      }
    }

    _setSheetColumnWidths(sheet2, [16, 24, 16, 16, 20]);

    // =========================================================================
    // SHEET 3: PREPAID TRANSACTION HISTORY
    // =========================================================================
    _appendTitleBanner(
      sheet3,
      title: 'SARAVANAS — PREPAID SALARY ADVANCE TRANSACTIONS',
      subtitle: 'Reporting Period: $monthYearLabel ($salaryPeriod)',
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );

    final sheet3Headers = [
      'Employee Code',
      'Employee Name',
      'Transaction Date',
      'Amount',
      'Description',
      'Salary Period',
    ];
    _appendStyledHeaderRow(sheet3, sheet3Headers, headerStyle, rowIndex: 3);

    // Flatten and sort all advances in this period by transaction date
    final allPeriodAdvances = <({Employee employee, Advance advance})>[];
    for (final item in items) {
      for (final adv in item.advances) {
        allPeriodAdvances.add((employee: item.employee, advance: adv));
      }
    }
    allPeriodAdvances.sort(
      (a, b) =>
          a.advance.transactionDate.compareTo(b.advance.transactionDate),
    );

    for (final record in allPeriodAdvances) {
      sheet3.appendRow([
        TextCellValue(record.employee.employeeCode),
        TextCellValue(record.employee.name),
        TextCellValue(record.advance.transactionDate),
        TextCellValue(
          CurrencyFormatter.formatPaise(record.advance.amountPaise),
        ),
        TextCellValue(
          record.advance.description?.isNotEmpty == true
              ? record.advance.description!
              : 'Salary Advance',
        ),
        TextCellValue(record.advance.salaryPeriod),
      ]);
    }

    if (allPeriodAdvances.isNotEmpty) {
      final totalAdvRow = sheet3.maxRows;
      sheet3.appendRow([
        TextCellValue('TOTAL'),
        TextCellValue('${allPeriodAdvances.length} Transactions'),
        TextCellValue('-'),
        TextCellValue(CurrencyFormatter.formatPaise(totalPrepaidPaise)),
        TextCellValue('-'),
        TextCellValue(salaryPeriod),
      ]);
      _styleRow(sheet3, totalAdvRow, sheet3Headers.length, boldTotalStyle);
    }

    _setSheetColumnWidths(sheet3, [16, 24, 18, 18, 28, 16]);

    // =========================================================================
    // SHEET 4: EMPLOYEE FINANCIAL SUMMARY
    // =========================================================================
    _appendTitleBanner(
      sheet4,
      title: 'SARAVANAS — EMPLOYEE FINANCIAL SUMMARY',
      subtitle: 'Reporting Period: $monthYearLabel ($salaryPeriod)',
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );

    final sheet4Headers = [
      'Employee Code',
      'Employee Name',
      'Applicable Monthly Salary',
      'Total Advance',
      'Remaining Salary',
      'Salary Period',
    ];
    _appendStyledHeaderRow(sheet4, sheet4Headers, headerStyle, rowIndex: 3);

    for (final item in items) {
      sheet4.appendRow([
        TextCellValue(item.employee.employeeCode),
        TextCellValue(item.employee.name),
        TextCellValue(
          CurrencyFormatter.formatPaise(item.salarySummary.monthlySalaryPaise),
        ),
        TextCellValue(
          CurrencyFormatter.formatPaise(item.salarySummary.totalAdvancesPaise),
        ),
        TextCellValue(
          CurrencyFormatter.formatPaise(
            item.salarySummary.remainingSalaryPaise,
          ),
        ),
        TextCellValue(salaryPeriod),
      ]);
    }

    if (items.isNotEmpty) {
      final finTotalRow = sheet4.maxRows;
      sheet4.appendRow([
        TextCellValue('TOTAL'),
        TextCellValue('${items.length} Employees'),
        TextCellValue(CurrencyFormatter.formatPaise(totalSalaryPaise)),
        TextCellValue(CurrencyFormatter.formatPaise(totalPrepaidPaise)),
        TextCellValue(CurrencyFormatter.formatPaise(totalRemainingPaise)),
        TextCellValue(salaryPeriod),
      ]);
      _styleRow(sheet4, finTotalRow, sheet4Headers.length, boldTotalStyle);
    }

    _setSheetColumnWidths(sheet4, [16, 24, 24, 18, 18, 16]);

    final encodedBytes = excel.encode();
    if (encodedBytes == null || encodedBytes.isEmpty) {
      throw StateError('Failed to encode Excel (.xlsx) workbook.');
    }

    return GeneratedExcelReport(
      fileName: fileName,
      bytes: encodedBytes,
      items: items,
      year: year,
      month: month,
    );
  }

  /// Generates and writes the .xlsx report to device storage, verifying file integrity.
  Future<GeneratedExcelReport> generateAndSaveReport({
    required int year,
    required int month,
    String? employeeId,
    Directory? overrideDirectory,
  }) async {
    final report = await generateExcelReport(
      year: year,
      month: month,
      employeeId: employeeId,
    );

    Directory targetDir;
    if (overrideDirectory != null) {
      targetDir = overrideDirectory;
    } else {
      targetDir = await _resolveAccessibleDirectory();
    }

    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    final fullPath = p.join(targetDir.path, report.fileName);
    final file = File(fullPath);
    await file.writeAsBytes(report.bytes, flush: true);

    if (!file.existsSync() || file.lengthSync() == 0) {
      throw FileSystemException(
        'Excel file verification failed after writing.',
        fullPath,
      );
    }

    return GeneratedExcelReport(
      fileName: report.fileName,
      filePath: fullPath,
      bytes: report.bytes,
      items: report.items,
      year: report.year,
      month: report.month,
    );
  }

  /// Shares or opens the generated Excel file using the Android system sheet.
  Future<void> shareGeneratedReport(GeneratedExcelReport report) async {
    final path = report.filePath;
    if (path == null || !File(path).existsSync()) {
      throw StateError('Report file does not exist on disk.');
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: report.fileName,
        text: 'Saravanas Monthly Employee Report (${report.fileName})',
      ),
    );
  }

  Future<Directory> _resolveAccessibleDirectory() async {
    if (Platform.isAndroid) {
      // Try public Download directory first if accessible under Android storage rules
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (downloadDir.existsSync()) {
          final probe = File(
            p.join(
              downloadDir.path,
              '.saravanas_probe_${DateTime.now().millisecondsSinceEpoch}',
            ),
          );
          await probe.writeAsBytes([1], flush: true);
          await probe.delete();
          return downloadDir;
        }
      } catch (_) {
        // Fallback to app-specific external or documents directory
      }

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final reportsDir = Directory(p.join(extDir.path, 'Reports'));
          if (!reportsDir.existsSync()) {
            await reportsDir.create(recursive: true);
          }
          return reportsDir;
        }
      } catch (_) {}
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(docsDir.path, 'Reports'));
    if (!reportsDir.existsSync()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }

  void _appendTitleBanner(
    Sheet sheet, {
    required String title,
    required String subtitle,
    required CellStyle titleStyle,
    required CellStyle subtitleStyle,
  }) {
    sheet.appendRow([TextCellValue(title)]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle =
        titleStyle;

    sheet.appendRow([TextCellValue(subtitle)]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle =
        subtitleStyle;

    // Blank spacer row
    sheet.appendRow([TextCellValue('')]);
  }

  void _appendStyledHeaderRow(
    Sheet sheet,
    List<String> headers,
    CellStyle headerStyle, {
    required int rowIndex,
  }) {
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    _styleRow(sheet, rowIndex, headers.length, headerStyle);
  }

  void _styleRow(
    Sheet sheet,
    int rowIndex,
    int colCount,
    CellStyle style,
  ) {
    for (int col = 0; col < colCount; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
      );
      cell.cellStyle = style;
    }
  }

  void _setSheetColumnWidths(Sheet sheet, List<double> widths) {
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }
}

