import 'dart:isolate';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/workbench_style.dart';
import '../editor/code_editor.dart';
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

class CompareDocuments extends ConsumerStatefulWidget {
  const CompareDocuments({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.highlight,
  });

  final List<WorkspaceTab> tabs;
  final int activeId;
  final JsonHighlight highlight;

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
      _result = ref.read(jsonComparisonProvider)(
        _before.document,
        _after.document,
      );
    });
  }

  Widget _picker(String label, WorkspaceTab selected, {required bool before}) {
    final strings = AppLocalizations.of(context);
    final names = widget.tabs.map(strings.tabName).toList();
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
        onSelected: (tab) => _choose(tab, before: before),
        itemBuilder: (_) => [
          for (final tab in widget.tabs)
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
              : EJsonCodeEditor(
                  key: ValueKey((before, tab.id)),
                  source: tab.text,
                  highlight: widget.highlight,
                  onChanged: (_) {},
                  readOnly: true,
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
                  onPressed: () => _comparePair(_after, _before),
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
                      if (result.truncated) Text(strings.comparisonLimit),
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
                                      SizedBox(width: 76, child: Text(label)),
                                      Expanded(
                                        child: Text(
                                          difference
                                                  .duplicateOccurrences
                                                  .isEmpty
                                              ? difference.path
                                              : '${difference.path} (#${difference.duplicateOccurrences.join(' / ')})',
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
