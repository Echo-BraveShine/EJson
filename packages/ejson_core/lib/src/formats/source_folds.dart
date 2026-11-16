import 'dart:collection';

import 'package:yaml/yaml.dart';

import '../syntax.dart';
import 'csv_document.dart';
import 'document_format.dart';
import 'format_structure.dart';
import 'toml_conversion.dart';
import 'toml_source_ranges.dart';
import 'xml_document.dart';
import 'xml_structure.dart';

/// Source spans for compound values or physically grouped records.
Iterable<SourceRange> sourceFoldRanges(
  String source,
  DocumentFormat format,
) sync* {
  switch (format) {
    case DocumentFormat.json:
      return;
    case DocumentFormat.csv:
      for (final record in csvRecords(source)) {
        yield record.range;
      }
    case DocumentFormat.jsonLines:
      final lines = LineIndex(source).starts;
      int? start;
      var end = 0;
      for (var i = 0; i < lines.length; i++) {
        final next = i + 1 < lines.length ? lines[i + 1] : source.length;
        if (source.substring(lines[i], next).trim().isEmpty) {
          if (start != null) yield (start: start, end: end);
          start = null;
        } else {
          start ??= lines[i];
          end = next;
        }
      }
      if (start != null) yield (start: start, end: end);
    case DocumentFormat.toml:
      parseTomlDocument(source);
      final folds = <SourceRange>[];
      tomlSourceRanges(source, folds: folds);
      yield* folds;
    case DocumentFormat.xml:
      parseXmlDocument(source);
      Iterable<SourceRange> elements(FormatTreeNode node) sync* {
        if (node.kind != 'element') return;
        if (node.range case final range?) yield range;
        for (final child in node.children) {
          yield* elements(child);
        }
      }

      yield* elements(xmlSourceStructure(source, StructureBudget()));
    case DocumentFormat.yaml:
      final visited = HashSet<YamlNode>.identity();
      Iterable<SourceRange> blocks(YamlNode node, int header, int depth) sync* {
        // Aliases can point backwards or to an ancestor.
        if (node.span.start.offset < header ||
            depth > 256 ||
            !visited.add(node)) {
          return;
        }
        if (node is YamlMap || node is YamlList || node is YamlScalar) {
          yield (start: header, end: node.span.end.offset);
        }
        if (node is YamlMap) {
          for (final entry in node.nodes.entries) {
            final key = entry.key as YamlNode;
            yield* blocks(entry.value, key.span.start.offset, depth + 1);
          }
        } else if (node is YamlList) {
          for (final child in node.nodes) {
            yield* blocks(child, child.span.start.offset, depth + 1);
          }
        }
      }

      for (final document in loadYamlDocuments(source)) {
        final node = document.contents;
        yield* blocks(node, node.span.start.offset, 0);
      }
  }
}
