import 'dart:isolate';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/workbench_style.dart';
import '../design/reading_style.dart';
import '../editor/code_editor.dart';
import '../editor/tree_panel.dart';
import '../editor/tree_style.dart';
import '../editor/json_highlight.dart';
import '../l10n/app_localizations.dart';
import '../l10n/workspace_messages.dart';
import 'workspace.dart';

Future<JsonComparison> _compare(JsonDocument before, JsonDocument after) =>
    Isolate.run(
      () => compareJsonStructure(
        before.source.text,
        before.snapshot!.root!,
        after.source.text,
        after.snapshot!.root!,
      ),
    );

final jsonComparisonProvider =
    Provider<Future<JsonComparison> Function(JsonDocument, JsonDocument)>(
      (ref) => _compare,
    );

bool _sameDocuments(
  Workspace workspace,
  WorkspaceTab before,
  WorkspaceTab after,
) {
  bool same(WorkspaceTab expected) {
    final current = workspace.tab(expected.id);
    return current != null &&
        current.document.isValid &&
        !current.large &&
        current.document.revision == expected.document.revision &&
        current.text == expected.text;
  }

  return same(before) && same(after);
}

Future<String> _prepareChanges(
  WorkspaceTab before,
  WorkspaceTab after,
  List<JsonDifference> changes,
) => Isolate.run(
  () => applyJsonDifferences(
    before.text,
    before.document.snapshot!.root!,
    after.text,
    after.document.snapshot!.root!,
    changes,
  ),
);

class CompareDocuments extends ConsumerStatefulWidget {
  const CompareDocuments({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.highlight,
    this.treeStyle = JsonTreeStyle.classic,
  });

  final List<WorkspaceTab> tabs;
  final int activeId;
  final JsonHighlight highlight;
  final JsonTreeStyle treeStyle;

  @override
  ConsumerState<CompareDocuments> createState() => _CompareDocumentsState();
}

class _CompareDocumentsState extends ConsumerState<CompareDocuments> {
  late WorkspaceTab _before = widget.tabs.firstWhere(
    (tab) => tab.id == widget.activeId,
    orElse: () => widget.tabs.first,
  );
  late WorkspaceTab _after = widget.tabs.firstWhere(
    (tab) => tab.id != _before.id,
  );
  late Future<JsonComparison> _result = ref.read(jsonComparisonProvider)(
    _before.document,
    _after.document,
  );
  JsonDifference? _selection;
  int _sequence = 0;
  final _checked = <int>{};
  bool _tree = false;
  bool _merging = false;
  String? _mergeError;
  int _generation = 0;

  bool get _stale =>
      !_sameDocuments(ref.read(workspaceProvider), _before, _after);

  void _refresh() {
    final tabs = ref
        .read(workspaceProvider)
        .tabs
        .where((t) => !t.large && t.document.isValid)
        .toList();
    if (tabs.length < 2) return;
    final before =
        tabs.where((t) => t.id == _before.id).firstOrNull ?? tabs.first;
    final after =
        tabs.where((t) => t.id == _after.id && t.id != before.id).firstOrNull ??
        tabs.firstWhere((t) => t.id != before.id);
    _comparePair(before, after);
  }

