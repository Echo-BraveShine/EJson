import 'document.dart';
import 'syntax.dart';

enum JsonIndentation {
  twoSpaces('  '),
  fourSpaces('    '),
  eightSpaces('        '),
  tabs('\t');

  const JsonIndentation(this.unit);
  final String unit;
}

enum JsonLineEnding {
  preserve,
  lf,
  crlf,
  cr;

  String resolve(String source) => switch (this) {
    preserve => RegExp(r'\r\n|\r|\n').firstMatch(source)?.group(0) ?? '\n',
    lf => '\n',
    crlf => '\r\n',
    cr => '\r',
  };
}

class JsonFormatOptions {
  const JsonFormatOptions({
    this.indentation = JsonIndentation.twoSpaces,
    this.lineEnding = JsonLineEnding.preserve,
  });

  final JsonIndentation indentation;
  final JsonLineEnding lineEnding;
}

/// Changes only structural whitespace. Duplicate keys and raw tokens survive.
String rewriteJson(
  JsonDocument document, {
  bool minify = false,
  JsonFormatOptions options = const JsonFormatOptions(),
  int? maxLength,
}) {
  final root = document.snapshot?.root;
  if (root == null) {
    throw StateError('The current revision must be valid JSON.');
  }
  final source = document.source;
  final newline = minify ? '' : options.lineEnding.resolve(source.text);
  final indent = minify ? '' : options.indentation.unit;
  final output = StringBuffer();

  void append(String text) {
    if (maxLength != null && output.length + text.length > maxLength) {
      throw const FormatException(
        'Formatted content exceeds the output size limit.',
      );
    }
    output.write(text);
  }

  void write(JsonNode node, int depth) {
    if (node.children.isEmpty) {
      append(switch (node.kind) {
        JsonKind.array => '[]',
        JsonKind.object => '{}',
        _ => source.slice(node.range),
      });
      return;
    }
    final object = node.kind == JsonKind.object;
    append(object ? '{' : '[');
    for (var index = 0; index < node.children.length; index++) {
      final child = node.children[index];
      if (index != 0) append(',');
      append(newline);
      append(indent * (depth + 1));
      final keyRange = child.keyRange;
      if (keyRange != null) {
        append(source.slice(keyRange));
        append(minify ? ':' : ': ');
      }
      write(child.value, depth + 1);
    }
    append(newline);
    append(indent * depth);
    append(object ? '}' : ']');
  }

  write(root, 0);
  if (!minify && (source.text.endsWith('\n') || source.text.endsWith('\r'))) {
    append(newline);
  }
  return output.toString();
}
