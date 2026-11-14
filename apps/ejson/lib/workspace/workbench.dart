import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show AppExitResponse;

import 'package:ejson_core/ejson_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../design/workbench_style.dart';
import '../editor/code_editor.dart';
import '../editor/document_find.dart';
import '../editor/json_highlight.dart';
import '../editor/tree_panel.dart';
import '../editor/tree_style.dart';
import '../l10n/app_localizations.dart';
import '../l10n/workspace_messages.dart';
import '../settings/settings_panel.dart';
import 'compare_documents.dart';
import 'local_files.dart';
import 'workspace.dart';
import 'workspace_session.dart';

final workspaceDraftDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => () async {
    final support = await getApplicationSupportDirectory();
    return Directory.fromUri(support.uri.resolve('Drafts/'));
  },
);

final formatTreeAdditionProvider =
    Provider<
      Future<({SourcePatch? patch, JsonDiagnostic? error})> Function(
        String,
        JsonNode,
        String,
      )
    >(
      (ref) =>
          (source, parent, entry) => Isolate.run(
            () => appendFormattedJsonChild(source, parent, entry),
          ),
    );

final workspaceAtomicWriterProvider =
    Provider<Future<void> Function(String, Uint8List)?>(
      (ref) => Platform.isMacOS
          ? (path, bytes) => const MethodChannel(
              'dev.ekko.ejson/files',
            ).invokeMethod<void>('atomicWrite', {'path': path, 'bytes': bytes})
          : null,
    );

class Workbench extends ConsumerStatefulWidget {
  const Workbench({
    super.key,
    required this.manageWindow,
    required this.workspaceSession,
    required this.restoreOnStartup,
    required this.failedRestorePaths,
    required this.themeMode,
    required this.onThemeChanged,
    required this.waitForThemeSave,
    required this.highlight,
    required this.onHighlightChanged,
    required this.treeStyle,
    required this.onTreeStyleChanged,
    required this.language,
    required this.onLanguageChanged,
  });

  final bool manageWindow;
  final WorkspaceSession? workspaceSession;
  final bool restoreOnStartup;
  final List<String> failedRestorePaths;
  final ThemeMode themeMode;
  final JsonHighlight highlight;
  final JsonTreeStyle treeStyle;
  final ValueChanged<JsonTreeStyle> onTreeStyleChanged;
  final ValueChanged<JsonHighlight> onHighlightChanged;
  final ValueChanged<ThemeMode> onThemeChanged;
  final Future<void> Function() waitForThemeSave;
  final String? language;
  final ValueChanged<String?> onLanguageChanged;

  @override
  ConsumerState<Workbench> createState() => _WorkbenchState();
}

enum _CloseAction { cancel, discard, save }

class _WorkbenchState extends ConsumerState<Workbench> with WindowListener {
  static const _appearanceChannel = MethodChannel('dev.ekko.ejson/appearance');
  late bool _restoreOnStartup = widget.restoreOnStartup;
  Future<void>? _savingRestorePreference;
  bool _glass = true;
  bool _settingsOpen = false;
  bool? _nativeDark;
  bool _fileBusy = false;
  bool _confirmingExit = false;
  bool _exitApproved = false;
  bool _closingTab = false;
  late final AppLifecycleListener? _lifecycle;
  ({SourceRange range, int sequence, int tabId, int revision})? _jump;
  int _jumpSequence = 0;
  bool _findOpen = false;
  bool _searchJump = false;
  final _findFocus = FocusNode();
  double _split = 0.61;

