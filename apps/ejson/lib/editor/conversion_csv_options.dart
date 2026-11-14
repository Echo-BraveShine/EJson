part of 'conversion_dialog.dart';

extension _ConversionCsvOptions on _ConversionDialogState {
  List<Widget> _csvOptions() {
    final strings = AppLocalizations.of(context);
    return [
      Text(strings.conversionCsvNotice, style: WorkbenchStyle.caption),
      const SizedBox(height: WorkbenchStyle.space8),
      WorkbenchTextField(
        controller: _csvPath,
        labelText: strings.conversionCsvPath,
        onChanged: (_) => _invalidate(resetColumns: true),
      ),
      const SizedBox(height: WorkbenchStyle.space8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: WorkbenchSelect<String>(
              label: strings.conversionDelimiter,
              value: _delimiter,
              options: [
                (value: ',', label: strings.conversionComma),
                (value: ';', label: strings.conversionSemicolon),
                (value: '\t', label: strings.indentTabs),
              ],
              onChanged: (value) {
                _delimiter = value;
                _invalidate();
              },
            ),
          ),
          const SizedBox(width: WorkbenchStyle.space8),
          _runButton(),
        ],
      ),
      _check(strings.conversionHeader, _header, (v) => _header = v),
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(strings.conversionFlatten, style: WorkbenchStyle.body),
        value: _flatten,
        onChanged: (v) {
          _flatten = v ?? false;
          _invalidate(resetColumns: true);
        },
      ),
      WorkbenchSelect<bool>(
        label: strings.lineEnding,
        value: _crlf,
        options: const [
          (value: true, label: 'CRLF'),
          (value: false, label: 'LF'),
        ],
        onChanged: (value) {
          _crlf = value;
          _invalidate();
        },
      ),
      _check('UTF-8 BOM', _bom, (v) => _bom = v),
      if (_columnsKnown && _order.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(strings.conversionColumns, style: WorkbenchStyle.body),
          children: [
            SizedBox(
              height: 180,
              child: ListView.builder(
                primary: false,
                itemCount: _order.length,
                itemBuilder: (context, index) {
                  final column = _order[index];
                  final label =
                      '${column.key ?? r'$'}${column.occurrence > 1 ? ' #${column.occurrence}' : ''}';
                  return Row(
                    key: ValueKey<Object>(('conversion-column', column)),
                    children: [
                      Checkbox(
                        value: _included.contains(column),
                        semanticLabel: label,
                        onChanged: (value) {
                          if (value == true) {
                            _included.add(column);
                          } else {
                            _included.remove(column);
                          }
                          _invalidate();
                        },
                      ),
                      Expanded(
                        child: Tooltip(
                          message: label,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: strings.conversionColumnUp,
                        onPressed: index == 0 ? null : () => _move(index, -1),
                        icon: const Icon(
                          CupertinoIcons.arrow_up,
                          size: WorkbenchStyle.controlIconSize,
                        ),
                      ),
                      IconButton(
                        tooltip: strings.conversionColumnDown,
                        onPressed: index == _order.length - 1
                            ? null
                            : () => _move(index, 1),
                        icon: const Icon(
                          CupertinoIcons.arrow_down,
                          size: WorkbenchStyle.controlIconSize,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
    ];
  }
}
