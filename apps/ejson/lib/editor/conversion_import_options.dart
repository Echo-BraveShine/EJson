part of 'conversion_dialog.dart';

extension _ConversionImportOptions on _ConversionDialogState {
  List<CsvImportColumn> _initialImportColumns() {
    if (widget.format != DocumentFormat.csv) return [];
    try {
      return csvImportColumns(
        widget.source,
        delimiter: _delimiter,
        header: _header,
      );
    } on FormatException {
      return [];
    }
  }

  List<Widget> _csvImportOptions() {
    final strings = AppLocalizations.of(context);
    return [
      const SizedBox(height: WorkbenchStyle.space12),
      Text(strings.csvImportNotice, style: WorkbenchStyle.caption),
      const SizedBox(height: WorkbenchStyle.space8),
      WorkbenchSelect<String>(
        label: strings.conversionDelimiter,
        value: _delimiter,
        options: [
          (value: ',', label: strings.conversionComma),
          (value: ';', label: strings.conversionSemicolon),
          (value: '\t', label: strings.indentTabs),
        ],
        onChanged: (value) {
          _delimiter = value;
          _importColumns = _initialImportColumns();
          _invalidate();
        },
      ),
      _check(strings.csvHeaderRow, _header, (value) {
        _header = value;
        _importColumns = _initialImportColumns();
      }),
      WorkbenchSelect<CsvEmptyValue>(
        label: strings.csvEmptyCells,
        value: _emptyCells,
        options: [
          (value: CsvEmptyValue.emptyString, label: strings.csvEmptyString),
          (value: CsvEmptyValue.nullValue, label: 'null'),
          (value: CsvEmptyValue.omitField, label: strings.csvOmitField),
        ],
        onChanged: (value) {
          _emptyCells = value;
          _invalidate();
        },
      ),
      if (_importColumns.isNotEmpty)
        ExpansionTile(
          title: Text(strings.csvImportColumns, style: WorkbenchStyle.body),
          tilePadding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: 190,
              child: ListView.builder(
                primary: false,
                itemCount: _importColumns.length,
                itemBuilder: (context, index) => _CsvImportColumnEditor(
                  key: ValueKey('csv-import-column-$index'),
                  column: _importColumns[index],
                  onChanged: (column) {
                    _importColumns[index] = column;
                    _invalidate();
                  },
                ),
              ),
            ),
          ],
        ),
    ];
  }
}

class _CsvImportColumnEditor extends StatefulWidget {
  const _CsvImportColumnEditor({
    super.key,
    required this.column,
    required this.onChanged,
  });
  final CsvImportColumn column;
  final ValueChanged<CsvImportColumn> onChanged;
  @override
  State<_CsvImportColumnEditor> createState() => _CsvImportColumnEditorState();
}

class _CsvImportColumnEditorState extends State<_CsvImportColumnEditor> {
  late final _name = TextEditingController(text: widget.column.name);
  @override
  void didUpdateWidget(covariant _CsvImportColumnEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_name.text != widget.column.name) _name.text = widget.column.name;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WorkbenchStyle.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: WorkbenchTextField(
              controller: _name,
              labelText: strings.csvColumnName,
              onChanged: (value) => widget.onChanged(
                CsvImportColumn(value, type: widget.column.type),
              ),
            ),
          ),
          const SizedBox(width: WorkbenchStyle.space8),
          Expanded(
            child: WorkbenchSelect<CsvValueType>(
              label: strings.csvColumnType,
              value: widget.column.type,
              options: [
                (value: CsvValueType.string, label: strings.csvTypeText),
                (value: CsvValueType.number, label: strings.csvTypeNumber),
                (value: CsvValueType.boolean, label: strings.csvTypeBoolean),
                (value: CsvValueType.json, label: 'JSON'),
              ],
              onChanged: (value) =>
                  widget.onChanged(CsvImportColumn(_name.text, type: value)),
            ),
          ),
        ],
      ),
    );
  }
}
