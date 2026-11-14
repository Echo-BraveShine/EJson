import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:ejson/main.dart';
import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/workspace/command_palette.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/recent_file.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> start(
  WidgetTester tester,
  Future<LocalJsonFile> Function(String) read, {
  ToolPreferences preferences = const ToolPreferences(),
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      parseDocumentProvider.overrideWithValue(
        (source, revision) async => parseJson(source, revision: revision),
      ),
      installedFontsProvider.overrideWith((ref) async => []),
      localFileReaderProvider.overrideWithValue(read),
      initialToolPreferencesProvider.overrideWithValue(preferences),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const EJsonApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> drop(WidgetTester tester, List<DropItem> files) async {
  tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
    DropDoneDetails(
      files: files,
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('multi-file drops deduplicate and preserve dirty open tabs', (
    tester,
  ) async {
    final reads = <String>[];
    final container = await start(tester, (path) async {
      reads.add(path);
      return LocalJsonFile(path, '{"file":"$path"}');
    });
    await drop(tester, [
      DropItemFile('/a.json'),
      DropItemFile('/b.json'),
      DropItemFile('/a.json'),
    ]);
    expect(reads, ['/a.json', '/b.json']);
    expect(
      container.read(toolPreferencesProvider).recentFiles.map((f) => f.path),
      ['/b.json', '/a.json'],
    );
    final controller = container.read(workspaceProvider.notifier);
    final a = container
        .read(workspaceProvider)
        .tabs
        .firstWhere((t) => t.file?.path == '/a.json');
    controller.editSource(a.id, '{"edited":true}');
    await drop(tester, [DropItemFile('/a.json')]);
    expect(reads.length, 2);
    expect(container.read(workspaceProvider).active.id, a.id);
    expect(container.read(workspaceProvider).active.text, '{"edited":true}');
    expect(
      container.read(toolPreferencesProvider).recentFiles.first.path,
      '/a.json',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('partial failures continue and promised copies become drafts', (
    tester,
  ) async {
    final container = await start(tester, (path) async {
      if (path == '/bad.json') throw const FileSystemException('missing');
      return LocalJsonFile(path, '[1,2]');
    });
    await drop(tester, [DropItemFile('/bad.json'), DropItemFile('/good.json')]);
    expect(container.read(workspaceProvider).active.file?.path, '/good.json');
    expect(
      container.read(toolPreferencesProvider).recentFiles.map((f) => f.path),
      ['/good.json'],
    );
    await drop(tester, [DropItemFile('/temporary.json', fromPromise: true)]);
    expect(container.read(workspaceProvider).active.file, isNull);
    expect(container.read(workspaceProvider).active.text, '[1,2]');
    expect(container.read(toolPreferencesProvider).recentFiles.length, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('recent search reopens and modal disables dropping', (
    tester,
  ) async {
    final reads = <String>[];
    final container = await start(
      tester,
      (path) async {
        reads.add(path);
        return LocalJsonFile(path, '{}');
      },
      preferences: const ToolPreferences(
        recentFiles: [RecentFile('/one/a.json'), RecentFile('/two/b.json')],
      ),
    );
    await tester.tap(find.byTooltip('Recent files'));
    await tester.pumpAndSettle();
    expect(tester.widget<DropTarget>(find.byType(DropTarget)).enable, isFalse);
    final recentRow = tester.widget<ListTile>(find.byType(ListTile).first);
    expect(recentRow.dense, isTrue);
    expect((recentRow.leading! as Icon).size, WorkbenchStyle.controlIconSize);
    expect(
      (recentRow.subtitle! as Text).style!.fontSize,
      WorkbenchStyle.caption.fontSize,
    );
    await tester.enterText(find.byType(TextField).last, 'two');
    await tester.pumpAndSettle();
    expect(find.text('a.json'), findsNothing);
    await tester.tap(find.text('b.json'));
    await tester.pumpAndSettle();
    expect(reads, ['/two/b.json']);
    expect(container.read(workspaceProvider).active.file?.path, '/two/b.json');
    await tester.tap(find.byTooltip('Recent files'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove from recent files').first);
    await tester.pumpAndSettle();
    expect(
      container.read(toolPreferencesProvider).recentFiles.single.path,
      '/one/a.json',
    );
    await tester.tap(find.text('Clear recent files'));
    await tester.pumpAndSettle();
    expect(container.read(toolPreferencesProvider).recentFiles, isEmpty);
    expect(container.read(workspaceProvider).active.file?.path, '/two/b.json');
    expect(tester.takeException(), isNull);
  });
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('new dialogs fit minimum window in $mode', (tester) async {
      await start(tester, (path) async => LocalJsonFile(path, '{}'));
      await tester.binding.setSurfaceSize(const Size(720, 460));
      await tester.pumpWidget(
        ProviderScope(child: EJsonApp(initialThemeMode: mode)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Recent files'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Command palette'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('palette arrows skip disabled commands and wrap selection', (
    tester,
  ) async {
    await start(tester, (path) async => LocalJsonFile(path, '{}'));
    final result = showDialog<WorkbenchCommandId>(
      context: tester.element(find.byType(Workbench)),
      builder: (_) => CommandPalette(
        commands: [
          WorkbenchCommand(
            id: WorkbenchCommandId.newTab,
            label: 'First',
            icon: Icons.add,
            action: () {},
          ),
          const WorkbenchCommand(
            id: WorkbenchCommandId.save,
            label: 'Disabled',
            icon: Icons.save,
            action: null,
          ),
          WorkbenchCommand(
            id: WorkbenchCommandId.open,
            label: 'Last',
            icon: Icons.folder,
            action: () {},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(await result, WorkbenchCommandId.open);
    expect(tester.takeException(), isNull);
  });

  testWidgets('palette shortcut searches Chinese keywords and executes Enter', (
    tester,
  ) async {
    final container = await start(
      tester,
      (path) async => LocalJsonFile(path, '{}'),
    );
    final before = container.read(workspaceProvider).tabs.length;
    final modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPalette), findsOneWidget);
    final palette = find.byType(CommandPalette);
    final list = tester.widget<ListView>(
      find.descendant(of: palette, matching: find.byType(ListView)),
    );
    expect(list.itemExtent, WorkbenchStyle.rowHeight);
    final label = tester.widget<Text>(
      find.descendant(of: palette, matching: find.text('New tab')),
    );
    final colors = Theme.of(tester.element(palette)).colorScheme;
    expect(label.style!.color, colors.onSecondaryContainer);

    await tester.enterText(
      find.descendant(
        of: find.byType(CommandPalette),
        matching: find.byType(TextField),
      ),
      '新建',
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPalette), findsNothing);
    expect(container.read(workspaceProvider).tabs.length, before + 1);
    await tester.tap(find.byTooltip('Command palette'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPalette), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
