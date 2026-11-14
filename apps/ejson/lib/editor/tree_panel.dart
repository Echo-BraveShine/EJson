import 'dart:math' as math;

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import 'tree_style.dart';

class TreePanel extends StatefulWidget {
  const TreePanel({
    super.key,
    required this.snapshot,
    required this.source,
    required this.current,
    required this.onReveal,
    required this.onEdit,
    this.style = JsonTreeStyle.classic,
    this.reveal,
    this.onAdd,
    this.onDelete,
    this.onCopyPath,
  });

  final ParseSnapshot snapshot;
  final JsonTreeStyle style;
  final String source;
  final bool current;
  final ValueChanged<SourceRange> onReveal;
  final void Function(SourceRange range, bool key) onEdit;
  final ({SourceRange range, int sequence})? reveal;
  final ValueChanged<JsonNode>? onAdd;
  final void Function(JsonNode parent, int index)? onDelete;
  final ValueChanged<String>? onCopyPath;

  @override
  State<TreePanel> createState() => _TreePanelState();
}

enum _NodeAction { focus, replace, rename, add, delete, copyPath }

typedef _Step = ({int index, String? key});

typedef _Row = ({
  JsonNode node,
  String label,
  String path,
  List<_Step> steps,
  int depth,
  SourceRange? keyRange,
});

class _TreePanelState extends State<TreePanel> {
  static const _rowLimit = 10000;
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  bool _pendingReveal = false;
  List<_Step> _revealSteps = const [];
  List<_Step> _focus = const [];
  String? _selected;
  final _expanded = <String>{'root'};

  void _focusOn(List<_Step> steps) {
    if (_horizontal.hasClients) _horizontal.jumpTo(0);
    if (_vertical.hasClients) _vertical.jumpTo(0);
    setState(() {
      _focus = steps;
      _selected = null;
      _expanded.add(_path(steps));
    });
  }

  String _path(List<_Step> steps) =>
      ['root', for (final step in steps) step.index].join('/');

