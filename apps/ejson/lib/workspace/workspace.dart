import 'dart:async';
import 'dart:isolate';

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_files.dart';

final workspaceProvider = NotifierProvider<WorkspaceController, Workspace>(
  WorkspaceController.new,
);

final initialWorkspaceProvider =
    Provider<({List<LocalJsonFile> files, String? activePath})>(
      (ref) => (files: const [], activePath: null),
    );

final parseDocumentProvider =
    Provider<Future<ParseSnapshot> Function(String, int)>(
      (ref) => _parseInBackground,
    );

Future<ParseSnapshot> _parseInBackground(String source, int revision) =>
    Isolate.run(() => parseJson(source, revision: revision));

const maxParsedUnits = 2 * 1024 * 1024;

class WorkspaceTab {
  const WorkspaceTab(
    this.id,
    this.document, {
    this.file,
    this.isDefault = false,
  });
  final int id;
  final JsonDocument document;
  final LocalJsonFile? file;

  final bool isDefault;

  String get name {
    final path = file?.path;
    if (path != null) return Uri.file(path).pathSegments.last;
    return isDefault ? 'Untitled' : 'Untitled $id';
  }

  String get text => document.source.text;
  bool get dirty => text != (file?.source ?? '');
  bool get large => text.length > maxParsedUnits;

  WorkspaceTab withDocument(JsonDocument document) =>
      WorkspaceTab(id, document, file: file, isDefault: isDefault);
}

class Workspace {
  Workspace(List<WorkspaceTab> tabs, this.activeId)
    : tabs = List.unmodifiable(tabs);
  final List<WorkspaceTab> tabs;
  final int activeId;
  WorkspaceTab get active => tabs.firstWhere((tab) => tab.id == activeId);

  bool canClose(WorkspaceTab tab) =>
      tabs.length > 1 || !tab.isDefault || tab.dirty || tab.file != null;

  WorkspaceTab? tab(int id) {
    for (final tab in tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }
}

class WorkspaceController extends Notifier<Workspace> {
  final _history = <int, EditHistory>{};
  final _timers = <int, Timer>{};
  final _parsing = <int>{};
  int _nextId = 0;

  @override
  Workspace build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
    });
    final initial = ref.read(initialWorkspaceProvider);
    final tabs = [
      for (final file in initial.files) _create(file.source, file: file),
    ];
    if (tabs.isEmpty) tabs.add(_create('', isDefault: true));
    for (final tab in tabs) {
      _schedule(tab);
    }
    final active = tabs.firstWhere(
      (tab) => tab.file?.path == initial.activePath,
      orElse: () => tabs.first,
    );
    return Workspace(tabs, active.id);
  }

  WorkspaceTab _create(
    String source, {
    LocalJsonFile? file,
    bool isDefault = false,
  }) {
    final id = ++_nextId;
    _history[id] = EditHistory();
    var document = JsonDocument(SourceBuffer(source));
    if (source.isEmpty) document = document.accept(parseJson(source));
    return WorkspaceTab(id, document, file: file, isDefault: isDefault);
  }

  void newTab() {
    final tab = _create('');
    state = Workspace([...state.tabs, tab], tab.id);
  }

  void activate(int id) {
    if (state.tab(id) != null) state = Workspace(state.tabs, id);
  }

  void open(LocalJsonFile file) {
    for (final tab in state.tabs) {
      if (tab.file?.path == file.path) {
        activate(tab.id);
        return;
      }
    }
    final tab = _create(file.source, file: file);
    state = Workspace([...state.tabs, tab], tab.id);
    _schedule(tab);
  }

  void close(int id) {
    final index = state.tabs.indexWhere((tab) => tab.id == id);
    if (index < 0 || !state.canClose(state.tabs[index])) return;
    _timers.remove(id)?.cancel();
    _history.remove(id);
    final tabs = [...state.tabs]..removeAt(index);
    if (tabs.isEmpty) tabs.add(_create('', isDefault: true));
    final neighbor = index.clamp(0, tabs.length - 1);
    state = Workspace(
      tabs,
      id == state.activeId ? tabs[neighbor].id : state.activeId,
    );
  }

  void _update(WorkspaceTab tab) {
    state = Workspace([
      for (final current in state.tabs)
        if (current.id == tab.id) tab else current,
    ], state.activeId);
  }

  void editSource(int id, String text) {
    final tab = state.tab(id);
    if (tab == null || tab.text == text || tab.large) return;
    _apply(tab, SourcePatch.between(tab.text, text));
  }

  void _apply(WorkspaceTab tab, SourcePatch patch, {bool record = true}) {
    final document = tab.document.apply(
      patch,
      expectedRevision: tab.document.revision,
    )!;
    if (document.source.text == tab.text) return;
    if (record) _history[tab.id]!.record(patch, tab.text);
    final updated = tab.withDocument(document);
    _update(updated);
    _schedule(updated);
  }

  /// Returns false if the dialog was based on an older source revision.
  bool editNode(int id, int revision, SourcePatch patch) {
    final tab = state.tab(id);
    if (tab == null ||
        tab.document.revision != revision ||
        !tab.document.isValid) {
      return false;
    }
    _apply(tab, patch);
    return true;
  }

  bool canUndo(int id) => _history[id]?.canUndo ?? false;
  bool canRedo(int id) => _history[id]?.canRedo ?? false;

  void undo(int id) {
    final tab = state.tab(id);
    final patch = _history[id]?.undo();
    if (tab != null && patch != null) _apply(tab, patch, record: false);
  }

  void redo(int id) {
    final tab = state.tab(id);
    final patch = _history[id]?.redo();
    if (tab != null && patch != null) _apply(tab, patch, record: false);
  }

  Future<void> rewrite(int id, {required bool minify}) async {
    final tab = state.tab(id);
    if (tab == null || !tab.document.isValid || tab.large) return;
    final document = tab.document;
    final text = await Isolate.run(() => rewriteJson(document, minify: minify));
    if (!ref.mounted || state.tab(id)?.document.revision != document.revision) {
      return;
    }
    editSource(id, text);
  }

  void markSaved(int id, LocalJsonFile file) {
    final tab = state.tab(id);
    if (tab != null) _update(WorkspaceTab(id, tab.document, file: file));
  }

  void _schedule(WorkspaceTab tab) {
    _timers.remove(tab.id)?.cancel();
    if (tab.large) return;
    final id = tab.id;
    _timers[id] = Timer(const Duration(milliseconds: 180), () {
      _timers.remove(id);
      unawaited(_parse(id));
    });
  }

  Future<void> _parse(int id) async {
    final tab = state.tab(id);
    if (tab == null || tab.large || !_parsing.add(id)) return;
    final source = tab.text;
    final revision = tab.document.revision;
    try {
      final result = await ref.read(parseDocumentProvider)(source, revision);
      if (!ref.mounted) return;
      final current = state.tab(id);
      if (current?.document.revision == revision) {
        _update(current!.withDocument(current.document.accept(result)));
      }
    } finally {
      _parsing.remove(id);
      if (ref.mounted && !_timers.containsKey(id)) {
        final current = state.tab(id);
        if (current != null && current.document.revision != revision) {
          _schedule(current);
        }
      }
    }
  }
}
