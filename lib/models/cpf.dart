String normalizeCpf(String value) => value.replaceAll(RegExp(r'\D'), '');

bool isValidCpf(String value) {
  final digits = normalizeCpf(value);
  if (digits.isEmpty) return true;
  if (digits.length != 11 ||
      digits.split('').every((digit) => digit == digits[0])) {
    return false;
  }

  for (var checkDigitIndex = 9; checkDigitIndex <= 10; checkDigitIndex++) {
    var sum = 0;
    for (var index = 0; index < checkDigitIndex; index++) {
      sum += int.parse(digits[index]) * (checkDigitIndex + 1 - index);
    }
    final remainder = sum % 11;
    final expectedDigit = remainder < 2 ? 0 : 11 - remainder;
    if (int.parse(digits[checkDigitIndex]) != expectedDigit) return false;
  }
  return true;
}
