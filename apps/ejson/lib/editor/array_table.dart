import '../design/workbench_text_field.dart';
import 'dart:math' as math;

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../design/reading_style.dart';
import '../l10n/app_localizations.dart';
import '../workspace/local_files.dart' show maxFileBytes;
import 'array_table_data.dart';

class ArrayTable extends StatefulWidget {
  const ArrayTable({
    super.key,
    required this.source,
    required this.array,
    required this.onCopy,
    required this.onExport,
    this.onReveal,
  });

  final String source;
  final JsonNode array;
  final Future<void> Function(String) onCopy;
  final Future<String?> Function(String) onExport;
  final ValueChanged<SourceRange>? onReveal;

  @override
  State<ArrayTable> createState() => _ArrayTableState();
}

class _ArrayTableState extends State<ArrayTable> {
  double get _columnWidth => 180 * ReadingStyle.of(context).widthScale;
  double get _indexWidth => 56 * ReadingStyle.of(context).widthScale;
  double get _rowHeight => ReadingStyle.of(context).rowHeight();
  late final _data = ArrayTableData(widget.source, widget.array);
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  final _filter = TextEditingController();
  late List<int> _rows = _data.select();
  int? _sortColumn;
  bool _ascending = true;
  bool _exporting = false;
  String? _feedback;

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _select() {
    _rows = _data.select(
      filter: _filter.text,
      sortColumn: _sortColumn,
      ascending: _ascending,
    );
    if (_vertical.hasClients) _vertical.jumpTo(0);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final message = await widget.onExport(
        _data.csv(_rows, maxLength: maxFileBytes),
      );
      if (mounted) setState(() => _feedback = message);
    } on FormatException {
      if (mounted) {
        setState(() => _feedback = AppLocalizations.of(context).exportFailed);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _copy(String value) async {
    await widget.onCopy(value);
    if (mounted) {
      setState(() => _feedback = AppLocalizations.of(context).valueCopied);
    }
  }

  Widget _cell(
    String text,
    double width, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: _rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.outlineVariant)),
        ),
        child: Tooltip(
          message: text,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WorkbenchStyle.space8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ReadingStyle.of(context).text,
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _cellMenu(JsonNode? node) {
    if (node == null || widget.onReveal == null) return null;
    final strings = AppLocalizations.of(context);
    return SizedBox(
      width: 24,
      child: PopupMenuButton<bool>(
        key: ValueKey('cell-menu:${node.range.start}'),
        tooltip: strings.nodeActions,
        padding: EdgeInsets.zero,
        icon: const Icon(CupertinoIcons.ellipsis, size: 14),
        onSelected: (reveal) {
          if (reveal) {
            widget.onReveal!(node.range);
          } else {
            _copy(_data.value(node));
          }
        },
        itemBuilder: (_) => [
          WorkbenchMenuItem(
            value: false,
            icon: CupertinoIcons.doc_on_doc,
            label: node.kind == JsonKind.string
                ? strings.copyDecodedString
                : strings.copyNodeValue,
          ),
          WorkbenchMenuItem(
            value: true,
            icon: CupertinoIcons.location,
            label: strings.goToSource,
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth,
          _indexWidth + _data.columns.length * _columnWidth,
        );
        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: width > constraints.maxWidth,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: AnimatedBuilder(
                animation: _horizontal,
                builder: (context, _) {
                  final offset = _horizontal.hasClients
                      ? _horizontal.offset
                      : 0.0;
                  final first = ((offset - _indexWidth) / _columnWidth)
                      .floor()
                      .clamp(0, _data.columns.length);
                  final last = ((offset + constraints.maxWidth) / _columnWidth)
                      .ceil()
                      .clamp(first, _data.columns.length);
                  return Column(
                    children: [
                      Material(
                        color: colors.surfaceContainer,
                        child: Row(
                          children: [
                            _cell(
                              '#',
                              _indexWidth,
                              onTap: () => setState(() {
                                _sortColumn = null;
                                _select();
                              }),
                            ),
                            SizedBox(width: first * _columnWidth),
                            for (var column = first; column < last; column++)
                              _cell(
                                _data.columnLabel(_data.columns[column]),
                                _columnWidth,
                                trailing: _sortColumn == column
                                    ? Icon(
                                        _ascending
                                            ? CupertinoIcons.chevron_up
                                            : CupertinoIcons.chevron_down,
                                        size: 12,
                                      )
                                    : null,
                                onTap: () => setState(() {
                                  _ascending = _sortColumn == column
                                      ? !_ascending
                                      : true;
                                  _sortColumn = column;
                                  _select();
                                }),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: Scrollbar(
                          controller: _vertical,
                          child: ListView.builder(
                            controller: _vertical,
                            itemExtent: _rowHeight,
                            itemCount: _rows.length,
                            itemBuilder: (context, row) {
                              final index = _rows[row];
                              return Material(
                                color: row.isOdd
                                    ? colors.surfaceContainerLow
                                    : colors.surface,
                                child: Row(
                                  children: [
                                    _cell('$index', _indexWidth),
                                    SizedBox(width: first * _columnWidth),
                                    for (final column
                                        in _data.columns
                                            .skip(first)
                                            .take(last - first))
                                      _cell(
                                        _data.value(_data.rows[index][column]),
                                        _columnWidth,
                                        trailing: _cellMenu(
                                          _data.rows[index][column],
                                        ),
                                        onTap: _data.rows[index][column] == null
                                            ? null
                                            : () => _copy(
                                                _data.value(
                                                  _data.rows[index][column],
                                                ),
                                              ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    return WorkbenchDialog(
      title: strings.arrayTable,
      scrollable: false,
      content: SizedBox(
        width: (size.width - 120).clamp(240.0, 1000.0),
        height: (size.height * .65).clamp(180.0, 620.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: WorkbenchTextField(
                    controller: _filter,
                    onChanged: (_) => setState(_select),
                    hintText: strings.filterRows,
                    prefixIcon: const Icon(
                      CupertinoIcons.search,
                      size: WorkbenchStyle.controlIconSize,
                    ),
                  ),
                ),
                const SizedBox(width: WorkbenchStyle.space12),
                Text(strings.tableRowCount(_rows.length, _data.rows.length)),
              ],
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            Expanded(
              child: _data.rows.isEmpty || _rows.isEmpty
                  ? Center(
                      child: Text(
                        _data.rows.isEmpty
                            ? strings.emptyArray
                            : strings.noMatches,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(
                        WorkbenchStyle.controlRadius,
                      ),
                      child: _grid(),
                    ),
            ),
            const SizedBox(height: WorkbenchStyle.space8),
            Text(
              _feedback ?? strings.tableInstructions,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: _exporting || _data.columns.isEmpty ? null : _export,
          child: Text(strings.exportCsv),
        ),
        FilledButton(
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.done),
        ),
      ],
    );
  }
}
