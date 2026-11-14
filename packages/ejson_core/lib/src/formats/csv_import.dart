import 'dart:convert';
import '../syntax.dart';
import 'csv_document.dart';
import 'conversion_support.dart';

enum CsvValueType { string, number, boolean, json }

enum CsvEmptyValue { emptyString, nullValue, omitField }

class CsvImportColumn {
  const CsvImportColumn(this.name, {this.type = CsvValueType.string});
  final String name;
  final CsvValueType type;
}

List<CsvImportColumn> csvImportColumns(
  String source, {
  String? delimiter,
  bool header = true,
}) {
  final first = csvRecords(source, delimiter: delimiter).firstOrNull;
  return [
    for (var i = 0; i < (first?.cells.length ?? 0); i++)
      CsvImportColumn(header ? first!.cells[i].text : 'column_${i + 1}'),
  ];
}

String csvToJson(
  String source, {
  String? delimiter,
  bool header = true,
  List<CsvImportColumn>? columns,
  CsvEmptyValue empty = CsvEmptyValue.emptyString,
  int indent = 2,
}) {
  final rows = readCsv(source, delimiter: delimiter).records;
  if (rows.isEmpty) return '[]';
  final fields =
      columns ?? csvImportColumns(source, delimiter: delimiter, header: header);
  if (fields.length != rows.first.cells.length) {
    throw const FormatException(
      'CSV column configuration does not match the input.',
    );
  }
  if (fields.any((c) => c.name.isEmpty) ||
      fields.map((c) => c.name).toSet().length != fields.length) {
    throw const FormatException(
      'CSV column names must be non-empty and unique. Rename the columns.',
    );
  }
  final output = ConversionBuffer()..write('[');
  for (var rowIndex = header ? 1 : 0; rowIndex < rows.length; rowIndex++) {
    if (rowIndex > (header ? 1 : 0)) output.write(',');
    output.write('{');
    var first = true;
    for (var columnIndex = 0; columnIndex < fields.length; columnIndex++) {
      final cell = rows[rowIndex].cells[columnIndex];
      if (cell.text.isEmpty && empty == CsvEmptyValue.omitField) continue;
      if (!first) output.write(',');
      first = false;
      output.write('${jsonEncode(fields[columnIndex].name)}:');
      if (cell.text.isEmpty) {
        output.write(empty == CsvEmptyValue.nullValue ? 'null' : '""');
        continue;
      }
      final text = cell.text.trim();
      final parsed = parseJson(text).root;
      final type = fields[columnIndex].type;
      if (type == CsvValueType.string) {
        output.write(jsonEncode(cell.text));
        continue;
      }
      final valid = switch (type) {
        CsvValueType.number => parsed?.kind == JsonKind.number,
        CsvValueType.boolean => parsed?.kind == JsonKind.boolean,
        CsvValueType.json => parsed != null,
        CsvValueType.string => true,
      };
      if (!valid) {
        throw FormatException(
          'Cannot read ${type.name} at row ${rowIndex + 1}, column ${columnIndex + 1} (${fields[columnIndex].name}).',
          source,
          cell.range.start,
        );
      }
      output.write(text);
    }
    output.write('}');
  }
  output.write(']');
  return prettyConversionJson(output.toString(), indent: indent);
}
