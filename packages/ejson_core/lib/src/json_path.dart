import 'dart:convert';

import 'syntax.dart';

typedef JsonPathSegment = ({String? key, int? index});

String formatJsonPath(Iterable<JsonPathSegment> segments) => [
  r'$',
  for (final segment in segments)
    if (segment.key case final key?)
      '[${jsonEncode(key)}]'
    else
      '[${segment.index}]',
].join();

final _dotSelector = RegExp(r'\.([a-zA-Z_][a-zA-Z_0-9]*)');
final _bracketSelector = RegExp(r'\[("(?:[^"\\]|\\.)*"|0|[1-9][0-9]*)\]');

enum JsonPathStatus { found, invalid, missing, ambiguous }

typedef JsonPathResult = ({JsonPathStatus status, SourceRange? range});

/// Resolves a single path produced by the tree, or simple dot notation.
JsonPathResult resolveJsonPath(JsonNode root, String input) {
  final path = input.trim();
  if (!path.startsWith(r'$')) {
    return (status: JsonPathStatus.invalid, range: null);
  }
  var offset = 1;
  final segments = <JsonPathSegment>[];
  while (offset < path.length) {
    final dot = _dotSelector.matchAsPrefix(path, offset);
    final match = dot ?? _bracketSelector.matchAsPrefix(path, offset);
    if (match == null) return (status: JsonPathStatus.invalid, range: null);
    offset = match.end;
    final token = match[1]!;
    if (dot != null) {
      segments.add((key: token, index: null));
    } else if (token.startsWith('"')) {
      try {
        segments.add((key: jsonDecode(token) as String, index: null));
      } on FormatException {
        return (status: JsonPathStatus.invalid, range: null);
      }
    } else {
      final index = int.tryParse(token);
      if (index == null) return (status: JsonPathStatus.invalid, range: null);
      segments.add((key: null, index: index));
    }
  }

  var node = root;
  for (final segment in segments) {
    if (segment.key case final key?) {
      if (node.kind != JsonKind.object) {
        return (status: JsonPathStatus.missing, range: null);
      }
      JsonChild? selected;
      for (final child in node.children) {
        if (child.key != key) continue;
        if (selected != null) {
          return (status: JsonPathStatus.ambiguous, range: null);
        }
        selected = child;
      }
      if (selected == null) {
        return (status: JsonPathStatus.missing, range: null);
      }
      node = selected.value;
    } else {
      final index = segment.index!;
      if (node.kind != JsonKind.array || index >= node.children.length) {
        return (status: JsonPathStatus.missing, range: null);
      }
      node = node.children[index].value;
    }
  }
  return (status: JsonPathStatus.found, range: node.range);
}
