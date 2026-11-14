import 'dart:convert';
import 'dart:math' as math;

import 'json_path.dart';
import 'syntax.dart';

enum JsonDifferenceKind { added, removed, changed }

typedef JsonDifference = ({
  JsonDifferenceKind kind,
  String path,
  List<int> duplicateOccurrences,
  SourceRange? left,
  SourceRange? right,
});

typedef JsonComparison = ({List<JsonDifference> differences, bool truncated});

/// Compares objects by key and arrays by index. Duplicate keys are paired
/// in occurrence order and retained as distinct differences.
JsonComparison compareJsonStructure(
  String leftSource,
  JsonNode leftRoot,
  String rightSource,
  JsonNode rightRoot, {
  int limit = 1000,
}) {
  assert(limit > 0);
  final differences = <JsonDifference>[];
  final path = <JsonPathSegment>[];
  final occurrences = <int>[];
  var truncated = false;

  void record(JsonNode? left, JsonNode? right) {
    if (differences.length == limit) {
      truncated = true;
      return;
    }
    differences.add((
      kind: left == null
          ? JsonDifferenceKind.added
          : right == null
          ? JsonDifferenceKind.removed
          : JsonDifferenceKind.changed,
      path: formatJsonPath(path),
      duplicateOccurrences: List.of(occurrences),
      left: left?.range,
      right: right?.range,
    ));
  }

  Map<String, List<JsonNode>> byKey(JsonNode node) {
    final groups = <String, List<JsonNode>>{};
    for (final child in node.children) {
      (groups[child.key!] ??= []).add(child.value);
    }
    return groups;
  }

  void visit(JsonNode? left, JsonNode? right) {
    if (truncated) return;
    if (left == null || right == null || left.kind != right.kind) {
      record(left, right);
      return;
    }
    switch (left.kind) {
      case JsonKind.object:
        final before = byKey(left);
        final after = byKey(right);
        for (final key in {...before.keys, ...after.keys}) {
          final a = before[key] ?? const [];
          final b = after[key] ?? const [];
          final count = math.max(a.length, b.length);
          path.add((key: key, index: null));
          for (var i = 0; i < count && !truncated; i++) {
            if (count > 1) occurrences.add(i + 1);
            visit(i < a.length ? a[i] : null, i < b.length ? b[i] : null);
            if (count > 1) occurrences.removeLast();
          }
          path.removeLast();
          if (truncated) break;
        }
      case JsonKind.array:
        final a = left.children;
        final b = right.children;
        for (var i = 0; i < math.max(a.length, b.length) && !truncated; i++) {
          path.add((key: null, index: i));
          visit(
            i < a.length ? a[i].value : null,
            i < b.length ? b[i].value : null,
          );
          path.removeLast();
        }
      default:
        final a = leftSource.substring(left.range.start, left.range.end);
        final b = rightSource.substring(right.range.start, right.range.end);
        if (a != b &&
            (left.kind != JsonKind.string || jsonDecode(a) != jsonDecode(b))) {
          record(left, right);
        }
    }
  }

  visit(leftRoot, rightRoot);
  return (differences: differences, truncated: truncated);
}
