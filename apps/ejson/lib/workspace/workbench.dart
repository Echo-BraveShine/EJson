import '../design/workbench_text_field.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show AppExitResponse;

import 'package:ejson_core/ejson_core.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../design/workbench_style.dart';
import '../design/reading_style.dart';
import '../editor/code_editor.dart';
import '../editor/array_table.dart';
import '../editor/json_query_dialog.dart';
import '../editor/document_statistics.dart';
import '../editor/document_find.dart';
import '../editor/json_highlight.dart';
import '../editor/tree_panel.dart';
import '../editor/tree_style.dart';
import '../l10n/app_localizations.dart';
import '../l10n/workspace_messages.dart';
import '../settings/settings_panel.dart';
import '../settings/tool_preferences.dart';
import '../editor/array_sort_dialog.dart';
import '../editor/schema_dialog.dart';
import '../editor/redaction_dialog.dart';
import '../editor/conversion_dialog.dart';
import 'compare_documents.dart';
import 'local_files.dart';
import 'workspace.dart';
import 'workspace_session.dart';
import 'recent_file.dart';
import 'recent_files_dialog.dart';
import 'file_drop_zone.dart';
import 'command_palette.dart';
import 'external_file_opens.dart';

final localFileReaderProvider =
    Provider<Future<LocalJsonFile> Function(String)>(
      (ref) => LocalJsonFile.read,
    );

