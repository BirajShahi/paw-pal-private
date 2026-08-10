/// In-memory card form validators for the simulated payment UI.
///
/// These helpers must never be used to send card data to a repository or API.
String? validateCardholderName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Enter the cardholder name.';
  }
  if (trimmed.length < 2 || trimmed.length > 80) {
    return 'Cardholder name must be between 2 and 80 characters.';
  }
  return null;
}

String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

String formatCardNumberGroups(String raw) {
  final digits = digitsOnly(raw);
  final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
  final buffer = StringBuffer();
  for (var i = 0; i < limited.length; i++) {
    if (i > 0 && i % 4 == 0) {
      buffer.write(' ');
    }
    buffer.write(limited[i]);
  }
  return buffer.toString();
}

String? validateCardNumber(String? value) {
  final digits = digitsOnly(value ?? '');
  if (digits.length != 16) {
    return 'Enter a 16-digit card number.';
  }
  return null;
}

String formatExpiryInput(String raw) {
  final digits = digitsOnly(raw);
  final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
  if (limited.length <= 2) {
    return limited;
  }
  return '${limited.substring(0, 2)}/${limited.substring(2)}';
}

String? validateExpiryDate(String? value, {DateTime? now}) {
  final trimmed = value?.trim() ?? '';
  final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(trimmed);
  if (match == null) {
    return 'Enter expiry as MM/YY.';
  }

  final month = int.tryParse(match.group(1)!);
  final yearTwoDigits = int.tryParse(match.group(2)!);
  if (month == null || yearTwoDigits == null || month < 1 || month > 12) {
    return 'Enter a valid expiry month between 01 and 12.';
  }

  final clock = now ?? DateTime.now();
  final year = 2000 + yearTwoDigits;
  // Card is valid through the end of the expiry month.
  final expiryEnd = DateTime(year, month + 1);
  if (!expiryEnd.isAfter(DateTime(clock.year, clock.month))) {
    return 'This card appears to be expired.';
  }
  return null;
}

String? validateCvv(String? value) {
  final digits = digitsOnly(value ?? '');
  if (digits.length != 3) {
    return 'Enter a 3-digit CVV.';
  }
  return null;
}
