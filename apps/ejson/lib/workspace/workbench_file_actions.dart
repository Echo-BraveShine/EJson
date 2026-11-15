part of 'workbench.dart';

extension _WorkbenchFileActions on _WorkbenchState {
  Future<void> _drainExternalFiles() async {
    _externalRetry = null;
    if (!mounted || _externalRequests.isEmpty) return;
    if (!_canOpenFiles) {
      _externalRetry = Timer(
        const Duration(milliseconds: 200),
        _drainExternalFiles,
      );
      return;
    }
    final files = [..._externalRequests];
    _externalRequests.clear();
    await _openRequests([
      for (final file in files)
        (path: file.path, bookmark: file.bookmark, asCopy: false),
    ]);
    if (mounted && widget.manageWindow) {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  WorkspaceController get controller => ref.read(workspaceProvider.notifier);
  Workspace get workspace => ref.read(workspaceProvider);
  AppLocalizations get strings => AppLocalizations.of(context);

  bool get _canOpenFiles =>
      !_fileBusy &&
      !_closingTab &&
      !_confirmingExit &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _open() async {
    if (!_canOpenFiles) return;
    _updateView(() => _fileBusy = true);
    List<XFile> selected = const [];
    try {
      selected = await openFiles();
    } on Exception catch (error) {
      if (mounted) _message(strings.openFailed(strings.fileError(error)));
    } finally {
      if (mounted) _updateView(() => _fileBusy = false);
    }
    if (!mounted) return;
    await _openRequests([
      for (final file in selected)
        (path: file.path, bookmark: null, asCopy: false),
    ]);
  }

  Future<void> _dropFiles(DropDoneDetails details) async {
    if (details.files.isEmpty) {
      _message(strings.noDroppedFiles);
      return;
    }
    await _openRequests([
      for (final file in details.files)
        (
          path: file.path,
          bookmark: file.extraAppleBookmark == null
              ? null
              : base64Encode(file.extraAppleBookmark!),
          asCopy: file.fromPromise,
        ),
    ]);
  }

  Future<RecentFile> _recentReference(
    LocalJsonFile file,
    _FileOpenRequest request,
  ) async {
    final bookmark = await widget.workspaceSession?.bookmarkFor(file.path);
    return RecentFile(
      file.path,
      bookmark:
          bookmark ?? (request.path == file.path ? request.bookmark : null),
    );
  }

  Future<void> _openRequests(List<_FileOpenRequest> requests) async {
    if (requests.isEmpty || !_canOpenFiles) return;
    _updateView(() => _fileBusy = true);
    final failures = <String>[];
    final recent = <RecentFile>[];
    final seen = <(String, bool)>{};
    var importedCopies = false;
    final session = widget.workspaceSession;
    final read = ref.read(localFileReaderProvider);
    try {
      for (final request in requests) {
        if (!mounted) break;
        if (!seen.add((request.path, request.asCopy))) continue;
        var acquired = false;
        try {
          final existing = workspace.tabs
              .where((tab) => tab.file?.path == request.path)
              .firstOrNull;
          if (!request.asCopy && existing != null) {
            controller.activate(existing.id);
            recent.add(await _recentReference(existing.file!, request));
            continue;
          }
          acquired =
              await session?.accessFile(request.path, request.bookmark) ??
              false;
          final file = await read(request.path);
          if (!mounted) {
            if (acquired) await session?.releaseAccess(request.path);
            break;
          }
          if (request.asCopy) {
            controller.newTabWithSource(
              file.source,
              format: DocumentFormat.fromPath(file.path),
              bom: file.bom,
            );
            importedCopies = true;
            if (acquired) await session?.releaseAccess(request.path);
            continue;
          }
          final alreadyOpen = workspace.tabs.any(
            (tab) => tab.file?.path == file.path,
          );
          controller.open(file);
          if (alreadyOpen) {
            if (acquired) await session?.releaseAccess(request.path);
          } else {
            session?.trackAccess(request.path, file.path);
          }
          acquired = false;
          recent.add(await _recentReference(file, request));
        } on Exception catch (error) {
          if (acquired) await session?.releaseAccess(request.path);
          if (mounted) {
            failures.add(
              strings.openFailed(
                '${RecentFile(request.path).name} · ${strings.fileError(error)}',
              ),
            );
          }
        }
      }
      if (mounted && recent.isNotEmpty) {
        final remembered = await ref
            .read(toolPreferencesProvider.notifier)
            .recordRecentFiles(recent);
        if (mounted && !remembered) _message(strings.recentSaveFailed);
      }
    } finally {
      if (mounted) _updateView(() => _fileBusy = false);
    }
    if (!mounted) return;
    if (importedCopies) _message(strings.droppedCopyOpened);
    if (failures.length == 1) {
      _message(failures.single);
    } else if (failures.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => WorkbenchDialog(
          title: strings.someFilesFailed,
          content: SizedBox(width: 460, child: Text(failures.join('\n\n'))),
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
        ),
      );
    }
  }

  Future<void> _rememberSavedFile(LocalJsonFile file) async {
    final entry = await _recentReference(file, (
      path: file.path,
      bookmark: null,
      asCopy: false,
    ));
    if (!mounted) return;
    final saved = await ref
        .read(toolPreferencesProvider.notifier)
        .recordRecentFiles([entry]);
    if (mounted && !saved) _message(strings.recentSaveFailed);
  }

  Future<void> _openRecents() async {
    if (_recentsOpen || !_canOpenFiles) return;
    _updateView(() => _recentsOpen = true);
    RecentFile? selected;
    try {
      selected = await showDialog<RecentFile>(
        context: context,
        builder: (_) => const RecentFilesDialog(),
      );
    } finally {
      if (mounted) _updateView(() => _recentsOpen = false);
    }
    if (!mounted || selected == null) return;
    await _openRequests([
      (path: selected.path, bookmark: selected.bookmark, asCopy: false),
    ]);
  }

  Future<bool> _save(
    int id, {
    bool saveAs = false,
    bool saveDraftOnExit = false,
    bool chooseFormat = true,
  }) async {
    if (_fileBusy || !mounted) return false;
    final tab = workspace.tab(id);
    if (tab == null) return false;
    _updateView(() => _fileBusy = true);
    try {
      final original = tab.file;
      final writeAtomically = ref.read(workspaceAtomicWriterProvider);
      if (original == null && saveDraftOnExit) {
        final directory = await ref.read(workspaceDraftDirectoryProvider)();
        final saved = await LocalJsonFile.saveDraft(
          directory,
          '${tab.name}.${tab.format.extension}',
          tab.text,
          bom: tab.bom,
          writeAtomically: writeAtomically,
        );
        if (mounted) controller.markSaved(id, saved);
        return true;
      }
      var output = ConversionOutput(tab.text, tab.format, bom: tab.bom);
      if (saveAs && chooseFormat) {
        final selected = await showDialog<ConversionOutput>(
          context: context,
          builder: (_) => SaveAsDialog(
            source: tab.text,
            format: tab.format,
            bom: tab.bom,
            highlight: widget.highlight,
          ),
        );
        if (selected == null || !mounted) return false;
        output = selected;
      }
      final converted = output.format != tab.format;
      String? destination;
      if (saveAs || original == null) {
        final selected = await getSaveLocation(
          acceptedTypeGroups: [
            XTypeGroup(
              label: output.format.label,
              extensions: output.format.extensions,
            ),
          ],
          suggestedName: original == null
              ? 'untitled.${output.format.extension}'
              : converted
              ? '${tab.name.replaceFirst(RegExp(r'\.[^.]+$'), '')}.${output.format.extension}'
              : tab.name,
        );
        if (selected == null || !mounted) return false;
        destination = selected.path;
        if (saveAs && chooseFormat) {
          final name = File(destination).uri.pathSegments.last;
          if (!name.contains('.')) {
            destination = '$destination.${output.format.extension}';
            if (await File(destination).exists()) {
              if (!mounted) return false;
              final replace = await showDialog<bool>(
                context: context,
                builder: (context) => WorkbenchDialog(
                  title: strings.saveAs,
                  content: Text(strings.saveAsOverwrite(destination!)),
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
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(strings.save),
                    ),
                  ],
                ),
              );
              if (replace != true || !mounted) return false;
            }
          } else {
            final extension = name.split('.').last.toLowerCase();
            if (!output.format.extensions.contains(extension)) {
              _message(strings.saveAsExtensionError(output.format.extension));
              return false;
            }
          }
        }
        final target = File(destination);
        if (await target.exists()) {
          final resolved = await target.resolveSymbolicLinks();
          if (!mounted) return false;
          if (workspace.tabs.any(
            (other) => other.id != id && other.file?.path == resolved,
          )) {
            _message(strings.fileAlreadyOpen);
            return false;
          }
          if (original?.path == resolved) {
            if (converted) {
              _message(strings.fileAlreadyOpen);
              return false;
            }
            destination = null;
          }
        }
      }
      if (!mounted || workspace.tab(id)?.text != tab.text) {
        if (mounted) _message(strings.staleNode);
        return false;
      }
      final saved = await ref.read(fileOperationQueueProvider).run(() async {
        if (!mounted || workspace.tab(id)?.text != tab.text) return null;
        final currentFile = workspace.tab(id)?.file;
        final base = converted
            ? LocalJsonFile(destination!, '', bom: output.bom)
            : currentFile ?? LocalJsonFile(destination!, '', bom: output.bom);
        final saved = await base.save(
          output.source,
          destination: destination,
          writeAtomically: writeAtomically,
        );
        if (mounted) {
          if (converted) {
            controller.newTabWithSource(
              output.source,
              format: output.format,
              bom: output.bom,
            );
            controller.markSaved(workspace.activeId, saved);
          } else if (workspace.tab(id)?.file == currentFile) {
            controller.markSaved(id, saved);
          }
        }
        return saved;
      });
      if (saved == null) {
        if (mounted) _message(strings.staleNode);
        return false;
      }
      if (mounted) {
        await _rememberSavedFile(saved);
        if (mounted) {
          await ref.read(workspaceAutosaveProvider.notifier).flush();
        }
      }
      if (!converted && original != null && original.path != saved.path) {
        await widget.workspaceSession?.releaseAccess(original.path);
      }
      return true;
    } on Exception catch (error) {
      if (mounted) _message(strings.saveFailed(strings.fileError(error)));
      return false;
    } finally {
      if (mounted) _updateView(() => _fileBusy = false);
    }
  }
}
