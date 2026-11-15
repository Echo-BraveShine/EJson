import '../document.dart';
import '../format.dart';
import '../syntax.dart';
import 'conversion_support.dart';

JsonLinesData readJsonLines(String source) {
  if (source.length > maxConversionUnits) {
    throw const FormatException(
      'Content exceeds the supported text size limit.',
    );
  }
  final records = <JsonLineRecord>[];
  var start = 0;
  void add(int end) {
    final text = source.substring(start, end);
    final parsed = parseJson(text);
    records.add(
      JsonLineRecord(
        lineNumber: records.length + 1,
        source: text,
        range: (start: start, end: end),
        diagnostics: List.unmodifiable([
          for (final diagnostic in parsed.diagnostics)
            JsonDiagnostic(
              diagnostic.code,
              diagnostic.message,
              (
                start: start + diagnostic.range.start,
                end: start + diagnostic.range.end,
              ),
              warning: diagnostic.warning,
              detail: diagnostic.detail,
            ),
        ]),
      ),
    );
  }

  for (final newline in RegExp(r'\r\n|\r|\n').allMatches(source)) {
    add(newline.start);
    start = newline.end;
  }
  if (start < source.length) add(source.length);
  return JsonLinesData(records);
}

String _compact(String source) => rewriteJson(
  JsonDocument(SourceBuffer(source), snapshot: parseJson(source)),
  minify: true,
  maxLength: maxConversionUnits,
);

void _requireValidLines(JsonLinesData data, String source) {
  for (final record in data.records) {
    if (record.isValid) continue;
    final error = record.diagnostics.firstWhere(
      (diagnostic) => !diagnostic.warning,
    );
    throw FormatException(error.message, source, error.range.start);
  }
}

String formatJsonLines(String source, {String lineEnding = '\n'}) {
  final data = readJsonLines(source);
  _requireValidLines(data, source);
  final output = ConversionBuffer();
  for (final record in data.records) {
    output.write(_compact(record.source));
    output.write(lineEnding);
  }
  return output.toString();
}

String jsonLinesToJson(String source, {int indent = 2}) {
  final data = readJsonLines(source);
  _requireValidLines(data, source);
  final output = ConversionBuffer()..write('[');
  for (var index = 0; index < data.records.length; index++) {
    if (index != 0) output.write(',');
    output.write(_compact(data.records[index].source));
  }
  output.write(']');
  requireJsonRoot(output.toString());
  return prettyConversionJson(output.toString(), indent: indent);
}

String jsonToJsonLines(String source, {String lineEnding = '\n'}) {
  final root = requireJsonRoot(source);
  final values = root.kind == JsonKind.array
      ? root.children.map((child) => child.value)
      : [root];
  final output = ConversionBuffer();
  for (final value in values) {
    output.write(
      _compact(source.substring(value.range.start, value.range.end)),
    );
    output.write(lineEnding);
  }
  return output.toString();
}
