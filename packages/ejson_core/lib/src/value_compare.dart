import 'dart:convert';

import 'number_compare.dart';
import 'syntax.dart';

/// Orders values by type, then value, retaining exact numeric comparisons.
int compareJsonValues(String source, JsonNode a, JsonNode b) {
  if (a.kind != b.kind) return a.kind.index.compareTo(b.kind.index);
  final rawA = source.substring(a.range.start, a.range.end);
  final rawB = source.substring(b.range.start, b.range.end);
  return switch (a.kind) {
    JsonKind.number => compareJsonNumbers(rawA, rawB),
    JsonKind.string => (jsonDecode(rawA) as String).compareTo(
      jsonDecode(rawB) as String,
    ),
    _ => rawA.compareTo(rawB),
  };
}
