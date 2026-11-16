part of 'workbench.dart';

extension _WorkbenchPanes on _WorkbenchState {
  Widget _sourceEditor(WorkspaceTab tab) {
    final folding = ref.watch(
      toolPreferencesProvider.select((value) => value.sourceFolding),
    );
    if (!folding) _sourceFolds.clear();
    final jump =
        _jump?.tabId == tab.id && _jump?.revision == tab.document.revision
        ? (range: _jump!.range, sequence: _jump!.sequence)
        : null;
    if (tab.large) {
      _sourceFolds.remove(tab.id);
      return LargeSourceView(
        key: ValueKey(tab.id),
        source: tab.text,
        format: tab.format,
        jump: jump,
        focusOnJump: !_searchJump,
      );
    }
    return EJsonCodeEditor(
      key: ValueKey(tab.id),
      source: tab.text,
      format: tab.format,
      highlight: widget.highlight,
      onPatch: (patch, before, after) {
        _jump = null;
        controller.editSourcePatch(tab.id, patch, before, after);
      },
      jump: jump,
      sourceLineIndex: tab.document.snapshot?.lines,
      focusOnJump: !_searchJump,
      readOnly: false,
      preserveViewOnUpdate: true,
      folds: folding ? _sourceFolds.putIfAbsent(tab.id, SourceFolds.new) : null,
    );
  }

