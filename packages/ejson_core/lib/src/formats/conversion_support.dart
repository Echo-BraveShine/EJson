import 'dart:convert';

import '../syntax.dart';
import '../document.dart';
import '../format.dart';

const maxConversionUnits = 16 * 1024 * 1024;

class ConversionBuffer implements StringSink {
  final _buffer = StringBuffer();
  int get length => _buffer.length;

  @override
  void write(Object? object) {
    final text = object.toString();
    if (_buffer.length + text.length > maxConversionUnits) {
      throw const FormatException(
        'Converted content exceeds the supported text size limit.',
      );
    }
    _buffer.write(text);
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    var first = true;
    for (final object in objects) {
      if (!first) write(separator);
      first = false;
      write(object);
    }
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));
  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }

  @override
  String toString() => _buffer.toString();
}

/// Carries validated numeric spelling across format adapters without a double.
class ExactJsonNumber {
  ExactJsonNumber(this.token) {
    if (parseJson(token).root?.kind != JsonKind.number) {
      throw FormatException('Invalid JSON number: $token');
    }
  }
  final String token;
}

JsonNode requireJsonRoot(String source, {bool uniqueKeys = false}) {
  final parsed = parseJson(source);
  final root = parsed.root;
  if (root == null) {
    final error = parsed.diagnostics.first;
    throw FormatException(error.message, source, error.range.start);
  }
  if (uniqueKeys && parsed.diagnostics.any((d) => d.code == 'duplicate_key')) {
    final error = parsed.diagnostics.firstWhere(
      (d) => d.code == 'duplicate_key',
    );
    throw FormatException(
      'Conversion requires unique object keys.',
      source,
      error.range.start,
    );
  }
  return root;
}

String prettyConversionJson(String source, {int indent = 2}) => rewriteJson(
  JsonDocument(SourceBuffer(source), snapshot: parseJson(source)),
  maxLength: maxConversionUnits,
  options: JsonFormatOptions(
    indentation: switch (indent) {
      4 => JsonIndentation.fourSpaces,
      8 => JsonIndentation.eightSpaces,
      _ => JsonIndentation.twoSpaces,
    },
  ),
);

String encodeConversionJson(Object? value, {int indent = 2}) {
  final output = ConversionBuffer();
  void write(Object? value, String path, int depth) {
    if (depth > 256) {
      throw FormatException('Data nesting exceeds 256 levels at $path.');
    }
    switch (value) {
      case ExactJsonNumber(:final token):
        output.write(token);
      case BigInt():
        output.write(value);
      case Map():
        output.write('{');
        var first = true;
        for (final entry in value.entries) {
          if (entry.key is! String) {
            throw FormatException('Object keys must be strings at $path.');
          }
          if (!first) output.write(',');
          first = false;
          output.write('${jsonEncode(entry.key)}:');
          write(entry.value, '$path[${jsonEncode(entry.key)}]', depth + 1);
        }
        output.write('}');
      case List():
        output.write('[');
        for (var i = 0; i < value.length; i++) {
          if (i > 0) output.write(',');
          write(value[i], '$path[$i]', depth + 1);
        }
        output.write(']');
      case double() when !value.isFinite:
        throw FormatException(
          'Non-finite numbers cannot be represented as JSON at $path.',
        );
      case String() || num() || bool() || null:
        output.write(jsonEncode(value));
      default:
        throw FormatException('Unsupported data type at $path.');
    }
  }

  write(value, r'$', 0);
  return prettyConversionJson(output.toString(), indent: indent);
}
