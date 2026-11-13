import 'dart:convert';
import 'dart:io';

import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson/workspace/workspace_session.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences extends Fake implements SharedPreferencesAsync {
  final values = <String, Object>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late _Preferences preferences;
  late WorkspaceSession session;
  const filesChannel = MethodChannel('dev.ekko.ejson/files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ejson-session-');
    preferences = _Preferences();
    session = WorkspaceSession(preferences);
    calls.clear();
    messenger.setMockMethodCallHandler(filesChannel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'createBookmark' => 'bookmark',
        'accessBookmark' => true,
        _ => null,
      };
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(filesChannel, null);
    await temp.delete(recursive: true);
  });

  Future<LocalJsonFile> makeFile(String name) async {
    final file = File.fromUri(temp.uri.resolve(name));
    await file.writeAsString('1');
    return LocalJsonFile.read(file.path);
  }

  WorkspaceTab tab(int id, LocalJsonFile? file, String source) =>
      WorkspaceTab(id, JsonDocument(SourceBuffer(source)), file: file);

  test('restores only open files in order, with fresh disk contents', () async {
    final a = await makeFile('a.json');
    final b = await makeFile('b.json');
    final c = await makeFile('c.json');
    await session.remember(
      Workspace([
        tab(1, a, '2'),
        tab(2, null, 'draft'),
        tab(3, b, '1'),
        tab(4, c, '1'),
      ], 3),
      enabled: true,
    );
    final raw = preferences.values['lastWorkspace']! as String;
    expect(jsonDecode(raw)['activePath'], b.path);
    expect(raw, isNot(contains('draft')));

    await File(a.path).writeAsString('3');
    await File(c.path).delete();
    final restored = await session.restore();
    expect(restored.files.map((file) => file.path), [a.path, b.path]);
    expect(restored.files.map((file) => file.source), ['3', '1']);
    expect(restored.activePath, b.path);
    expect(restored.failedPaths, [c.path]);
    await session.releaseAccess(b.path);
    if (Platform.isMacOS) expect(calls.last, 'releaseBookmark');

    final container = ProviderContainer(
      overrides: [
        initialWorkspaceProvider.overrideWithValue((
          files: restored.files,
          activePath: restored.activePath,
        )),
      ],
    );
    addTearDown(container.dispose);
    final workspace = container.read(workspaceProvider);
    expect(workspace.tabs.map((item) => item.name), ['a.json', 'b.json']);
    expect(workspace.active.file?.path, b.path);
  });

  test(
    'missing selection falls back to first file, and disabling skips restore',
    () async {
      final a = await makeFile('a.json');
      final b = await makeFile('b.json');
      final workspace = Workspace([tab(1, a, '1'), tab(2, b, '1')], 2);
      await session.remember(workspace, enabled: true);
      await File(b.path).delete();
      final restored = await session.restore();
      expect(restored.activePath, isNull);
      final container = ProviderContainer(
        overrides: [
          initialWorkspaceProvider.overrideWithValue((
            files: restored.files,
            activePath: restored.activePath,
          )),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(workspaceProvider).active.file?.path, a.path);

      expect(await session.isEnabled(), isTrue);
      await session.setEnabled(false);
      expect(await session.isEnabled(), isFalse);
      await session.remember(workspace, enabled: false);
      expect((await session.restore()).files, isEmpty);
    },
  );
}
