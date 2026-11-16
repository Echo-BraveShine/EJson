import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:ejson/main.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/reveal_file.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderContainer> openWorkbench(
    WidgetTester tester, {
    List<LocalJsonFile> files = const [],
    String? activePath,
    Future<RevealFileResult> Function(String)? reveal,
  }) async {
    await tester.binding.setSurfaceSize(const Size(720, 460));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        initialWorkspaceProvider.overrideWithValue((
          files: files,
          activePath: activePath,
        )),
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
        if (reveal != null) revealFileProvider.overrideWithValue(reveal),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const EJsonApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('restored active file is visible in an overflowing tab strip', (
    tester,
  ) async {
    final files = [
      for (var i = 0; i < 22; i++)
        LocalJsonFile('/fixture/configuration-$i.json', '{}'),
    ];
    final container = await openWorkbench(
      tester,
      files: files,
      activePath: files[17].path,
    );

    final active = find.text('configuration-17.json');
    expect(active.hitTestable(), findsOneWidget);
    expect(tester.getRect(active).right, lessThan(720));
    final controller = container.read(workspaceProvider.notifier);
    controller.activate(container.read(workspaceProvider).tabs.first.id);
    await tester.pumpAndSettle();
    expect(find.text('configuration-0.json').hitTestable(), findsOneWidget);
  });

  testWidgets('hover tints the tab and reveals close without shifting layout', (
    tester,
  ) async {
    await openWorkbench(
      tester,
      files: const [
        LocalJsonFile('/fixture/active.json', '{}'),
        LocalJsonFile('/fixture/other.json', '{}'),
      ],
    );
    final label = find.text('other.json');
    final material = find
        .ancestor(of: label, matching: find.byType(Material))
        .first;
    final bounds = tester.getRect(label);
    final tabBounds = tester.getRect(material);
    final activeTab = find
        .ancestor(of: find.text('active.json'), matching: find.byType(Material))
        .first;
    expect(tabBounds.left - tester.getRect(activeTab).right, 2);
    expect(tabBounds.right - bounds.right, 10);
    expect(tester.widget<Material>(material).color, Colors.transparent);
    expect(find.byTooltip('Close other.json'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: bounds.center);
    await tester.pumpAndSettle();
    expect(tester.widget<Material>(material).color, isNot(Colors.transparent));
    final close = find.byTooltip('Close other.json');
    expect(close.hitTestable(), findsOneWidget);
    expect(tester.getRect(close).right, lessThan(bounds.left));
    final closeIcon = find.descendant(
      of: close,
      matching: find.byIcon(Icons.close_rounded),
    );
    expect(tester.getCenter(closeIcon).dy, closeTo(bounds.center.dy, .01));
    expect(tester.getRect(label), bounds);
    expect(tester.getRect(material), tabBounds);

    await mouse.moveTo(const Offset(20, 300));
    await tester.pumpAndSettle();
    expect(tester.widget<Material>(material).color, Colors.transparent);
    expect(find.byTooltip('Close other.json'), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('new tab button and shortcut require a format selection', (
    tester,
  ) async {
    final container = await openWorkbench(tester);
    final button = find.byTooltip('New document format');
    expect(button, findsOneWidget);
    expect(find.byTooltip('New tab'), findsNothing);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).tabs, hasLength(1));
    for (final format in DocumentFormat.values) {
      expect(find.text(format.label), findsWidgets);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).tabs, hasLength(1));

    final modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).tabs, hasLength(1));
    await tester.tap(find.text('TOML'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).tabs, hasLength(2));
    expect(
      container.read(workspaceProvider).active.format,
      DocumentFormat.toml,
    );
  });

  testWidgets(
    'right-click reveals a background file and can copy a failed path',
    (tester) async {
      const path = '/fixture/未保存修改.json';
      final requests = <String>[];
      final container = await openWorkbench(
        tester,
        files: const [
          LocalJsonFile('/fixture/active.json', '{}'),
          LocalJsonFile(path, '{}'),
        ],
        reveal: (path) async {
          requests.add(path);
          return RevealFileResult.failed;
        },
      );
      final controller = container.read(workspaceProvider.notifier);
      final background = container.read(workspaceProvider).tabs.last;
      controller.editSource(background.id, '{"edited":true}');
      await tester.pumpAndSettle();
      final activeId = container.read(workspaceProvider).activeId;
      await tester.tap(
        find.text('未保存修改.json'),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(Platform.isMacOS ? 'Show in Finder' : 'Show in Folder'),
      );
      await tester.pumpAndSettle();
      expect(requests, [path]);
      final model = container.read(workspaceProvider);
      expect(model.activeId, activeId);
      expect(model.tab(background.id)!.text, '{"edited":true}');
      expect(find.text('Could not open the file manager.'), findsOneWidget);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.text('Copy File Path'));
      await tester.pump();
      expect(copied, path);
    },
  );

  testWidgets('tab menu closes its target and confirms unsaved edits', (
    tester,
  ) async {
    final container = await openWorkbench(tester);
    final controller = container.read(workspaceProvider.notifier);
    controller.newTabWithSource('{"draft":true}');
    final draftId = container.read(workspaceProvider).activeId;
    final first = container.read(workspaceProvider).tabs.first.id;
    controller.activate(first);
    await tester.pumpAndSettle();
    Future<void> openMenu() async {
      await tester.tap(
        find.byKey(ValueKey(draftId)),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
    }

    await openMenu();
    expect(find.text('Show in Finder'), findsNothing);
    expect(find.text('Show in Folder'), findsNothing);
    await tester.tap(find.text('Close Tab'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).tab(draftId), isNotNull);
    await openMenu();
    await tester.tap(find.text('Close Tab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).tab(draftId), isNull);
    expect(container.read(workspaceProvider).activeId, first);
  });

  test(
    'reveal selects an existing file and falls back to its original folder',
    () async {
      final directory = await Directory.systemTemp.createTemp('ejson-reveal-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}空 格 #.json');
      await file.writeAsString('{}');
      var selected = 0;
      var opened = 0;
      Future<RevealFileResult> reveal({
        bool canSelect = true,
        bool canOpen = true,
        String? path,
      }) => revealFileInFolder(
        path ?? file.path,
        selectFile: (path) async {
          selected++;
          expect(path, file.path);
          return canSelect;
        },
        openFolder: (uri) async {
          opened++;
          expect(uri, directory.uri);
          return canOpen;
        },
      );

      expect(await reveal(), RevealFileResult.opened);
      expect(opened, 0);
      expect(await reveal(canSelect: false), RevealFileResult.opened);
      await file.delete();
      expect(await reveal(), RevealFileResult.openedOriginalFolder);
      expect(selected, 2);
      expect(opened, 2);
      expect(await reveal(canOpen: false), RevealFileResult.failed);
      expect(
        await reveal(
          path: directory.uri.resolve('missing/file.json').toFilePath(),
        ),
        RevealFileResult.folderMissing,
      );
    },
  );
}
