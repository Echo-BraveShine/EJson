import 'dart:convert';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/editor/document_find.dart';

import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/main.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('replace, undo, string conversion and subtree extraction', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const EJsonApp()),
    );
    await tester.pumpAndSettle();
    final controller = container.read(workspaceProvider.notifier);
    final id = container.read(workspaceProvider).activeId;
    const source = '{"name":"Alice", "other":"alice", "items":[1e2,2]}';
    controller.editSource(id, source);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Find in document'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Replace all'), findsNothing);
    final compactHeight = tester.getSize(find.byType(DocumentFind)).height;
    await tester.tap(find.byTooltip('Show replace'));
    await tester.pumpAndSettle();
    final findArea = find.byType(DocumentFind);
    for (final type in [TextField, TextButton, IconButton]) {
      final controls = find.descendant(
        of: findArea,
        matching: find.byType(type),
      );
      for (var i = 0; i < controls.evaluate().length; i++) {
        expect(
          tester.getSize(controls.at(i)).height,
          WorkbenchStyle.inputHeight,
        );
      }
    }
    final editableInputs = find.descendant(
      of: findArea,
      matching: find.byType(EditableText),
    );
    for (var i = 0; i < editableInputs.evaluate().length; i++) {
      expect(
        InputDecorator.containerOf(
          tester.element(editableInputs.at(i)),
        )!.size.height,
        WorkbenchStyle.inputHeight,
      );
    }
    final scopeControl = find.descendant(
      of: findArea,
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    expect(tester.getSize(scopeControl).height, WorkbenchStyle.inputHeight);
    await tester.tap(scopeControl);
    await tester.pumpAndSettle();
    final options = find.byWidgetPredicate((widget) => widget is PopupMenuItem);
    expect(options, findsNWidgets(3));
    expect(
      find.descendant(
        of: options,
        matching: find.byIcon(CupertinoIcons.search),
      ),
      findsNothing,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'alice');
    await tester.enterText(find.byType(TextField).last, 'Bob');
    expect(tester.getSize(findArea).height, greaterThan(compactHeight));
    await tester.tap(find.byTooltip('Hide replace'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.getSize(findArea).height, compactHeight);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'alice',
    );
    await tester.tap(find.byTooltip('Show replace'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'Bob',
    );
    await tester.tap(find.text('Replace all'));
    await tester.pumpAndSettle();
    expect(
      container.read(workspaceProvider).active.text,
      '{"name":"Bob", "other":"Bob", "items":[1e2,2]}',
    );
    controller.undo(id);
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, source);
    await tester.tap(find.byTooltip('Close find'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Escape as JSON string'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, jsonEncode(source));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byTooltip('Unescape JSON string'), findsOneWidget);
    await tester.tap(find.byTooltip('Unescape JSON string'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).active.text, source);
    final tree = tester.widget<TreePanel>(find.byType(TreePanel));
    tree.onExtract!(tree.snapshot.root!.children.last.value.range);
    await tester.pumpAndSettle();
    final workspace = container.read(workspaceProvider);
    expect(workspace.tabs.length, 2);
    expect(workspace.active.text, '[1e2,2]');
    expect(workspace.active.dirty, isTrue);
    expect(workspace.tab(id)!.text, source);
    expect(tester.takeException(), isNull);
  });
}
