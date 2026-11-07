import 'package:intl/intl.dart';

/// Date formatting and normalization utilities.
/// Ensures consistent ISO-8601 date strings for SQLite storage and queries.
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _periodFormat = DateFormat('yyyy-MM');
  static final DateFormat _displayDate = DateFormat('dd MMM yyyy');
  static final DateFormat _displayMonthYear = DateFormat('MMMM yyyy');
  static final DateFormat _shortDate = DateFormat('dd MMM');

  /// Normalizes DateTime to date only (removes time component).
  static DateTime normalizeDate(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Formats date to 'yyyy-MM-dd' for SQLite persistence.
  static String toIsoDateString(DateTime date) {
    return _isoDate.format(date);
  }

  /// Parses 'yyyy-MM-dd' to normalized DateTime.
  static DateTime parseIsoDateString(String dateStr) {
    return DateTime.parse(dateStr);
  }

  /// Extracts salary period 'yyyy-MM' from a DateTime.
  static String toSalaryPeriod(DateTime date) {
    return _periodFormat.format(date);
  }

  /// Formats date to readable string, e.g., '15 Oct 2026'.
  static String formatDisplayDate(DateTime date) {
    return _displayDate.format(date);
  }

  /// Formats date to 'October 2026'.
  static String formatMonthYear(DateTime date) {
    return _displayMonthYear.format(date);
  }

  /// Formats date string to 'dd MMM', e.g., '15 Oct'.
  static String formatShortDate(DateTime date) {
    return _shortDate.format(date);
  }

  /// Converts 'yyyy-MM' to readable month string (e.g. 'October 2026').
  static String formatPeriodDisplay(String periodStr) {
    try {
      final parts = periodStr.split('-');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        return _displayMonthYear.format(DateTime(year, month, 1));
      }
    } catch (_) {}
    return periodStr;
  }
}