  Future<void> _previewChanges(List<JsonDifference> changes) async {
    if (_stale || _merging || changes.isEmpty) return;
    final generation = ++_generation;
    final before = _before;
    final after = _after;
    setState(() {
      _merging = true;
      _mergeError = null;
    });
    try {
      final source = await _prepareChanges(before, after, changes);
      if (!mounted || generation != _generation || _stale) return;
      final applied = await showDialog<bool>(
        context: context,
        builder: (_) => _ApplyPreview(
          before: before,
          after: after,
          source: source,
          highlight: widget.highlight,
        ),
      );
      if (mounted && applied == true) Navigator.pop(context);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _mergeError = AppLocalizations.of(context).comparisonApplyFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  void _choose(WorkspaceTab tab, {required bool before}) {
    if (tab.id == (before ? _before.id : _after.id)) return;
    if (tab.id == (before ? _after.id : _before.id)) {
      _comparePair(_after, _before);
    } else if (before) {
      _comparePair(tab, _after);
    } else {
      _comparePair(_before, tab);
    }
  }

  void _comparePair(WorkspaceTab before, WorkspaceTab after) {
    setState(() {
      _before = before;
      _after = after;
      _selection = null;
      _checked.clear();
      _mergeError = null;
      _generation++;
      _result = ref.read(jsonComparisonProvider)(
        _before.document,
        _after.document,
      );
    });
  }

  Widget _picker(String label, WorkspaceTab selected, {required bool before}) {
    final strings = AppLocalizations.of(context);
    final tabs = ref
        .read(workspaceProvider)
        .tabs
        .where((t) => !t.large && t.document.isValid)
        .toList();
    final names = tabs.map(strings.tabName).toList();
    String tabLabel(WorkspaceTab tab) {
      final name = strings.tabName(tab);
      return names.where((other) => other == name).length > 1
          ? tab.file?.path ?? name
          : name;
    }

    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: PopupMenuButton<WorkspaceTab>(
        tooltip: '$label · ${tabLabel(selected)}',
        initialValue: selected,
        enabled: !_stale && !_merging,
        onSelected: (tab) => _choose(tab, before: before),
        itemBuilder: (_) => [
          for (final tab in tabs)
            WorkbenchMenuItem(
              value: tab,
              icon: CupertinoIcons.doc,
              label: tabLabel(tab),
              checked: tab.id == selected.id,
            ),
        ],
        child: Row(
          children: [
            Expanded(
              child: Text(
                tabLabel(selected),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(CupertinoIcons.chevron_down, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _preview(WorkspaceTab tab, SourceRange? range, bool before) {
    final theme = Theme.of(context);
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
        child: ColoredBox(
          color: theme.colorScheme.surface,
          child: _selection != null && range == null
              ? Center(
                  child: Text(AppLocalizations.of(context).comparisonMissing),
                )
              : _tree
              ? TreePanel(
                  key: ValueKey(('comparison-tree', before, tab.id)),
                  snapshot: tab.document.snapshot!,
                  source: tab.text,
                  current: true,
                  readOnly: true,
                  style: widget.treeStyle,
                  onReveal: (_) {},
                  onEdit: (_, _) {},
                  reveal: range == null
                      ? null
                      : (range: range, sequence: _sequence),
                )
              : EJsonCodeEditor(
                  key: ValueKey((before, tab.id)),
                  source: tab.text,
                  highlight: widget.highlight,
                  onChanged: (_) {},
                  readOnly: true,
                  useWorkspaceShortcuts: false,
                  focusOnJump: false,
                  jump: range == null
                      ? null
                      : (range: range, sequence: _sequence),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    final stale = !_sameDocuments(workspace, _before, _after);
    ref.listen(workspaceProvider, (previous, next) {
      if (!_sameDocuments(next, _before, _after)) {
        setState(() {
          _checked.clear();
          _selection = null;
          _generation++;
        });
      }
    });
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    return WorkbenchDialog(
      title: strings.compareDocuments,
      scrollable: false,
      content: SizedBox(
        width: (size.width - 124).clamp(360.0, 980.0),
        height: (size.height - 190).clamp(245.0, 580.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _picker(
                    strings.comparisonBefore,
                    _before,
                    before: true,
                  ),
                ),
                const SizedBox(width: WorkbenchStyle.space4),
                IconButton(
                  tooltip: strings.comparisonSwap,
                  onPressed: stale || _merging
                      ? null
                      : () => _comparePair(_after, _before),
                  icon: const Icon(
                    CupertinoIcons.arrow_right_arrow_left,
                    size: WorkbenchStyle.controlIconSize,
                  ),
                ),
                const SizedBox(width: WorkbenchStyle.space4),
                Expanded(
                  child: _picker(
                    strings.comparisonAfter,
                    _after,
                    before: false,
                  ),
                ),
              ],
            ),
            if (stale)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.comparisonStale,
                      style: WorkbenchStyle.caption.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        workspace.tabs
                                .where((t) => !t.large && t.document.isValid)
                                .length <
                            2
                        ? null
                        : _refresh,
                    child: Text(strings.comparisonRefresh),
                  ),
                ],
              ),
            const SizedBox(height: WorkbenchStyle.space8),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _preview(_before, _selection?.left, true),
                  const SizedBox(width: WorkbenchStyle.space8),
                  _preview(_after, _selection?.right, false),
                ],
              ),
            ),
            const SizedBox(height: WorkbenchStyle.space8),
            Expanded(
              flex: 2,
              child: FutureBuilder<JsonComparison>(
                future: _result,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final result = snapshot.data;
                  if (result == null) {
                    return Center(child: Text(strings.comparisonFailed));
                  }
                  if (result.differences.isEmpty) {
                    return Center(child: Text(strings.comparisonEmpty));
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Tooltip(
                            message: strings.comparisonSelectAll,
                            child: Checkbox(
                              value: _checked.isEmpty
                                  ? false
                                  : _checked.length == result.differences.length
                                  ? true
                                  : null,
                              tristate: true,
                              visualDensity: VisualDensity.compact,
                              onChanged: stale || _merging
                                  ? null
                                  : (_) => setState(() {
                                      if (_checked.length ==
                                          result.differences.length) {
                                        _checked.clear();
                                      } else {
                                        _checked.addAll(
                                          List.generate(
                                            result.differences.length,
                                            (i) => i,
                                          ),
                                        );
                                      }
                                    }),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              strings.comparisonSelected(_checked.length),
                              style: WorkbenchStyle.caption,
                            ),
                          ),
                          IconButton(
                            tooltip: strings.source,
                            isSelected: !_tree,
                            onPressed: () => setState(() => _tree = false),
                            icon: const Icon(
                              CupertinoIcons.chevron_left_slash_chevron_right,
                              size: WorkbenchStyle.controlIconSize,
                            ),
                          ),
                          IconButton(
                            tooltip: strings.jsonTree,
                            isSelected: _tree,
                            onPressed: () => setState(() => _tree = true),
                            icon: const Icon(
                              CupertinoIcons.list_bullet_indent,
                              size: WorkbenchStyle.controlIconSize,
                            ),
                          ),
                          TextButton(
                            onPressed: stale || _merging || _checked.isEmpty
                                ? null
                                : () => _previewChanges([
                                    for (
                                      var i = 0;
                                      i < result.differences.length;
                                      i++
                                    )
                                      if (_checked.contains(i))
                                        result.differences[i],
                                  ]),
                            child: Text(
                              _merging
                                  ? strings.schemaChecking
                                  : strings.comparisonPreviewChanges,
                            ),
                          ),
                        ],
                      ),
                      if (_mergeError != null)
                        Text(
                          _mergeError!,
                          style: WorkbenchStyle.caption.copyWith(
                            color: colors.error,
                          ),
                        ),
                      if (result.truncated)
                        Text(
                          strings.comparisonLimit,
                          style: WorkbenchStyle.caption,
                        ),

                      Expanded(
                        child: ListView.builder(
                          itemCount: result.differences.length,
                          itemBuilder: (context, index) {
                            final difference = result.differences[index];
                            final label = switch (difference.kind) {
                              JsonDifferenceKind.added =>
                                strings.comparisonAdded,
                              JsonDifferenceKind.removed =>
                                strings.comparisonRemoved,
                              JsonDifferenceKind.changed =>
                                strings.comparisonChanged,
                            };
                            return Material(
                              color: difference == _selection
                                  ? colors.secondaryContainer
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _selection = difference;
                                  _sequence++;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: WorkbenchStyle.space8,
                                    vertical: WorkbenchStyle.space4,
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        key: ValueKey(
                                          'comparison-select-$index',
                                        ),
                                        semanticLabel:
                                            '$label ${difference.path}',
                                        value: _checked.contains(index),
                                        visualDensity: VisualDensity.compact,
                                        onChanged: stale || _merging
                                            ? null
                                            : (checked) => setState(() {
                                                if (checked == true) {
                                                  _checked.add(index);
                                                } else {
                                                  _checked.remove(index);
                                                }
                                                _selection = difference;
                                                _sequence++;
                                              }),
                                      ),
                                      SizedBox(width: 76, child: Text(label)),
                                      Expanded(
                                        child: Text(
                                          difference
                                                  .duplicateOccurrences
                                                  .isEmpty
                                              ? difference.path
                                              : '${difference.path} (#${difference.duplicateOccurrences.join(' / ')})',
                                          style: ReadingStyle.of(context).text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        Text(strings.comparisonApplyDirection, style: WorkbenchStyle.caption),
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

class _ApplyPreview extends ConsumerWidget {
  const _ApplyPreview({
    required this.before,
    required this.after,
    required this.source,
    required this.highlight,
  });
  final WorkspaceTab before;
  final WorkspaceTab after;
  final String source;
  final JsonHighlight highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final targetName = before.file?.path ?? strings.tabName(before);
    final stale = !_sameDocuments(ref.watch(workspaceProvider), before, after);
    return WorkbenchDialog(
      title: strings.comparisonApplyPreview,
      scrollable: false,
      content: SizedBox(
        width: 680,
        height: (MediaQuery.sizeOf(context).height - 220).clamp(180.0, 500.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Tooltip(
              message: targetName,
              child: Text(
                strings.comparisonApplyTarget(targetName),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: WorkbenchStyle.body,
              ),
            ),
            if (stale)
              Text(
                strings.comparisonStale,
                style: WorkbenchStyle.caption.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            const SizedBox(height: WorkbenchStyle.space8),
            Expanded(
              child: EJsonCodeEditor(
                key: const ValueKey('comparison-apply-preview'),
                source: source,
                highlight: highlight,
                onChanged: (_) {},
                readOnly: true,
                useWorkspaceShortcuts: false,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: () => Navigator.pop(context, false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          onPressed: stale
              ? null
              : () {
                  if (!_sameDocuments(
                    ref.read(workspaceProvider),
                    before,
                    after,
                  )) {
                    return;
                  }
                  final controller = ref.read(workspaceProvider.notifier);
                  controller.editSource(before.id, source);
                  controller.activate(before.id);
                  Navigator.pop(context, true);
                },
          child: Text(strings.comparisonApplyChanges),
        ),
      ],
    );
  }
}
