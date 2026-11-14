import 'dart:io';

import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/editor/document_find.dart';
import 'package:ejson/main.dart';
import 'package:ejson/workspace/compare_documents.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'support/workbench_test_harness.dart';

void main() {
  testWidgets('find reveals a collapsed key and tree edits can be undone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        formatTreeAdditionProvider.overrideWithValue(
          (source, parent, entry) async =>
              appendFormattedJsonChild(source, parent, entry),
        ),
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
      ],
    );
    addTearDown(container.dispose);
    final messenger = tester.binding.defaultBinaryMessenger;
    String? copied;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const EJsonApp()),
    );
    final editor = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    editor.text = '{"a/b":[{"x.y":1}]}';
    await settleDocumentEdits(tester);
    expect(find.text('x.y'), findsNothing);

    await tester.tap(find.byType(CodeEditor));
    final modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    final search = find
        .descendant(
          of: find.byType(DocumentFind),
          matching: find.byType(TextField),
        )
        .first;
    await tester.tap(find.text('Source text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keys'));
    await tester.pumpAndSettle();
    await tester.enterText(search, 'x.y');
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('x.y')),
      findsOneWidget,
    );
    expect(editor.selection.extentOffset - editor.selection.baseOffset, 5);
    final nextMatch = find.byTooltip('Next match');
    final closeFind = find.byTooltip('Close find');
    expect(
      tester.getCenter(closeFind).dx,
      greaterThan(tester.getCenter(nextMatch).dx),
    );
    expect(
      tester.getCenter(closeFind).dx - tester.getCenter(nextMatch).dx,
      lessThan(48),
    );

    await tester.tap(find.byTooltip('Close find'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('node-menu:root/0/0/0')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy JSONPath'));
    await tester.pumpAndSettle();
    expect(copied, r'$["a/b"][0]["x.y"]');

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('node-menu:root/0/0/0')),
        matching: find.byTooltip('Edit node'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete node'));
    await settleDocumentEdits(tester);
    expect(editor.text, '{"a/b":[{}]}');

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('node-menu:root/0/0')),
        matching: find.byTooltip('Edit node'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add property'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Apply')).height,
      WorkbenchStyle.dialogButtonHeight,
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Cancel')).height,
      WorkbenchStyle.dialogButtonHeight,
    );
    await tester.enterText(find.byType(TextField), 'new');
    await tester.tap(find.text('Apply'));
    await settleDocumentEdits(tester);
    expect(
      editor.text,
      '{\n  "a/b": [\n    {\n      "new": null\n    }\n  ]\n}',
    );
    await tester.tap(find.byTooltip('Undo'));
    await settleDocumentEdits(tester);
    expect(editor.text, '{"a/b":[{}]}');
    await tester.tap(find.byTooltip('Undo'));
    await settleDocumentEdits(tester);
    expect(editor.text, '{"a/b":[{"x.y":1}]}');
  });

  testWidgets('opens comparison and jumps to a copied path', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 460));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        jsonComparisonProvider.overrideWithValue(
          (a, b) async => compareJsonStructure(
            a.source.text,
            a.snapshot!.root!,
            b.source.text,
            b.snapshot!.root!,
          ),
        ),
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const EJsonApp()),
    );
    final controller = container.read(workspaceProvider.notifier);
    controller.editSource(1, '{"items":[{"name":"new"}],"added":true}');
    controller.newTab();
    controller.editSource(2, '{"items":[{"name":"old"}]}');
    controller.newTab();
    controller.editSource(3, '{"items":[{"name":"old"}],"extra":true}');
    controller.activate(2);
    await settleDocumentEdits(tester);

    await tester.tap(find.byTooltip('Compare JSON documents'));
    await tester.pumpAndSettle();
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Changed'), findsOneWidget);
    await tester.tap(find.text(r'$["items"][0]["name"]'));
    await tester.pumpAndSettle();
    final editors = tester
        .widgetList<CodeEditor>(find.byType(CodeEditor))
        .toList();
    expect(editors.where((editor) => editor.readOnly == true), hasLength(2));
    for (final editor in editors.where((editor) => editor.readOnly == true)) {
      final selection = editor.controller!.selection;
      expect(selection.extentOffset - selection.baseOffset, 5);
    }

    await tester.tap(find.byTooltip('Swap comparison sides'));
    await tester.pumpAndSettle();
    expect(find.text('Removed'), findsOneWidget);
    expect(find.text('Added'), findsNothing);

    await tester.tap(find.byTooltip('Before · Untitled'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        matching: find.text('Untitled 3'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Before · Untitled 3'), findsOneWidget);
    expect(find.byTooltip('After · Untitled 2'), findsOneWidget);
    expect(find.text('Removed'), findsOneWidget);
    expect(find.text('Changed'), findsNothing);
    expect(find.text(r'$["extra"]'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Go to JSONPath'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), r'$.items[0].name');
    await tester.tap(find.widgetWithText(FilledButton, 'Go to node'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('name')),
      findsOneWidget,
    );
    final selection = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!
        .selection;
    expect(selection.extentOffset - selection.baseOffset, 5);
    expect(tester.takeException(), isNull);
  });
}
