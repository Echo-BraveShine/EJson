import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:ejson/main.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:window_manager/window_manager.dart';

Future<ProviderContainer> openWorkbench(
  WidgetTester tester, {
  bool manageWindow = false,
  Future<void> Function(String, Uint8List)? atomicWriter,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (atomicWriter != null)
        workspaceAtomicWriterProvider.overrideWithValue(atomicWriter),
      parseDocumentProvider.overrideWithValue(
        (source, revision) async => parseJson(source, revision: revision),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: EJsonApp(manageWindow: manageWindow),
    ),
  );
  return container;
}

Future<void> closeShortcut(WidgetTester tester) async {
  final modifier = Platform.isMacOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'discard approves the native exit callback without a second prompt',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      const window = MethodChannel('window_manager');
      const appearance = MethodChannel('dev.ekko.ejson/appearance');
      AppExitResponse? response;
      var destroyCalls = 0;
      messenger.setMockMethodCallHandler(appearance, (_) async => false);
      messenger.setMockMethodCallHandler(window, (call) async {
        if (call.method == 'destroy') {
          destroyCalls++;
          response = await tester.binding.handleRequestAppExit();
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(window, null);
        messenger.setMockMethodCallHandler(appearance, null);
      });

      final container = await openWorkbench(tester, manageWindow: true);
      container
          .read(workspaceProvider.notifier)
          .editSource(1, '{"draft":true}');
      await tester.pumpAndSettle();
      final listener = tester.state(find.byType(Workbench)) as WindowListener;
      listener.onWindowClose();
      await tester.pumpAndSettle();
      expect(find.text('Save changes before quitting?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(destroyCalls, 1);
      expect(response, AppExitResponse.exit);
      expect(find.text('Save changes before quitting?'), findsNothing);
    },
  );

  testWidgets('close button keeps the active tab or selects its neighbor', (
    tester,
  ) async {
    final container = await openWorkbench(tester);
    final controller = container.read(workspaceProvider.notifier);
    Workspace workspace() => container.read(workspaceProvider);
    controller.newTab();
    controller.newTab();
    controller.newTab();
    controller.activate(3);
    await tester.pumpAndSettle();

    Future<void> close(int id) async {
      await tester.tap(find.byTooltip('Close Untitled $id'));
      await tester.pumpAndSettle();
      expect(workspace().tab(id), isNull);
    }

    await close(2);
    expect(workspace().activeId, 3);
    await close(3);
    expect(workspace().activeId, 4);
    await tester.tap(find.byTooltip('Close Untitled'));
    await tester.pumpAndSettle();
    expect(workspace().tab(1), isNull);
    expect(workspace().activeId, 4);
    await close(4);
    expect(workspace().tabs, hasLength(1));
    expect(find.text('Untitled'), findsOneWidget);
    expect(find.byTooltip('Close Untitled'), findsNothing);
    final defaultId = workspace().activeId;
    await closeShortcut(tester);
    await closeShortcut(tester);
    expect(workspace().activeId, defaultId);
    expect(find.text('Untitled'), findsOneWidget);
    expect(workspace().active.text, isEmpty);
    expect(workspace().active.dirty, isFalse);
  });

  testWidgets(
    'shortcut from the editor prompts and cancel keeps unsaved text',
    (tester) async {
      final container = await openWorkbench(tester);
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      editor.focusNode!.requestFocus();
      editor.controller!.text = '{"draft":';
      await tester.pumpAndSettle();

      await closeShortcut(tester);
      expect(find.text('Save changes?'), findsOneWidget);
      await closeShortcut(tester);
      expect(find.text('Save changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, '{"draft":');
      expect(container.read(workspaceProvider).active.dirty, isTrue);

      await closeShortcut(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).tab(1), isNull);
      expect(container.read(workspaceProvider).active.text, isEmpty);
      expect(find.text('Untitled'), findsOneWidget);
      expect(find.byTooltip('Close Untitled'), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
    },
  );
  testWidgets('Save closes a dirty tab only after writing succeeds', (
    tester,
  ) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('ejson-close-'),
    ))!;
    addTearDown(() => temp.delete(recursive: true));
    final file = File.fromUri(temp.uri.resolve('example.json'));
    final opened = (await tester.runAsync(() async {
      await file.writeAsString('{}');
      return LocalJsonFile.read(file.path);
    }))!;
    final container = await openWorkbench(
      tester,
      atomicWriter: (path, bytes) async {
        await File(path).writeAsBytes(bytes, flush: true);
      },
    );
    final controller = container.read(workspaceProvider.notifier);
    controller.open(opened);
    final id = container.read(workspaceProvider).activeId;
    controller.editSource(id, '{"saved":true}');
    await tester.pumpAndSettle();

    Future<void> saveAndClose() async {
      await tester.tap(find.byTooltip('Close example.json'));
      await tester.pumpAndSettle();
      final dialog = find.widgetWithText(FilledButton, 'Save');
      await tester.runAsync(() async {
        // Invoking the action in this zone also keeps the async save out of
        // Flutter's fake clock while the dialog route is being dismissed.
        tester.widget<FilledButton>(dialog).onPressed!();
        await tester.pumpAndSettle();
      });
    }

    await tester.runAsync(() => file.writeAsString('null'));
    await saveAndClose();
    await tester.runAsync(() async {
      for (var i = 0; i < 150; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.textContaining('Save failed').evaluate().isNotEmpty) break;
      }
    });
    expect(find.textContaining('Save failed'), findsOneWidget);
    expect(container.read(workspaceProvider).tab(id)?.text, '{"saved":true}');
    expect(await tester.runAsync(file.readAsString), 'null');

    await tester.runAsync(() => file.writeAsString('{}'));
    await saveAndClose();
    await tester.runAsync(() async {
      for (var i = 0; i < 150; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (container.read(workspaceProvider).tab(id) == null) break;
      }
    });
    expect(container.read(workspaceProvider).tab(id), isNull);
    expect(await tester.runAsync(file.readAsString), '{"saved":true}');
    await tester.pumpAndSettle();
  });
}
