import 'dart:convert';
import 'dart:io';

import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/editor/array_table.dart';
import 'package:ejson/editor/array_table_data.dart';
import 'package:ejson/editor/document_statistics.dart';
import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/l10n/app_localizations.dart';
import 'package:ejson/main.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget harness(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: workbenchTheme(brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  test('table retains duplicate keys, missing values and number spelling', () {
    const source =
        '[{"id":10,"id":1e2,"name":"A,\\"B\\nC"},'
        '{"id":2,"extra":null},3,{}]';
    final data = ArrayTableData(source, parseJson(source).root!);
    expect(data.columns, [
      (key: 'id', occurrence: 1),
      (key: 'id', occurrence: 2),
      (key: 'name', occurrence: 1),
      (key: 'extra', occurrence: 1),
      (key: null, occurrence: 1),
    ]);
    expect(data.raw(data.rows[0][data.columns[1]]!), '1e2');
    expect(data.select(sortColumn: 0), [1, 0, 2, 3]);
    expect(data.select(filter: 'a,"b'), [0]);
    final csv = data.csv([0, 1]);
    expect(() => data.csv([0, 1], maxLength: 10), throwsFormatException);
    expect(csv, contains('"1e2"'));
    expect(csv, contains('"A,""B\nC"'));
    expect(csv, contains('"null"'));
    expect(data.columnLabel(data.columns[1]), '"id" #2');
    expect(ArrayTableData('[]', parseJson('[]').root!).rows, isEmpty);
  });

  test('numeric sorting preserves large integer and exponent precision', () {
    const source =
        '[2e400,1e400,9007199254740993,9007199254740992,-2,-10,0,-0.0,1.10,1.1]';
    final data = ArrayTableData(source, parseJson(source).root!);
    expect(data.select(sortColumn: 0), [5, 4, 6, 7, 8, 9, 3, 2, 1, 0]);
    expect(data.select(sortColumn: 0, ascending: false), [
      0,
      1,
      2,
      3,
      8,
      9,
      6,
      7,
      4,
      5,
    ]);
  });

  test('mixed scalar types have a consistent sort order', () {
    const source = '[2,10,"11",false,null,{},[]]';
    final data = ArrayTableData(source, parseJson(source).root!);
    final valueColumn = data.columns.indexWhere((column) => column.key == null);
    // Empty object rows have no scalar value and sort after populated cells.
    expect(data.select(sortColumn: valueColumn), [6, 2, 0, 1, 3, 4, 5]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('table sorts, filters, copies and exports in $brightness', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 650));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const source = '[{"id":10,"name":"Alice"},{"id":2,"name":"Bob"}]';
      String? copied;
      String? exported;
      await tester.pumpWidget(
        harness(
          ArrayTable(
            source: source,
            array: parseJson(source).root!,
            onCopy: (value) async {
              copied = value;
            },
            onExport: (value) async {
              exported = value;
              return null;
            },
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      expect(copied, 'Alice');
      await tester.tap(find.text('"id"'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();
      expect(exported!.indexOf('"2"'), lessThan(exported!.indexOf('"10"')));
      await tester.enterText(find.byType(TextField), 'BOB');
      await tester.pumpAndSettle();
      expect(find.text('1 / 2 rows'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();
      expect(exported, contains('Bob'));
      expect(exported, isNot(contains('Alice')));
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wide tables build visible columns and keep all export fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = jsonEncode([
      {for (var column = 0; column < 200; column++) 'field$column': column},
    ]);
    String? copied;
    String? exported;
    await tester.pumpWidget(
      harness(
        ArrayTable(
          source: source,
          array: parseJson(source).root!,
          onCopy: (value) async {
            copied = value;
          },
          onExport: (value) async {
            exported = value;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('"field0"'), findsOneWidget);
    expect(find.text('"field199"'), findsNothing);
    final horizontal = tester
        .widget<SingleChildScrollView>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.horizontal,
          ),
        )
        .controller!;
    horizontal.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('"field199"'), findsOneWidget);
    expect(find.text('"field0"'), findsNothing);
    await tester.tap(find.text('199'));
    await tester.pumpAndSettle();
    expect(copied, '199');
    expect(find.text('Node value copied'), findsOneWidget);
    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();
    expect(exported, contains('field0'));
    expect(exported, contains('field199'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty arrays show an empty state', (tester) async {
    await tester.pumpWidget(
      harness(
        ArrayTable(
          source: '[]',
          array: parseJson('[]').root!,
          onCopy: (_) async {},
          onExport: (_) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The array is empty'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Export CSV'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics count UTF-8 bytes, value nodes and array depth', (
    tester,
  ) async {
    const source = '{"中":[1,{"x":null}]}';
    final document = JsonDocument(
      SourceBuffer(source),
      snapshot: parseJson(source),
    );
    await tester.pumpWidget(
      harness(DocumentStatistics(document: document, bom: true)),
    );
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('25 bytes'));
    expect(tooltip.message, contains('5 nodes'));
    expect(tooltip.message, contains('Maximum depth 3'));
    expect(tooltip.message, contains('Longest array 2 items'));
    await tester.pumpWidget(
      harness(
        const DocumentStatistics(document: JsonDocument(SourceBuffer('{'))),
      ),
    );
    expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, '1 bytes');
  });

  testWidgets(
    'node menu copies raw and decoded values and opens a nested array',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1120, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Uint8List? exportedBytes;
      var failExport = false;
      final container = ProviderContainer(
        overrides: [
          workspaceAtomicWriterProvider.overrideWithValue((path, bytes) async {
            if (failExport) throw const FileSystemException('write failed');
            exportedBytes = bytes;
          }),
          parseDocumentProvider.overrideWithValue(
            (source, revision) async => parseJson(source, revision: revision),
          ),
        ],
      );
      addTearDown(container.dispose);
      String? copied;
      final exportDirectory = Directory.systemTemp.createTempSync(
        'ejson-array-export-',
      );
      addTearDown(() => exportDirectory.deleteSync(recursive: true));
      final exportPath = File.fromUri(
        exportDirectory.uri.resolve('ejson-array-export-test.csv'),
      ).path;
      String? destination = exportPath;
      final messenger = tester.binding.defaultBinaryMessenger;
      const fileSelector = MethodChannel('plugins.flutter.io/file_selector');
      messenger.setMockMethodCallHandler(fileSelector, (call) async {
        if (call.method == 'getSavePath') return destination;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(fileSelector, null));
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
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(),
        ),
      );
      await tester.pumpAndSettle();
      final controller = container.read(workspaceProvider.notifier);
      controller.editSource(
        container.read(workspaceProvider).activeId,
        '{"message":"line\\n中", "items":[{"id":1}]}',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('node-menu:root/0')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy JSON value'));
      await tester.pumpAndSettle();
      expect(copied, '"line\\n中"');
      await tester.tap(find.byKey(const ValueKey('node-menu:root/0')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy string contents'));
      await tester.pumpAndSettle();
      expect(copied, 'line\n中');
      await tester.tap(find.byKey(const ValueKey('node-menu:root/1')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Array table'));
      await tester.pumpAndSettle();
      expect(find.byType(ArrayTable), findsOneWidget);
      expect(find.text('"id"'), findsOneWidget);
      expect(find.byType(TreePanel), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Export CSV'));
        for (
          var attempt = 0;
          attempt < 100 && exportedBytes == null;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(
        exportedBytes,
        isNotNull,
        reason: 'CSV export should invoke the writer',
      );
      expect(utf8.decode(exportedBytes!), '"id"\r\n"1"');
      expect(find.text('CSV exported'), findsOneWidget);
      exportedBytes = null;
      destination = null;
      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();
      expect(exportedBytes, isNull);
      destination = exportPath;
      failExport = true;
      await tester.runAsync(() async {
        await tester.tap(find.text('Export CSV'));
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          if (find.text('Export failed').evaluate().isNotEmpty) break;
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Export failed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
