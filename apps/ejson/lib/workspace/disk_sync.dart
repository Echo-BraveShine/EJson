import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/tool_preferences.dart';
import 'file_io.dart';
import 'local_files.dart';
import 'workspace.dart';

final diskSyncAvailableProvider = Provider<bool>((ref) => false);

enum DiskSyncStatus { waiting, saving, saved, conflict, unavailable, failed }

class DiskSyncState {
  const DiskSyncState(this.status, {this.external, this.error});
  final DiskSyncStatus status;
  final LocalJsonFile? external;
  final Object? error;
}

final diskSyncProvider =
    NotifierProvider<DiskSyncController, Map<int, DiskSyncState>>(
      DiskSyncController.new,
    );

class DiskSyncController extends Notifier<Map<int, DiskSyncState>> {
  final _writes = <int, Timer>{};
  final _checking = <int, int>{};
  final _observed = <int, (String, int, DateTime, DateTime)>{};
  Timer? _poll;
  bool _suspended = false;

  bool get _enabled =>
      !_suspended &&
      ref.read(diskSyncAvailableProvider) &&
      ref.read(toolPreferencesProvider).syncDiskFiles;

  @override
  Map<int, DiskSyncState> build() {
    ref.onDispose(_cancel);
    ref.listen(workspaceProvider, (previous, next) {
      if (_enabled) _updateFiles(previous, next);
    });
    ref.listen(
      toolPreferencesProvider.select((value) => value.syncDiskFiles),
      (previous, next) => _configure(),
    );
    scheduleMicrotask(() {
      if (ref.mounted) _configure();
    });
    return const {};
  }

