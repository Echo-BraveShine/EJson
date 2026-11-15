import 'dart:isolate';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/workbench_style.dart';
import '../design/reading_style.dart';
import '../settings/tool_preferences.dart';
import '../editor/code_editor.dart';
import '../editor/tree_panel.dart';
import '../editor/tree_style.dart';
import '../editor/json_highlight.dart';
import '../l10n/app_localizations.dart';
import '../l10n/workspace_messages.dart';
import 'workspace.dart';

part 'comparison_changes.dart';

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
  void _updateView(VoidCallback update) => setState(update);

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
                  showConnectors: ref
                      .watch(toolPreferencesProvider)
                      .treeConnectors,
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
            Expanded(flex: 2, child: _differences(stale)),
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
