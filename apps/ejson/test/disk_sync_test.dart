import 'dart:async';
import 'dart:io';

import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/workspace/disk_sync.dart';
import 'package:ejson/workspace/file_io.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestDiskWriter {
  bool fail = false;
  Completer<void>? gate;
  int writes = 0;

  Future<void> write(String path, Uint8List bytes) async {
    writes++;
    if (fail) throw const FileSystemException('permission denied');
    await gate?.future;
    File(path).writeAsBytesSync(bytes);
  }
}

Future<void> waitForDisk(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (ready()) return;
  }
  expect(ready(), isTrue);
}

Future<T> runDiskOperation<T>(
  WidgetTester tester,
  Future<T> Function() operation,
) async {
  var completed = false;
  T? result;
  Object? failure;
  await Future<void>.sync(() {
    operation().then(
      (value) {
        result = value;
        completed = true;
      },
      onError: (Object error) {
        failure = error;
        completed = true;
      },
    );
  });
  await waitForDisk(tester, () => completed);
  if (failure != null) throw failure!;
  return result as T;
}

void syncTest(
  String name,
  Future<void> Function(WidgetTester, ProviderContainer, File, TestDiskWriter)
  body,
) {
  testWidgets(name, (tester) async {
    final directory = Directory.systemTemp.createTempSync('ejson-sync-');
    final requested = File('${directory.path}/file.json')
      ..writeAsStringSync('0');
    final file = File(requested.resolveSymbolicLinksSync());
    final disk = TestDiskWriter();
    var activeReads = 0;
    var readCount = 0;
    final container = ProviderContainer(
      overrides: [
        diskSyncAvailableProvider.overrideWithValue(true),
        initialWorkspaceProvider.overrideWithValue((
          files: [LocalJsonFile(file.path, '0')],
          activePath: file.path,
        )),
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
        workspaceAtomicWriterProvider.overrideWithValue(disk.write),
        localFileReaderProvider.overrideWithValue((path) async {
          activeReads++;
          readCount++;
          try {
            return await LocalJsonFile.read(path);
          } finally {
            activeReads--;
          }
        }),
      ],
    );
    container.read(diskSyncProvider);
    try {
      await tester.pump();
      await waitForDisk(tester, () => readCount > 0 && activeReads == 0);
      await body(tester, container, file, disk);
    } finally {
      if (disk.gate != null && !disk.gate!.isCompleted) disk.gate!.complete();
      await runDiskOperation(
        tester,
        container.read(diskSyncProvider.notifier).suspend,
      );
      container.dispose();
      directory.deleteSync(recursive: true);
    }
  });
}

