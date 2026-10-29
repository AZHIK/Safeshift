/// Builds a human-readable, collision-resistant reference number.
///
/// Example: `DSR-20261029-8F31C2A4`. The timestamp component makes the value
/// readable in support conversations while microseconds keep client-side
/// inserts unique in practice.
String generateReferenceNumber(String prefix, DateTime now) {
  final normalizedPrefix = prefix
      .trim()
      .toUpperCase()
      .replaceAll(RegExp('[^A-Z0-9]'), '');
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final suffix = now.microsecondsSinceEpoch.toRadixString(36).toUpperCase();
  final safePrefix = normalizedPrefix.isEmpty ? 'REF' : normalizedPrefix;
  return '$safePrefix-$year$month$day-$suffix';
}
