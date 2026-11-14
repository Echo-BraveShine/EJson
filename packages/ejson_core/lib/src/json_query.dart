import 'dart:convert';

import 'number_compare.dart';
import 'syntax.dart';

class JsonQueryMatch {
  const JsonQueryMatch(this.node, this.path);

  final JsonNode node;
  final String path;
}

typedef _Selector = Iterable<JsonQueryMatch> Function(JsonQueryMatch);
typedef _Predicate = bool Function(JsonNode);
typedef _Value = ({JsonNode node, String source});
typedef _Operand = ({bool path, _Value? Function(JsonNode) read});

/// Queries keys, indices, wildcards and scalar filters without decoding the
/// document into a map. Duplicate keys and original token ranges are retained.
/// Throws FormatException with an expression offset for unsupported syntax.
List<JsonQueryMatch> queryJsonPath(String source, JsonNode root, String input) {
  final selectors = _QueryParser(source, input).parse();
  var matches = [JsonQueryMatch(root, r'$')];
  for (final selector in selectors) {
    matches = [for (final match in matches) ...selector(match)];
  }
  return matches;
}

class _QueryParser {
  _QueryParser(this.source, this.input);

  final String source;
  final String input;
  int offset = 0;
  int _depth = 0;
  static final _name = RegExp(r'[a-zA-Z_][a-zA-Z_0-9]*');
  static final _integer = RegExp(r'-?(?:0|[1-9][0-9]*)');
  static final _number = RegExp(
    r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
  );

  Never _invalid() => throw FormatException('Invalid JSONPath', input, offset);

  void _space() {
    while (offset < input.length && ' \t\r\n'.contains(input[offset])) {
      offset++;
    }
  }

  bool _take(String token) {
    _space();
    if (!input.startsWith(token, offset)) return false;
    offset += token.length;
    return true;
  }

  void _expect(String token) {
    if (!_take(token)) _invalid();
  }

  String _identifier() {
    _space();
    final match = _name.matchAsPrefix(input, offset);
    if (match == null) _invalid();
    offset = match.end;
    return match[0]!;
  }

  String _quoted() {
    _space();
    if (offset == input.length || !'"\''.contains(input[offset])) _invalid();
    final quote = input[offset++];
    final buffer = StringBuffer();
    while (offset < input.length) {
      final char = input[offset++];
      if (char == quote) return buffer.toString();
      if (char.codeUnitAt(0) < 32) _invalid();
      if (char != r'\') {
        buffer.write(char);
        continue;
      }
      if (offset == input.length) _invalid();
      final escape = input[offset++];
      if (escape == 'u') {
        if (offset + 4 > input.length) _invalid();
        final hex = input.substring(offset, offset + 4);
        if (!RegExp(r'^[0-9a-fA-F]{4}$').hasMatch(hex)) _invalid();
        buffer.writeCharCode(int.parse(hex, radix: 16));
        offset += 4;
      } else if (escape == "'" && quote == "'") {
        buffer.write("'");
      } else {
        const escapes = {
          '"': '"',
          r'\': r'\',
          '/': '/',
          'b': '\b',
          'f': '\f',
          'n': '\n',
          'r': '\r',
          't': '\t',
        };
        final decoded = escapes[escape];
        if (decoded == null) _invalid();
        buffer.write(decoded);
      }
    }
    _invalid();
  }

  List<_Selector> parse() {
    _expect(r'$');
    final selectors = <_Selector>[];
    while (true) {
      _space();
      if (offset == input.length) return selectors;
      selectors.add(_selector());
    }
  }

  _Selector _selector({bool singular = false}) {
    if (_take('.')) {
      if (_take('*')) {
        if (singular) _invalid();
        return _children;
      }
      return _key(_identifier());
    }
    _expect('[');
    if (_take('*')) {
      if (singular) _invalid();
      _expect(']');
      return _children;
    }
    if (_take('?')) {
      if (singular) _invalid();
      final predicate = _or();
      _expect(']');
      return (match) =>
          _children(match).where((child) => predicate(child.node));
    }
    _space();
    if (offset < input.length && '"\''.contains(input[offset])) {
      final selector = _key(_quoted());
      _expect(']');
      return selector;
    }
    final match = _integer.matchAsPrefix(input, offset);
    if (match == null) _invalid();
    final index = int.tryParse(match[0]!);
    if (index == null) _invalid();
    offset = match.end;
    _expect(']');
    return (match) sync* {
      if (match.node.kind != JsonKind.array) return;
      final resolved = index < 0 ? match.node.children.length + index : index;
      if (resolved < 0 || resolved >= match.node.children.length) return;
      yield JsonQueryMatch(
        match.node.children[resolved].value,
        '${match.path}[$resolved]',
      );
    };
  }