void main() {
  syncTest('every format starts syncing after its first disk save', (
    tester,
    container,
    file,
    disk,
  ) async {
    final controller = container.read(workspaceProvider.notifier);
    for (final format in DocumentFormat.values) {
      final target = File(
        '${file.parent.path}${Platform.pathSeparator}new.${format.extension}',
      )..writeAsStringSync('before');
      controller.newTabWithSource('before', format: format);
      final id = container.read(workspaceProvider).activeId;
      controller.markSaved(id, LocalJsonFile(target.path, 'before'));
      controller.editSource(id, 'unfinished<');
      await runDiskOperation(
        tester,
        () => container.read(diskSyncProvider.notifier).check(id, write: true),
      );
      expect(target.readAsStringSync(), 'unfinished<');
      expect(container.read(workspaceProvider).active.format, format);
      expect(container.read(workspaceProvider).active.dirty, isFalse);
    }
  });

  syncTest('named files save incomplete syntax after 500 ms', (
    tester,
    container,
    file,
    disk,
  ) async {
    container.read(workspaceProvider.notifier).editSource(1, '{"unfinished":');
    await tester.pump(const Duration(milliseconds: 499));
    expect(disk.writes, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await waitForDisk(
      tester,
      () => !container.read(workspaceProvider).active.dirty,
    );
    expect(file.readAsStringSync(), '{"unfinished":');
    expect(disk.writes, 1);
    expect(container.read(diskSyncProvider)[1]!.status, DiskSyncStatus.saved);
  });

  syncTest('external content automatically reloads and clears stale undo', (
    tester,
    container,
    file,
    disk,
  ) async {
    final controller = container.read(workspaceProvider.notifier);
    controller.editSource(1, '1');
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1, write: true),
    );
    expect(controller.canUndo(1), isTrue);
    file.writeAsStringSync('2');
    await tester.pump(const Duration(seconds: 1));
    await waitForDisk(
      tester,
      () => container.read(workspaceProvider).active.text == '2',
    );
    expect(container.read(workspaceProvider).active.dirty, isFalse);
    expect(controller.canUndo(1), isFalse);
    expect(disk.writes, 1);
  });

  syncTest('same-size replacement and BOM-only changes synchronize', (
    tester,
    container,
    file,
    disk,
  ) async {
    final replacement = File('${file.path}.replacement')
      ..writeAsStringSync('1');
    replacement.renameSync(file.path);
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1),
    );
    expect(container.read(workspaceProvider).active.text, '1');
    file.writeAsStringSync('\uFEFF1');
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1),
    );
    expect(container.read(workspaceProvider).active.bom, isTrue);
    container.read(workspaceProvider.notifier).editSource(1, '2');
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1, write: true),
    );
    expect(file.readAsBytesSync().take(3), [0xef, 0xbb, 0xbf]);
  });

  syncTest('concurrent edits pause synchronization until the user reloads', (
    tester,
    container,
    file,
    disk,
  ) async {
    container.read(workspaceProvider.notifier).editSource(1, '1');
    file.writeAsStringSync('2');
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1, write: true),
    );
    expect(
      container.read(diskSyncProvider)[1]!.status,
      DiskSyncStatus.conflict,
    );
    expect(container.read(workspaceProvider).active.text, '1');
    expect(file.readAsStringSync(), '2');
    container.read(workspaceProvider.notifier).editSource(1, '3');
    await tester.pump(const Duration(seconds: 2));
    await waitForDisk(
      tester,
      () =>
          container.read(diskSyncProvider)[1]?.status ==
          DiskSyncStatus.conflict,
    );
    expect(disk.writes, 0);
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1, reload: true),
    );
    expect(container.read(workspaceProvider).active.text, '2');
    expect(container.read(workspaceProvider).active.dirty, isFalse);
  });

  syncTest('confirmed local overwrite rejects a newer external version', (
    tester,
    container,
    file,
    disk,
  ) async {
    final sync = container.read(diskSyncProvider.notifier);
    container.read(workspaceProvider.notifier).editSource(1, '1');
    file.writeAsStringSync('2');
    await runDiskOperation(tester, () => sync.check(1));
    final expected = container.read(diskSyncProvider)[1]!.external!;
    file.writeAsStringSync('3');
    expect(
      await runDiskOperation(tester, () => sync.overwrite(1, expected)),
      isFalse,
    );
    expect(file.readAsStringSync(), '3');
    await runDiskOperation(tester, () => sync.check(1));
    final latest = container.read(diskSyncProvider)[1]!.external!;
    expect(
      await runDiskOperation(tester, () => sync.overwrite(1, latest)),
      isTrue,
    );
    expect(file.readAsStringSync(), '1');
    expect(container.read(workspaceProvider).active.dirty, isFalse);
  });

  syncTest('deleted files retain edits and synchronize after recreation', (
    tester,
    container,
    file,
    disk,
  ) async {
    container.read(workspaceProvider.notifier).editSource(1, '1');
    file.deleteSync();
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1),
    );
    expect(
      container.read(diskSyncProvider)[1]!.status,
      DiskSyncStatus.unavailable,
    );
    expect(container.read(workspaceProvider).active.text, '1');
    expect(file.existsSync(), isFalse);
    file.writeAsStringSync('0');
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await waitForDisk(
      tester,
      () => !container.read(workspaceProvider).active.dirty,
    );
    expect(file.readAsStringSync(), '1');
  });

  syncTest('write failure can retry without losing edits', (
    tester,
    container,
    file,
    disk,
  ) async {
    disk.fail = true;
    container.read(workspaceProvider.notifier).editSource(1, '1');
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1, write: true),
    );
    expect(container.read(diskSyncProvider)[1]!.status, DiskSyncStatus.failed);
    expect(container.read(workspaceProvider).active.dirty, isTrue);
    disk.fail = false;
    await runDiskOperation(
      tester,
      () => container.read(diskSyncProvider.notifier).check(1, write: true),
    );
    expect(file.readAsStringSync(), '1');
    expect(container.read(workspaceProvider).active.dirty, isFalse);
  });

  syncTest('edits during a write receive a subsequent save', (
    tester,
    container,
    file,
    disk,
  ) async {
    final gate = Completer<void>();
    disk.gate = gate;
    container.read(workspaceProvider.notifier).editSource(1, '1');
    await tester.pump(const Duration(milliseconds: 500));
    await waitForDisk(tester, () => disk.writes == 1);
    container.read(workspaceProvider.notifier).editSource(1, '2');
    gate.complete();
    disk.gate = null;
    await waitForDisk(tester, () => file.readAsStringSync() == '1');
    expect(container.read(workspaceProvider).active.dirty, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    await waitForDisk(
      tester,
      () => !container.read(workspaceProvider).active.dirty,
    );
    expect(file.readAsStringSync(), '2');
    expect(disk.writes, 2);
  });

  syncTest('unnamed documents remain drafts and disabling sync stops writes', (
    tester,
    container,
    file,
    disk,
  ) async {
    final controller = container.read(workspaceProvider.notifier);
    controller.newTabWithSource('{"draft":');
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(workspaceProvider).active.file, isNull);
    expect(disk.writes, 0);
    await container
        .read(toolPreferencesProvider.notifier)
        .setSyncDiskFiles(false);
    controller.editSource(1, '1');
    await tester.pump(const Duration(seconds: 1));
    expect(file.readAsStringSync(), '0');
    expect(container.read(diskSyncProvider), isEmpty);
    await container
        .read(toolPreferencesProvider.notifier)
        .setSyncDiskFiles(true);
    await tester.pump(const Duration(milliseconds: 500));
    await waitForDisk(tester, () => file.readAsStringSync() == '1');
  });

  syncTest('suspending for close prevents a delayed write', (
    tester,
    container,
    file,
    disk,
  ) async {
    container.read(workspaceProvider.notifier).editSource(1, '1');
    final sync = container.read(diskSyncProvider.notifier);
    await runDiskOperation(tester, sync.suspend);
    await tester.pump(const Duration(seconds: 1));
    expect(disk.writes, 0);
    sync.resume();
    await tester.pump(const Duration(milliseconds: 500));
    await waitForDisk(tester, () => file.readAsStringSync() == '1');
  });
}
