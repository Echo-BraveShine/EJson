// Compare decimal spellings directly so large integers and exponents stay exact.
int compareJsonNumbers(String left, String right) {
  ({int sign, String digits, BigInt magnitude}) decimal(String raw) {
    final negative = raw.startsWith('-');
    final unsigned = negative ? raw.substring(1) : raw;
    final parts = unsigned.toLowerCase().split('e');
    final mantissa = parts.first;
    final dot = mantissa.indexOf('.');
    final fractionLength = dot < 0 ? 0 : mantissa.length - dot - 1;
    final digits = mantissa
        .replaceAll('.', '')
        .replaceFirst(RegExp(r'^0+'), '');
    final exponent = parts.length == 1 ? BigInt.zero : BigInt.parse(parts.last);
    return (
      sign: digits.isEmpty
          ? 0
          : negative
          ? -1
          : 1,
      digits: digits,
      magnitude: exponent + BigInt.from(digits.length - fractionLength),
    );
  }

  final a = decimal(left);
  final b = decimal(right);
  final signOrder = a.sign.compareTo(b.sign);
  if (signOrder != 0) return signOrder;
  if (a.sign == 0) return 0;
  final magnitudeOrder = a.magnitude.compareTo(b.magnitude);
  if (magnitudeOrder != 0) return magnitudeOrder * a.sign;
  final length = a.digits.length > b.digits.length
      ? a.digits.length
      : b.digits.length;
  return a.digits
          .padRight(length, '0')
          .compareTo(b.digits.padRight(length, '0')) *
      a.sign;
}
