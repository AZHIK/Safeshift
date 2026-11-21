import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Which numbers a field accepts.
enum PhoneKind {
  /// Must receive SMS: login, recipients, SOS contacts.
  mobile,

  /// Any reachable number (mobile or landline), e.g. a business line.
  any,
}

/// Result of checking a phone number against its country's numbering plan.
class PhoneCheck {
  const PhoneCheck._({this.e164, this.isoCode, this.error});

  /// The number in international E.164 form (`+255712345678`) when valid.
  final String? e164;

  /// Two-letter country of the number (`TZ`, `KE`, ...), when recognised.
  final String? isoCode;

  /// Customer-facing reason the number is not accepted; null when valid.
  final String? error;

  bool get isValid => e164 != null;

  /// Flag emoji for [isoCode], or null.
  String? get flag {
    final code = isoCode;
    if (code == null || code.length != 2) return null;
    return String.fromCharCodes(
      code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
    );
  }
}

/// Default country for numbers typed without a `+` country code.
const String defaultPhoneCountry = 'TZ';

/// Checks [input] against the numbering plan of its country.
///
/// Numbers with a `+` (or `00`) prefix are checked for that country; local
/// numbers (`0712 345 678`, `712345678`) are read as [defaultCountry]. Uses
/// Google's libphonenumber metadata, so lengths and prefixes follow each
/// country's real plan.
PhoneCheck checkPhone(
  String input, {
  PhoneKind kind = PhoneKind.mobile,
  String defaultCountry = defaultPhoneCountry,
}) {
  final cleaned = input.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (cleaned.isEmpty) {
    return const PhoneCheck._(error: 'Enter a phone number');
  }
  if (!RegExp(r'^(\+|00)?[0-9]+$').hasMatch(cleaned)) {
    return const PhoneCheck._(error: 'Use digits only, with an optional +');
  }
  final normalised = cleaned.startsWith('00')
      ? '+${cleaned.substring(2)}'
      : cleaned;
  final caller = IsoCode.values.byName(defaultCountry.toUpperCase());
  final PhoneNumber phone;
  try {
    phone = PhoneNumber.parse(normalised, callerCountry: caller);
  } on PhoneNumberException {
    return const PhoneCheck._(
      error: 'Unknown country code. Start with + and the country code',
    );
  } catch (_) {
    return const PhoneCheck._(error: 'Enter a valid phone number');
  }

  final iso = phone.isoCode.name;
  final valid = switch (kind) {
    PhoneKind.mobile => phone.isValid(type: PhoneNumberType.mobile),
    PhoneKind.any => phone.isValid(),
  };
  if (!valid) {
    final country = iso == defaultCountry.toUpperCase()
        ? 'Tanzanian'
        : '+${phone.countryCode}';
    final lengthOk = kind == PhoneKind.mobile
        ? phone.isValidLength(type: PhoneNumberType.mobile) || phone.isValid()
        : phone.isValidLength();
    final error = !lengthOk
        ? 'This $country number has the wrong number of digits'
        : kind == PhoneKind.mobile && phone.isValid()
        ? 'Enter a mobile number that can receive SMS'
        : 'This is not a valid $country number';
    return PhoneCheck._(isoCode: iso, error: error);
  }
  return PhoneCheck._(e164: phone.international, isoCode: iso);
}

/// The number in E.164 form, or null when it is not valid.
String? normalizePhone(
  String input, {
  PhoneKind kind = PhoneKind.mobile,
  String defaultCountry = defaultPhoneCountry,
}) => checkPhone(input, kind: kind, defaultCountry: defaultCountry).e164;

/// Readable international form for display: `+255 712 345 678`.
String formatPhoneInternational(String e164) {
  try {
    final phone = PhoneNumber.parse(e164);
    return '+${phone.countryCode} '
        '${phone.formatNsn(format: NsnFormat.international)}';
  } catch (_) {
    return e164;
  }
}
