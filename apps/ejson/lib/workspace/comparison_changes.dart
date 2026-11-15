part of 'compare_documents.dart';

extension _ComparisonChanges on _CompareDocumentsState {
  Future<void> _previewChanges(List<JsonDifference> changes) async {
    if (_stale || _merging || changes.isEmpty) return;
    final generation = ++_generation;
    final before = _before;
    final after = _after;
    _updateView(() {
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
        _updateView(
          () =>
              _mergeError = AppLocalizations.of(context).comparisonApplyFailed,
        );
      }
    } finally {
      if (mounted) _updateView(() => _merging = false);
    }
  }

  Widget _differences(bool stale) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<JsonComparison>(
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
                  child: WorkbenchCheckbox(
                    value: _checked.isEmpty
                        ? false
                        : _checked.length == result.differences.length
                        ? true
                        : null,
                    tristate: true,
                    onChanged: stale || _merging
                        ? null
                        : (_) => _updateView(() {
                            if (_checked.length == result.differences.length) {
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
                  onPressed: () => _updateView(() => _tree = false),
                  icon: const Icon(
                    CupertinoIcons.chevron_left_slash_chevron_right,
                    size: WorkbenchStyle.controlIconSize,
                  ),
                ),
                IconButton(
                  tooltip: strings.jsonTree,
                  isSelected: _tree,
                  onPressed: () => _updateView(() => _tree = true),
                  icon: const Icon(
                    CupertinoIcons.list_bullet_indent,
                    size: WorkbenchStyle.controlIconSize,
                  ),
                ),
                TextButton(
                  onPressed: stale || _merging || _checked.isEmpty
                      ? null
                      : () => _previewChanges([
                          for (var i = 0; i < result.differences.length; i++)
                            if (_checked.contains(i)) result.differences[i],
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
                style: WorkbenchStyle.caption.copyWith(color: colors.error),
              ),
            if (result.truncated)
              Text(strings.comparisonLimit, style: WorkbenchStyle.caption),

            Expanded(
              child: ListView.builder(
                itemCount: result.differences.length,
                itemBuilder: (context, index) {
                  final difference = result.differences[index];
                  final label = switch (difference.kind) {
                    JsonDifferenceKind.added => strings.comparisonAdded,
                    JsonDifferenceKind.removed => strings.comparisonRemoved,
                    JsonDifferenceKind.changed => strings.comparisonChanged,
                  };
                  return Material(
                    color: difference == _selection
                        ? colors.secondaryContainer
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () => _updateView(() {
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
                            WorkbenchCheckbox(
                              controlKey: ValueKey('comparison-select-$index'),
                              semanticLabel: '$label ${difference.path}',
                              value: _checked.contains(index),
                              onChanged: stale || _merging
                                  ? null
                                  : (checked) => _updateView(() {
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
                                difference.duplicateOccurrences.isEmpty
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