  Widget _panes(WorkspaceTab tab, bool valid) {
    if (tab.format != DocumentFormat.json) return _otherPanes(tab);
    final colors = Theme.of(context).colorScheme;
    final doc = tab.document;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          SizedBox(
            width:
                (constraints.maxWidth - 7).clamp(0, double.infinity) * _split,
            child: _Panel(
              title: strings.source,
              icon: CupertinoIcons.chevron_left_slash_chevron_right,
              child: _sourceEditor(tab),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (event) => _updateView(() {
                _split = (_split + event.delta.dx / constraints.maxWidth).clamp(
                  0.35,
                  0.72,
                );
              }),
              child: VerticalDivider(width: 7, color: colors.outlineVariant),
            ),
          ),
          Expanded(
            child: _Panel(
              title: strings.jsonTree,
              icon: CupertinoIcons.list_bullet_indent,
              detail: !valid && doc.lastValid != null && !tab.large
                  ? strings.previousRevision
                  : null,
              child: tab.large || doc.lastValid == null
                  ? _EmptyTree(large: tab.large)
                  : TreePanel(
                      key: ValueKey(tab.id),
                      snapshot: doc.lastValid!,
                      style: widget.treeStyle,
                      showConnectors: ref
                          .watch(toolPreferencesProvider)
                          .treeConnectors,
                      source: doc.lastValidSource!.text,
                      current: valid,
                      onReveal: _reveal,
                      reveal:
                          _searchJump &&
                              _jump?.tabId == tab.id &&
                              _jump?.revision == doc.revision
                          ? (range: _jump!.range, sequence: _jump!.sequence)
                          : null,
                      onAdd: (node) => _addChild(tab, node),
                      onDelete: (parent, index) =>
                          _applyTreePatch(tab, removeJsonChild(parent, index)),
                      onMoveArrayItem: (array, index, delta) => _applyTreePatch(
                        tab,
                        moveJsonArrayItem(
                          tab.text,
                          array,
                          index,
                          index + delta,
                        ),
                      ),
                      onDuplicateArrayItem: (array, index) => _applyTreePatch(
                        tab,
                        duplicateJsonArrayItem(tab.text, array, index),
                      ),
                      onSortArray: (array) => _sortArray(tab, array),
                      onCopyPath: _copyPath,
                      onTable: (array) => _openTable(tab, array),
                      onCopyValue: (range, decoded) {
                        if (!_isCurrent(tab)) {
                          _message(strings.staleNode);
                          return;
                        }
                        final raw = doc.source.slice(range);
                        _copyValue(decoded ? jsonDecode(raw) as String : raw);
                      },
                      onExtract: (range) {
                        if (workspace.tab(tab.id)?.document.revision !=
                                doc.revision ||
                            !doc.isValid) {
                          _message(strings.staleNode);
                          return;
                        }
                        controller.newTabWithSource(doc.source.slice(range));
                      },
                      onEdit: (range, key) => _editNode(tab, range, key),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBar(
    WorkspaceTab tab,
    String status,
    JsonDiagnostic? diagnostic,
    bool valid,
  ) {
    final colors = Theme.of(context).colorScheme;
    final autosave = ref.watch(workspaceAutosaveProvider);
    final diskSync = ref.watch(diskSyncProvider)[tab.id];
    return Container(
      height: 29,
      color: colors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: WorkbenchStyle.space12),
      child: Row(
        children: [
          Icon(
            diagnostic != null && tab.text.isNotEmpty
                ? CupertinoIcons.exclamationmark_circle
                : valid
                ? CupertinoIcons.checkmark_circle
                : Icons.code,
            color:
                diagnostic != null && !diagnostic.warning && tab.text.isNotEmpty
                ? colors.error
                : colors.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: diagnostic == null || tab.text.isEmpty
                  ? null
                  : () => _reveal(diagnostic.range),
              child: Text(
                status,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Flexible(
            child: DocumentStatistics(document: tab.document, bom: tab.bom),
          ),
          if (diskSync != null) ...[
            const SizedBox(width: WorkbenchStyle.space8),
            Tooltip(
              message: switch (diskSync.status) {
                DiskSyncStatus.waiting => strings.diskSyncWaiting,
                DiskSyncStatus.saving => strings.diskSyncSaving,
                DiskSyncStatus.saved => strings.diskSyncSaved,
                DiskSyncStatus.conflict => strings.diskSyncConflict,
                DiskSyncStatus.unavailable ||
                DiskSyncStatus.failed => strings.diskSyncFailed,
              },
              child: Icon(
                key: const ValueKey('disk-sync-status'),
                switch (diskSync.status) {
                  DiskSyncStatus.saved => Icons.check_circle_outline,
                  DiskSyncStatus.waiting => Icons.schedule,
                  DiskSyncStatus.saving => Icons.sync,
                  _ => Icons.error_outline,
                },
                size: 16,
                color:
                    diskSync.status == DiskSyncStatus.conflict ||
                        diskSync.status == DiskSyncStatus.unavailable ||
                        diskSync.status == DiskSyncStatus.failed
                    ? colors.error
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
          if (ref.watch(workspaceRecoveryProvider) != null) ...[
            const SizedBox(width: WorkbenchStyle.space8),
            IconButton(
              key: const ValueKey('autosave-status'),
              tooltip: switch (autosave) {
                AutosaveStatus.disabled => strings.autosaveDisabled,
                AutosaveStatus.waiting => strings.autosaveWaiting,
                AutosaveStatus.saving => strings.autosaveSaving,
                AutosaveStatus.saved => strings.autosaveSaved,
                AutosaveStatus.failed => strings.autosaveFailed,
              },
              onPressed: autosave == AutosaveStatus.failed
                  ? () => ref.read(workspaceAutosaveProvider.notifier).flush()
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 22, height: 22),
              iconSize: 15,
              disabledColor: colors.onSurfaceVariant,
              color: colors.error,
              icon: Icon(switch (autosave) {
                AutosaveStatus.failed => Icons.error_outline,
                AutosaveStatus.saving => Icons.sync,
                AutosaveStatus.waiting => Icons.schedule,
                AutosaveStatus.saved => Icons.save_outlined,
                AutosaveStatus.disabled => Icons.pause_circle_outline,
              }),
            ),
          ],
          const SizedBox(width: WorkbenchStyle.space12),
          Text(
            'UTF-8${tab.bom ? " BOM" : ""}  ·  ${tab.format.label}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    this.detail,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String? detail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 33,
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(
            horizontal: WorkbenchStyle.space12,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    detail!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

class _EmptyTree extends StatelessWidget {
  const _EmptyTree({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WorkbenchStyle.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(
                  WorkbenchStyle.dialogRadius,
                ),
              ),
              child: Icon(
                CupertinoIcons.list_bullet_indent,
                size: 22,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              large
                  ? AppLocalizations.of(context).treeLargeFile
                  : AppLocalizations.of(context).treeEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
