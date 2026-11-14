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
    await tester.pumpAndSettle();
  });
}
