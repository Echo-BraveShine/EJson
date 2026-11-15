import 'dart:ui' show PointerDeviceKind;

import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/main.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'support/workbench_test_harness.dart';

void main() {
  testWidgets('mouse click reveals immediately and double click still edits', (
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
    container
        .read(workspaceProvider.notifier)
        .newTabWithSource('{"alpha": 101, "beta": 202}');
    await settleDocumentEdits(tester);
    final editor = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    Future<void> click(int index) => tester.tap(
      find.byKey(ValueKey('tree-row:root/$index')),
      kind: PointerDeviceKind.mouse,
    );

    await click(0);
    await tester.pump();
    expect(editor.selectedText, '101');
    await tester.pump(const Duration(milliseconds: 60));
    await click(1);
    await tester.pump();
    expect(editor.selectedText, '202');
    expect(find.byType(CodeEditor), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    await click(1);
    await tester.pumpAndSettle();
    expect(find.byType(CodeEditor), findsNWidgets(2));
  });

  testWidgets(
    'tree selects the exact source when jumping far in both directions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1120, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final padding = List.filled(1500, '0').join(',\r\n');
      final source =
          '{\r\n"first": "上海",\r\n"before": [\r\n$padding'
          '\r\n],\r\n"middle": 202,\r\n"after": [\r\n$padding'
          '\r\n],\r\n"last": 404\r\n}';
      final container = ProviderContainer(
        overrides: [
          parseDocumentProvider.overrideWithValue(
            (source, revision) async => parseJson(source, revision: revision),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(),
        ),
      );
      container.read(workspaceProvider.notifier).newTabWithSource(source);
      await settleDocumentEdits(tester);
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      final controller = editor.controller!;
      final scroll = editor.scrollController!.verticalScroller;

      Future<void> select(String key, String value, int line) async {
        await tester.tap(find.text(key));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(controller.selectedText, value);
        expect(controller.selection.baseIndex, line);
        final gutter = tester.widget<DefaultCodeLineNumber>(
          find.byType(DefaultCodeLineNumber),
        );
        expect(
          gutter.notifier.value!.paragraphs.map((paragraph) => paragraph.index),
          contains(line),
        );
      }

      await select('last', '404', 3007);
      final bottom = scroll.offset;
      await select('middle', '202', 1504);
      expect(scroll.offset, inInclusiveRange(1000, bottom - 1000));
      await select('first', '"上海"', 1);
      expect(scroll.offset, 0);
      await select('last', '404', 3007);
      expect(scroll.offset, greaterThan(1000));
      expect(container.read(workspaceProvider).active.text, source);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source and tree share revisions, edits, diagnostics and undo', (
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

    final editor = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    editor.text = '0';
    editor.text = '1';
    expect(container.read(workspaceProvider).active.text, '1');
    editor.text = '{ "city" : "上海", "age": 20 }';
    await settleDocumentEdits(tester);
    expect(find.text('Valid JSON'), findsOneWidget);
    expect(find.text('age'), findsOneWidget);

    await tester.tap(find.text('age'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(editor.selectedText, '20');
    final panel = tester.widget<TreePanel>(find.byType(TreePanel));
    final ageRange = panel.snapshot.root!.children.last.value.range;
    panel.onEdit(ageRange, false);
    await tester.pumpAndSettle();
    tester.widget<CodeEditor>(find.byType(CodeEditor).last).controller!.text =
        '21';
    await tester.tap(find.text('Apply'));
    await settleDocumentEdits(tester);
    expect(editor.text, '{ "city" : "上海", "age": 21 }');

    await tester.tap(find.byTooltip('Undo'));
    await settleDocumentEdits(tester);
    expect(editor.text, '{ "city" : "上海", "age": 20 }');

    editor.text = '{';
    await settleDocumentEdits(tester);
    expect(find.text('Previous valid revision'), findsOneWidget);
    expect(tester.widget<TreePanel>(find.byType(TreePanel)).current, isFalse);
    expect(find.textContaining('Error at 1:2'), findsOneWidget);
    expect(editor.text, '{');
    await tester.tap(find.textContaining('Error at'));
    await tester.pumpAndSettle();
    expect(editor.selection.extentOffset, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapter preserves mixed line endings outside a source edit', (
    tester,
  ) async {
    String? edited;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EJsonCodeEditor(
            source: '{\r\n"x":1,\r"y":2\n}\r\n',
            readOnly: false,
            onChanged: (value) => edited = value,
          ),
        ),
      ),
    );
    final controller = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    controller.text = '{\n"x":10,\n"y":2\n}\n';
    expect(edited, '{\r\n"x":10,\r"y":2\n}\r\n');
    controller.text = '{\n"y":2\n}\n';
    expect(edited, '{\r\n"y":2\n}\r\n');
    controller.text = '{\n"y":2,\n"新":3\n}\n';
    expect(edited, '{\r\n"y":2,\r\n"新":3\n}\r\n');
    await tester.pumpAndSettle();
  });
}
