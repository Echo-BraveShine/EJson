import 'dart:io';

import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/disk_sync.dart';
import 'package:ejson/workspace/file_io.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'disk_sync_test.dart' show runDiskOperation, waitForDisk;

void main() {
  testWidgets('conflict actions work at the minimum window size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 460));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final directory = Directory.systemTemp.createTempSync('ejson-sync-ui-');
    final requested = File('${directory.path}/file.json')
      ..writeAsStringSync('0');
    final file = File(requested.resolveSymbolicLinksSync());
    final container = ProviderContainer(
      overrides: [
        installedFontsProvider.overrideWith((ref) async => []),
        diskSyncAvailableProvider.overrideWithValue(true),
        initialWorkspaceProvider.overrideWithValue((
          files: [LocalJsonFile(file.path, '0')],
          activePath: file.path,
        )),
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
        workspaceAtomicWriterProvider.overrideWithValue((path, bytes) async {
          File(path).writeAsBytesSync(bytes);
        }),
      ],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(initialLanguage: 'en'),
        ),
      );
      await tester.pumpAndSettle();
      final sync = container.read(diskSyncProvider.notifier);
      await runDiskOperation(tester, () => sync.check(1));
      container.read(workspaceProvider.notifier).editSource(1, '1');
      file.writeAsStringSync('2');
      await runDiskOperation(tester, () => sync.check(1));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, '1');
      expect(file.readAsStringSync(), '2');
      expect(container.read(workspaceProvider).active.file!.source, '0');
      expect(
        container.read(diskSyncProvider)[1]!.status,
        DiskSyncStatus.conflict,
      );
      expect(find.text('Load disk version'), findsOneWidget);
      expect(find.text('Keep local edits'), findsOneWidget);
      await tester.tap(find.text('Compare versions'));
      await tester.pumpAndSettle();
      expect(find.text('Current edits'), findsOneWidget);
      expect(find.text('Disk version'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load disk version'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, '1');
      await tester.tap(find.text('Keep local edits'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await waitForDisk(
        tester,
        () => !container.read(workspaceProvider).active.dirty,
      );
      await tester.pumpAndSettle();
      expect(file.readAsStringSync(), '1');
      expect(find.text('Load disk version'), findsNothing);
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      editor.controller!.selection = const CodeLineSelection.collapsed(
        index: 0,
        offset: 1,
      );
      file.writeAsStringSync('12345');
      await runDiskOperation(tester, () => sync.check(1));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, '12345');
      expect(editor.controller!.selection.extentOffset, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await runDiskOperation(
        tester,
        container.read(diskSyncProvider.notifier).suspend,
      );
      container.dispose();
      directory.deleteSync(recursive: true);
    }
  });
}
