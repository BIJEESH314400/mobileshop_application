import 'package:intl/intl.dart';

/// Formats a number as Indian Rupees, e.g. `formatInr(31499)` -> "₹31,499".
String formatInr(num amount) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}
