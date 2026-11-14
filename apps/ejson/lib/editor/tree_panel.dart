import 'dart:math' as math;

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../design/workbench_style.dart';
import '../design/reading_style.dart';
import '../l10n/app_localizations.dart';
import 'tree_style.dart';

part 'tree_node_menu.dart';

part 'tree_rows.dart';

class TreePanel extends StatefulWidget {
  const TreePanel({
    super.key,
    required this.snapshot,
    required this.source,
    required this.current,
    required this.onReveal,
    required this.onEdit,
    this.style = JsonTreeStyle.classic,
    this.readOnly = false,
    this.reveal,
    this.onAdd,
    this.onDelete,
    this.onCopyPath,
    this.onExtract,
    this.onCopyValue,
    this.onTable,
    this.onMoveArrayItem,
    this.onDuplicateArrayItem,
    this.onSortArray,
  });

  final ParseSnapshot snapshot;
  final JsonTreeStyle style;
  final bool readOnly;
  final String source;
  final bool current;
  final ValueChanged<SourceRange> onReveal;
  final void Function(SourceRange range, bool key) onEdit;
  final ({SourceRange range, int sequence})? reveal;
  final ValueChanged<JsonNode>? onAdd;
  final void Function(JsonNode parent, int index)? onDelete;
  final ValueChanged<String>? onCopyPath;
  final ValueChanged<SourceRange>? onExtract;
  final void Function(SourceRange range, bool decoded)? onCopyValue;
  final ValueChanged<JsonNode>? onTable;
  final void Function(JsonNode array, int index, int delta)? onMoveArrayItem;
  final void Function(JsonNode array, int index)? onDuplicateArrayItem;
  final ValueChanged<JsonNode>? onSortArray;

  @override
  State<TreePanel> createState() => _TreePanelState();
}

typedef _Step = ({int index, String? key});

typedef _Row = ({
  JsonNode node,
  String label,
  String path,
  List<_Step> steps,
  int depth,
  SourceRange? keyRange,
  List<bool> continuation,
});

class _TreePanelState extends State<TreePanel> {
  void _updateView(VoidCallback update) => setState(update);

  static const _rowLimit = 10000;
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  final _breadcrumbs = ScrollController();
  String? _breadcrumbPath;

  @override
  void initState() {
    super.initState();
    if (widget.current && widget.reveal != null) {
      _showMatch(widget.reveal!.range.start);
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    _breadcrumbs.dispose();
    super.dispose();
  }

  bool _pendingReveal = false;
  List<_Step> _revealSteps = const [];
  List<_Step> _focus = const [];
  String? _selected;
  final _expanded = <String>{'root'};

  JsonNode? _parent(List<_Step> steps) {
    if (steps.isEmpty) return null;
    var parent = widget.snapshot.root!;
    for (final step in steps.take(steps.length - 1)) {
      parent = parent.children[step.index].value;
    }
    return parent;
  }

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
      List<bool> continuation = const [],
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
        continuation: continuation,
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
          [...continuation, index < node.children.length - 1],
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
    final reading = ReadingStyle.of(context);
    final code = reading.text;
    final rowHeight = reading.rowHeight(minimum: style.rowHeight);
    final indent = math.max(style.indent, reading.scaledFontSize * .7);
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
            (index * rowHeight - rowHeight).clamp(
              0.0,
              _vertical.position.maxScrollExtent,
            ),
          );
          final horizontalOffset = rows[index].depth * indent;
          _horizontal.jumpTo(
            horizontalOffset.clamp(0.0, _horizontal.position.maxScrollExtent),
          );
        });
      }
    }
    final list = ListView.builder(
      controller: _vertical,
      primary: false,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemExtent: rowHeight,
      itemCount: rows.length + (clipped ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          return Center(child: Text(strings.treeLimit));
        }
        return _treeRow(rows[index], index, style, code, indent, colors);
      },
    );
    final scrollableTree = LayoutBuilder(
      builder: (context, constraints) {
        // Preserve room for the key, value and menu as indentation grows.
        final width = math.max(
          constraints.maxWidth,
          (224.0 + (style.typeIcons ? 24 : 0)) * reading.widthScale +
              indent * deepestRow,
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
    final selectedSteps =
        rows.where((row) => row.path == _selected).firstOrNull?.steps ?? _focus;
    var breadcrumbNode = widget.snapshot.root!;
    final crumbs = <({String label, SourceRange range, List<_Step> steps})>[
      (label: r'$', range: breadcrumbNode.range, steps: const []),
    ];
    for (var index = 0; index < selectedSteps.length; index++) {
      final step = selectedSteps[index];
      breadcrumbNode = breadcrumbNode.children[step.index].value;
      crumbs.add((
        label: step.key ?? '[${step.index}]',
        range: breadcrumbNode.range,
        steps: selectedSteps.take(index + 1).toList(),
      ));
    }
    final fullPath = formatJsonPath(
      selectedSteps.map(
        (step) => (key: step.key, index: step.key == null ? step.index : null),
      ),
    );
    if (fullPath != _breadcrumbPath) {
      _breadcrumbPath = fullPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _breadcrumbPath == fullPath && _breadcrumbs.hasClients) {
          _breadcrumbs.jumpTo(_breadcrumbs.position.maxScrollExtent);
        }
      });
    }
    return Column(
      children: [
        SizedBox(
          height: WorkbenchStyle.rowHeight,
          child: Row(
            children: [
              if (_focus.isNotEmpty)
                IconButton(
                  tooltip: strings.goToParent,
                  icon: const Icon(
                    CupertinoIcons.arrow_left,
                    size: WorkbenchStyle.controlIconSize,
                  ),
                  onPressed: () =>
                      _focusOn(_focus.take(_focus.length - 1).toList()),
                ),
              Expanded(
                child: Tooltip(
                  message: fullPath,
                  child: SingleChildScrollView(
                    controller: _breadcrumbs,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var index = 0; index < crumbs.length; index++) ...[
                          if (index > 0)
                            const Icon(CupertinoIcons.chevron_right, size: 12),
                          TextButton(
                            key: ValueKey('breadcrumb-$index'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.symmetric(
                                horizontal: WorkbenchStyle.space8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: !widget.current
                                ? null
                                : () {
                                    _focusOn(crumbs[index].steps);
                                    widget.onReveal(crumbs[index].range);
                                  },
                            child: Text(
                              crumbs[index].label,
                              style: WorkbenchStyle.label,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_focus.isNotEmpty)
                IconButton(
                  tooltip: strings.backToRoot,
                  icon: const Icon(
                    CupertinoIcons.house,
                    size: WorkbenchStyle.controlIconSize,
                  ),
                  onPressed: () => _focusOn(const []),
                ),
              if (widget.onCopyPath != null)
                IconButton(
                  tooltip: strings.copyJsonPath,
                  icon: const Icon(
                    CupertinoIcons.doc_on_clipboard,
                    size: WorkbenchStyle.controlIconSize,
                  ),
                  onPressed: widget.current
                      ? () => widget.onCopyPath!(fullPath)
                      : null,
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
