import 'dart:convert';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
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
  testWidgets('find row keeps its search geometry at minimum width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 460));
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
    final id = container.read(workspaceProvider).activeId;
    container
        .read(workspaceProvider.notifier)
        .editSource(id, '{"alpha":"first","beta":"second"}');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Find in document'));
    await tester.pumpAndSettle();

    final search = find.byType(TextField);
    final initialSize = tester.getSize(search);
    await tester.enterText(search, 'a');
    await tester.pumpAndSettle();

    expect(find.text('1/3'), findsOneWidget);
    expect(tester.getSize(find.byType(TextField)), initialSize);
    expect(tester.takeException(), isNull);
  });

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
    final findArea = find.byType(DocumentFind);
    final inputLeft = tester.getTopLeft(find.byType(TextField)).dx;
    expect(
      inputLeft,
      closeTo(tester.getTopLeft(findArea).dx + WorkbenchStyle.space12, 0.1),
    );
    expect(find.text('Replace'), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('Show replace')).dx,
      lessThan(tester.getCenter(find.byTooltip('Match case')).dx),
    );
    final compactHeight = tester.getSize(find.byType(DocumentFind)).height;
    final inputWidth = tester.getSize(find.byType(TextField)).width;
    await tester.tap(find.byTooltip('Show replace'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TextField).first).dx, inputLeft);
    expect(tester.getSize(find.byType(TextField).first).width, inputWidth);
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
    expect(tester.getSize(find.byType(TextField).first).width, inputWidth);
    expect(find.text('1/2'), findsOneWidget);
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
  testWidgets(
    'ignore whitespace matches formatted multi-line query against minified source',
    (tester) async {
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
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(),
        ),
      );
      await tester.pumpAndSettle();
      final controller = container.read(workspaceProvider.notifier);
      final id = container.read(workspaceProvider).activeId;
      const minifiedSource = '{"name":"Alice","items":[{"id":1}]}';
      controller.editSource(id, minifiedSource);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Find in document'));
      await tester.pumpAndSettle();
      final search = find
          .descendant(
            of: find.byType(DocumentFind),
            matching: find.byType(TextField),
          )
          .first;
      await tester.tap(search);
      // Enter a formatted multi-line query (with newlines and extra spaces).
      await tester.enterText(
        search,
        '{\n  "name": "Alice",\n  "items": [\n    {\n      "id": 1\n    }\n  ]\n}',
      );
      await tester.pumpAndSettle();
      // Without ignore whitespace, the query has newlines/spaces not present in minified source.
      expect(find.text('No matches'), findsOneWidget);

      // Enable ignore whitespace; the formatted query's non-whitespace characters match
      // the minified source exactly after stripping.
      await tester.tap(find.byTooltip('Ignore whitespace'));
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('No matches'), findsNothing);

      await tester.enterText(search, '   ');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      await tester.tap(find.byTooltip('Regular expression'));
      await tester.enterText(search, '^');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1/1'), findsOneWidget);
      await tester.enterText(search, r'$');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1/1'), findsOneWidget);

      controller.newTabWithSource('{"value":"hello world"}');
      await tester.pumpAndSettle();
      expect(find.byType(DocumentFind), findsNothing);
      await tester.tap(find.byTooltip('Find in document'));
      await tester.pumpAndSettle();
      await tester.enterText(search, 'hello world');
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);
      await tester.enterText(search, 'hello  world');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      await tester.enterText(search, ' ');
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);
      controller.activate(id);
      await tester.pumpAndSettle();
      expect(find.byType(DocumentFind), findsNothing);
      await tester.tap(find.byTooltip('Find in document'));
      await tester.pumpAndSettle();
      await tester.enterText(search, '"name":"Alice"');
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);
      await tester.runAsync(() => controller.rewrite(id, minify: false));
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      final editor = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!;
      expect(editor.selection.isCollapsed, isTrue);
      final selectedRows = find.descendant(
        of: find.byType(TreePanel),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Material &&
              widget.color ==
                  Theme.of(
                    tester.element(find.byType(TreePanel)),
                  ).colorScheme.secondaryContainer,
        ),
      );
      expect(selectedRows, findsNothing);
      for (
        var i = 0;
        i < 100 && !container.read(workspaceProvider).active.document.isValid;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.enterText(search, 'Alice');
      await tester.pumpAndSettle();
      expect(selectedRows, findsOneWidget);
      await tester.enterText(search, 'no-such-value');
      await tester.pumpAndSettle();
      expect(selectedRows, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
