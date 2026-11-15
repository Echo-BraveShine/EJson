import 'package:ejson_core/ejson_core.dart';
import 'array_table_data.dart';

enum ConversionDirection {
  jsonToYaml(DocumentFormat.json, DocumentFormat.yaml),
  yamlToJson(DocumentFormat.yaml, DocumentFormat.json),
  jsonToCsv(DocumentFormat.json, DocumentFormat.csv),
  csvToJson(DocumentFormat.csv, DocumentFormat.json),
  jsonToToml(DocumentFormat.json, DocumentFormat.toml),
  tomlToJson(DocumentFormat.toml, DocumentFormat.json),
  jsonToXml(DocumentFormat.json, DocumentFormat.xml),
  xmlToJson(DocumentFormat.xml, DocumentFormat.json),
  jsonToJsonLines(DocumentFormat.json, DocumentFormat.jsonLines),
  jsonLinesToJson(DocumentFormat.jsonLines, DocumentFormat.json);

  const ConversionDirection(this.sourceFormat, this.targetFormat);
  final DocumentFormat sourceFormat, targetFormat;
  String get label => '${sourceFormat.label} → ${targetFormat.label}';
}

class ConversionRequest {
  const ConversionRequest(
    this.source,
    this.direction, {
    this.indent = 2,
    this.document = 0,
    this.flatten = false,
    this.delimiter = ',',
    this.header = true,
    this.crlf = true,
    this.bom = false,
    this.columns,
    this.csvPath = r'$',
    this.importColumns,
    this.emptyCells = CsvEmptyValue.emptyString,
    this.xmlRoot = 'root',
    this.xmlMapping = XmlMappingMode.typed,
  });
  final String source;
  final ConversionDirection direction;
  final int indent;
  final int document;
  final bool flatten;
  final String delimiter;
  final bool header;
  final bool crlf;
  final bool bom;
  final List<ArrayTableColumn>? columns;
  final String csvPath;
  final List<CsvImportColumn>? importColumns;
  final CsvEmptyValue emptyCells;
  final String xmlRoot;
  final XmlMappingMode xmlMapping;
}

class ConversionOutput {
  const ConversionOutput(
    this.source,
    this.format, {
    this.columns = const [],
    this.documents = 1,
    this.bom = false,
  });
  final String source;
  final DocumentFormat format;
  final List<ArrayTableColumn> columns;
  final int documents;
  final bool bom;
}

class ConversionCancelled implements Exception {}
