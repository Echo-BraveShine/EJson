import 'document.dart';
import 'syntax.dart';
import 'value_compare.dart';

void _checkArray(JsonNode array) {
  if (array.kind != JsonKind.array) {
    throw ArgumentError('Expected a JSON array');
  }
}

/// Rewrites value slots while preserving their original comma/whitespace gaps.
SourcePatch _replaceItems(String source, JsonNode array, List<int> order) {
  final children = array.children;
  if (children.isEmpty) {
    return SourcePatch(
      array.range,
      source.substring(array.range.start, array.range.end),
    );
  }
  final gaps = [
    for (var index = 1; index < children.length; index++)
      source.substring(
        children[index - 1].value.range.end,
        children[index].value.range.start,
      ),
  ];
  final fallback = gaps.isEmpty
      ? ',${source.substring(array.range.start + 1, children.first.value.range.start)}'
      : gaps.last;
  final output = StringBuffer();
  for (var position = 0; position < order.length; position++) {
    if (position > 0) {
      output.write(position <= gaps.length ? gaps[position - 1] : fallback);
    }
    final range = children[order[position]].value.range;
    output.write(source.substring(range.start, range.end));
  }
  return SourcePatch((
    start: children.first.value.range.start,
    end: children.last.value.range.end,
  ), output.toString());
}

SourcePatch moveJsonArrayItem(
  String source,
  JsonNode array,
  int index,
  int target,
) {
  _checkArray(array);
  RangeError.checkValidIndex(index, array.children);
  RangeError.checkValidIndex(target, array.children);
  final order = List.generate(array.children.length, (index) => index);
  order.insert(target, order.removeAt(index));
  return _replaceItems(source, array, order);
}

SourcePatch duplicateJsonArrayItem(String source, JsonNode array, int index) {
  _checkArray(array);
  RangeError.checkValidIndex(index, array.children);
  final order = List.generate(array.children.length, (index) => index);
  order.insert(index + 1, index);
  return _replaceItems(source, array, order);
}

/// Sorts by a direct object key, or by each element when key is null.
/// Missing fields remain last in either direction. Equal values retain order.
/// Duplicate occurrences of the selected key are reported as ambiguous.
SourcePatch sortJsonArray(
  String source,
  JsonNode array, {
  String? key,
  bool ascending = true,
}) {
  _checkArray(array);
  final values = <JsonNode?>[];
  for (final child in array.children) {
    final node = child.value;
    if (key == null) {
      values.add(node);
      continue;
    }
    final fields = node.kind == JsonKind.object
        ? node.children.where((child) => child.key == key).toList()
        : const <JsonChild>[];
    if (fields.length > 1) throw const FormatException('Ambiguous sort field');
    values.add(fields.firstOrNull?.value);
  }
  final order = List.generate(values.length, (index) => index);
  order.sort((left, right) {
    final a = values[left];
    final b = values[right];
    if (a == null || b == null) {
      if (a == b) return left.compareTo(right);
      return a == null ? 1 : -1;
    }
    final compared = compareJsonValues(source, a, b);
    if (compared == 0) return left.compareTo(right);
    return ascending ? compared : -compared;
  });
  return _replaceItems(source, array, order);
}
