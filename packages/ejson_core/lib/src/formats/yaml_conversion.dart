import 'dart:collection';
import 'dart:convert';
import 'package:yaml/yaml.dart';
import '../syntax.dart';
import '../format.dart';
import '../document.dart';
import 'conversion_support.dart';

String jsonToYaml(String source, {int indent = 2}) {
  if (indent < 1 || indent > 8) throw ArgumentError.value(indent, 'indent');
  final parsed = parseJson(source);
  if (parsed.root == null) throw const FormatException('Invalid JSON');
  final duplicate = parsed.diagnostics
      .where((d) => d.code == 'duplicate_key')
      .firstOrNull;
  if (duplicate != null) {
    throw FormatException(
      'YAML mappings require unique keys.',
      source,
      duplicate.range.start,
    );
  }
  final output = ConversionBuffer();
  void write(JsonNode node, int depth) {
    if (node.children.isEmpty ||
        node.kind != JsonKind.object && node.kind != JsonKind.array) {
      output.write(source.substring(node.range.start, node.range.end));
      return;
    }
    for (var i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      if (i > 0) output.write('\n');
      output.write(' ' * (indent * depth));
      if (child.key != null) {
        output.write('${jsonEncode(child.key)}:');
      } else {
        output.write('-');
      }
      final nested =
          child.value.children.isNotEmpty &&
          (child.value.kind == JsonKind.object ||
              child.value.kind == JsonKind.array);
      output.write(nested ? '\n' : ' ');
      write(child.value, depth + 1);
    }
  }

  write(parsed.root!, 0);
  output.write('\n');
  // JSON quoted strings and exact numeric tokens are retained in the YAML.
  loadYamlDocuments(output.toString());
  return output.toString();
}

List<YamlDocument> _yamlDocuments(String source) => loadYamlDocuments(source);
int yamlDocumentCount(String source) => _yamlDocuments(source).length;

String _numberToken(YamlScalar scalar) {
  var token = scalar.span.text.trim();
  final property = RegExp(r'^(?:&[^\s]+|!<[^>]+>|![^\s]+)\s+');
  while (property.hasMatch(token)) {
    token = token.replaceFirst(property, '');
  }
  if (scalar.style == ScalarStyle.SINGLE_QUOTED ||
      scalar.style == ScalarStyle.DOUBLE_QUOTED) {
    token = loadYamlNode(token).value as String;
  }
  final radix = RegExp(r'^([+-]?)0([xob])([0-9a-fA-F]+)$').firstMatch(token);
  if (radix != null) {
    final value = BigInt.parse(
      radix[3]!,
      radix: switch (radix[2]) {
        'x' => 16,
        'o' => 8,
        _ => 2,
      },
    );
    return '${radix[1] == '-' ? '-' : ''}$value';
  }
  final decimal = RegExp(
    r'^([+-]?)(\d*)(?:\.(\d*))?([eE][+-]?\d+)?$',
  ).firstMatch(token);
  if (decimal == null || '${decimal[2]}${decimal[3] ?? ''}'.isEmpty) {
    throw FormatException(
      'This YAML number has no JSON representation.',
      null,
      scalar.span.start.offset,
    );
  }
  final integer = (decimal[2]!.isEmpty ? '0' : decimal[2]!).replaceFirst(
    RegExp(r'^0+(?=\d)'),
    '',
  );
  final fraction = decimal[3];
  return '${decimal[1] == '-' ? '-' : ''}$integer${fraction == null ? '' : '.${fraction.isEmpty ? '0' : fraction}'}${decimal[4] ?? ''}';
}

