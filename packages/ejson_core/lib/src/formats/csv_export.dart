import 'dart:convert';
import '../syntax.dart';
import '../json_path.dart';
import 'conversion_support.dart';

/// Flattens object-row leaves to JSONPath columns, retaining other array rows.
String flattenObjectArray(String source) {
  final root = parseJson(source).root;
  if (root?.kind != JsonKind.array) {
    throw const FormatException('CSV conversion requires a JSON array.');
  }
  final output = ConversionBuffer()..write('[');
  for (var i = 0; i < root!.children.length; i++) {
    if (i > 0) output.write(',');
    final row = root.children[i].value;
    if (row.kind != JsonKind.object) {
      output.write(source.substring(row.range.start, row.range.end));
      continue;
    }
    output.write('{');
    var first = true;
    void visit(JsonNode node, List<JsonPathSegment> path) {
      if (node.children.isNotEmpty &&
          (node.kind == JsonKind.object || node.kind == JsonKind.array)) {
        for (var j = 0; j < node.children.length; j++) {
          final child = node.children[j];
          visit(child.value, [
            ...path,
            (key: child.key, index: child.key == null ? j : null),
          ]);
        }
      } else {
        if (!first) output.write(',');
        first = false;
        output.write(
          '${jsonEncode(formatJsonPath(path))}:${source.substring(node.range.start, node.range.end)}',
        );
      }
    }

    for (final child in root.children[i].value.children) {
      visit(child.value, [(key: child.key, index: null)]);
    }
    output.write('}');
  }
  output.write(']');
  return output.toString();
}
