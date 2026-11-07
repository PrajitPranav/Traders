import 'package:intl/intl.dart';

/// Formatter for handling Indian Currency (INR / ₹) with exact integer paise precision.
/// Prevents IEEE-754 floating point arithmetic issues.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrWithDecimalsFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Converts paise (integer) to formatted Indian Rupee string (e.g. ₹20,000).
  /// If [showDecimalsIfAny] is true and there are non-zero paise, shows two decimal digits.
  static String formatPaise(int paise, {bool showSymbol = true, bool showDecimalsIfAny = true}) {
    final bool isNegative = paise < 0;
    final int absPaise = paise.abs();
    final int rupees = absPaise ~/ 100;
    final int remainingPaise = absPaise % 100;

    String formatted;
    if (showDecimalsIfAny && remainingPaise > 0) {
      formatted = _inrWithDecimalsFormatter.format(absPaise / 100);
    } else {
      formatted = _inrFormatter.format(rupees);
    }

    if (!showSymbol) {
      formatted = formatted.replaceAll('₹', '').trim();
    }

    return isNegative ? '-$formatted' : formatted;
  }

  /// Converts integer rupees to integer paise (1 Rupee = 100 Paise).
  static int rupeesToPaise(num rupees) {
    return (rupees * 100).round();
  }

  /// Parses user-input string into integer paise safely.
  /// Returns 0 if invalid.
  static int parseInputToPaise(String input) {
    final clean = input.replaceAll('₹', '').replaceAll(',', '').trim();
    if (clean.isEmpty) return 0;
    final parsed = double.tryParse(clean);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return 0;
    return (parsed * 100).round();
  }

  /// Converts paise to rupees as double (strictly for visual display purposes).
  static double paiseToRupees(int paise) {
    return paise / 100.0;
  }
}

