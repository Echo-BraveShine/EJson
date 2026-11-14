import 'dart:collection';
import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'conversion_support.dart';
import 'format_structure.dart';

FormatTreeNode valueStructure(
  Object? value,
  String label,
  StructureBudget budget, {
  int depth = 0,
  Map<String, TextRange> ranges = const {},
  List<Object> path = const [],
}) {
  if (depth > 256) {
    throw const FormatException('Data nesting exceeds 256 levels.');
  }
  final kind = switch (value) {
    Map() => 'object',
    List() => 'array',
    ExactJsonNumber() || num() || BigInt() => 'number',
    bool() => 'boolean',
    null => 'null',
    _ => 'string',
  };
  final children = <FormatTreeNode>[];
  if (value is Map) {
    for (final entry in value.entries) {
      if (!budget.take()) break;
      children.add(
        valueStructure(
          entry.value,
          entry.key.toString(),
          budget,
          depth: depth + 1,
          ranges: ranges,
          path: [...path, entry.key as String],
        ),
      );
    }
  } else if (value is List) {
    for (var i = 0; i < value.length; i++) {
      if (!budget.take()) break;
      children.add(
        valueStructure(
          value[i],
          '[$i]',
          budget,
          depth: depth + 1,
          ranges: ranges,
          path: [...path, i],
        ),
      );
    }
  }
  return FormatTreeNode(
    label,
    kind,
    value is Map
        ? '{${value.length}}'
        : value is List
        ? '[${value.length}]'
        : value is ExactJsonNumber
        ? value.token
        : value?.toString() ?? 'null',
    children: children,
    range: ranges[jsonEncode(path)],
  );
}

FormatTreeNode yamlStructure(
  YamlNode node,
  String label,
  StructureBudget budget, {
  Set<YamlNode>? ancestors,
}) {
  final active = ancestors ?? HashSet<YamlNode>.identity();
  if (active.length > 256) {
    throw const FormatException('YAML nesting exceeds 256 levels.');
  }
  final cycle = !active.add(node);
  final children = <FormatTreeNode>[];
  if (!cycle && node is YamlMap) {
    for (final entry in node.nodes.entries) {
      if (!budget.take()) break;
      final key = entry.key as YamlNode;
      children.add(
        yamlStructure(
          entry.value,
          key.value.toString(),
          budget,
          ancestors: active,
        ),
      );
    }
  } else if (!cycle && node is YamlList) {
    for (var i = 0; i < node.nodes.length; i++) {
      if (!budget.take()) break;
      children.add(
        yamlStructure(node.nodes[i], '[$i]', budget, ancestors: active),
      );
    }
  }
  if (!cycle) active.remove(node);
  final kind = node is YamlMap
      ? 'object'
      : node is YamlList
      ? 'array'
      : node.value == null
      ? 'null'
      : node.value is num
      ? 'number'
      : node.value is bool
      ? 'boolean'
      : 'string';
  final text = cycle
      ? '↩'
      : node is YamlMap
      ? '{${node.nodes.length}}'
      : node is YamlList
      ? '[${node.nodes.length}]'
      : node.span.text;
  return FormatTreeNode(
    label,
    kind,
    text,
    children: children,
    range: (start: node.span.start.offset, end: node.span.end.offset),
  );
}
