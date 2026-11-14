part of 'workbench.dart';

extension _WorkbenchWindowActions on _WorkbenchState {
  Future<bool> _confirmExit() async {
    if (_confirmingExit || _closingTab || _fileBusy) return false;
    _confirmingExit = true;
    try {
      final unsaved = workspace.tabs.where((tab) => tab.dirty).toList();
      if (unsaved.isNotEmpty) {
        final action = await _confirmClose(
          strings.saveBeforeQuit,
          unsaved.map(strings.tabName).toList(),
          quitting: true,
        );
        if (!mounted || action == _CloseAction.cancel) return false;
        if (action == _CloseAction.save) {
          for (final tab in unsaved) {
            if (!await _save(tab.id, saveDraftOnExit: true)) return false;
          }
          if (!mounted || workspace.tabs.any((tab) => tab.dirty)) return false;
        }
      }

      await widget.waitForThemeSave();
      await ref.read(toolPreferencesProvider.notifier).flush();
      if (!mounted) return false;
      final session = widget.workspaceSession;
      if (session != null) {
        try {
          await _savingRestorePreference;
          if (!mounted) return false;
          await session.remember(workspace, enabled: _restoreOnStartup);
        } on Exception {
          if (mounted) _message(strings.workspaceSaveFailed);
          return false;
        }
      }
      return mounted;
    } finally {
      _confirmingExit = false;
    }
  }

  Future<void> _showRestoreFailures() => showDialog<void>(
    context: context,
    builder: (context) {
      final labels = AppLocalizations.of(context);
      return WorkbenchDialog(
        title: labels.restoreFailed,
        content: SizedBox(
          width: 440,
          child: Text(widget.failedRestorePaths.join('\n')),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(labels.done),
          ),
        ],
      );
    },
  );

  Future<bool> _setRestoreOnStartup(bool value) async {
    final session = widget.workspaceSession;
    if (session != null) {
      try {
        await session.setEnabled(value);
      } on Exception {
        if (mounted) _message(strings.workspacePreferenceFailed);
        return false;
      }
    }
    if (!mounted) return false;
    _updateView(() => _restoreOnStartup = value);
    return true;
  }

  Future<_CloseAction> _confirmClose(
    String title,
    List<String> documents, {
    bool quitting = false,
  }) async =>
      await showDialog<_CloseAction>(
        context: context,
        builder: (context) => WorkbenchDialog(
          title: title,
          content: SizedBox(
            width: 336,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context).unsavedChangesDescription),
                const SizedBox(height: WorkbenchStyle.space12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(
                      WorkbenchStyle.controlRadius,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(WorkbenchStyle.space12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final name in documents)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: workbenchDialogButtonStyle(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _CloseAction.discard),
              style: workbenchDialogButtonStyle(
                context,
                role: DialogButtonRole.destructive,
              ),
              child: Text(AppLocalizations.of(context).discard),
            ),
            FilledButton(
              autofocus: quitting,
              onPressed: () => Navigator.pop(context, _CloseAction.save),
              style: workbenchDialogButtonStyle(
                context,
                role: DialogButtonRole.primary,
              ),
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ) ??
      _CloseAction.cancel;

  Future<void> _close(int id) async {
    if (_closingTab || _confirmingExit || _fileBusy) return;
    final tab = workspace.tab(id);
    if (tab == null || !workspace.canClose(tab)) return;
    _closingTab = true;
    try {
      if (tab.dirty) {
        final action = await _confirmClose(strings.saveChanges, [
          strings.tabName(tab),
        ]);
        if (!mounted || action == _CloseAction.cancel) return;
        if (action == _CloseAction.save &&
            (!await _save(id) ||
                !mounted ||
                workspace.tab(id)?.dirty == true)) {
          return;
        }
      }
      controller.close(id);
      final path = workspace.tab(id) == null ? tab.file?.path : null;
      if (path != null) await widget.workspaceSession?.releaseAccess(path);
    } finally {
      _closingTab = false;
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
