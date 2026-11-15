import 'dart:async';
import 'dart:io';

import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson/workspace/workspace_autosave.dart';
import 'package:ejson/workspace/workspace_recovery.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingRecovery extends WorkspaceRecovery {
  RecordingRecovery() : super(Directory.systemTemp);
  final snapshots = <Workspace?>[];
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<void> save(Workspace? workspace) async {
    snapshots.add(workspace);
    if (fail) throw const FileSystemException('unavailable');
    await gate?.future;
  }
}

void main() {
  ProviderContainer mount(RecordingRecovery recovery) {
    final container = ProviderContainer(
      overrides: [
        workspaceRecoveryProvider.overrideWithValue(recovery),
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(workspaceAutosaveProvider);
    return container;
  }

  testWidgets('editing auto-saves after two idle seconds', (tester) async {
    final recovery = RecordingRecovery();
    final container = mount(recovery);
    await tester.pump();
    container.read(workspaceProvider.notifier).editSource(1, '1');
    await tester.pump(const Duration(milliseconds: 1999));
    expect(recovery.snapshots, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(recovery.snapshots.single!.active.text, '1');
    expect(container.read(workspaceAutosaveProvider), AutosaveStatus.saved);
    expect(container.read(workspaceProvider).active.dirty, isTrue);
  });

  testWidgets('continuous editing checkpoints within ten seconds', (
    tester,
  ) async {
    final recovery = RecordingRecovery();
    final container = mount(recovery);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      container.read(workspaceProvider.notifier).editSource(1, '$i');
      await tester.pump(const Duration(seconds: 1));
    }
    expect(recovery.snapshots, hasLength(1));
    expect(recovery.snapshots.single!.active.text, '9');
  });

  testWidgets('failed auto-save retries and keeps latest edits', (
    tester,
  ) async {
    final recovery = RecordingRecovery()..fail = true;
    final container = mount(recovery);
    await tester.pump();
    container.read(workspaceProvider.notifier).editSource(1, '1');
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(workspaceAutosaveProvider), AutosaveStatus.failed);
    recovery.fail = false;
    await tester.pump(const Duration(seconds: 10));
    expect(container.read(workspaceAutosaveProvider), AutosaveStatus.saved);
    expect(recovery.snapshots, hasLength(2));
  });

  testWidgets('overlapping writes serialize and retain edits during a save', (
    tester,
  ) async {
    final recovery = RecordingRecovery()..gate = Completer<void>();
    final container = mount(recovery);
    await tester.pump();
    final controller = container.read(workspaceProvider.notifier);
    controller.editSource(1, '1');
    await tester.pump(const Duration(seconds: 2));
    controller.editSource(1, '2');
    await tester.pump(const Duration(seconds: 2));
    expect(recovery.snapshots, hasLength(1));
    recovery.gate!.complete();
    await tester.pump();
    expect(recovery.snapshots.map((model) => model!.active.text), ['1', '2']);
    expect(container.read(workspaceAutosaveProvider), AutosaveStatus.saved);
  });

  testWidgets('disabling auto-save clears drafts and persists the preference', (
    tester,
  ) async {
    final recovery = RecordingRecovery();
    final container = mount(recovery);
    await tester.pump();
    container.read(workspaceProvider.notifier).editSource(1, '1');
    await tester.pump(const Duration(seconds: 2));
    await container.read(toolPreferencesProvider.notifier).setAutosave(false);
    await tester.pump();
    expect(recovery.snapshots.last, isNull);
    expect(container.read(workspaceAutosaveProvider), AutosaveStatus.disabled);
    container.read(workspaceProvider.notifier).editSource(1, '2');
    final count = recovery.snapshots.length;
    await tester.pump(const Duration(seconds: 20));
    expect(recovery.snapshots, hasLength(count));
  });

  testWidgets('clean exit retires drafts and ignores later lifecycle flushes', (
    tester,
  ) async {
    final recovery = RecordingRecovery();
    final container = mount(recovery);
    await tester.pump();
    container.read(workspaceProvider.notifier).editSource(1, '1');
    await tester.pump(const Duration(seconds: 2));
    final autosave = container.read(workspaceAutosaveProvider.notifier);
    expect(await autosave.finish(), isTrue);
    expect(await autosave.flush(), isTrue);
    await tester.pump(const Duration(seconds: 20));
    expect(recovery.snapshots.last, isNull);
    expect(recovery.snapshots, hasLength(2));
    autosave.resume();
    await tester.pump(const Duration(seconds: 2));
    expect(recovery.snapshots.last!.active.text, '1');
  });
}
