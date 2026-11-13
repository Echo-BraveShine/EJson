import 'document.dart';
import 'syntax.dart';

/// Changes only structural whitespace. Duplicate keys and raw tokens survive.
String rewriteJson(JsonDocument document, {bool minify = false}) {
  final root = document.snapshot?.root;
  if (root == null) {
    throw StateError('The current revision must be valid JSON.');
  }
  final source = document.source;
  final newline = minify
      ? ''
      : (RegExp(r'\r\n|\r|\n').firstMatch(source.text)?.group(0) ?? '\n');
  final indent = minify ? '' : '  ';
  final output = StringBuffer();

  void write(JsonNode node, int depth) {
    if (node.children.isEmpty) {
      output.write(switch (node.kind) {
        JsonKind.array => '[]',
        JsonKind.object => '{}',
        _ => source.slice(node.range),
      });
      return;
    }
    final object = node.kind == JsonKind.object;
    output.write(object ? '{' : '[');
    for (var index = 0; index < node.children.length; index++) {
      final child = node.children[index];
      if (index != 0) output.write(',');
      output.write(newline);
      output.write(indent * (depth + 1));
      final keyRange = child.keyRange;
      if (keyRange != null) {
        output.write(source.slice(keyRange));
        output.write(minify ? ':' : ': ');
      }
      write(child.value, depth + 1);
    }
    output.write(newline);
    output.write(indent * depth);
    output.write(object ? '}' : ']');
  }

  write(root, 0);
  if (!minify && (source.text.endsWith('\n') || source.text.endsWith('\r'))) {
    output.write(newline);
  }
  return output.toString();
}