typedef _FileOpenRequest = ({String path, String? bookmark, bool asCopy});

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
      (ref) => (source, parent, entry) {
        final options = ref.read(toolPreferencesProvider).format;
        return Isolate.run(
          () =>
              appendFormattedJsonChild(source, parent, entry, options: options),
        );
      },
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
  bool _paletteOpen = false;
  String _schemaDraft = '';
  bool _recentsOpen = false;
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
  StreamSubscription<List<RecentFile>>? _externalSubscription;
  Timer? _externalRetry;
  final _externalRequests = <RecentFile>[];

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

  @override
  void initState() {
    super.initState();
    _externalSubscription = ref
        .read(externalFileOpensProvider)
        ?.requests
        .listen((files) {
          _externalRequests.addAll(files);
          if (_externalRetry?.isActive ?? false) return;
          _externalRetry = Timer(Duration.zero, _drainExternalFiles);
        });
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
    _externalRetry?.cancel();
    unawaited(_externalSubscription?.cancel());
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

  bool get _canOpenFiles =>
      !_fileBusy &&
      !_closingTab &&
      !_confirmingExit &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _open() async {
    if (!_canOpenFiles) return;
    setState(() => _fileBusy = true);
    List<XFile> selected = const [];
    try {
      selected = await openFiles();
    } on Exception catch (error) {
      if (mounted) _message(strings.openFailed(strings.fileError(error)));
    } finally {
      if (mounted) setState(() => _fileBusy = false);
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
    setState(() => _fileBusy = true);
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
      if (mounted) setState(() => _fileBusy = false);
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
    setState(() => _recentsOpen = true);
    RecentFile? selected;
    try {
      selected = await showDialog<RecentFile>(
        context: context,
        builder: (_) => const RecentFilesDialog(),
      );
    } finally {
      if (mounted) setState(() => _recentsOpen = false);
    }
    if (!mounted || selected == null) return;
    await _openRequests([
      (path: selected.path, bookmark: selected.bookmark, asCopy: false),
    ]);
  }

  JsonNode? _arrayForCommands(WorkspaceTab tab) {
    if (!tab.document.isValid || tab.large) return null;
    final root = tab.document.snapshot!.root!;
    final jump = _jump;
    if (jump != null &&
        jump.tabId == tab.id &&
        jump.revision == tab.document.revision) {
      JsonNode? selected(JsonNode node) {
        if (node.range == jump.range && node.kind == JsonKind.array) {
          return node;
        }
        for (final child in node.children) {
          if (child.value.range.start <= jump.range.start &&
              child.value.range.end >= jump.range.end) {
            final match = selected(child.value);
            if (match != null) return match;
          }
        }
        return null;
      }

      final array = selected(root);
      if (array != null) return array;
    }
    return root.kind == JsonKind.array ? root : null;
  }

  List<WorkbenchCommand> _commands() {
    final tab = workspace.active;
    final valid = tab.document.isValid && !tab.large;
    final io = !_fileBusy && !_closingTab && !_confirmingExit;
    final array = _arrayForCommands(tab);
    final primary = Platform.isMacOS ? '⌘' : 'Ctrl+';
    final shift = Platform.isMacOS ? '⇧' : 'Shift+';
    final compare =
        workspace.tabs
            .where((tab) => !tab.large && tab.document.isValid)
            .take(2)
            .length ==
        2;
    return [
      WorkbenchCommand(
        id: WorkbenchCommandId.newTab,
        label: strings.newTab,
        icon: CupertinoIcons.plus,
        shortcut: '${primary}N',
        keywords: 'new document tab 新建 文档 标签页',
        action: controller.newTab,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.open,
        label: strings.open,
        icon: CupertinoIcons.folder,
        shortcut: '${primary}O',
        keywords: 'open file 打开 文件',
        action: io ? _open : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.recentFiles,
        label: strings.recentFiles,
        icon: CupertinoIcons.clock,
        shortcut: '${primary}P',
        keywords: 'recent files history 最近 文件 历史',
        action: io ? _openRecents : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.save,
        label: strings.save,
        icon: CupertinoIcons.square_arrow_down,
        shortcut: '${primary}S',
        keywords: 'save file 保存 文件',
        action: io ? () => _save(tab.id) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.saveAs,
        label: strings.saveAs,
        icon: CupertinoIcons.square_arrow_down_on_square,
        shortcut: '$primary${shift}S',
        keywords: 'save as 另存为',
        action: io ? () => _save(tab.id, saveAs: true) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.closeTab,
        label: strings.closeTab(strings.tabName(tab)),
        icon: CupertinoIcons.xmark,
        shortcut: '${primary}W',
        keywords: 'close tab 关闭 标签页',
        action: io && workspace.canClose(tab) ? () => _close(tab.id) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.undo,
        label: strings.undo,
        icon: CupertinoIcons.arrow_uturn_left,
        shortcut: '${primary}Z',
        keywords: 'undo 撤销',
        action: controller.canUndo(tab.id)
            ? () => controller.undo(tab.id)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.redo,
        label: strings.redo,
        icon: CupertinoIcons.arrow_uturn_right,
        shortcut: '$primary${shift}Z',
        keywords: 'redo 重做',
        action: controller.canRedo(tab.id)
            ? () => controller.redo(tab.id)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.find,
        label: strings.findInDocument,
        icon: CupertinoIcons.search,
        shortcut: '${primary}F',
        keywords: 'find search replace 查找 搜索 替换',
        action: _openFind,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.format,
        label: strings.format,
        icon: CupertinoIcons.text_alignleft,
        keywords: 'format pretty json 格式化',
        action: valid ? () => controller.rewrite(tab.id, minify: false) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.minify,
        label: strings.minify,
        icon: CupertinoIcons.arrow_down_right_arrow_up_left,
        keywords: 'minify compact json 压缩',
        action: valid ? () => controller.rewrite(tab.id, minify: true) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.escape,
        label: strings.escapeJson,
        icon: CupertinoIcons.text_quote,
        keywords: 'escape json string 转义 字符串',
        action: !tab.large && tab.format == DocumentFormat.json
            ? () => _transformString(tab, escape: true)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.unescape,
        label: strings.unescapeJson,
        icon: CupertinoIcons.text_quote,
        keywords: 'unescape decode json string 反转义',
        action: !tab.large && tab.format == DocumentFormat.json
            ? () => _transformString(tab, escape: false)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.jsonPath,
        label: strings.goToJsonPath,
        icon: CupertinoIcons.location,
        keywords: 'jsonpath goto path 跳转 路径',
        action: valid ? () => _goToPath(tab) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.jsonQuery,
        label: strings.jsonQuery,
        icon: CupertinoIcons.line_horizontal_3_decrease,
        keywords: 'jsonpath query filter 查询 筛选',
        action: valid ? () => _openQuery(tab) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.compare,
        label: strings.compareDocuments,
        icon: CupertinoIcons.square_split_2x1,
        keywords: 'compare diff json 对比 比较 差异',
        action: compare ? _openComparison : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.arrayTable,
        label: strings.arrayTable,
        icon: CupertinoIcons.table,
        keywords: 'array table csv export 数组 表格 导出',
        action: array != null ? () => _openTable(tab, array) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.sortArray,
        label: strings.sortArray,
        icon: CupertinoIcons.sort_down,
        keywords: 'sort array 排序 数组',
        action: array != null && array.children.length > 1
            ? () => _sortArray(tab, array)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.convert,
        label: strings.formatConversion,
        icon: CupertinoIcons.arrow_2_squarepath,
        keywords: 'convert conversion json yaml csv 转换 格式',
        action: !tab.large && tab.format != DocumentFormat.csv
            ? () => _openConversion(tab)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.schema,
        label: strings.schemaValidation,
        icon: CupertinoIcons.checkmark_shield,
        keywords: 'schema validate validation 校验 规则',
        action: valid ? () => _openSchema(tab) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.redact,
        label: strings.redactData,
        icon: CupertinoIcons.eye_slash,
        keywords: 'redact mask privacy 脱敏 隐私',
        action: valid ? () => _openRedaction(tab) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.settings,
        label: strings.settings,
        icon: CupertinoIcons.slider_horizontal_3,
        keywords: 'settings preferences font theme language 设置 字体 字号 主题 语言',
        action: io && !_settingsOpen ? _openSettings : null,
      ),
    ];
  }

  Future<void> _openPalette() async {
    if (_paletteOpen || !_canOpenFiles) return;
    setState(() => _paletteOpen = true);
    WorkbenchCommandId? selected;
    try {
      selected = await showDialog<WorkbenchCommandId>(
        context: context,
        builder: (_) => Consumer(
          builder: (context, ref, _) {
            ref.watch(workspaceProvider);
            return CommandPalette(commands: _commands());
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _paletteOpen = false);
    }
    if (!mounted || selected == null) return;
    _commands()
        .where((command) => command.id == selected)
        .firstOrNull
        ?.action
        ?.call();
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
          '${tab.name}.${tab.format.extension}',
          tab.text,
          bom: tab.bom,
          writeAtomically: writeAtomically,
        );
        if (mounted) controller.markSaved(id, saved);
        return true;
      }
      String? destination;
      if (saveAs || original == null) {
        final selected = await getSaveLocation(
          suggestedName: original == null
              ? 'untitled.${tab.format.extension}'
              : tab.name,
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
      final saved =
          await (original ?? LocalJsonFile(destination!, '', bom: tab.bom))
              .save(
                tab.text,
                destination: destination,
                writeAtomically: writeAtomically,
              );
      if (mounted) {
        controller.markSaved(id, saved);
        await _rememberSavedFile(saved);
      }
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
        treeStyle: widget.treeStyle,
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

  Future<void> _openQuery(WorkspaceTab tab) async {
    final result = await showDialog<JsonQueryResult>(
      context: context,
      builder: (_) =>
          JsonQueryDialog(source: tab.text, root: tab.document.snapshot!.root!),
    );
    if (!mounted || result == null) return;
    if (!_isCurrent(tab) || workspace.activeId != tab.id) {
      _message(strings.staleNode);
      return;
    }
    if (result.range case final range?) {
      _reveal(range, search: true);
    } else if (result.source case final source?) {
      controller.newTabWithSource(source);
    }
  }

  Future<void> _openConversion(WorkspaceTab tab) async {
    final result = await showDialog<ConversionResult>(
      context: context,
      builder: (_) => ConversionDialog(
        source: tab.text,
        format: tab.format,
        highlight: widget.highlight,
      ),
    );
    if (!mounted || result == null) return;
    final output = result.output;
    controller.newTabWithSource(
      output.source,
      format: output.format,
      bom: output.bom,
    );
    if (result.save) await _save(workspace.activeId, saveAs: true);
  }

  Future<void> _openSchema(WorkspaceTab tab) async {
    final range = await showDialog<SourceRange>(
      context: context,
      builder: (_) => SchemaDialog(
        source: tab.text,
        initialSchema: _schemaDraft,
        onSchemaChanged: (value) => _schemaDraft = value,
      ),
    );
    if (!mounted || range == null) return;
    if (!_isCurrent(tab)) {
      _message(strings.staleNode);
      return;
    }
    _reveal(range, search: true);
  }

  Future<void> _openRedaction(WorkspaceTab tab) async {
    final result = await showDialog<RedactionResult>(
      context: context,
      builder: (_) =>
          RedactionDialog(source: tab.text, highlight: widget.highlight),
    );
    if (!mounted || result == null) return;
    controller.newTabWithSource(result.source);
    if (result.save) await _save(workspace.activeId, saveAs: true);
  }

  void _toggleString(WorkspaceTab tab) {
    if (tab.large) return;
    try {
      final decoded = jsonDecode(tab.text);
      if (decoded is String) {
        controller.editSource(tab.id, decoded);
        return;
      }
    } on FormatException {
      // Plain text can be escaped into a JSON string as well.
    }
    controller.editSource(tab.id, jsonEncode(tab.text));
  }

  void _transformString(WorkspaceTab tab, {required bool escape}) {
    if (tab.large) return;
    if (escape) {
      controller.editSource(tab.id, jsonEncode(tab.text));
      return;
    }
    try {
      final decoded = jsonDecode(tab.text);
      if (decoded is! String) throw const FormatException();
      controller.editSource(tab.id, decoded);
    } on FormatException {
      _message(strings.unescapeFailed);
    }
  }

  void _openFind() {
    setState(() => _findOpen = true);
    _findFocus.requestFocus();
  }

  void _closeFind() => setState(() {
    _findOpen = false;
    if (_searchJump) _jump = null;
  });

  bool _isCurrent(WorkspaceTab tab) =>
      workspace.tab(tab.id)?.document.revision == tab.document.revision &&
      tab.document.isValid &&
      !tab.large;

  Future<void> _copyValue(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _message(strings.valueCopied);
  }

  Future<void> _openTable(WorkspaceTab tab, JsonNode array) async {
    if (!_isCurrent(tab)) {
      _message(strings.staleNode);
      return;
    }
    final range = await showDialog<SourceRange>(
      context: context,
      builder: (_) => ArrayTable(
        source: tab.text,
        array: array,
        onCopy: (value) => Clipboard.setData(ClipboardData(text: value)),
        onExport: _exportCsv,
        onReveal: (range) => Navigator.pop(context, range),
      ),
    );
    if (!mounted || range == null) return;
    if (!_isCurrent(tab) || workspace.activeId != tab.id) {
      _message(strings.staleNode);
      return;
    }
    _reveal(range, search: true);
  }

  Future<String?> _exportCsv(String csv) async {
    try {
      final destination = await getSaveLocation(suggestedName: 'array.csv');
      if (destination == null || !mounted) return null;
      final target = File(destination.path);
      final resolved = await target.exists()
          ? await target.resolveSymbolicLinks()
          : target.absolute.path;
      if (!mounted) return null;
      if (workspace.tabs.any((tab) => tab.file?.path == resolved)) {
        return strings.fileAlreadyOpen;
      }
      await LocalJsonFile(destination.path, '').save(
        csv,
        destination: destination.path,
        writeAtomically: ref.read(workspaceAtomicWriterProvider),
      );
      return mounted ? strings.csvExported : null;
    } on Exception {
      return mounted ? strings.exportFailed : null;
    }
  }

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
        formatOptions: ref.read(toolPreferencesProvider).format,
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

  Future<void> _sortArray(WorkspaceTab tab, JsonNode array) async {
    final options = await showDialog<ArraySortOptions>(
      context: context,
      builder: (_) => ArraySortDialog(array: array),
    );
    if (options == null || !mounted) return;
    final source = tab.text;
    try {
      final patch = await Isolate.run(
        () => sortJsonArray(
          source,
          array,
          key: options.key,
          ascending: options.ascending,
        ),
      );
      if (mounted) _applyTreePatch(tab, patch);
    } on FormatException {
      if (mounted) _message(strings.sortArrayAmbiguous);
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
        formatOptions: ref.read(toolPreferencesProvider).format,
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
      fixedSize: const Size(32, WorkbenchStyle.toolbarControlHeight),
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
                  strings.recentFiles,
                  CupertinoIcons.clock,
                  _fileBusy ? null : _openRecents,
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
                _tool(
                  strings.jsonQuery,
                  CupertinoIcons.line_horizontal_3_decrease,
                  valid ? () => _openQuery(tab) : null,
                ),
                _tool(strings.findInDocument, CupertinoIcons.search, _openFind),
                _tool(
                  tab.document.snapshot?.root?.kind == JsonKind.string
                      ? strings.unescapeJson
                      : strings.escapeJson,
                  CupertinoIcons.text_quote,
                  tab.large || tab.format != DocumentFormat.json
                      ? null
                      : () => _toggleString(tab),
                ),
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
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: WorkbenchStyle.toolbarControlHeight,
                  child: PopupMenuButton<WorkbenchCommandId>(
                    tooltip: strings.documentTools,
                    enabled: !tab.large && tab.format != DocumentFormat.csv,
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      CupertinoIcons.ellipsis,
                      size: WorkbenchStyle.controlIconSize,
                    ),
                    onSelected: (id) => _commands()
                        .firstWhere((command) => command.id == id)
                        .action
                        ?.call(),
                    itemBuilder: (_) => [
                      WorkbenchMenuItem(
                        value: WorkbenchCommandId.convert,
                        enabled: tab.format != DocumentFormat.csv,
                        label: strings.formatConversion,
                        icon: CupertinoIcons.arrow_2_squarepath,
                      ),
                      WorkbenchMenuItem(
                        enabled: valid,
                        value: WorkbenchCommandId.schema,
                        label: strings.schemaValidation,
                        icon: CupertinoIcons.checkmark_shield,
                      ),
                      WorkbenchMenuItem(
                        enabled: valid,
                        value: WorkbenchCommandId.redact,
                        label: strings.redactData,
                        icon: CupertinoIcons.eye_slash,
                      ),
                    ],
                  ),
                ),
                _tool(
                  strings.commandPalette,
                  CupertinoIcons.command,
                  _fileBusy ? null : _openPalette,
                ),
                _tool(
                  strings.settings,
                  CupertinoIcons.slider_horizontal_3,
                  _openSettings,
                ),
              ],
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

  Widget _sourceEditor(WorkspaceTab tab) => EJsonCodeEditor(
    key: ValueKey(tab.id),
    source: tab.text,
    format: tab.format,
    highlight: widget.highlight,
    onChanged: (text) {
      _jump = null;
      controller.editSource(tab.id, text);
    },
    jump: _jump?.tabId == tab.id && _jump?.revision == tab.document.revision
        ? (range: _jump!.range, sequence: _jump!.sequence)
        : null,
    focusOnJump: !_searchJump,
    readOnly: tab.large,
  );

  Widget _panes(WorkspaceTab tab, bool valid) {
    if (tab.format != DocumentFormat.json) {
      return _Panel(
        title: '${strings.source} · ${tab.format.label}',
        icon: CupertinoIcons.doc_text,
        child: _sourceEditor(tab),
      );
    }
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
          const SizedBox(width: WorkbenchStyle.space12),
          Text(
            'UTF-8${tab.bom ? " BOM" : ""}  ·  ${tab.format.label}',
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
        ? tab.format == DocumentFormat.json
              ? strings.validJson
              : strings.contentValid(tab.format.label)
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
        shortcut(LogicalKeyboardKey.keyP): _openRecents,
        shortcut(LogicalKeyboardKey.keyP, shift: true): _openPalette,
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
            child: FileDropZone(
              enabled: !_fileBusy && !_closingTab && !_confirmingExit,
              onDrop: (details) => unawaited(_dropFiles(details)),
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
                      structured: tab.format == DocumentFormat.json,
                      enabled: !tab.large,
                      focusNode: _findFocus,
                      onMatch: (range) => _reveal(range, search: true),
                      onClose: _closeFind,
                      onReplace: (text) => controller.editSource(tab.id, text),
                    ),
                  Expanded(child: _panes(tab, valid)),
                  const Divider(height: 1),
                  _statusBar(
                    tab,
                    status,
                    diagnostic,
                    valid ||
                        tab.format != DocumentFormat.json &&
                            snapshot != null &&
                            diagnostics.every((d) => d.warning),
                  ),
                ],
              ),
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
        child: WorkbenchTextField(
          autofocus: true,
          controller: _path,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
          style: ReadingStyle.of(context).text,
          hintText: r'$["items"][0]',
          errorText: switch (_error) {
            JsonPathStatus.invalid => strings.invalidJsonPath,
            JsonPathStatus.missing => strings.missingJsonPath,
            JsonPathStatus.ambiguous => strings.ambiguousJsonPath,
            _ => null,
          },
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
    this.formatOptions = const JsonFormatOptions(),
  });
  final String value;
  final bool keyName;
  final JsonKind? addTo;
  final JsonFormatOptions formatOptions;
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
        : rewriteJson(
            JsonDocument(SourceBuffer(source), snapshot: snapshot),
            options: widget.formatOptions,
          );
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
            ? WorkbenchTextField(
                controller: _keyText,
                autofocus: true,
                style: ReadingStyle.of(context).text,
                errorText: error,
                onSubmitted: (_) => _submit(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.addTo == JsonKind.object) ...[
                    WorkbenchTextField(
                      controller: _property,
                      autofocus: true,
                      labelText: strings.propertyName,
                    ),
                    const SizedBox(height: WorkbenchStyle.space12),
                  ],
                  Material(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        WorkbenchStyle.controlRadius,
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
