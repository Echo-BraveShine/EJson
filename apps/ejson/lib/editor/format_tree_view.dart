import 'dart:math' as math;
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import '../design/reading_style.dart';
import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import 'tree_style.dart';
import 'hierarchy_guide_painter.dart';

class FormatTreeView extends StatefulWidget {
  const FormatTreeView({
    super.key,
    required this.root,
    required this.style,
    required this.onReveal,
    this.truncated = false,
    this.showConnectors = true,
  });
  final FormatTreeNode root;
  final JsonTreeStyle style;
  final bool truncated;
  final bool showConnectors;
  final ValueChanged<SourceRange> onReveal;
  @override
  State<FormatTreeView> createState() => _FormatTreeViewState();
}

typedef _FormatRow = ({
  FormatTreeNode node,
  String path,
  int depth,
  List<bool> continuation,
});

class _FormatTreeViewState extends State<FormatTreeView> {
  final _expanded = <String>{'root'};
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  String? _selected;
  ({List<_FormatRow> rows, int deepest})? _visibleRows;
  @override
  void didUpdateWidget(covariant FormatTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.root != widget.root) {
      _selected = null;
      _visibleRows = null;
    }
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  ({List<_FormatRow> rows, int deepest}) _buildRows() {
    final rows = <_FormatRow>[];
    var deepest = 0;
    void visit(
      FormatTreeNode node,
      String path,
      int depth,
      List<bool> continuation,
    ) {
      deepest = math.max(deepest, depth);
      rows.add((
        node: node,
        path: path,
        depth: depth,
        continuation: continuation,
      ));
      if (!_expanded.contains(path)) return;
      for (var i = 0; i < node.children.length; i++) {
        visit(node.children[i], '$path/$i', depth + 1, [
          ...continuation,
          i < node.children.length - 1,
        ]);
      }
    }

    visit(widget.root, 'root', 0, []);
    return (rows: rows, deepest: deepest);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final reading = ReadingStyle.of(context);
    final indent = math.max(widget.style.indent, reading.scaledFontSize * .7);
    final (:rows, :deepest) = _visibleRows ??= _buildRows();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth,
          248 * reading.widthScale + deepest * indent,
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
              child: Scrollbar(
                controller: _vertical,
                child: ListView.builder(
                  controller: _vertical,
                  padding: const EdgeInsets.all(WorkbenchStyle.space8),
                  itemExtent: reading.rowHeight(
                    minimum: widget.style.rowHeight,
                  ),
                  itemCount: rows.length + (widget.truncated ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == rows.length) {
                      return Text(
                        strings.treeLimit,
                        style: WorkbenchStyle.caption,
                      );
                    }
                    final row = rows[index];
                    final kind = switch (row.node.kind) {
                      'object' || 'element' => JsonKind.object,
                      'array' => JsonKind.array,
                      'number' => JsonKind.number,
                      'boolean' => JsonKind.boolean,
                      'null' => JsonKind.nil,
                      _ => JsonKind.string,
                    };
                    return Material(
                      color: _selected == row.path
                          ? colors.secondaryContainer
                          : widget.style == JsonTreeStyle.striped && index.isOdd
                          ? colors.surfaceContainer
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          WorkbenchStyle.controlRadius,
                        ),
                        side:
                            widget.style == JsonTreeStyle.outline &&
                                row.node.children.isNotEmpty
                            ? BorderSide(color: colors.outlineVariant)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        key: ValueKey('format-row:${row.path}'),
                        onTap: () {
                          setState(() => _selected = row.path);
                          if (row.node.range case final range?) {
                            widget.onReveal(range);
                          }
                        },
                        child: CustomPaint(
                          painter: widget.showConnectors
                              ? HierarchyGuidePainter(
                                  row.continuation,
                                  indent,
                                  colors.outline.withValues(alpha: .55),
                                  expanded:
                                      row.node.children.isNotEmpty &&
                                      _expanded.contains(row.path),
                                )
                              : null,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 2 + row.depth * indent,
                              right: 8,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: row.node.children.isEmpty
                                      ? null
                                      : IconButton(
                                          key: ValueKey(
                                            'format-expand:${row.path}',
                                          ),
                                          tooltip: _expanded.contains(row.path)
                                              ? strings.collapse
                                              : strings.expand,
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            _expanded.contains(row.path)
                                                ? CupertinoIcons.chevron_down
                                                : CupertinoIcons.chevron_right,
                                            size: 12,
                                          ),
                                          onPressed: () => setState(() {
                                            if (!_expanded.remove(row.path)) {
                                              _expanded.add(row.path);
                                            }
                                            _visibleRows = null;
                                          }),
                                        ),
                                ),
                                if (widget.style.typeIcons) ...[
                                  Icon(
                                    switch (kind) {
                                      JsonKind.object =>
                                        CupertinoIcons.cube_box,
                                      JsonKind.array =>
                                        CupertinoIcons.list_bullet,
                                      JsonKind.number => CupertinoIcons.number,
                                      JsonKind.boolean =>
                                        CupertinoIcons.checkmark_square,
                                      JsonKind.nil => CupertinoIcons.nosign,
                                      _ => CupertinoIcons.textformat,
                                    },
                                    size: 16,
                                    color: widget.style.valueColor(
                                      kind,
                                      colors,
                                    ),
                                  ),
                                  const SizedBox(width: WorkbenchStyle.space8),
                                ],
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          row.node.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: reading.text.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: WorkbenchStyle.space12,
                                      ),
                                      Flexible(
                                        child: Text(
                                          row.node.value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: reading.text.copyWith(
                                            color: widget.style.valueColor(
                                              kind,
                                              colors,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
