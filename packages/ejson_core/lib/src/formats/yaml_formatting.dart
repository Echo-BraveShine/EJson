import 'dart:collection';
import 'package:yaml/yaml.dart';
import 'conversion_support.dart';

String formatYaml(String source, {int indent = 2, String lineEnding = '\n'}) {
  final documents = loadYamlDocuments(source);
  final protected = <int, int>{};
  final seen = HashSet<YamlNode>.identity();
  void collect(YamlNode node) {
    if (!seen.add(node)) return;
    if (node is YamlScalar && node.span.end.line > node.span.start.line) {
      for (
        var line = node.span.start.line + 1;
        line <= node.span.end.line;
        line++
      ) {
        protected[line] = node.span.start.line;
      }
    }
    if (node is YamlMap) {
      for (final entry in node.nodes.entries) {
        collect(entry.key as YamlNode);
        collect(entry.value);
      }
    } else if (node is YamlList) {
      for (final child in node.nodes) {
        collect(child);
      }
    }
  }

  for (final document in documents) {
    collect(document.contents);
  }
  final lines = source.split(RegExp(r'\r\n|\r|\n'));
  final levels = <int>[0];
  final deltas = <int, int>{};
  final output = ConversionBuffer();
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) output.write(lineEnding);
    final line = lines[i];
    final spaces = line.length - line.trimLeft().length;
    if (line.trim().isEmpty) {
      output.write(line);
      continue;
    }
    final parent = protected[i];
    if (parent != null) {
      output.write(
        ' ' * (spaces + (deltas[parent] ?? 0)).clamp(0, maxConversionUnits),
      );
      output.write(line.substring(spaces));
      continue;
    }
    final text = line.substring(spaces);
    if (text == '---' || text == '...') {
      levels
        ..clear()
        ..add(0);
    }
    if (!text.startsWith('#')) {
      while (levels.length > 1 && spaces < levels.last) {
        levels.removeLast();
      }
      if (spaces > levels.last) levels.add(spaces);
    }
    final width = (levels.length - 1) * indent;
    deltas[i] = width - spaces;
    output.write(' ' * width);
    output.write(text);
  }
  final text = output.toString();
  loadYamlDocuments(text);
  return text;
}