String yamlToJson(String source, {int document = 0, int indent = 2}) {
  final documents = _yamlDocuments(source);
  if (document < 0 || document >= documents.length) {
    throw const FormatException('Select an available YAML document.');
  }
  final directives = <String, String>{
    '!': '!',
    '!!': 'tag:yaml.org,2002:',
    for (final directive in documents[document].tagDirectives)
      directive.handle: directive.prefix,
  };
  bool checkTags(YamlNode node) {
    var tagged = false;
    var prefix = node.span.text.trimLeft();
    final property = RegExp(r'^(?:&[^\s]+|!<[^>]+>|![^\s]*)(?:\s+|$)');
    while (true) {
      if (prefix.startsWith('#')) {
        final newline = prefix.indexOf('\n');
        if (newline < 0) break;
        prefix = prefix.substring(newline + 1).trimLeft();
        continue;
      }
      final match = property.firstMatch(prefix);
      if (match == null) break;
      final token = match[0]!.trim();
      if (token.startsWith('!')) tagged = true;
      if (token.startsWith('!') && token != '!') {
        final handled = RegExp(r'^(![^!]*!)(.*)$').firstMatch(token);
        final tag = token.startsWith('!<')
            ? token.substring(2, token.length - 1)
            : handled == null
            ? token
            : '${directives[handled[1]] ?? handled[1]}${handled[2]}';
        if (!{
          'null',
          'bool',
          'int',
          'float',
          'str',
          'map',
          'seq',
        }.any((name) => tag == 'tag:yaml.org,2002:$name')) {
          throw FormatException(
            'This YAML tag has no JSON representation: $token',
            source,
            node.span.start.offset,
          );
        }
      }
      prefix = prefix.substring(match.end).trimLeft();
    }
    return tagged;
  }

  final output = ConversionBuffer();
  final active = HashSet<YamlNode>.identity();
  final merging = HashSet<YamlNode>.identity();
  Map<String, YamlNode> entries(YamlMap map, int depth) {
    if (depth > 512 || !merging.add(map)) {
      throw const FormatException('Cyclic or deeply nested YAML mapping.');
    }
    final result = <String, YamlNode>{};
    final explicit = <String, YamlNode>{};
    for (final entry in map.nodes.entries) {
      final key = entry.key as YamlNode;
      final tagged = checkTags(key);
      if (key is! YamlScalar || key.value is! String) {
        throw FormatException(
          'JSON object keys must be strings.',
          source,
          key.span.start.offset,
        );
      }
      if (key.value == '<<' && key.style == ScalarStyle.PLAIN && !tagged) {
        final merges = entry.value is YamlList
            ? (entry.value as YamlList).nodes
            : [entry.value];
        for (final merge in merges) {
          if (merge is! YamlMap) {
            throw FormatException(
              'A YAML merge must contain mappings.',
              source,
              merge.span.start.offset,
            );
          }
          for (final merged in entries(merge, depth + 1).entries) {
            result.putIfAbsent(merged.key, () => merged.value);
          }
        }
      } else {
        explicit[key.value as String] = entry.value;
      }
    }
    merging.remove(map);
    return result..addAll(explicit);
  }

  void write(YamlNode node, int depth) {
    checkTags(node);
    if (depth > 512 || !active.add(node)) {
      throw const FormatException('Cyclic or deeply nested YAML data.');
    }
    if (node is YamlScalar) {
      output.write(
        node.value is num ? _numberToken(node) : jsonEncode(node.value),
      );
    } else if (node is YamlList) {
      output.write('[');
      for (var i = 0; i < node.nodes.length; i++) {
        if (i > 0) output.write(',');
        write(node.nodes[i], depth + 1);
      }
      output.write(']');
    } else if (node is YamlMap) {
      output.write('{');
      var first = true;
      for (final entry in entries(node, 0).entries) {
        if (!first) output.write(',');
        first = false;
        output.write('${jsonEncode(entry.key)}:');
        write(entry.value, depth + 1);
      }
      output.write('}');
    }
    active.remove(node);
  }

  write(documents[document].contents, 0);
  final text = output.toString();
  final parsed = parseJson(text);
  if (parsed.root == null) {
    throw const FormatException('YAML data cannot be represented as JSON.');
  }
  return rewriteJson(
    JsonDocument(SourceBuffer(text), snapshot: parsed),
    maxLength: maxConversionUnits,
    options: JsonFormatOptions(
      indentation: switch (indent) {
        4 => JsonIndentation.fourSpaces,
        8 => JsonIndentation.eightSpaces,
        _ => JsonIndentation.twoSpaces,
      },
    ),
  );
}
