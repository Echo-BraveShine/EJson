typedef TextRange = ({int start, int end});

class CsvCell {
  const CsvCell(this.text, this.range);
  final String text;
  final TextRange range;
}

class CsvRecord {
  const CsvRecord(this.cells, this.range);
  final List<CsvCell> cells;
  final TextRange range;
}

class CsvData {
  const CsvData(this.records, this.delimiter);
  final List<CsvRecord> records;
  final String delimiter;
}

/// Read-only structural information sent with validation results from isolates.
class FormatTreeNode {
  const FormatTreeNode(
    this.label,
    this.kind,
    this.value, {
    this.children = const [],
    this.range,
  });
  final String label;
  final String kind;
  final String value;
  final List<FormatTreeNode> children;
  final ({int start, int end})? range;
}

class StructureBudget {
  var remaining = 10000;
  bool truncated = false;
  bool take() {
    if (remaining <= 0) {
      truncated = true;
      return false;
    }
    remaining--;
    return true;
  }
}
