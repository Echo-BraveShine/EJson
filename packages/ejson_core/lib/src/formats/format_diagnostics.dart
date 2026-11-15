import 'package:yaml/yaml.dart';
import 'package:toml/toml.dart';
import '../syntax.dart';
import 'document_format.dart';
import 'conversion_support.dart';
import 'csv_document.dart';
import 'toml_conversion.dart';
import 'xml_document.dart';
import 'format_structure.dart';
import 'format_structure_builders.dart';
import 'toml_source_ranges.dart';
import 'xml_structure.dart';
import 'json_lines.dart';

ParseSnapshot parseOtherFormat(
  String source,
  DocumentFormat format, {
  int revision = 0,
}) {
  final diagnostics = <JsonDiagnostic>[];
  FormatTreeNode? structure;
  CsvData? table;
  JsonLinesData? jsonLines;
  final budget = StructureBudget();
  try {
    if (source.length > maxConversionUnits) {
      throw const FormatException(
        'Content exceeds the supported text size limit.',
      );
    }
    switch (format) {
      case DocumentFormat.jsonLines:
        jsonLines = readJsonLines(source);
        diagnostics.addAll(
          jsonLines.records.expand((record) => record.diagnostics),
        );
      case DocumentFormat.json:
        return parseJson(source, revision: revision);
      case DocumentFormat.yaml:
        final documents = loadYamlDocuments(source);
        structure = FormatTreeNode(
          'YAML',
          'array',
          '[${documents.length}]',
          children: [
            for (var i = 0; i < documents.length; i++)
              if (budget.take())
                yamlStructure(documents[i].contents, '[${i + 1}]', budget),
          ],
        );
      case DocumentFormat.csv:
        table = readCsv(source);
      case DocumentFormat.xml:
        parseXmlDocument(source);
        structure = xmlSourceStructure(source, budget);
      case DocumentFormat.toml:
        // Syntax validation also accepts non-finite floats, which a JSON
        // conversion reports separately as an incompatible value.
        final data = readTomlData(source, allowNonFinite: true);
        structure = valueStructure(
          data,
          'TOML',
          budget,
          ranges: tomlSourceRanges(source),
        );
    }
  } catch (error) {
    final offset = switch (error) {
      YamlException(:final span) => span?.start.offset ?? 0,
      FormatException(:final offset) => offset ?? 0,
      _ => 0,
    };
    final message = error is TomlException ? error.message : error.toString();
    diagnostics.add(
      JsonDiagnostic('format_error', message, (
        start: offset.clamp(0, source.length),
        end: offset.clamp(0, source.length),
      )),
    );
  }
  return ParseSnapshot(
    revision,
    LineIndex(source),
    null,
    diagnostics,
    structure: diagnostics.isEmpty ? structure : null,
    table: diagnostics.isEmpty ? table : null,
    jsonLines: jsonLines,
    structureTruncated: budget.truncated,
  );
}
