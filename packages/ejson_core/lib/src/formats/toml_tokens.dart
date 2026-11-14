/// Token boundaries preserve comments and quoted text during formatting and
/// retain numeric spelling when the TOML parser's semantic float uses a double.
class TomlToken {
  const TomlToken(this.text, this.start, this.end, this.kind);
  final String text;
  final int start, end;
  final String kind;
}

List<TomlToken> tokenizeToml(String source) {
  final result = <TomlToken>[];
  var i = 0;
  while (i < source.length) {
    final start = i;
    final c = source[i];
    String kind;
    if (c == '"' || c == "'") {
      kind = 'string';
      final triple = source.startsWith(c * 3, i);
      i += triple ? 3 : 1;
      while (i < source.length) {
        if (c == '"' && source[i] == r'\') {
          i += 2;
          continue;
        }
        if (source[i] == c) {
          var end = i + 1;
          while (end < source.length && source[end] == c) {
            end++;
          }
          if (!triple) {
            i++;
            break;
          }
          if (end - i >= 3) {
            i = end;
            break;
          }
          i = end;
        } else {
          i++;
        }
      }
      i = i.clamp(0, source.length);
    } else if (c == '#') {
      kind = 'comment';
      while (i < source.length && source[i] != '\n' && source[i] != '\r') {
        i++;
      }
    } else if (RegExp(r'\s').hasMatch(c)) {
      kind = 'space';
      while (i < source.length && RegExp(r'\s').hasMatch(source[i])) {
        i++;
      }
    } else if ('[]=,{}'.contains(c)) {
      kind = 'symbol';
      i++;
    } else {
      kind = 'bare';
      while (i < source.length &&
          !RegExp(r'''[\s\[\]=,{}#"']''').hasMatch(source[i])) {
        i++;
      }
    }
    result.add(TomlToken(source.substring(start, i), start, i, kind));
  }
  return result;
}

String normalizeTomlNumber(String source) {
  var token = source.replaceAll('_', '');
  if (token.startsWith('+')) token = token.substring(1);
  final radix = RegExp(r'^0([xob])(.+)$').firstMatch(token);
  if (radix != null) {
    return BigInt.parse(
      radix[2]!,
      radix: switch (radix[1]) {
        'x' => 16,
        'o' => 8,
        _ => 2,
      },
    ).toString();
  }
  return token;
}

({String source, Map<String, String> numbers}) protectTomlNumbers(
  String source,
) {
  final tokens = tokenizeToml(source);
  var prefix = '__ejson_numeric_';
  while (source.contains(prefix)) {
    prefix += '_';
  }
  final numbers = <String, String>{};
  final output = StringBuffer();
  var header = false;
  var statementStart = true;
  var depth = 0;
  final number = RegExp(
    r'^[+-]?(?:\d[\d_]*(?:\.[\d_]+)?(?:[eE][+-]?[\d_]+)?|0[xob][0-9a-fA-F_]+|inf|nan)$',
  );
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.kind == 'space' &&
        (token.text.contains('\n') || token.text.contains('\r')) &&
        depth == 0) {
      statementStart = true;
      header = false;
    }
    if (statementStart && token.text == '[' && depth == 0) header = true;
    if (token.kind != 'space' && token.kind != 'comment') {
      statementStart = false;
    }
    if (!header && token.kind == 'symbol') {
      if (token.text == '[' || token.text == '{') depth++;
      if (token.text == ']' || token.text == '}') depth--;
    }
    var next = i + 1;
    while (next < tokens.length && tokens[next].kind == 'space') {
      next++;
    }
    final isKey = next < tokens.length && tokens[next].text == '=';
    if (!header &&
        !isKey &&
        token.kind == 'bare' &&
        number.hasMatch(token.text)) {
      final key = '$prefix${numbers.length}';
      numbers[key] = normalizeTomlNumber(token.text);
      output.write('"$key"');
    } else {
      output.write(token.text);
    }
  }
  return (source: output.toString(), numbers: numbers);
}
