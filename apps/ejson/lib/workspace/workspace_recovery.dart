import 'dart:convert';
import 'dart:io';

import 'package:ejson_core/ejson_core.dart';

import 'local_files.dart';
import 'recovered_workspace.dart';
import 'workspace.dart';

/// Two committed generations allow recovery when the newest snapshot is damaged.
class WorkspaceRecovery {
  WorkspaceRecovery(this.directory, {this.bookmarkFor, this.accessFile});

  final Directory directory;
  final Future<String?> Function(String)? bookmarkFor;
  final Future<bool> Function(String, String?)? accessFile;
  Future<void> _pending = Future.value();
  int _sequence = 0;
  bool _initialized = false;
  RandomAccessFile? _lease;
  final _previous = <WorkspaceRecovery>[];
  static final _heldLeases = <String>{};
  static Future<void> _opening = Future.value();

  /// Each running process owns a separate directory and an OS-held lease.
  static Future<WorkspaceRecovery> open(
    Directory root, {
    Future<String?> Function(String)? bookmarkFor,
    Future<bool> Function(String, String?)? accessFile,
  }) {
    final task = _opening.then(
      (_) => _open(root, bookmarkFor: bookmarkFor, accessFile: accessFile),
    );
    _opening = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  static Future<WorkspaceRecovery> _open(
    Directory root, {
    Future<String?> Function(String)? bookmarkFor,
    Future<bool> Function(String, String?)? accessFile,
  }) async {
    await root.create(recursive: true);
    root = Directory(await root.resolveSymbolicLinks());
    final catalog = await File(
      '${root.path}${Platform.pathSeparator}.catalog',
    ).open(mode: FileMode.append);
    WorkspaceRecovery? current;
    try {
      await catalog.lock(FileLock.blockingExclusive);
      final directory = await root.createTemp('session-');
      current = WorkspaceRecovery(
        directory,
        bookmarkFor: bookmarkFor,
        accessFile: accessFile,
      );
      await current._acquireLease();
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory ||
            entity.path == directory.path ||
            !entity.uri.pathSegments
                .where((part) => part.isNotEmpty)
                .last
                .startsWith('session-')) {
          continue;
        }
        final previous = WorkspaceRecovery(
          entity,
          bookmarkFor: bookmarkFor,
          accessFile: accessFile,
        );
        try {
          await previous._acquireLease();
          current._previous.add(previous);
        } on FileSystemException {
          // A live process keeps its recovery data private to that workspace.
        }
      }
      return current;
    } catch (_) {
      await current?.close();
      rethrow;
    } finally {
      await catalog.close();
    }
  }

  Future<void> _acquireLease() async {
    if (!_heldLeases.add(directory.path)) {
      throw FileSystemException(
        'Recovery workspace is already open',
        directory.path,
      );
    }
    RandomAccessFile? lease;
    try {
      lease = await File(
        '${directory.path}${Platform.pathSeparator}.lease',
      ).open(mode: FileMode.append);
      await lease.lock(FileLock.exclusive);
      _lease = lease;
    } catch (_) {
      _heldLeases.remove(directory.path);
      await lease?.close();
      rethrow;
    }
  }

  Future<void> close() async {
    await _pending;
    for (final previous in _previous) {
      await previous.close();
    }
    final lease = _lease;
    _lease = null;
    if (lease != null) {
      try {
        await lease.unlock();
      } finally {
        _heldLeases.remove(directory.path);
        await lease.close();
      }
    }
  }

  File _slot(int sequence) => File(
    '${directory.path}${Platform.pathSeparator}recovery-${sequence % 2}.json',
  );

  Future<Map<String, dynamic>?> _load() async {
    Map<String, dynamic>? newest;
    var foundFile = false;
    for (var slot = 0; slot < 2; slot++) {
      final file = _slot(slot);
      if (!await file.exists()) continue;
      foundFile = true;
      try {
        final data = jsonDecode(await file.readAsString());
        if (!_validSnapshot(data)) continue;
        final snapshot = data as Map<String, dynamic>;
        if (newest == null ||
            (snapshot['sequence'] as int) > (newest['sequence'] as int)) {
          newest = snapshot;
        }
      } on FormatException {
        // Try the other committed generation.
      } on FileSystemException {
        // A readable generation can still recover an inaccessible slot.
      }
    }
    if (newest == null && foundFile) {
      throw const FormatException('No readable recovery snapshot was found.');
    }
    _sequence = newest?['sequence'] as int? ?? 0;
    _initialized = true;
    return newest;
  }

  bool _validSnapshot(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['sequence'] is! int ||
        (value['sequence'] as int) < 0 ||
        value['activeId'] is! int ||
        value['tabs'] is! List) {
      return false;
    }
    final ids = <int>{};
    for (final entry in value['tabs'] as List) {
      if (entry is! Map<String, dynamic> ||
          entry['id'] is! int ||
          !ids.add(entry['id'] as int) ||
          !DocumentFormat.values.any(
            (format) => format.name == entry['format'],
          ) ||
          entry['bom'] is! bool ||
          (entry['path'] != null && entry['path'] is! String) ||
          entry['path'] == '' ||
          (entry['bookmark'] != null && entry['bookmark'] is! String) ||
          (entry['source'] != null && entry['source'] is! String) ||
          (entry['path'] == null && entry['source'] == null) ||
          (entry['path'] != null &&
              entry['source'] != null &&
              (entry['baseline'] is! String ||
                  entry['baselineBom'] is! bool))) {
        return false;
      }
    }
    return ids.isEmpty || ids.contains(value['activeId']);
  }

  Future<RecoveredWorkspace?> restore({bool restoreCleanFiles = true}) async {
    if (_previous.isEmpty) {
      return _restoreCurrent(restoreCleanFiles: restoreCleanFiles);
    }
    final documents = <RecoveredDocument>[];
    final failedPaths = <String>[];
    final seenPaths = <String>{};
    var activeIndex = 0;
    var recoveredCount = 0;
    for (final store in [..._previous, this]) {
      try {
        final recovered = await store._restoreCurrent(
          restoreCleanFiles: restoreCleanFiles,
        );
        if (recovered == null) continue;
        failedPaths.addAll(recovered.failedPaths);
        for (var index = 0; index < recovered.documents.length; index++) {
          final document = recovered.documents[index];
          final file = document.file;
          if (index == recovered.activeIndex) activeIndex = documents.length;
          final duplicatePath = file != null && !seenPaths.add(file.path);
          final restored = duplicatePath
              ? RecoveredDocument(
                  source: document.source,
                  format: document.format,
                  bom: document.bom,
                )
              : document;
          if (restored.source != (restored.file?.source ?? '')) {
            recoveredCount++;
          }
          documents.add(restored);
        }
      } on Exception {
        failedPaths.add(store.directory.path);
      }
    }
    if (documents.isEmpty && failedPaths.isEmpty) return null;
    return RecoveredWorkspace(
      documents: documents,
      activeIndex: activeIndex,
      recoveredCount: recoveredCount,
      failedPaths: failedPaths,
    );
  }

  Future<RecoveredWorkspace?> _restoreCurrent({
    required bool restoreCleanFiles,
  }) async {
    await _pending;
    final data = await _load();
    if (data == null || (data['tabs'] as List).isEmpty) return null;
    final documents = <RecoveredDocument>[];
    final failedPaths = <String>[];
    var activeIndex = 0;
    var recoveredCount = 0;
    for (final value in data['tabs'] as List) {
      final entry = value as Map<String, dynamic>;
      final source = entry['source'] as String?;
      final path = entry['path'] as String?;
      if (source == null && !restoreCleanFiles) continue;
      LocalJsonFile? file;
      try {
        if (path != null) {
          await accessFile?.call(path, entry['bookmark'] as String?);
          file = source == null
              ? await LocalJsonFile.read(path)
              : LocalJsonFile(
                  path,
                  entry['baseline'] as String,
                  bom: entry['baselineBom'] as bool,
                );
          if (source == null && file.path != path) {
            throw FileChangedException(path);
          }
          if (source != null) {
            final current = await LocalJsonFile.read(path);
            if (current.path == path &&
                current.source == source &&
                current.bom == entry['bom']) {
              file = current;
            }
          }
        }
      } on Exception {
        if (path != null) failedPaths.add(path);
        if (source == null) continue;
      }
      if (entry['id'] == data['activeId']) activeIndex = documents.length;
      if (source != null && source != (file?.source ?? '')) recoveredCount++;
      documents.add(
        RecoveredDocument(
          source: source ?? file!.source,
          format: DocumentFormat.values.firstWhere(
            (format) => format.name == entry['format'],
          ),
          bom: entry['bom'] as bool,
          file: file,
        ),
      );
    }
    return RecoveredWorkspace(
      documents: documents,
      activeIndex: activeIndex,
      recoveredCount: recoveredCount,
      failedPaths: failedPaths,
    );
  }

  /// Passing null commits an empty snapshot, retiring older recovery data.
  Future<void> save(Workspace? workspace) {
    final task = _pending.then((_) => _write(workspace));
    _pending = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<void> _write(Workspace? workspace) async {
    if (!_initialized) {
      try {
        await _load();
      } on FormatException {
        // A new committed generation restarts recovery after unreadable data.
        _initialized = true;
      }
    }
    final tabs = <Map<String, Object?>>[];
    if (workspace != null && workspace.tabs.any((tab) => tab.dirty)) {
      for (final tab in workspace.tabs) {
        final file = tab.file;
        tabs.add({
          'id': tab.id,
          'format': tab.format.name,
          'bom': tab.bom,
          if (file != null) ...{
            'path': file.path,
            'bookmark': await bookmarkFor?.call(file.path),
          },
          if (tab.dirty || file == null) ...{
            'source': tab.text,
            if (file != null) ...{
              'baseline': file.source,
              'baselineBom': file.bom,
            },
          },
        });
      }
    }
    final sequence = _sequence + 1;
    final contents = jsonEncode({
      'version': 1,
      'sequence': sequence,
      'activeId': workspace?.activeId ?? 0,
      'tabs': tabs,
    });
    await directory.create(recursive: true);
    final target = _slot(sequence);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(target.path);
    _sequence = sequence;
    if (tabs.isEmpty) {
      final previous = _slot(sequence + 1);
      if (await previous.exists()) await previous.delete();
    }
    for (final previous in [..._previous]) {
      try {
        await previous.save(null);
        await previous.close();
        _previous.remove(previous);
        await previous.directory.delete(recursive: true);
      } on FileSystemException {
        // The current generation already contains the recovered documents.
      }
    }
  }
}
