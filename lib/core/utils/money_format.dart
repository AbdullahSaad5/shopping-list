import 'package:intl/intl.dart';

/// Formats integer minor units (paisa) as a rupee string: 123456 → "Rs 1,235".
/// PKR displays whole rupees (0 decimal digits), like ledgr.
String formatMinor(int minor, {String symbol = 'Rs '}) {
  final rupees = (minor / 100).round();
  return '$symbol${NumberFormat('#,##0').format(rupees)}';
}
