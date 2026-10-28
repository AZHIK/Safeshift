import 'package:intl/intl.dart';

/// East Africa Time is UTC+3 year-round (no daylight saving).
const Duration _eastAfricaTimeOffset = Duration(hours: 3);

final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm', 'en_US');
final DateFormat _dateOnly = DateFormat('d MMM yyyy', 'en_US');
final DateFormat _timeOnly = DateFormat('HH:mm', 'en_US');

/// Converts an instant to Dar es Salaam wall-clock time.
DateTime toDarEsSalaam(DateTime value) => value.toUtc().add(_eastAfricaTimeOffset);

String formatDarEsSalaamDateTime(DateTime value) => _dateTime.format(toDarEsSalaam(value));

String formatDarEsSalaamDate(DateTime value) => _dateOnly.format(toDarEsSalaam(value));

String formatDarEsSalaamTime(DateTime value) => _timeOnly.format(toDarEsSalaam(value));
