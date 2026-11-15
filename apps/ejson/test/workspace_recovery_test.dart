import 'dart:convert';
import 'dart:io';

import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson/workspace/workspace_recovery.dart';
import 'package:ejson/workspace/workspace_autosave.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceTab recoveryTab(
  int id,
  String text, {
  LocalJsonFile? file,
  DocumentFormat format = DocumentFormat.json,
  bool bom = false,
}) => WorkspaceTab(
  id,
  JsonDocument(SourceBuffer(text)),
  file: file,
  format: format,
  draftBom: bom,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late Directory snapshots;
  late WorkspaceRecovery recovery;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ejson-recovery-');
    snapshots = Directory('${temp.path}/Recovery');
    recovery = WorkspaceRecovery(snapshots);
  });
  tearDown(() => temp.delete(recursive: true));

  Future<LocalJsonFile> makeFile(String name, String source) async {
    final file = File('${temp.path}/$name');
    await file.writeAsString(source);
    return LocalJsonFile.read(file.path);
  }

  test('recovers content, formats, BOM, tab order and active draft', () async {
    final edited = await makeFile('edited.json', '{"id":1}');
    final clean = await makeFile('clean.yaml', 'id: 1');
    final workspace = Workspace([
      recoveryTab(4, '{"id":2', file: edited),
      recoveryTab(9, '<unfinished', format: DocumentFormat.xml, bom: true),
      recoveryTab(12, clean.source, file: clean, format: DocumentFormat.yaml),
    ], 9);
    await recovery.save(workspace);
    await File(clean.path).writeAsString('id: 3');
    final restored = (await WorkspaceRecovery(snapshots).restore())!;
    expect(restored.documents.map((document) => document.source), [
      '{"id":2',
      '<unfinished',
      'id: 3',
    ]);
    expect(restored.documents[1].format, DocumentFormat.xml);
    expect(restored.documents[1].bom, isTrue);
    expect(restored.documents[0].file!.source, edited.source);
    expect(restored.activeIndex, 1);
    expect(restored.recoveredCount, 2);
    expect(await File(edited.path).readAsString(), edited.source);

    final container = ProviderContainer(
      overrides: [
        initialRecoveredWorkspaceProvider.overrideWithValue(restored),
      ],
    );
    addTearDown(container.dispose);
    final model = container.read(workspaceProvider);
    expect(model.tabs.map((tab) => tab.dirty), [true, true, false]);
    expect(model.active.format, DocumentFormat.xml);
    expect(model.active.bom, isTrue);
  });

  test(
    'newest corrupted snapshot falls back to previous committed data',
    () async {
      await recovery.save(Workspace([recoveryTab(1, 'old')], 1));
      await recovery.save(Workspace([recoveryTab(1, 'new')], 1));
      await File(
        '${snapshots.path}/recovery-0.json',
      ).writeAsString('{truncated');
      await File(
        '${snapshots.path}/recovery-1.json.tmp',
      ).writeAsString('partial');
      final restored = (await WorkspaceRecovery(snapshots).restore())!;
      expect(restored.documents.single.source, 'old');
    },
  );

  test('clean saves and explicit discard retire older drafts', () async {
    await recovery.save(Workspace([recoveryTab(1, 'old')], 1));
    await recovery.save(Workspace([recoveryTab(1, 'new')], 1));
    await recovery.save(null);
    expect(await WorkspaceRecovery(snapshots).restore(), isNull);
    expect(await File('${snapshots.path}/recovery-0.json').exists(), isFalse);
    final file = await makeFile('saved.csv', 'id\r\n001');
    await recovery.save(Workspace([recoveryTab(2, 'draft')], 2));
    await recovery.save(
      Workspace([recoveryTab(3, file.source, file: file)], 3),
    );
    expect(await WorkspaceRecovery(snapshots).restore(), isNull);
  });

  test('concurrent saves commit in invocation order', () async {
    await Future.wait([
      recovery.save(Workspace([recoveryTab(1, 'first')], 1)),
      recovery.save(Workspace([recoveryTab(1, 'second')], 1)),
      recovery.save(Workspace([recoveryTab(1, 'last')], 1)),
    ]);
    final restored = (await WorkspaceRecovery(snapshots).restore())!;
    expect(restored.documents.single.source, 'last');
  });

  test(
    'external changes preserve the original save conflict baseline',
    () async {
      final file = await makeFile('edited.json', '{"value":1}');
      await recovery.save(
        Workspace([recoveryTab(1, '{"value":2}', file: file)], 1),
      );
      await File(file.path).writeAsString('{"value":3}');
      final restored = (await recovery.restore())!.documents.single;
      expect(restored.file!.source, '{"value":1}');
      await expectLater(
        restored.file!.save(restored.source),
        throwsA(isA<FileChangedException>()),
      );
      expect(await File(file.path).readAsString(), '{"value":3}');
    },
  );

  test('a completed manual save is recognized after a crash', () async {
    final file = await makeFile('edited.json', '1');
    await recovery.save(Workspace([recoveryTab(1, '2', file: file)], 1));
    await File(file.path).writeAsString('2');
    final restored = (await recovery.restore())!;
    expect(restored.documents.single.file!.source, '2');
    expect(restored.recoveredCount, 0);
  });

  test('deleted originals retain their edited recovery contents', () async {
    final edited = await makeFile('edited.toml', 'id = 1');
    final clean = await makeFile('clean.json', '{}');
    await recovery.save(
      Workspace([
        recoveryTab(1, 'id = 2', file: edited, format: DocumentFormat.toml),
        recoveryTab(2, clean.source, file: clean),
      ], 1),
    );
    await File(edited.path).delete();
    await File(clean.path).delete();
    final restored = (await recovery.restore())!;
    expect(restored.documents, hasLength(1));
    expect(restored.documents.single.source, 'id = 2');
    expect(restored.failedPaths, [edited.path, clean.path]);
  });

  test('recovery works independently of normal workspace restore', () async {
    final clean = await makeFile('clean.json', '{}');
    await recovery.save(
      Workspace([
        recoveryTab(1, clean.source, file: clean),
        recoveryTab(2, 'draft', format: DocumentFormat.yaml),
      ], 2),
    );
    final restored = (await recovery.restore(restoreCleanFiles: false))!;
    expect(restored.documents, hasLength(1));
    expect(restored.documents.single.source, 'draft');
    expect(restored.activeIndex, 0);
  });

  test(
    'unreadable snapshots report failure and allow future auto-saves',
    () async {
      await snapshots.create();
      await File('${snapshots.path}/recovery-0.json').writeAsString('{');
      await File('${snapshots.path}/recovery-1.json').writeAsString('null');
      await expectLater(recovery.restore(), throwsFormatException);
      await recovery.save(Workspace([recoveryTab(1, 'repaired')], 1));
      expect((await recovery.restore())!.documents.single.source, 'repaired');
    },
  );

  test('invalid schema falls back to the prior snapshot', () async {
    await recovery.save(Workspace([recoveryTab(1, 'valid')], 1));
    await File('${snapshots.path}/recovery-0.json').writeAsString(
      jsonEncode({
        'version': 1,
        'sequence': 99,
        'activeId': 2,
        'tabs': [
          {'id': 2, 'format': 'unknown', 'bom': false, 'source': 'bad'},
        ],
      }),
    );
    expect((await recovery.restore())!.documents.single.source, 'valid');
  });

  test('auto-save preferences default on and round trip older settings', () {
    expect(
      ToolPreferences.fromJson({
        'queries': ['x'],
      }).autosave,
      isTrue,
    );
    final saved = const ToolPreferences().copyWith(autosave: false);
    expect(ToolPreferences.fromJson(saved.toJson()).autosave, isFalse);
  });

  test('running workspaces keep separate recovery data', () async {
    final stores = await Future.wait([
      WorkspaceRecovery.open(snapshots),
      WorkspaceRecovery.open(snapshots),
    ]);
    final first = stores[0];
    final second = stores[1];
    try {
      await first.save(Workspace([recoveryTab(1, 'first')], 1));
      await second.save(Workspace([recoveryTab(1, 'second')], 1));
      expect(await second.restore(), isNotNull);
      expect((await second.restore())!.documents.single.source, 'second');
      expect((await first.restore())!.documents.single.source, 'first');
    } finally {
      await first.close();
      await second.close();
    }
  });

  test(
    'restart merges crashed workspaces and retires them after commit',
    () async {
      final first = await WorkspaceRecovery.open(snapshots);
      final second = await WorkspaceRecovery.open(snapshots);
      await first.save(Workspace([recoveryTab(1, 'first')], 1));
      await second.save(Workspace([recoveryTab(1, 'second')], 1));
      await first.close();
      await second.close();
      final restarted = await WorkspaceRecovery.open(snapshots);
      final restored = (await restarted.restore())!;
      expect(restored.documents.map((document) => document.source).toSet(), {
        'first',
        'second',
      });
      await restarted.save(
        Workspace([
          for (var index = 0; index < restored.documents.length; index++)
            recoveryTab(index + 1, restored.documents[index].source),
        ], 1),
      );
      await restarted.close();
      final next = await WorkspaceRecovery.open(snapshots);
      try {
        final recoveredAgain = (await next.restore())!;
        expect(recoveredAgain.documents, hasLength(2));
      } finally {
        await next.close();
      }
    },
  );

  testWidgets('a restarted app restores its recovery draft', (tester) async {
    final first = ProviderContainer(
      overrides: [
        installedFontsProvider.overrideWith((ref) async => []),
        workspaceRecoveryProvider.overrideWithValue(recovery),
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: first,
        child: const EJsonApp(initialLanguage: 'en'),
      ),
    );
    await tester.pumpAndSettle();
    first.read(workspaceProvider.notifier).editSource(1, '{"unfinished":');
    await tester.runAsync(
      () => first.read(workspaceAutosaveProvider.notifier).flush(),
    );
    expect(first.read(workspaceProvider).active.dirty, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();
    final restored = (await tester.runAsync(() => recovery.restore()))!;
    final second = ProviderContainer(
      overrides: [
        installedFontsProvider.overrideWith((ref) async => []),
        workspaceRecoveryProvider.overrideWithValue(recovery),
        initialRecoveredWorkspaceProvider.overrideWithValue(restored),
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: second,
        child: const EJsonApp(initialLanguage: 'en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(second.read(workspaceProvider).active.text, '{"unfinished":');
    expect(second.read(workspaceProvider).active.dirty, isTrue);
    expect(
      find.text('Recovered unsaved changes in 1 document.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    second.dispose();
  });
}
