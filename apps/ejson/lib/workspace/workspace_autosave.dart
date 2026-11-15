import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/tool_preferences.dart';
import 'workspace.dart';
import 'workspace_recovery.dart';

final workspaceRecoveryProvider = Provider<WorkspaceRecovery?>((ref) => null);

enum AutosaveStatus { disabled, waiting, saving, saved, failed }

final workspaceAutosaveProvider =
    NotifierProvider<WorkspaceAutosaveController, AutosaveStatus>(
      WorkspaceAutosaveController.new,
    );

class WorkspaceAutosaveController extends Notifier<AutosaveStatus> {
  Timer? _idle;
  Timer? _deadline;
  Timer? _retry;
  Future<void> _pending = Future.value();
  bool _stopped = false;

  @override
  AutosaveStatus build() {
    ref.onDispose(_cancelTimers);
    ref.listen(workspaceProvider, (previous, next) {
      if (previous == null || !_sameWorkspace(previous, next)) _schedule();
    });
    ref.listen(toolPreferencesProvider.select((value) => value.autosave), (
      previous,
      next,
    ) {
      if (next) {
        _schedule();
      } else {
        unawaited(flush());
      }
    });
    scheduleMicrotask(() {
      if (ref.mounted) _schedule();
    });
    return AutosaveStatus.disabled;
  }

  bool _sameWorkspace(Workspace previous, Workspace next) {
    if (previous.activeId != next.activeId ||
        previous.tabs.length != next.tabs.length) {
      return false;
    }
    for (var index = 0; index < previous.tabs.length; index++) {
      final before = previous.tabs[index];
      final after = next.tabs[index];
      if (before.id != after.id ||
          before.file != after.file ||
          before.text != after.text ||
          before.format != after.format ||
          before.bom != after.bom) {
        return false;
      }
    }
    return true;
  }

  void _schedule() {
    if (_stopped || ref.read(workspaceRecoveryProvider) == null) return;
    if (!ref.read(toolPreferencesProvider).autosave) {
      state = AutosaveStatus.disabled;
      return;
    }
    _idle?.cancel();
    _retry?.cancel();
    state = AutosaveStatus.waiting;
    _idle = Timer(const Duration(seconds: 2), () => unawaited(flush()));
    _deadline ??= Timer(const Duration(seconds: 10), () => unawaited(flush()));
  }

  void _cancelTimers() {
    _idle?.cancel();
    _deadline?.cancel();
    _retry?.cancel();
    _idle = null;
    _deadline = null;
    _retry = null;
  }

  Future<bool> flush({bool discard = false}) {
    _cancelTimers();
    final task = _pending.then((_) async {
      if (!ref.mounted) return false;
      if (_stopped && !discard) return true;
      _cancelTimers();
      final recovery = ref.read(workspaceRecoveryProvider);
      if (recovery == null) return true;
      final enabled = ref.read(toolPreferencesProvider).autosave;
      final snapshot = discard || !enabled ? null : ref.read(workspaceProvider);
      state = AutosaveStatus.saving;
      try {
        await recovery.save(snapshot);
        if (ref.mounted) {
          if (!_stopped &&
              (enabled != ref.read(toolPreferencesProvider).autosave ||
                  snapshot != null &&
                      !_sameWorkspace(snapshot, ref.read(workspaceProvider)))) {
            _schedule();
          } else {
            state = enabled ? AutosaveStatus.saved : AutosaveStatus.disabled;
          }
        }
        return true;
      } on Exception {
        if (ref.mounted) {
          state = AutosaveStatus.failed;
          if (!_stopped) {
            _retry = Timer(
              const Duration(seconds: 10),
              () => unawaited(flush()),
            );
          }
        }
        return false;
      }
    });
    _pending = task.then((_) {});
    return task;
  }

  Future<bool> finish() async {
    _stopped = true;
    final saved = await flush(discard: true);
    if (!saved) resume();
    return saved;
  }

  void resume() {
    _stopped = false;
    _schedule();
  }
}
