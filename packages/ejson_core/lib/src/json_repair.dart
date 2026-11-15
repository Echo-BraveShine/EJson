import 'dart:convert';

import 'document.dart';
import 'format.dart';
import 'syntax.dart';

enum JsonRepairKind {
  byteOrderMark,
  comments,
  singleQuotes,
  unquotedKeys,
  trailingCommas,
  missingCommas,
  missingColons,
  closingContainers,
  closingStrings,
  controlCharacters,
  literals,
}

class JsonRepairResult {
  JsonRepairResult(this.source, Map<JsonRepairKind, int> repairs)
    : repairs = Map.unmodifiable(repairs);

  final String source;
  final Map<JsonRepairKind, int> repairs;
}

/// Repairs recoverable syntax while retaining duplicate keys and raw numbers.
JsonRepairResult repairJson(
  String source, {
  JsonFormatOptions options = const JsonFormatOptions(),
}) {
  const limit = 2 * 1024 * 1024;
  if (source.length > limit) {
    throw const FormatException(
      'The document exceeds the JSON repair size limit.',
    );
  }
  if (parseJson(source).root != null) return JsonRepairResult(source, const {});
  final parser = _RepairParser(source);
  final repaired = parser.value(0);
  parser.skip();
  if (parser.offset != source.length) {
    parser.fail('Unexpected trailing content.');
  }
  final parsed = parseJson(repaired);
  if (parsed.root == null) parser.fail('The repaired content is invalid JSON.');
  final formatted = rewriteJson(
    JsonDocument(SourceBuffer(repaired)).accept(parsed),
    options: JsonFormatOptions(
      indentation: options.indentation,
      lineEnding: switch (options.lineEnding.resolve(source)) {
        '\r\n' => JsonLineEnding.crlf,
        '\r' => JsonLineEnding.cr,
        _ => JsonLineEnding.lf,
      },
    ),
    maxLength: 16 * 1024 * 1024,
  );
  return JsonRepairResult(formatted, parser.repairs);
}

class _RepairParser {
  _RepairParser(this.source);

  final String source;
  final repairs = <JsonRepairKind, int>{};
  int offset = 0;
  String get current => offset < source.length ? source[offset] : '';

  Never fail(String message) => throw FormatException(message, source, offset);

  void repaired(JsonRepairKind kind) =>
      repairs.update(kind, (count) => count + 1, ifAbsent: () => 1);

  void skip() {
    while (offset < source.length) {
      if (' \t\r\n\uFEFF'.contains(current)) {
        if (current == '\uFEFF') repaired(JsonRepairKind.byteOrderMark);
        offset++;
      } else if (source.startsWith('//', offset)) {
        repaired(JsonRepairKind.comments);
        while (offset < source.length && current != '\n' && current != '\r') {
          offset++;
        }
      } else if (source.startsWith('/*', offset)) {
        final end = source.indexOf('*/', offset + 2);
        if (end < 0) fail('The block comment is not closed.');
        offset = end + 2;
        repaired(JsonRepairKind.comments);
      } else {
        return;
      }
    }
  }

  String value(int depth) {
    if (depth > 256) fail('JSON nesting exceeds 256 levels.');
    skip();
    if (current == '{' || current == '[') return container(depth);
    if (current == '"' || current == "'") return string();
    final word = bare();
    final normalized = switch (word) {
      'True' => 'true',
      'False' => 'false',
      'None' => 'null',
      _ => word,
    };
    if (normalized != word) repaired(JsonRepairKind.literals);
    if (normalized.isEmpty || parseJson(normalized).root == null) {
      fail('A value is missing or cannot be interpreted as JSON.');
    }
    return normalized;
  }

  String bare() {
    final start = offset;
    while (offset < source.length &&
        !' \t\r\n{}[]:,"\''.contains(current) &&
        !source.startsWith('//', offset) &&
        !source.startsWith('/*', offset)) {
      offset++;
    }
    return source.substring(start, offset);
  }

  String container(int depth) {
    final object = current == '{';
    final close = object ? '}' : ']';
    final output = StringBuffer(current);
    offset++;
    skip();
    if (current == close) {
      offset++;
      return '$output$close';
    }
    // An empty unterminated container has one unambiguous closing delimiter.
    if (current.isEmpty) {
      repaired(JsonRepairKind.closingContainers);
      return '$output$close';
    }
    while (true) {
      if (object) {
        if (current == '"' || current == "'") {
          output.write(string());
        } else {
          final key = bare();
          if (key.isEmpty) fail('An object key is missing.');
          output.write(jsonEncode(key));
          repaired(JsonRepairKind.unquotedKeys);
        }
        skip();
        if (current == ':') {
          offset++;
        } else {
          repaired(JsonRepairKind.missingColons);
        }
        output.write(':');
      }
      output.write(value(depth + 1));
      skip();
      if (current == close) {
        offset++;
        return '$output$close';
      }
      if (current.isEmpty) {
        repaired(JsonRepairKind.closingContainers);
        return '$output$close';
      }
      if (current == ']' || current == '}') {
        fail('Closing delimiters do not match.');
      }
      if (current == ',') {
        offset++;
        skip();
        if (current == close || current.isEmpty) {
          repaired(JsonRepairKind.trailingCommas);
          if (current == close) {
            offset++;
          } else {
            repaired(JsonRepairKind.closingContainers);
          }
          return '$output$close';
        }
      } else {
        repaired(JsonRepairKind.missingCommas);
      }
      output.write(',');
    }
  }

  String string() {
    final quote = current;
    if (quote == "'") repaired(JsonRepairKind.singleQuotes);
    final output = StringBuffer('"');
    offset++;
    var closed = false;
    while (offset < source.length) {
      final char = current;
      offset++;
      if (char == quote) {
        closed = true;
        break;
      }
      if (char == '\\') {
        if (current.isEmpty) fail('The string ends in an incomplete escape.');
        final escaped = current;
        offset++;
        if (escaped == "'" && quote == "'") {
          output.write("'");
        } else if ('"\\/bfnrtu'.contains(escaped)) {
          output.write('\\$escaped');
        } else {
          fail('The string contains an unsupported escape sequence.');
        }
      } else if (char == '"') {
        output.write('\\"');
      } else if (char.codeUnitAt(0) < 32) {
        final escaped = jsonEncode(char);
        output.write(escaped.substring(1, escaped.length - 1));
        repaired(JsonRepairKind.controlCharacters);
      } else {
        output.write(char);
      }
    }
    if (!closed) repaired(JsonRepairKind.closingStrings);
    output.write('"');
    final result = output.toString();
    try {
      jsonDecode(result);
    } on FormatException {
      fail('The string contains an invalid escape or Unicode sequence.');
    }
    return result;
  }
}