  void _configure() {
    _cancel();
    if (!_enabled) {
      state = const {};
      return;
    }
    _updateFiles(null, ref.read(workspaceProvider));
    // Metadata checks stay cheap, with full-content verification every ten ticks.
    _poll = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => checkAll(metadataOnly: timer.tick % 10 != 0),
    );
    checkAll();
  }

  void _cancel() {
    _poll?.cancel();
    _poll = null;
    for (final timer in _writes.values) {
      timer.cancel();
    }
    _writes.clear();
    _observed.clear();
  }

  void _set(int id, DiskSyncState value) {
    if (!ref.mounted ||
        !_enabled ||
        ref.read(workspaceProvider).tab(id)?.file == null) {
      return;
    }
    if (value.status == DiskSyncStatus.saved &&
        state[id]?.status == DiskSyncStatus.saved) {
      return;
    }
    state = {...state, id: value};
  }

  void _updateFiles(Workspace? previous, Workspace next) {
    final ids = next.tabs
        .where((tab) => tab.file != null)
        .map((tab) => tab.id)
        .toSet();
    _observed.removeWhere((id, _) => !ids.contains(id));
    for (final id in _writes.keys.toList()) {
      if (!ids.contains(id)) _writes.remove(id)?.cancel();
    }
    if (state.keys.any((id) => !ids.contains(id))) {
      state = {
        for (final entry in state.entries)
          if (ids.contains(entry.key)) entry.key: entry.value,
      };
    }
    for (final tab in next.tabs) {
      if (tab.file == null) continue;
      final before = previous?.tab(tab.id);
      if (before?.text == tab.text && before?.file == tab.file) continue;
      if (!tab.dirty) {
        _writes.remove(tab.id)?.cancel();
        _set(tab.id, const DiskSyncState(DiskSyncStatus.saved));
      } else if (before?.file?.path != tab.file!.path ||
          state[tab.id]?.status != DiskSyncStatus.conflict &&
              state[tab.id]?.status != DiskSyncStatus.unavailable) {
        _scheduleWrite(tab.id);
      }
    }
  }

  void _scheduleWrite(int id) {
    if (!_enabled) return;
    _writes.remove(id)?.cancel();
    _set(id, const DiskSyncState(DiskSyncStatus.waiting));
    _writes[id] = Timer(const Duration(milliseconds: 500), () {
      _writes.remove(id);
      unawaited(check(id, write: true));
    });
  }

  void checkAll({bool metadataOnly = false}) {
    if (!_enabled) return;
    for (final tab in ref.read(workspaceProvider).tabs) {
      if (tab.file != null && !_checking.containsKey(tab.id)) {
        unawaited(check(tab.id, metadataOnly: metadataOnly));
      }
    }
  }

  Future<bool> check(
    int id, {
    bool write = false,
    bool reload = false,
    bool metadataOnly = false,
  }) {
    if (!ref.mounted || !_enabled) return Future.value(false);
    _checking[id] = (_checking[id] ?? 0) + 1;
    return ref
        .read(fileOperationQueueProvider)
        .run(() async {
          if (!ref.mounted || !_enabled) return false;
          final tab = ref.read(workspaceProvider).tab(id);
          final baseline = tab?.file;
          if (tab == null || baseline == null) return false;
          try {
            final stat = await File(baseline.path).stat();
            final observed = (
              baseline.path,
              stat.size,
              stat.modified,
              stat.changed,
            );
            if (metadataOnly && _observed[id] == observed) return true;
            final disk = await ref.read(localFileReaderProvider)(baseline.path);
            if (!ref.mounted || !_enabled) return false;
            final current = ref.read(workspaceProvider).tab(id);
            if (current == null || current.file != baseline) return false;
            _observed[id] = observed;
            if (disk.path != baseline.path) {
              throw FileChangedException(baseline.path);
            }
            final controller = ref.read(workspaceProvider.notifier);
            if (reload) {
              controller.reloadFromDisk(id, disk);
              _set(id, const DiskSyncState(DiskSyncStatus.saved));
              return true;
            }
            final changed =
                disk.source != baseline.source || disk.bom != baseline.bom;
            if (changed) {
              if (current.text == disk.source || !current.dirty) {
                if (current.text == disk.source) {
                  controller.markSaved(id, disk);
                } else {
                  controller.reloadFromDisk(id, disk);
                }
                _set(id, const DiskSyncState(DiskSyncStatus.saved));
                return true;
              }
              _writes.remove(id)?.cancel();
              _set(id, DiskSyncState(DiskSyncStatus.conflict, external: disk));
              return false;
            }
            if (!current.dirty) {
              _set(id, const DiskSyncState(DiskSyncStatus.saved));
              return true;
            }
            if (!write) {
              final status = state[id]?.status;
              if (status == DiskSyncStatus.failed ||
                  status == DiskSyncStatus.unavailable ||
                  status == DiskSyncStatus.conflict) {
                _scheduleWrite(id);
              }
              return true;
            }
            _set(id, const DiskSyncState(DiskSyncStatus.saving));
            final saved = await baseline.save(
              current.text,
              writeAtomically: ref.read(workspaceAtomicWriterProvider),
            );
            if (!ref.mounted) return true;
            final latest = ref.read(workspaceProvider).tab(id);
            if (latest?.file != baseline) return true;
            controller.markSaved(id, saved);
            if (ref.read(workspaceProvider).tab(id)?.dirty == true) {
              _scheduleWrite(id);
            } else {
              _set(id, const DiskSyncState(DiskSyncStatus.saved));
            }
            return true;
          } on FileChangedException catch (error) {
            _observed.remove(id);
            _set(id, DiskSyncState(DiskSyncStatus.conflict, error: error));
            return false;
          } on Exception catch (error) {
            _observed.remove(id);
            _set(
              id,
              DiskSyncState(
                write ? DiskSyncStatus.failed : DiskSyncStatus.unavailable,
                error: error,
              ),
            );
            return false;
          }
        })
        .whenComplete(() {
          final pending = (_checking[id] ?? 1) - 1;
          if (pending == 0) {
            _checking.remove(id);
          } else {
            _checking[id] = pending;
          }
        });
  }

  Future<bool> overwrite(int id, LocalJsonFile expected) =>
      ref.read(fileOperationQueueProvider).run(() async {
        if (!ref.mounted || !_enabled) return false;
        final tab = ref.read(workspaceProvider).tab(id);
        if (tab?.file?.path != expected.path) return false;
        try {
          _set(id, const DiskSyncState(DiskSyncStatus.saving));
          final saved = await expected.save(
            tab!.text,
            outputBom: tab.bom,
            writeAtomically: ref.read(workspaceAtomicWriterProvider),
          );
          if (ref.mounted &&
              ref.read(workspaceProvider).tab(id)?.file == tab.file) {
            ref.read(workspaceProvider.notifier).markSaved(id, saved);
            if (ref.read(workspaceProvider).tab(id)?.dirty == true) {
              _scheduleWrite(id);
            }
          }
          return true;
        } on FileChangedException catch (error) {
          _set(id, DiskSyncState(DiskSyncStatus.conflict, error: error));
          return false;
        } on Exception catch (error) {
          _set(id, DiskSyncState(DiskSyncStatus.failed, error: error));
          return false;
        }
      });

  Future<void> suspend() async {
    _suspended = true;
    _cancel();
    await ref.read(fileOperationQueueProvider).run(() async {});
  }

  void resume() {
    _suspended = false;
    _configure();
  }
}
