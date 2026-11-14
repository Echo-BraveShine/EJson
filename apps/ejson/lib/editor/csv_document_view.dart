import 'dart:math' as math;
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import '../design/reading_style.dart';
import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';

class CsvDocumentView extends StatefulWidget {
  const CsvDocumentView({
    super.key,
    required this.data,
    required this.onReveal,
  });
  final CsvData data;
  final ValueChanged<SourceRange> onReveal;
  @override
  State<CsvDocumentView> createState() => _CsvDocumentViewState();
}

class _CsvDocumentViewState extends State<CsvDocumentView> {
  bool _header = true;
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final reading = ReadingStyle.of(context);
    final colors = Theme.of(context).colorScheme;
    final records = widget.data.records;
    if (records.isEmpty) return Center(child: Text(strings.noStructure));
    final totalColumns = records.first.cells.length;
    final columns = math.min(200, totalColumns);
    final start = _header ? 1 : 0;
    final count = math.min(10000, records.length - start);
    final cellWidth = 160 * reading.widthScale;
    final indexWidth = 44 * reading.widthScale;
    final height = reading.rowHeight();
    Widget cell(
      String text,
      double width, {
      VoidCallback? onTap,
      bool heading = false,
    }) => SizedBox(
      width: width,
      height: height,
      child: Material(
        color: heading ? colors.surfaceContainerLow : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(
              horizontal: WorkbenchStyle.space8,
            ),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: colors.outlineVariant),
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Tooltip(
              message: text,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: reading.text.copyWith(
                  fontWeight: heading ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WorkbenchStyle.space8,
          ),
          child: Row(
            children: [
              Checkbox(
                value: _header,
                onChanged: (value) => setState(() => _header = value ?? true),
              ),
              Expanded(
                child: Text(
                  strings.csvTableHeader,
                  style: WorkbenchStyle.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: WorkbenchStyle.space8),
              Flexible(
                child: Text(
                  strings.tableRowCount(count, records.length - start),
                  style: WorkbenchStyle.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (columns < totalColumns)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WorkbenchStyle.space8,
            ),
            child: Text(
              strings.csvVisibleColumns(columns, totalColumns),
              style: WorkbenchStyle.caption,
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(
                constraints.maxWidth,
                indexWidth + columns * cellWidth,
              );
              return Scrollbar(
                controller: _horizontal,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            cell('#', indexWidth, heading: true),
                            for (var i = 0; i < columns; i++)
                              cell(
                                _header
                                    ? records.first.cells[i].text
                                    : '[${i + 1}]',
                                cellWidth,
                                heading: true,
                              ),
                          ],
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: _vertical,
                            child: ListView.builder(
                              controller: _vertical,
                              itemExtent: height,
                              itemCount: count,
                              itemBuilder: (context, index) => Row(
                                children: [
                                  cell('${index + 1}', indexWidth),
                                  for (final item
                                      in records[index + start].cells.take(
                                        columns,
                                      ))
                                    cell(
                                      item.text,
                                      cellWidth,
                                      onTap: () => widget.onReveal(item.range),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
