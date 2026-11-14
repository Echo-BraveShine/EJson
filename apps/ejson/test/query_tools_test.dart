import 'dart:async';

import 'package:ejson/editor/array_table.dart';
import 'package:ejson/editor/document_find.dart';
import 'package:ejson/editor/json_query_dialog.dart';
import 'package:ejson/editor/regex_replacement.dart';
import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/main.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

Future<ProviderContainer> workbench(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      parseDocumentProvider.overrideWithValue(
        (source, revision) async => parseJson(source, revision: revision),
      ),
      jsonQueryProvider.overrideWithValue(
        (source, root, query) async => queryJsonPath(source, root, query),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const EJsonApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test(
    'capture expansion supports numbered, named, optional and literal tokens',
    () {
      final match = RegExp(r'(?<word>abc)(\d+)?').firstMatch('abc')!;
      expect(
        expandRegexReplacement(r'$1-$2-$0-$&-$$-$<word>-$<missing>-$99', match),
        r'abc--abc-abc-$-abc-$<missing>-$99',
      );
      expect(expandRegexReplacement(r'$12', match), 'abc2');
    },
  );

  test('background query provider returns results and syntax errors', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final query = container.read(jsonQueryProvider);
    const source = '[1,2,3]';
    final root = parseJson(source).root!;
    final matches = await query(source, root, r'$[?@ >= 2]');
    expect(matches.map((match) => match.path), [r'$[1]', r'$[2]']);
    await expectLater(query(source, root, r'$['), throwsFormatException);
  });

  for (final scope in ['Source text', 'Keys', 'Values']) {
    testWidgets('regex capture replacement and undo in $scope', (tester) async {
      final container = await workbench(tester);
      final controller = container.read(workspaceProvider.notifier);
      final id = container.read(workspaceProvider).activeId;
      const original = r'{"field12":"value34", "other":"value56"}';
      controller.editSource(id, original);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Find in document'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show replace'));
      await tester.pumpAndSettle();
      if (scope != 'Source text') {
        await tester.tap(find.text('Source text'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(scope));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Regular expression'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(DocumentFind),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        fields.first,
        scope == 'Keys' ? r'field(\d+)' : r'value(\d+)',
      );
      await tester.enterText(fields.last, r'number-$1-$$');
      await tester.tap(find.text('Replace all'));
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceProvider).active.text,
        scope == 'Keys'
            ? r'{"number-12-$":"value34", "other":"value56"}'
            : r'{"field12":"number-34-$", "other":"number-56-$"}',
      );
      controller.undo(id);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, original);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'decoded captures stay JSON-escaped and plain replacement stays literal',
    (tester) async {
      final container = await workbench(tester);
      final controller = container.read(workspaceProvider.notifier);
      controller.editSource(1, r'{"name":"a\"b"}');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Find in document'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show replace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Values'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Regular expression'));
      final fields = find.descendant(
        of: find.byType(DocumentFind),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, '(a)(")(b)');
      await tester.enterText(fields.last, r'$3$2$1');
      await tester.tap(find.text('Replace all'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).active.text, r'{"name":"b\"a"}');
      await tester.tap(find.byTooltip('Regular expression'));
      await tester.pumpAndSettle();
      await tester.enterText(fields.first, 'b');
      await tester.enterText(fields.last, r'$1');
      await tester.tap(find.text('Replace all'));
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceProvider).active.text,
        r'{"name":"$1\"a"}',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source captures retain lookbehind context and current-match selection',
    (tester) async {
      final container = await workbench(tester);
      final controller = container.read(workspaceProvider.notifier);
      controller.editSource(1, r'["item12","item34"]');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Find in document'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show replace'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Regular expression'));
      final fields = find.descendant(
        of: find.byType(DocumentFind),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, r'(?<=(item))(\d+)');
      await tester.enterText(fields.last, r'$1-$2');
      await tester.tap(find.byTooltip('Next match'));
      await tester.tap(find.text('Replace current'));
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceProvider).active.text,
        r'["item12","itemitem-34"]',
      );
    },
  );

  testWidgets('query results preserve raw values and extract into a new tab', (
    tester,
  ) async {
    final container = await workbench(tester);
    final controller = container.read(workspaceProvider.notifier);
    const original =
        r'{"items":[{"id":1e2,"active":true},{"id":200,"active":false},{"id":300,"active":true}]}';
    controller.editSource(1, original);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('JSONPath query'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      r'$.items[?@.active == true].id',
    );
    await tester.pump();
    await tester.tap(find.text('Run query'));
    await tester.pumpAndSettle();
    expect(find.text('2 results'), findsOneWidget);
    expect(find.text('1e2'), findsOneWidget);
    await tester.tap(find.text('Extract results to new tab'));
    await tester.pumpAndSettle();
    expect(container.read(workspaceProvider).tabs.length, 2);
    expect(container.read(workspaceProvider).active.text, '[1e2,300]');
    expect(container.read(workspaceProvider).tab(1)!.text, original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('query validates syntax, clears old results and reveals source', (
    tester,
  ) async {
    final container = await workbench(tester);
    final controller = container.read(workspaceProvider.notifier);
    controller.editSource(1, r'{"items":[{"id":10},{"id":20}]}');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('JSONPath query'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), r'$.items[*].id');
    await tester.pump();
    await tester.tap(find.text('Run query'));
    await tester.pumpAndSettle();
    expect(find.text('2 results'), findsOneWidget);
    await tester.enterText(find.byType(TextField), r'$[');
    await tester.pump();
    expect(find.text('2 results'), findsNothing);
    await tester.pump();
    await tester.tap(find.text('Run query'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Invalid or unsupported JSONPath'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), r'$.missing[*]');
    await tester.pump();
    await tester.tap(find.text('Run query'));
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    await tester.enterText(find.byType(TextField), r'$.items[1].id');
    await tester.pump();
    await tester.tap(find.text('Run query'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'$["items"][1]["id"]'));
    await tester.pumpAndSettle();
    expect(find.byType(JsonQueryDialog), findsNothing);
    expect(
      tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!
          .selectedText,
      '20',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'table location uses the original cell after filtering and sorting',
    (tester) async {
      final container = await workbench(tester);
      final controller = container.read(workspaceProvider.notifier);
      controller.editSource(
        1,
        r'{"items":[{"id":10,"name":"first"},{"id":2,"name":"second"}]}',
      );
      await tester.pumpAndSettle();
      final tree = tester.widget<TreePanel>(find.byType(TreePanel));
      final array = tree.snapshot.root!.children.first.value;
      final target = array.children[1].value.children.first.value.range;
      await tester.tap(find.byKey(const ValueKey('node-menu:root/0')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Array table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('"id"'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'second');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('cell-menu:${target.start}')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reveal in source'));
      await tester.pumpAndSettle();
      expect(find.byType(ArrayTable), findsNothing);
      final editor = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!;
      expect(editor.selectedText, '2');
      expect(editor.selection.baseOffset, target.start);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'query discards old async completions and rejects stale document ranges',
    (tester) async {
      final container = await workbench(tester);
      final controller = container.read(workspaceProvider.notifier);
      const source = r'{"id":1}';
      controller.editSource(1, source);
      await tester.pumpAndSettle();
      final first = Completer<List<JsonQueryMatch>>();
      final second = Completer<List<JsonQueryMatch>>();
      var requests = 0;
      container.updateOverrides([
        parseDocumentProvider.overrideWithValue(
          (source, revision) async => parseJson(source, revision: revision),
        ),
        jsonQueryProvider.overrideWithValue(
          (source, root, query) =>
              ++requests == 1 ? first.future : second.future,
        ),
      ]);
      await tester.tap(find.byTooltip('JSONPath query'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), r'$.id');
      await tester.pump();
      await tester.tap(find.text('Run query'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), r'$');
      await tester.pump();
      await tester.tap(find.text('Run query'));
      await tester.pump();
      second.complete(queryJsonPath(source, parseJson(source).root!, r'$'));
      await tester.pumpAndSettle();
      first.complete(queryJsonPath(source, parseJson(source).root!, r'$.id'));
      await tester.pumpAndSettle();
      final result = find.descendant(
        of: find.byType(ListTile),
        matching: find.text(r'$'),
      );
      expect(result, findsOneWidget);
      expect(find.text(r'$["id"]'), findsNothing);
      controller.editSource(1, r'{"id":2}');
      await tester.pumpAndSettle();
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(
        find.text('The document changed. Select the node again.'),
        findsOneWidget,
      );
      expect(container.read(workspaceProvider).tabs.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