  WorkspaceController get controller => ref.read(workspaceProvider.notifier);
  Workspace get workspace => ref.read(workspaceProvider);
  AppLocalizations get strings => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    if (widget.manageWindow) windowManager.addListener(this);
    if (widget.failedRestorePaths.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showRestoreFailures());
      });
    }
    _lifecycle = widget.manageWindow
        ? AppLifecycleListener(
            onExitRequested: () async => _exitApproved || await _confirmExit()
                ? AppExitResponse.exit
                : AppExitResponse.cancel,
          )
        : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.manageWindow && Platform.isMacOS) {
      final language = Localizations.localeOf(context).languageCode;
      unawaited(
        _appearanceChannel.invokeMethod<void>('setMenuLanguage', language),
      );
    }
  }

  void _syncNativeAppearance() {
    if (!widget.manageWindow) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark == _nativeDark) return;
    _nativeDark = dark;
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      unawaited(
        _appearanceChannel.invokeMethod<void>('setDarkAppearance', dark),
      );
    }
  }

  String _logoAsset(bool dark) =>
      dark ? 'assets/branding/logo_dark.png' : 'assets/branding/logo_light.png';

  @override
  void dispose() {
    if (widget.manageWindow) windowManager.removeListener(this);
    _lifecycle?.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (_exitApproved || !await _confirmExit()) return;
    // The macOS runner calls back into onExitRequested during destroy().
    _exitApproved = true;
    try {
      await windowManager.destroy();
    } catch (_) {
      _exitApproved = false;
      rethrow;
    }
  }

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
    setState(() => _restoreOnStartup = value);
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

  Future<void> _open() async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      final selected = await openFiles();
      for (final file in selected) {
        try {
          final opened = await LocalJsonFile.read(file.path);
          if (mounted) controller.open(opened);
        } on Exception catch (error) {
          if (mounted) {
            _message(
              strings.openFailed('${file.name} · ${strings.fileError(error)}'),
            );
          }
        }
      }
    } on Exception catch (error) {
      if (mounted) _message(strings.openFailed(strings.fileError(error)));
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<bool> _save(
    int id, {
    bool saveAs = false,
    bool saveDraftOnExit = false,
  }) async {
    if (_fileBusy || !mounted) return false;
    final tab = workspace.tab(id);
    if (tab == null) return false;
    setState(() => _fileBusy = true);
    try {
      final original = tab.file;
      final writeAtomically = ref.read(workspaceAtomicWriterProvider);
      if (original == null && saveDraftOnExit) {
        final directory = await ref.read(workspaceDraftDirectoryProvider)();
        final saved = await LocalJsonFile.saveDraft(
          directory,
          '${tab.name}.json',
          tab.text,
          writeAtomically: writeAtomically,
        );
        if (mounted) controller.markSaved(id, saved);
        return true;
      }
      String? destination;
      if (saveAs || original == null) {
        final selected = await getSaveLocation(
          suggestedName: original == null ? 'untitled.json' : tab.name,
        );
        if (selected == null || !mounted) return false;
        destination = selected.path;
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
          if (original?.path == resolved) destination = null;
        }
      }
      final saved = await (original ?? LocalJsonFile(destination!, '')).save(
        tab.text,
        destination: destination,
        writeAtomically: writeAtomically,
      );
      if (mounted) controller.markSaved(id, saved);
      if (original != null && original.path != saved.path) {
        await widget.workspaceSession?.releaseAccess(original.path);
      }
      return true;
    } on Exception catch (error) {
      if (mounted) _message(strings.saveFailed(strings.fileError(error)));
      return false;
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  void _reveal(SourceRange range, {bool search = false}) => setState(() {
    _searchJump = search;
    _jump = (
      range: range,
      sequence: ++_jumpSequence,
      tabId: workspace.activeId,
      revision: workspace.active.document.revision,
    );
  });

  Future<void> _openComparison() async {
    final model = workspace;
    final tabs = model.tabs
        .where((tab) => !tab.large && tab.document.isValid)
        .toList();
    if (tabs.length < 2) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CompareDocuments(
        tabs: tabs,
        activeId: model.activeId,
        highlight: widget.highlight,
      ),
    );
  }

  Future<void> _goToPath(WorkspaceTab tab) async {
    final range = await showDialog<SourceRange>(
      context: context,
      builder: (_) => _PathDialog(root: tab.document.snapshot!.root!),
    );
    if (!mounted || range == null) return;
    final active = workspace.active;
    if (active.id != tab.id ||
        active.document.revision != tab.document.revision) {
      _message(strings.staleNode);
      return;
    }
    _reveal(range, search: true);
  }

  void _openFind() {
    setState(() => _findOpen = true);
    _findFocus.requestFocus();
  }

  void _closeFind() => setState(() {
    _findOpen = false;
    if (_searchJump) _jump = null;
  });

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) _message(strings.jsonPathCopied);
  }

  void _applyTreePatch(WorkspaceTab tab, SourcePatch patch) {
    if (!controller.editNode(tab.id, tab.document.revision, patch)) {
      _message(strings.staleNode);
    }
  }

  Future<void> _addChild(WorkspaceTab tab, JsonNode parent) async {
    final entry = await showDialog<String>(
      context: context,
      builder: (_) => _NodeEditor(
        value: 'null',
        keyName: false,
        addTo: parent.kind,
        highlight: widget.highlight,
      ),
    );
    if (entry == null || !mounted) return;
    final result = await ref.read(formatTreeAdditionProvider)(
      tab.text,
      parent,
      entry,
    );
    if (!mounted) return;
    if (result.patch case final patch?) {
      _applyTreePatch(tab, patch);
    } else {
      _message(strings.diagnosticMessage(result.error!));
    }
  }

  Future<void> _editNode(WorkspaceTab tab, SourceRange range, bool key) async {
    final document = tab.document;
    final replacement = await showDialog<String>(
      context: context,
      builder: (_) => _NodeEditor(
        value: document.source.slice(range),
        keyName: key,
        highlight: widget.highlight,
      ),
    );
    if (replacement == null || !mounted) return;
    _applyTreePatch(tab, SourcePatch(range, replacement));
  }

  Widget _tool(String label, IconData icon, VoidCallback? action) => IconButton(
    tooltip: label,
    icon: Icon(icon, size: WorkbenchStyle.controlIconSize),
    onPressed: action,
    style: IconButton.styleFrom(
      minimumSize: const Size(32, WorkbenchStyle.toolbarControlHeight),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  Future<void> _openSettings() async {
    if (_settingsOpen || _confirmingExit || _closingTab || _fileBusy) return;
    _settingsOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => SettingsPanel(
          themeMode: widget.themeMode,
          restoreOnStartup: _restoreOnStartup,
          onRestoreOnStartupChanged: (value) {
            final update = _setRestoreOnStartup(value);
            _savingRestorePreference = update;
            return update;
          },
          highlight: widget.highlight,
          onHighlightChanged: widget.onHighlightChanged,
          treeStyle: widget.treeStyle,
          onTreeStyleChanged: widget.onTreeStyleChanged,
          glassEnabled: _glass,
          language: widget.language,
          onThemeChanged: widget.onThemeChanged,
          onGlassChanged: (value) => setState(() => _glass = value),
          onLanguageChanged: widget.onLanguageChanged,
        ),
      );
    } finally {
      _settingsOpen = false;
    }
  }

  Widget _toolbar(WorkspaceTab tab, bool valid) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkbenchStyle.space12,
        vertical: WorkbenchStyle.space8,
      ),
      child: Row(
        children: [
          Image.asset(
            _logoAsset(theme.brightness == Brightness.dark),
            width: 19,
            height: 19,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 7),
          Text(
            'EJson',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GlassGroup(
            enabled: _glass,
            child: Row(
              children: [
                _tool(
                  strings.open,
                  CupertinoIcons.folder,
                  _fileBusy ? null : _open,
                ),
                _tool(
                  strings.save,
                  CupertinoIcons.square_arrow_down,
                  _fileBusy ? null : () => _save(tab.id),
                ),
                _tool(
                  strings.saveAs,
                  CupertinoIcons.square_arrow_down_on_square,
                  _fileBusy ? null : () => _save(tab.id, saveAs: true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GlassGroup(
            enabled: _glass,
            child: Row(
              children: [
                _tool(
                  strings.compareDocuments,
                  CupertinoIcons.square_split_2x1,
                  workspace.tabs
                              .where(
                                (item) => !item.large && item.document.isValid,
                              )
                              .take(2)
                              .length ==
                          2
                      ? _openComparison
                      : null,
                ),
                _tool(
                  strings.goToJsonPath,
                  CupertinoIcons.location,
                  valid ? () => _goToPath(tab) : null,
                ),
                _tool(strings.findInDocument, CupertinoIcons.search, _openFind),
                _tool(
                  strings.undo,
                  CupertinoIcons.arrow_uturn_left,
                  controller.canUndo(tab.id)
                      ? () => controller.undo(tab.id)
                      : null,
                ),
                _tool(
                  strings.redo,
                  CupertinoIcons.arrow_uturn_right,
                  controller.canRedo(tab.id)
                      ? () => controller.redo(tab.id)
                      : null,
                ),
                const SizedBox(height: 16, child: VerticalDivider(width: 8)),
                _tool(
                  strings.minify,
                  CupertinoIcons.arrow_down_right_arrow_up_left,
                  valid ? () => controller.rewrite(tab.id, minify: true) : null,
                ),
                _tool(
                  strings.format,
                  CupertinoIcons.text_alignleft,
                  valid
                      ? () => controller.rewrite(tab.id, minify: false)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: WorkbenchStyle.space8),
          GlassGroup(
            enabled: _glass,
            child: _tool(
              strings.settings,
              CupertinoIcons.slider_horizontal_3,
              _openSettings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(Workspace model) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 39,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
        scrollDirection: Axis.horizontal,
        itemCount: model.tabs.length + 1,
        findItemIndexCallback: (key) {
          if (key is! ValueKey<int>) return null;
          final index = model.tabs.indexWhere((tab) => tab.id == key.value);
          return index < 0 ? null : index;
        },
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          if (index == model.tabs.length) {
            return _tool(
              strings.newTab,
              CupertinoIcons.plus,
              controller.newTab,
            );
          }
          final item = model.tabs[index];
          final selected = item.id == model.activeId;
          return Semantics(
            key: ValueKey(item.id),
            selected: selected,
            child: Material(
              color: selected ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  WorkbenchStyle.controlRadius,
                ),
                onTap: () => controller.activate(item.id),
                child: Tooltip(
                  message: item.file?.path ?? strings.tabName(item),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 11, right: 3),
                    child: Row(
                      children: [
                        Icon(
                          item.dirty ? Icons.circle : CupertinoIcons.doc_text,
                          size: item.dirty ? 7 : 15,
                          color: selected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 190),
                          child: Text(
                            strings.tabName(item),
                            overflow: TextOverflow.ellipsis,
                            style: WorkbenchStyle.body.copyWith(
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (model.canClose(item)) ...[
                          const SizedBox(width: 3),
                          IconButton(
                            tooltip: strings.closeTab(strings.tabName(item)),
                            icon: const Icon(CupertinoIcons.xmark, size: 14),
                            onPressed: _fileBusy ? null : () => _close(item.id),
                          ),
                        ] else
                          const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _panes(WorkspaceTab tab, bool valid) {
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
              child: EJsonCodeEditor(
                key: ValueKey(tab.id),
                source: tab.text,
                highlight: widget.highlight,
                onChanged: (text) {
                  _jump = null;
                  controller.editSource(tab.id, text);
                },
                jump: _jump?.tabId == tab.id && _jump?.revision == doc.revision
                    ? (range: _jump!.range, sequence: _jump!.sequence)
                    : null,
                focusOnJump: !_searchJump,
                readOnly: tab.large,
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (event) => setState(() {
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
                      onCopyPath: _copyPath,
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
          Text(
            'UTF-8${tab.file?.bom == true ? " BOM" : ""}  ·  JSON',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncNativeAppearance();
    final model = ref.watch(workspaceProvider);
    final tab = model.active;
    final doc = tab.document;
    final colors = Theme.of(context).colorScheme;
    final valid = doc.isValid && !tab.large;
    final snapshot = doc.snapshot;
    final diagnostics = snapshot?.diagnostics ?? const [];
    final diagnostic = diagnostics.firstOrNull;
    final position = diagnostic == null
        ? null
        : snapshot!.lines.position(diagnostic.range.start);
    final status = tab.large
        ? strings.largeFile
        : tab.text.isEmpty
        ? strings.emptyDocument
        : snapshot == null
        ? strings.checking
        : diagnostic == null
        ? strings.validJson
        : diagnostic.warning
        ? strings.warningAt(
            position!.line,
            position.column,
            strings.diagnosticMessage(diagnostic),
          )
        : strings.errorAt(
            position!.line,
            position.column,
            strings.diagnosticMessage(diagnostic),
          );
    final primary = Platform.isMacOS;
    SingleActivator shortcut(LogicalKeyboardKey key, {bool shift = false}) =>
        SingleActivator(key, meta: primary, control: !primary, shift: shift);

    return CallbackShortcuts(
      bindings: {
        shortcut(LogicalKeyboardKey.keyF): _openFind,
        if (_findOpen)
          const SingleActivator(LogicalKeyboardKey.escape): _closeFind,
        shortcut(LogicalKeyboardKey.keyN): controller.newTab,
        shortcut(LogicalKeyboardKey.keyO): _open,
        shortcut(LogicalKeyboardKey.keyS): () => _save(tab.id),
        shortcut(LogicalKeyboardKey.keyS, shift: true): () =>
            _save(tab.id, saveAs: true),
        shortcut(LogicalKeyboardKey.keyW): () => _close(tab.id),
        shortcut(LogicalKeyboardKey.keyZ): () => controller.undo(tab.id),
        shortcut(LogicalKeyboardKey.keyZ, shift: true): () =>
            controller.redo(tab.id),
        if (!primary)
          shortcut(LogicalKeyboardKey.keyY): () => controller.redo(tab.id),
        if (primary && widget.manageWindow)
          shortcut(LogicalKeyboardKey.keyQ): onWindowClose,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _toolbar(tab, valid),
                const Divider(height: 1),
                Material(color: colors.surfaceContainer, child: _tabs(model)),
                const Divider(height: 1),
                if (_findOpen)
                  DocumentFind(
                    key: ValueKey(tab.id),
                    document: doc,
                    enabled: !tab.large,
                    focusNode: _findFocus,
                    onMatch: (range) => _reveal(range, search: true),
                    onClose: _closeFind,
                  ),
                Expanded(child: _panes(tab, valid)),
                const Divider(height: 1),
                _statusBar(tab, status, diagnostic, valid),
              ],
            ),
          ),
        ),
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

class _PathDialog extends StatefulWidget {
  const _PathDialog({required this.root});

  final JsonNode root;

  @override
  State<_PathDialog> createState() => _PathDialogState();
}

class _PathDialogState extends State<_PathDialog> {
  final _path = TextEditingController();
  JsonPathStatus? _error;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  void _submit() {
    final result = resolveJsonPath(widget.root, _path.text);
    if (result.status == JsonPathStatus.found) {
      Navigator.pop(context, result.range);
    } else {
      setState(() => _error = result.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return WorkbenchDialog(
      title: strings.goToJsonPath,
      content: SizedBox(
        width: 400,
        child: TextField(
          autofocus: true,
          controller: _path,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
          style: WorkbenchStyle.code(Theme.of(context).platform),
          decoration: InputDecoration(
            hintText: r'$["items"][0]',
            errorText: switch (_error) {
              JsonPathStatus.invalid => strings.invalidJsonPath,
              JsonPathStatus.missing => strings.missingJsonPath,
              JsonPathStatus.ambiguous => strings.ambiguousJsonPath,
              _ => null,
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          onPressed: _submit,
          child: Text(strings.goToNode),
        ),
      ],
    );
  }
}

class _NodeEditor extends StatefulWidget {
  const _NodeEditor({
    required this.value,
    required this.keyName,
    required this.highlight,
    this.addTo,
  });
  final String value;
  final bool keyName;
  final JsonKind? addTo;
  final JsonHighlight highlight;

  @override
  State<_NodeEditor> createState() => _NodeEditorState();
}

class _NodeEditorState extends State<_NodeEditor> {
  late final String _initialValue = _formatValue(widget.value);
  late String _value = _initialValue;
  late final TextEditingController? _keyText = widget.keyName
      ? TextEditingController(text: widget.value)
      : null;
  final _property = TextEditingController();
  JsonDiagnostic? _error;
  bool _requiresString = false;

  String _formatValue(String source) {
    final snapshot = parseJson(source);
    return snapshot.root == null
        ? source
        : rewriteJson(JsonDocument(SourceBuffer(source), snapshot: snapshot));
  }

  void _submit() {
    final text = _keyText?.text ?? _value;
    final snapshot = parseJson(text);
    final node = snapshot.root;
    if (node == null || (widget.keyName && node.kind != JsonKind.string)) {
      setState(() {
        _error = snapshot.diagnostics.firstOrNull;
        _requiresString = node != null;
      });
      return;
    }
    final value = !widget.keyName && text == _initialValue
        ? widget.value
        : text.substring(node.range.start, node.range.end);
    Navigator.pop(
      context,
      widget.addTo == JsonKind.object
          ? '${jsonEncode(_property.text)}: $value'
          : value,
    );
  }

  @override
  void dispose() {
    _keyText?.dispose();
    _property.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final error = _requiresString
        ? strings.quotedString
        : _error == null
        ? null
        : strings.diagnosticMessage(_error!);
    return WorkbenchDialog(
      title: switch (widget.addTo) {
        JsonKind.object => strings.addProperty,
        JsonKind.array => strings.addArrayItem,
        _ => widget.keyName ? strings.renameKey : strings.replaceJsonValue,
      },
      content: SizedBox(
        width: 480,
        child: widget.keyName
            ? TextField(
                controller: _keyText,
                autofocus: true,
                style: WorkbenchStyle.code(Theme.of(context).platform),
                decoration: InputDecoration(errorText: error),
                onSubmitted: (_) => _submit(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.addTo == JsonKind.object) ...[
                    TextField(
                      controller: _property,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: strings.propertyName,
                      ),
                    ),
                    const SizedBox(height: WorkbenchStyle.space12),
                  ],
                  Material(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        WorkbenchStyle.groupRadius,
                      ),
                      side: BorderSide(
                        color: error == null
                            ? colors.outlineVariant
                            : colors.error,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: (MediaQuery.sizeOf(context).height * .38).clamp(
                        100.0,
                        280.0,
                      ),
                      child: EJsonCodeEditor(
                        source: _value,
                        highlight: widget.highlight,
                        readOnly: false,
                        useWorkspaceShortcuts: false,
                        onChanged: (text) {
                          _value = text;
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(color: colors.error),
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
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          child: Text(strings.apply),
        ),
      ],
    );
  }
}