  _Selector _key(String key) => (match) sync* {
    if (match.node.kind != JsonKind.object) return;
    for (final child in match.node.children) {
      if (child.key == key) {
        yield JsonQueryMatch(child.value, '${match.path}[${jsonEncode(key)}]');
      }
    }
  };

  Iterable<JsonQueryMatch> _children(JsonQueryMatch match) sync* {
    for (var index = 0; index < match.node.children.length; index++) {
      final child = match.node.children[index];
      final segment = child.key == null ? '$index' : jsonEncode(child.key);
      yield JsonQueryMatch(child.value, '${match.path}[$segment]');
    }
  }

  _Predicate _or() {
    final parts = [_and()];
    while (_take('||')) {
      parts.add(_and());
    }
    return (node) => parts.any((part) => part(node));
  }

  _Predicate _and() {
    final parts = [_unary()];
    while (_take('&&')) {
      parts.add(_unary());
    }
    return (node) => parts.every((part) => part(node));
  }

  _Predicate _unary() {
    var negate = false;
    while (_take('!')) {
      negate = !negate;
    }
    late _Predicate predicate;
    if (_take('(')) {
      if (++_depth > 128) _invalid();
      predicate = _or();
      _expect(')');
      _depth--;
    } else {
      predicate = _comparison();
    }
    return (node) => negate != predicate(node);
  }

  _Predicate _comparison() {
    final left = _operand();
    String? operator;
    for (final candidate in ['==', '!=', '<=', '>=', '<', '>']) {
      if (_take(candidate)) {
        operator = candidate;
        break;
      }
    }
    if (operator == null) {
      if (!left.path) _invalid();
      return (node) => left.read(node) != null;
    }
    final right = _operand();
    return (node) => _compare(left.read(node), right.read(node), operator!);
  }

  _Operand _operand() {
    if (_take('@')) {
      final selectors = <_Selector>[];
      while (true) {
        _space();
        if (offset == input.length || !'.['.contains(input[offset])) break;
        selectors.add(_selector(singular: true));
      }
      return (
        path: true,
        read: (node) {
          var matches = [JsonQueryMatch(node, '@')];
          for (final selector in selectors) {
            matches = [for (final match in matches) ...selector(match)];
          }
          return matches.length == 1
              ? (node: matches.single.node, source: source)
              : null;
        },
      );
    }
    _space();
    final start = offset;
    String literal;
    if (offset < input.length && '"\''.contains(input[offset])) {
      literal = jsonEncode(_quoted());
    } else {
      final number = _number.matchAsPrefix(input, offset);
      if (number != null) {
        offset = number.end;
      } else if (!_take('true') && !_take('false') && !_take('null')) {
        _invalid();
      }
      literal = input.substring(start, offset);
    }
    final node = parseJson(literal).root;
    if (node == null) _invalid();
    return (path: false, read: (_) => (node: node, source: literal));
  }
}

bool _compare(_Value? a, _Value? b, String operator) {
  bool equal() {
    if (a == null || b == null) return a == b;
    if (a.node.kind != b.node.kind) return false;
    final rawA = a.source.substring(a.node.range.start, a.node.range.end);
    final rawB = b.source.substring(b.node.range.start, b.node.range.end);
    return switch (a.node.kind) {
      JsonKind.number => compareJsonNumbers(rawA, rawB) == 0,
      JsonKind.string => jsonDecode(rawA) == jsonDecode(rawB),
      JsonKind.boolean || JsonKind.nil => rawA == rawB,
      _ => false,
    };
  }

  if (operator == '==') return equal();
  if (operator == '!=') return !equal();
  if (a == null || b == null || a.node.kind != b.node.kind) return false;
  final rawA = a.source.substring(a.node.range.start, a.node.range.end);
  final rawB = b.source.substring(b.node.range.start, b.node.range.end);
  final order = switch (a.node.kind) {
    JsonKind.number => compareJsonNumbers(rawA, rawB),
    JsonKind.string => (jsonDecode(rawA) as String).compareTo(
      jsonDecode(rawB) as String,
    ),
    _ => null,
  };
  if (order == null) return false;
  return switch (operator) {
    '<' => order < 0,
    '<=' => order <= 0,
    '>' => order > 0,
    '>=' => order >= 0,
    _ => false,
  };
}
