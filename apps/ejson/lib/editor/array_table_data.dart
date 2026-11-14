import 'dart:convert';

import 'package:ejson_core/ejson_core.dart';

typedef ArrayTableColumn = ({String? key, int occurrence});

/// Reads cells from source ranges, retaining duplicate keys and number spelling.
class ArrayTableData {
  ArrayTableData(this.source, JsonNode array) {
    final found = <ArrayTableColumn>{};
    for (final child in array.children) {
      final cells = <ArrayTableColumn, JsonNode>{};
      final node = child.value;
      if (node.kind == JsonKind.object) {
        final occurrences = <String, int>{};
        for (final property in node.children) {
          final key = property.key!;
          final occurrence = occurrences.update(
            key,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          final column = (key: key, occurrence: occurrence);
          found.add(column);
          cells[column] = property.value;
        }
      } else {
        const column = (key: null, occurrence: 1);
        found.add(column);
        cells[column] = node;
      }
      rows.add(cells);
    }
    columns = found.toList();
  }

  final String source;
  final rows = <Map<ArrayTableColumn, JsonNode>>[];
  late final List<ArrayTableColumn> columns;

  String columnLabel(ArrayTableColumn column, {bool quoteKeys = true}) {
    if (column.key == null) return r'$';
    final label = quoteKeys ? jsonEncode(column.key) : column.key!;
    return column.occurrence == 1 ? label : '$label #${column.occurrence}';
  }

  String raw(JsonNode node) =>
      source.substring(node.range.start, node.range.end);

  String value(JsonNode? node) {
    if (node == null) return '';
    final text = raw(node);
    return node.kind == JsonKind.string ? jsonDecode(text) as String : text;
  }

  List<int> select({
    String filter = '',
    int? sortColumn,
    bool ascending = true,
  }) {
    final query = filter.toLowerCase();
    final selected = <int>[
      for (var index = 0; index < rows.length; index++)
        if (query.isEmpty ||
            rows[index].values.any(
              (node) => value(node).toLowerCase().contains(query),
            ))
          index,
    ];
    if (sortColumn == null) return selected;
    final column = columns[sortColumn];
    selected.sort((left, right) {
      final a = rows[left][column];
      final b = rows[right][column];
      var order = 0;
      if (a == null || b == null) {
        order = a == b
            ? 0
            : a == null
            ? 1
            : -1;
      } else {
        order = compareJsonValues(source, a, b);
      }
      if (order == 0) return left.compareTo(right);
      return ascending ? order : -order;
    });
    return selected;
  }

  /// Exports the visible row order. Quoting also preserves embedded line breaks.
  String csv(
    List<int> selected, {
    int? maxLength,
    List<ArrayTableColumn>? selectedColumns,
    String delimiter = ',',
    bool header = true,
    String lineEnding = '\r\n',
    bool bom = false,
  }) {
    final exportedColumns = selectedColumns ?? columns;
    String quote(String value) => '"${value.replaceAll('"', '""')}"';
    final buffer = StringBuffer();
    void appendRow(Iterable<String> fields) {
      final line = fields.map(quote).join(delimiter);
      final separator = buffer.isEmpty ? '' : lineEnding;
      if (maxLength != null &&
          buffer.length + separator.length + line.length > maxLength) {
        throw const FormatException('CSV exceeds output size limit');
      }
      buffer.write(separator);
      buffer.write(line);
    }

    if (header) {
      appendRow(
        exportedColumns.map((column) => columnLabel(column, quoteKeys: false)),
      );
    }
    for (final index in selected) {
      appendRow(exportedColumns.map((column) => value(rows[index][column])));
    }
    return '${bom ? '\uFEFF' : ''}$buffer';
  }
}
