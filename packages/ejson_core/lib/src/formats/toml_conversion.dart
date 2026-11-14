import 'dart:convert';
import 'package:toml/toml.dart';

import '../syntax.dart';
import '../number_compare.dart';
import 'conversion_support.dart';
import 'toml_tokens.dart';

TomlDocument parseTomlDocument(String source) {
  if (source.length > maxConversionUnits) {
    throw const FormatException('TOML exceeds the supported text size limit.');
  }
  try {
    final document = TomlDocument.parse(source);
    document.toMap();
    return document;
  } on TomlException catch (error) {
    throw FormatException(
      error.message,
      source,
      error is FormatException ? (error as FormatException).offset : null,
    );
  }
}

Map<String, Object?> readTomlData(
  String source, {
  bool allowNonFinite = false,
}) {
  parseTomlDocument(source);
  final protected = protectTomlNumbers(source);
  final data = TomlDocument.parse(protected.source).toMap();
  Object? restore(Object? value, String path, int depth) {
    if (depth > 256) {
      throw FormatException('TOML nesting exceeds 256 levels at $path.');
    }
    if (value is String && protected.numbers.containsKey(value)) {
      final token = protected.numbers[value]!;
      if (token.contains('inf') || token.contains('nan')) {
        if (allowNonFinite) return token;
        throw FormatException(
          'Non-finite number cannot be represented as JSON at $path.',
        );
      }
      return ExactJsonNumber(token);
    }
    if (value is TomlDateTime) {
      final printer = TomlPrettyPrinter(
        alwaysIncludeSeconds: true,
        useIsoDateTimeSeparator: true,
      )..visit(value);
      return printer.toString();
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key as String: restore(
            entry.value,
            '$path[${jsonEncode(entry.key)}]',
            depth + 1,
          ),
      };
    }
    if (value is List) {
      return [
        for (var i = 0; i < value.length; i++)
          restore(value[i], '$path[$i]', depth + 1),
      ];
    }
    return value;
  }

  return (restore(data, r'$', 0) as Map).cast<String, Object?>();
}

String tomlToJson(String source, {int indent = 2}) =>
    encodeConversionJson(readTomlData(source), indent: indent);

String jsonToToml(String source) {
  final root = requireJsonRoot(source, uniqueKeys: true);
  if (root.kind != JsonKind.object) {
    throw const FormatException(r'TOML requires an object at $.');
  }
  final output = ConversionBuffer();
  void value(JsonNode node, String path, int depth) {
    if (depth > 256) {
      throw FormatException('TOML nesting exceeds 256 levels at $path.');
    }
    final raw = source.substring(node.range.start, node.range.end);
    switch (node.kind) {
      case JsonKind.nil:
        throw FormatException(
          'TOML has no null value at $path.',
          source,
          node.range.start,
        );
      case JsonKind.number:
        if (!raw.contains(RegExp('[.eE]'))) {
          final integer = BigInt.parse(raw);
          if (integer < -(BigInt.one << 63) || integer >= (BigInt.one << 63)) {
            throw FormatException(
              'Integer exceeds the portable TOML signed 64-bit range at $path.',
              source,
              node.range.start,
            );
          }
        } else {
          final number = double.tryParse(raw);
          if (number == null ||
              !number.isFinite ||
              compareJsonNumbers(raw, number.toString()) != 0) {
            throw FormatException(
              'Number would lose precision in a TOML float at $path.',
              source,
              node.range.start,
            );
          }
        }
        output.write(raw);
      case JsonKind.string:
        // Both formats support quoted strings, with Unicode and control escapes.
        final text = jsonDecode(raw) as String;
        output.write(jsonEncode(text).replaceAll(r'\/', '/'));
      case JsonKind.boolean:
        output.write(raw);
      case JsonKind.array:
        output.write('[');
        for (var i = 0; i < node.children.length; i++) {
          if (i > 0) output.write(', ');
          value(node.children[i].value, '$path[$i]', depth + 1);
        }
        output.write(']');
      case JsonKind.object:
        output.write('{ ');
        for (var i = 0; i < node.children.length; i++) {
          final child = node.children[i];
          if (i > 0) output.write(', ');
          output.write('${jsonEncode(child.key)} = ');
          value(child.value, '$path[${jsonEncode(child.key)}]', depth + 1);
        }
        output.write(' }');
    }
  }

  for (final child in root.children) {
    output.write('${jsonEncode(child.key)} = ');
    value(child.value, '\$[${jsonEncode(child.key)}]', 0);
    output.write('\n');
  }
  final text = output.toString();
  parseTomlDocument(text);
  return text;
}

/// Normalizes assignment spacing without re-encoding comments or value tokens.
String formatToml(String source) {
  parseTomlDocument(source);
  final tokens = tokenizeToml(source);
  final output = ConversionBuffer();
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.kind == 'space' &&
        i + 1 < tokens.length &&
        tokens[i + 1].text == '=' &&
        !token.text.contains(RegExp(r'[\r\n]'))) {
      continue;
    }
    if (token.text == '=') {
      output.write(' = ');
      if (i + 1 < tokens.length &&
          tokens[i + 1].kind == 'space' &&
          !tokens[i + 1].text.contains(RegExp(r'[\r\n]'))) {
        i++;
      }
    } else {
      output.write(token.text);
    }
  }
  final text = output.toString().trimRight();
  parseTomlDocument(text);
  return text.isEmpty ? '' : '$text\n';
}
