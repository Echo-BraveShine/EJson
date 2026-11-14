/// Expands numbered captures, the whole match ($0 or $&), named captures, and
/// literal dollar signs ($$). Unknown references remain literal text.
String expandRegexReplacement(String template, Match match) {
  return template.replaceAllMapped(RegExp(r'\$\$|\$&|\$[0-9]+|\$<[^>]+>'), (
    token,
  ) {
    final text = token[0]!;
    if (text == r'$$') return r'$';
    if (text == r'$&') return match[0]!;
    if (text.startsWith(r'$<')) {
      final name = text.substring(2, text.length - 1);
      if (match is RegExpMatch && match.groupNames.contains(name)) {
        return match.namedGroup(name) ?? '';
      }
      return text;
    }
    final digits = text.substring(1);
    final maxDigits = match.groupCount.toString().length;
    for (
      var length = digits.length < maxDigits ? digits.length : maxDigits;
      length > 0;
      length--
    ) {
      final index = int.tryParse(digits.substring(0, length));
      if (index != null && index <= match.groupCount) {
        return '${match[index] ?? ''}${digits.substring(length)}';
      }
    }
    return text;
  });
}
