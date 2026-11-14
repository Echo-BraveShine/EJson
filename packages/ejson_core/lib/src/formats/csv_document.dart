import 'conversion_support.dart';
import 'format_structure.dart';
export 'format_structure.dart' show CsvCell, CsvRecord, CsvData;

String detectCsvDelimiter(String source) {
  final counts = {',': 0, ';': 0, '\t': 0};
  var quoted = false;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (c == '"') {
      if (quoted && i + 1 < source.length && source[i + 1] == '"') {
        i++;
      } else {
        quoted = !quoted;
      }
    }
    if (!quoted && (c == '\r' || c == '\n')) break;
    if (!quoted && counts.containsKey(c)) counts[c] = counts[c]! + 1;
  }
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// A lazy RFC-4180-style reader. Header inspection reads only the first record.
Iterable<CsvRecord> csvRecords(String source, {String? delimiter}) sync* {
  if (source.length > maxConversionUnits) {
    throw const FormatException('CSV exceeds the supported text size limit.');
  }
  final separator = delimiter ?? detectCsvDelimiter(source);
  if (![',', ';', '\t'].contains(separator)) {
    throw const FormatException('Unsupported CSV delimiter.');
  }
  if (source.isEmpty) return;
  var offset = source.startsWith('\uFEFF') ? 1 : 0;
  var cellStart = offset;
  var rowStart = offset;
  var quoted = false;
  var closed = false;
  var value = StringBuffer();
  var cells = <CsvCell>[];
  int? columns;
  var count = 0;
  CsvCell finishCell(int end) {
    if (++count > 1000000) {
      throw FormatException(
        'CSV exceeds the supported cell count.',
        source,
        offset,
      );
    }
    final cell = CsvCell(value.toString(), (start: cellStart, end: end));
    value = StringBuffer();
    closed = false;
    return cell;
  }

  CsvRecord finishRow(int end) {
    if (columns != null && columns != cells.length) {
      throw FormatException(
        'CSV rows have different column counts.',
        source,
        rowStart,
      );
    }
    columns = cells.length;
    final row = CsvRecord(List.unmodifiable(cells), (
      start: rowStart,
      end: end,
    ));
    cells = [];
    return row;
  }

  for (; offset < source.length; offset++) {
    final c = source[offset];
    if (quoted) {
      if (c != '"') {
        value.write(c);
      } else if (offset + 1 < source.length && source[offset + 1] == '"') {
        value.write('"');
        offset++;
      } else {
        quoted = false;
        closed = true;
      }
      continue;
    }
    if (c == separator) {
      cells.add(finishCell(offset));
      cellStart = offset + 1;
    } else if (c == '\r' || c == '\n') {
      cells.add(finishCell(offset));
      final end = offset;
      if (c == '\r' &&
          offset + 1 < source.length &&
          source[offset + 1] == '\n') {
        offset++;
      }
      yield finishRow(end);
      rowStart = offset + 1;
      cellStart = rowStart;
    } else if (c == '"' && offset == cellStart) {
      quoted = true;
    } else if (c == '"' || closed) {
      throw FormatException('Invalid CSV quote.', source, offset);
    } else {
      value.write(c);
    }
  }
  if (quoted) {
    throw FormatException('Unclosed CSV quoted field.', source, source.length);
  }
  if (cellStart < source.length || cells.isNotEmpty || closed) {
    cells.add(finishCell(source.length));
    yield finishRow(source.length);
  }
}

CsvData readCsv(String source, {String? delimiter}) {
  final separator = delimiter ?? detectCsvDelimiter(source);
  return CsvData(
    csvRecords(source, delimiter: separator).toList(growable: false),
    separator,
  );
}

void validateCsv(String source) {
  for (final _ in csvRecords(source)) {}
}
