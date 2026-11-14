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

/// Applies the selected right-hand values to the left-hand document in one edit.
/// Array positions and duplicate-key occurrences refer to the original inputs.
String applyJsonDifferences(
  String leftSource,
  JsonNode leftRoot,
  String rightSource,
  JsonNode rightRoot,
  List<JsonDifference> differences,
) {
  final selected = differences.map((d) => (d.left, d.right)).toSet();
  if (selected.isEmpty) return leftSource;
  final applied = <(SourceRange?, SourceRange?)>{};
  String raw(String source, JsonNode node) =>
      source.substring(node.range.start, node.range.end);
  int start(JsonChild child) =>
      child.keyRange?.start ?? child.value.range.start;

  String? visit(JsonNode? left, JsonNode? right) {
    final pair = (left?.range, right?.range);
    if (selected.contains(pair)) {
      applied.add(pair);
      return right == null ? null : raw(rightSource, right);
    }
    if (left == null) return null;
    if (right == null ||
        left.kind != right.kind ||
        left.kind != JsonKind.object && left.kind != JsonKind.array) {
      return raw(leftSource, left);
    }
    final object = left.kind == JsonKind.object;
    final rightGroups = <String, List<JsonChild>>{};
    if (object) {
      for (final child in right.children) {
        (rightGroups[child.key!] ??= []).add(child);
      }
    }
    final leftCounts = <String, int>{};
    final entries = <({int? index, String text})>[];
    for (var i = 0; i < left.children.length; i++) {
      final child = left.children[i];
      JsonChild? counterpart;
      if (object) {
        final key = child.key!;
        final occurrence =
            leftCounts.update(key, (count) => count + 1, ifAbsent: () => 1) - 1;
        final matches = rightGroups[key] ?? const [];
        if (occurrence < matches.length) counterpart = matches[occurrence];
      } else if (i < right.children.length) {
        counterpart = right.children[i];
      }
      final value = visit(child.value, counterpart?.value);
      if (value != null) {
        entries.add((
          index: i,
          text:
              '${leftSource.substring(start(child), child.value.range.start)}$value',
        ));
      }
    }
    final rightCounts = <String, int>{};
    for (var i = 0; i < right.children.length; i++) {
      final child = right.children[i];
      final occurrence = object
          ? rightCounts.update(
                  child.key!,
                  (count) => count + 1,
                  ifAbsent: () => 1,
                ) -
                1
          : i;
      final existingCount = object
          ? leftCounts[child.key!] ?? 0
          : left.children.length;
      if (occurrence < existingCount) continue;
      final value = visit(null, child.value);
      if (value != null) {
        entries.add((
          index: null,
          text:
              '${rightSource.substring(start(child), child.value.range.start)}$value',
        ));
      }
    }
    final children = left.children;
    final leading = children.isEmpty
        ? ''
        : leftSource.substring(left.range.start + 1, start(children.first));
    final trailing = children.isEmpty
        ? leftSource.substring(left.range.start + 1, left.range.end - 1)
        : leftSource.substring(
            children.last.value.range.end,
            left.range.end - 1,
          );
    final additionSeparator =
        ',${leading.contains('\n') || leading.contains('\r') ? leading : ' '}';
    final output = StringBuffer(leftSource[left.range.start])..write(leading);
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i > 0) {
        final original = entry.index;
        output.write(
          original != null && original > 0
              ? leftSource.substring(
                  children[original - 1].value.range.end,
                  start(children[original]),
                )
              : additionSeparator,
        );
      }
      output.write(entry.text);
    }
    output
      ..write(trailing)
      ..write(leftSource[left.range.end - 1]);
    return output.toString();
  }

  final rewritten = visit(leftRoot, rightRoot)!;
  if (applied.length != selected.length) {
    throw StateError('The selected differences do not match these documents.');
  }
  return leftSource.replaceRange(
    leftRoot.range.start,
    leftRoot.range.end,
    rewritten,
  );
}
