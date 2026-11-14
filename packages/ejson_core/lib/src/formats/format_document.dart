import 'document_format.dart';
import 'csv_document.dart';
import 'conversion_support.dart';
import 'toml_conversion.dart';
import 'xml_document.dart';
import 'yaml_formatting.dart';

String formatOtherDocument(
  String source,
  DocumentFormat format, {
  int indent = 2,
  String lineEnding = '\n',
  bool minify = false,
}) {
  switch (format) {
    case DocumentFormat.xml:
      return writeXmlDocument(
        parseXmlDocument(source),
        indent: indent,
        compact: minify,
        lineEnding: lineEnding,
      );
    case DocumentFormat.toml:
      return formatToml(source).replaceAll(RegExp(r'\r\n|\r|\n'), lineEnding);
    case DocumentFormat.yaml:
      return formatYaml(source, indent: indent, lineEnding: lineEnding);
    case DocumentFormat.csv:
      final data = readCsv(source);
      final output = ConversionBuffer();
      for (var i = 0; i < data.records.length; i++) {
        if (i > 0) output.write(lineEnding);
        output.write(
          data.records[i].cells
              .map((c) => '"${c.text.replaceAll('"', '""')}"')
              .join(data.delimiter),
        );
      }
      return output.toString();
    case DocumentFormat.json:
      throw ArgumentError('Use the JSON formatter for JSON documents.');
  }
}
