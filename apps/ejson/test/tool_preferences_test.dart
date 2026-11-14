import 'dart:async';
import 'dart:convert';

import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/workspace/recent_file.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'recent files cap, reorder, preserve bookmarks and survive queued edits',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(toolPreferencesProvider.notifier);
      await controller.recordRecentFiles([
        for (var i = 0; i < 25; i++)
          RecentFile('/$i.json', bookmark: 'grant$i'),
      ]);
      expect(container.read(toolPreferencesProvider).recentFiles.length, 20);
      await Future.wait([
        controller.recordRecentFiles([const RecentFile('/5.json')]),
        controller.setQuerySaved(r'$.id', saved: true),
        controller.setFormat(
          const JsonFormatOptions(indentation: JsonIndentation.tabs),
        ),
      ]);
      final preferences = container.read(toolPreferencesProvider);
      expect(preferences.recentFiles.first.path, '/5.json');
      expect(preferences.recentFiles.first.bookmark, 'grant5');
      expect(preferences.queries, [r'$.id']);
      expect(preferences.format.indentation, JsonIndentation.tabs);
      final restored = ToolPreferences.fromJson(
        jsonDecode(jsonEncode(preferences.toJson())),
      );
      expect(
        restored.recentFiles.map((f) => f.path),
        preferences.recentFiles.map((f) => f.path),
      );
      await controller.removeRecentFile('/5.json');
      await controller.clearRecentFiles();
      expect(container.read(toolPreferencesProvider).recentFiles, isEmpty);
      expect(container.read(toolPreferencesProvider).queries, [r'$.id']);
    },
  );

  test(
    'recent codec ignores malformed entries and failed save permits retry',
    () async {
      final initial = ToolPreferences.fromJson({
        'recentFiles': [
          null,
          {},
          {'path': 4},
          {'path': ''},
          {'path': '/a', 'bookmark': 4},
          {'path': '/a'},
          {'path': '/b'},
        ],
      });
      expect(initial.recentFiles.map((f) => f.path), ['/a', '/b']);
      var fail = true;
      final container = ProviderContainer(
        overrides: [
          initialToolPreferencesProvider.overrideWithValue(initial),
          saveToolPreferencesProvider.overrideWithValue((_) async {
            if (fail) throw Exception('failed');
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(toolPreferencesProvider.notifier);
      expect(await controller.clearRecentFiles(), isFalse);
      expect(container.read(toolPreferencesProvider).recentFiles.length, 2);
      fail = false;
      expect(await controller.clearRecentFiles(), isTrue);
      expect(container.read(toolPreferencesProvider).recentFiles, isEmpty);
    },
  );

  test(
    'preferences round-trip and recover supported values from older data',
    () {
      final preferences = ToolPreferences.fromJson({
        'indentation': 'tabs',
        'lineEnding': 'crlf',
        'queries': [r' $.items[*] ', r'$.items[*]', 42, '', r'$.id'],
      });
      final restored = ToolPreferences.fromJson(
        jsonDecode(jsonEncode(preferences.toJson())),
      );
      expect(restored.format.indentation, JsonIndentation.tabs);
      expect(restored.format.lineEnding, JsonLineEnding.crlf);
      expect(restored.queries, [r'$.items[*]', r'$.id']);
      final older = ToolPreferences.fromJson({
        'indentation': 'unknown',
        'queries': true,
      });
      expect(older.format.indentation, JsonIndentation.twoSpaces);
      expect(older.format.lineEnding, JsonLineEnding.preserve);
      expect(older.queries, isEmpty);
      expect(ToolPreferences.fromJson(null).queries, isEmpty);
    },
  );

  test(
    'queued writes preserve simultaneous changes and flush on completion',
    () async {
      final started = Completer<void>();
      final gate = Completer<void>();
      final saved = <ToolPreferences>[];
      final container = ProviderContainer(
        overrides: [
          saveToolPreferencesProvider.overrideWithValue((preferences) async {
            if (saved.isEmpty) {
              started.complete();
              await gate.future;
            }
            saved.add(preferences);
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(toolPreferencesProvider.notifier);
      final format = controller.setFormat(
        const JsonFormatOptions(indentation: JsonIndentation.fourSpaces),
      );
      final favorite = controller.setQuerySaved(r'$.items[*]', saved: true);
      await started.future;
      expect(container.read(toolPreferencesProvider).queries, isEmpty);
      gate.complete();
      expect(await format, isTrue);
      expect(await favorite, isTrue);
      await controller.flush();
      expect(saved.last.format.indentation, JsonIndentation.fourSpaces);
      expect(saved.last.queries, [r'$.items[*]']);
      expect(
        await controller.setQuerySaved(r' $.items[*] ', saved: true),
        isTrue,
      );
      expect(saved.length, 2);
      expect(
        await controller.setQuerySaved(r'$.items[*]', saved: false),
        isTrue,
      );
      expect(container.read(toolPreferencesProvider).queries, isEmpty);
    },
  );

  test('failed saves retain prior preferences and allow retry', () async {
    var fail = true;
    final container = ProviderContainer(
      overrides: [
        saveToolPreferencesProvider.overrideWithValue((_) async {
          if (fail) throw Exception('save failed');
        }),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(toolPreferencesProvider.notifier);
    expect(await controller.setQuerySaved(r'$.id', saved: true), isFalse);
    expect(container.read(toolPreferencesProvider).queries, isEmpty);
    fail = false;
    expect(await controller.setQuerySaved(r'$.id', saved: true), isTrue);
    expect(container.read(toolPreferencesProvider).queries, [r'$.id']);
  });
}