  @override
  void didUpdateWidget(covariant TreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current &&
        widget.reveal != null &&
        widget.reveal != oldWidget.reveal) {
      _showMatch(widget.reveal!.range.start);
      return;
    }
    if (widget.snapshot == oldWidget.snapshot) return;
    var node = widget.snapshot.root!;
    var validSteps = 0;
    for (final step in _focus) {
      if (step.index >= node.children.length) break;
      final child = node.children[step.index];
      if (child.key != step.key || child.value.children.isEmpty) break;
      node = child.value;
      validSteps++;
    }
    if (validSteps < _focus.length) {
      _focus = _focus.take(validSteps).toList();
      _selected = null;
    }
  }

  void _showMatch(int offset) {
    var node = widget.snapshot.root!;
    var path = 'root';
    final steps = <_Step>[];
    _focus = const [];
    _expanded.add(path);
    while (true) {
      final index = node.children.indexWhere((child) {
        final start = child.keyRange?.start ?? child.value.range.start;
        return start <= offset && offset < child.value.range.end;
      });
      if (index < 0) break;
      _expanded.add(path);
      path = '$path/$index';
      final child = node.children[index];
      steps.add((index: index, key: child.key));
      node = child.value;
    }
    _selected = path;
    _revealSteps = steps;
    _pendingReveal = true;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final style = widget.style;
    final rows = <_Row>[];
    var clipped = false;
    var deepestRow = 0;
    void visit(
      JsonNode node,
      String label,
      String path,
      List<_Step> steps,
      int depth, [
      SourceRange? keyRange,
    ]) {
      if (rows.length == _rowLimit) {
        clipped = true;
        return;
      }
      deepestRow = math.max(deepestRow, depth);
      rows.add((
        node: node,
        label: label,
        path: path,
        steps: steps,
        depth: depth,
        keyRange: keyRange,
      ));
      if (!_expanded.contains(path)) return;
      for (var index = 0; index < node.children.length && !clipped; index++) {
        final child = node.children[index];
        visit(
          child.value,
          child.key ?? '[$index]',
          '$path/$index',
          [...steps, (index: index, key: child.key)],
          depth + 1,
          child.keyRange,
        );
      }
    }

    var root = widget.snapshot.root!;
    SourceRange? rootKey;
    final trail = [strings.rootNode];
    for (final step in _focus) {
      final child = root.children[step.index];
      root = child.value;
      rootKey = child.keyRange;
      trail.add(child.key ?? '[${step.index}]');
    }
    final rootPath = _path(_focus);
    visit(root, trail.last, rootPath, _focus, 0, rootKey);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final code = WorkbenchStyle.code(theme.platform);
    if (widget.reveal != null && widget.current && _selected != null) {
      final index = rows.indexWhere((row) => row.path == _selected);
      if (index < 0 && _pendingReveal && clipped && _revealSteps.isNotEmpty) {
        _pendingReveal = false;
        final sequence = widget.reveal!.sequence;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.reveal?.sequence != sequence) return;
          setState(() {
            _focus = _revealSteps;
            _expanded.remove(_selected);
            _pendingReveal = true;
          });
        });
      }
      if (index >= 0 && _pendingReveal) {
        _pendingReveal = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_vertical.hasClients || !_horizontal.hasClients) {
            return;
          }
          _vertical.jumpTo(
            (index * style.rowHeight - style.rowHeight).clamp(
              0.0,
              _vertical.position.maxScrollExtent,
            ),
          );
          final indent = rows[index].depth * style.indent;
          _horizontal.jumpTo(
            indent.clamp(0.0, _horizontal.position.maxScrollExtent),
          );
        });
      }
    }
    final list = ListView.builder(
      controller: _vertical,
      primary: false,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemExtent: style.rowHeight,
      itemCount: rows.length + (clipped ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          return Center(child: Text(strings.treeLimit));
        }
        final row = rows[index];
        final node = row.node;
        final range = node.range;
        final hasChildren = node.children.isNotEmpty;
        final expanded = _expanded.contains(row.path);
        final preview = switch (node.kind) {
          JsonKind.object => '{${node.children.length}}',
          JsonKind.array => '[${node.children.length}]',
          _ => widget.source.substring(
            range.start,
            (range.start + 120).clamp(0, range.end),
          ),
        };
        final selected = widget.current && _selected == row.path;
        return Material(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
            side: style == JsonTreeStyle.outline && (hasChildren || selected)
                ? BorderSide(color: colors.outlineVariant)
                : BorderSide.none,
          ),
          color: selected
              ? colors.secondaryContainer
              : style == JsonTreeStyle.striped && index.isOdd
              ? colors.surfaceContainer
              : Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
            onTap: widget.current
                ? () {
                    setState(() => _selected = row.path);
                    widget.onReveal(range);
                  }
                : null,
            onDoubleTap: widget.current
                ? () => widget.onEdit(range, false)
                : null,
            child: Padding(
              padding: EdgeInsets.only(
                left: 2.0 + style.indent * row.depth,
                right: 8,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: hasChildren
                        ? IconButton(
                            key: ValueKey('expand:${row.path}'),
                            padding: EdgeInsets.zero,
                            iconSize: 12,
                            tooltip: expanded
                                ? strings.collapse
                                : strings.expand,
                            onPressed: () => setState(() {
                              if (!_expanded.remove(row.path)) {
                                _expanded.add(row.path);
                              }
                            }),
                            icon: Icon(
                              expanded
                                  ? CupertinoIcons.chevron_down
                                  : CupertinoIcons.chevron_right,
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            row.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WorkbenchStyle.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: code.copyWith(
                              color: style.valueColor(node.kind, colors),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.current || hasChildren && row.depth > 0)
                    PopupMenuButton<_NodeAction>(
                      key: ValueKey('node-menu:${row.path}'),
                      tooltip: widget.current
                          ? strings.editNode
                          : strings.nodeActions,
                      child: const SizedBox(
                        width: 28,
                        height: 24,
                        child: Icon(CupertinoIcons.ellipsis, size: 15),
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case _NodeAction.focus:
                            _focusOn(row.steps);
                          case _NodeAction.replace:
                            widget.onEdit(range, false);
                          case _NodeAction.rename:
                            widget.onEdit(row.keyRange!, true);
                          case _NodeAction.add:
                            widget.onAdd?.call(node);
                          case _NodeAction.delete:
                            var parent = widget.snapshot.root!;
                            for (final step in row.steps.take(
                              row.steps.length - 1,
                            )) {
                              parent = parent.children[step.index].value;
                            }
                            widget.onDelete?.call(parent, row.steps.last.index);
                          case _NodeAction.copyPath:
                            widget.onCopyPath?.call(
                              formatJsonPath(
                                row.steps.map(
                                  (step) => (
                                    key: step.key,
                                    index: step.key == null ? step.index : null,
                                  ),
                                ),
                              ),
                            );
                        }
                      },
                      itemBuilder: (context) => [
                        if (hasChildren && row.depth > 0)
                          WorkbenchMenuItem(
                            value: _NodeAction.focus,
                            icon: Icons.center_focus_strong_outlined,
                            label: strings.focusSubtree,
                          ),
                        if (widget.current) ...[
                          if (widget.onCopyPath != null)
                            WorkbenchMenuItem(
                              value: _NodeAction.copyPath,
                              icon: CupertinoIcons.doc_on_doc,
                              label: strings.copyJsonPath,
                            ),
                          if (widget.onAdd != null &&
                              (node.kind == JsonKind.array ||
                                  node.kind == JsonKind.object))
                            WorkbenchMenuItem(
                              value: _NodeAction.add,
                              icon: CupertinoIcons.plus,
                              label: node.kind == JsonKind.object
                                  ? strings.addProperty
                                  : strings.addArrayItem,
                            ),
                          if (widget.onDelete != null && row.steps.isNotEmpty)
                            WorkbenchMenuItem(
                              value: _NodeAction.delete,
                              icon: CupertinoIcons.trash,
                              label: strings.deleteNode,
                            ),
                          WorkbenchMenuItem(
                            value: _NodeAction.replace,
                            icon: CupertinoIcons.arrow_left_right,
                            label: strings.replaceValue,
                          ),
                          if (row.keyRange != null)
                            WorkbenchMenuItem(
                              value: _NodeAction.rename,
                              icon: CupertinoIcons.pencil,
                              label: strings.renameKey,
                            ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    final scrollableTree = LayoutBuilder(
      builder: (context, constraints) {
        // Preserve room for the key, value and menu as indentation grows.
        final width = math.max(
          constraints.maxWidth,
          224.0 + style.indent * deepestRow,
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
              child: list,
            ),
          ),
        );
      },
    );
    if (_focus.isEmpty) return scrollableTree;

    final label = trail.length <= 3
        ? trail.join(' › ')
        : '${strings.rootNode} › … › ${trail[trail.length - 2]} › ${trail.last}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: strings.goToParent,
                icon: const Icon(CupertinoIcons.arrow_left, size: 17),
                onPressed: () =>
                    _focusOn(_focus.take(_focus.length - 1).toList()),
              ),
              Expanded(
                child: Tooltip(
                  message: trail.join(' › '),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: strings.backToRoot,
                icon: const Icon(CupertinoIcons.house, size: 17),
                onPressed: () => _focusOn(const []),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: scrollableTree),
      ],
    );
  }
}
