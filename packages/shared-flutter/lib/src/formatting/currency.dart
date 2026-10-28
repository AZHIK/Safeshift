import 'package:intl/intl.dart';

final NumberFormat _tzs = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'TZS ',
  decimalDigits: 0,
);

/// Formats a Tanzanian shilling amount without decimal places.
String formatTzs(num amount) => _tzs.format(amount);

/// Formats an already-validated ISO 4217 amount using its currency code.
String formatMoney(num amount, String currencyCode) {
  final format = NumberFormat.currency(
    locale: 'en_US',
    name: currencyCode,
    symbol: '$currencyCode ',
    decimalDigits: 2,
  );
  return format.format(amount);
}
