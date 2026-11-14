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
import '../editor/format_tree_view.dart';
import '../editor/csv_document_view.dart';
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
import 'restore_failures_dialog.dart';
import 'file_drop_zone.dart';
import 'command_palette.dart';
import 'external_file_opens.dart';

part 'workbench_file_actions.dart';
part 'workbench_window_actions.dart';
part 'workbench_commands.dart';
part 'workbench_document_actions.dart';
part 'workbench_navigation.dart';
part 'workbench_panes.dart';
part 'workbench_format_panes.dart';
part 'workbench_node_dialogs.dart';

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
  void _updateView(VoidCallback update) => setState(update);

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
    if (_exitApproved || !await _confirmExit() || !mounted) return;
    // The macOS runner calls back into onExitRequested during destroy().
    _exitApproved = true;
    var hidden = false;
    try {
      if (Theme.of(context).platform == TargetPlatform.windows) {
        // Engine teardown can outlive the native message loop on Windows.
        await windowManager.hide();
        hidden = true;
      }
      await windowManager.destroy();
    } catch (_) {
      _exitApproved = false;
      if (hidden) await windowManager.show();
      rethrow;
    }
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
