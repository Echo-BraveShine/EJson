import 'dart:convert';

/// Half-open UTF-16 code unit range, as used by Flutter selections.
typedef SourceRange = ({int start, int end});

class LineIndex {
  LineIndex(String source) : starts = _lineStarts(source);

  final List<int> starts;

  static List<int> _lineStarts(String source) {
    final starts = [0];
    for (var i = 0; i < source.length; i++) {
      final char = source.codeUnitAt(i);
      if (char == 13 &&
          i + 1 < source.length &&
          source.codeUnitAt(i + 1) == 10) {
        i++;
      }
      if (char == 13 || char == 10) starts.add(i + 1);
    }
    return List.unmodifiable(starts);
  }

  /// Returns one-based line and column.
  ({int line, int column}) position(int offset) {
    var low = 0;
    var high = starts.length;
    while (low + 1 < high) {
      final mid = (low + high) ~/ 2;
      if (starts[mid] <= offset) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (line: low + 1, column: offset - starts[low] + 1);
  }
}

enum JsonKind { object, array, string, number, boolean, nil }

class JsonChild {
  const JsonChild(this.value, {this.key, this.keyRange});
  final JsonNode value;
  final String? key;
  final SourceRange? keyRange;
}

class JsonNode {
  JsonNode(this.kind, this.range, [List<JsonChild> children = const []])
    : children = List.unmodifiable(children);

  final JsonKind kind;
  final SourceRange range;
  final List<JsonChild> children;
}

class JsonDiagnostic {
  const JsonDiagnostic(
    this.code,
    this.message,
    this.range, {
    this.warning = false,
    this.detail,
  });
  final String code;
  final String message;
  final SourceRange range;
  final bool warning;
  final String? detail;
}

class ParseSnapshot {
  ParseSnapshot(
    this.revision,
    this.lines,
    this.root,
    List<JsonDiagnostic> diagnostics,
  ) : diagnostics = List.unmodifiable(diagnostics);

  final int revision;
  final LineIndex lines;
  final JsonNode? root;
  final List<JsonDiagnostic> diagnostics;
}

/// Parses strict JSON while keeping the raw token ranges and member order.
ParseSnapshot parseJson(String source, {int revision = 0}) {
  final parser = _Parser(source);
  final lines = LineIndex(source);
  try {
    final root = parser.value(0);
    parser.skipWhitespace();
    if (parser.offset != source.length) {
      parser.fail('trailing_content', 'Unexpected text after the JSON value.');
    }
    return ParseSnapshot(revision, lines, root, parser.warnings);
  } on JsonDiagnostic catch (error) {
    return ParseSnapshot(revision, lines, null, [error]);
  }
}

class _Parser {
  _Parser(this.source);
  static final _number = RegExp(
    r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
  );
  final String source;
  final warnings = <JsonDiagnostic>[];
  int offset = 0;

  int get char => offset < source.length ? source.codeUnitAt(offset) : -1;

  void skipWhitespace() {
    while (char == 32 || char == 9 || char == 10 || char == 13) {
      offset++;
    }
  }

  Never fail(String code, String message, {String? detail}) =>
      throw JsonDiagnostic(code, message, (
        start: offset,
        end: offset < source.length ? offset + 1 : offset,
      ), detail: detail);

  bool consume(int expected) {
    if (char != expected) return false;
    offset++;
    return true;
  }

  JsonNode value(int depth) {
    skipWhitespace();
    if (depth > 256) fail('depth_limit', 'JSON nesting exceeds 256 levels.');
    final start = offset;
    final JsonKind kind;
    switch (char) {
      case 123:
      case 91:
        final object = char == 123;
        offset++;
        final children = container(object, depth);
        return JsonNode(object ? JsonKind.object : JsonKind.array, (
          start: start,
          end: offset,
        ), children);
      case 34:
        string();
        kind = JsonKind.string;
      case 116:
        literal('true');
        kind = JsonKind.boolean;
      case 102:
        literal('false');
        kind = JsonKind.boolean;
      case 110:
        literal('null');
        kind = JsonKind.nil;
      default:
        final number = _number.matchAsPrefix(source, offset);
        if (number == null) fail('expected_value', 'Expected a JSON value.');
        offset = number.end;
        kind = JsonKind.number;
    }
    return JsonNode(kind, (start: start, end: offset));
  }

  List<JsonChild> container(bool object, int depth) {
    final close = object ? 125 : 93;
    final children = <JsonChild>[];
    final keys = <String>{};
    skipWhitespace();
    if (consume(close)) return children;
    while (true) {
      String? key;
      SourceRange? keyRange;
      if (object) {
        skipWhitespace();
        if (char != 34) {
          fail('expected_key', 'Expected a quoted property name.');
        }
        final start = offset;
        string();
        keyRange = (start: start, end: offset);
        key = jsonDecode(source.substring(start, offset)) as String;
        if (!keys.add(key)) {
          warnings.add(
            JsonDiagnostic(
              'duplicate_key',
              'Duplicate property name.',
              keyRange,
              warning: true,
            ),
          );
        }
        skipWhitespace();
        if (!consume(58)) {
          fail('expected_colon', 'Expected ":" after the property name.');
        }
      }
      children.add(JsonChild(value(depth + 1), key: key, keyRange: keyRange));
      skipWhitespace();
      if (consume(close)) return children;
      if (!consume(44)) {
        fail(
          'expected_delimiter',
          object ? 'Expected "," or "}".' : 'Expected "," or "]".',
          detail: object ? 'object' : 'array',
        );
      }
    }
  }

  void literal(String token) {
    for (final unit in token.codeUnits) {
      if (!consume(unit)) {
        fail('invalid_literal', 'Expected "$token".', detail: token);
      }
    }
  }

  void string() {
    offset++;
    while (char != 34) {
      if (char == -1) fail('unclosed_string', 'Expected a closing quote.');
      if (char < 32) {
        fail('control_character', 'Escape control characters inside strings.');
      }
      if (!consume(92)) {
        offset++;
        continue;
      }
      if (consume(117)) {
        for (var digit = 0; digit < 4; digit++) {
          final unit = char;
          if (!(unit >= 48 && unit <= 57 ||
              unit >= 65 && unit <= 70 ||
              unit >= 97 && unit <= 102)) {
            fail(
              'invalid_unicode_escape',
              'Expected four hexadecimal digits after "\\u".',
            );
          }
          offset++;
        }
      } else {
        if (char < 0 || !r'"/\bfnrt'.codeUnits.contains(char)) {
          fail('invalid_escape', 'Invalid string escape.');
        }
        offset++;
      }
    }
    offset++;
  }
}
