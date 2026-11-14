import 'dart:convert';
import 'package:ejson/design/workbench_style.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:ejson/editor/conversion_dialog.dart';
import 'package:ejson/editor/conversion_job.dart';
import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/settings/reading_preferences.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

Future<ProviderContainer> mount(
  WidgetTester tester,
  ThemeMode mode, {
  String language = 'en',
  String source = '{"id":"001","active":"true","large":123456789012345678901}',
  DocumentFormat format = DocumentFormat.json,
  void Function(String, Uint8List)? save,
}) async {
  await tester.binding.setSurfaceSize(const Size(720, 460));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      installedFontsProvider.overrideWith((ref) async => []),
      parseDocumentProvider.overrideWithValue(
        (source, revision) async => parseJson(source, revision: revision),
      ),
      workspaceAtomicWriterProvider.overrideWithValue((path, bytes) async {
        save?.call(path, bytes);
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: EJsonApp(initialThemeMode: mode, initialLanguage: language),
    ),
  );
  if (format == DocumentFormat.json) {
    container.read(workspaceProvider.notifier).editSource(1, source);
  } else {
    container
        .read(workspaceProvider.notifier)
        .newTabWithSource(source, format: format);
  }
  await tester.pumpAndSettle();
  await tester.tap(
    find.byTooltip(language == 'zh' ? '文档工具' : 'Document tools'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(language == 'zh' ? '格式转换' : 'Format conversion'));
  await tester.pumpAndSettle();
  return container;
}

Future<void> direction(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byType(WorkbenchSelect<ConversionDirection>));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(WorkbenchSelect<ConversionDirection>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> convert(WidgetTester tester, {bool chinese = false}) async {
  final button = find.text(chinese ? '转换并预览' : 'Convert and preview');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await waitFor(tester, find.byKey(const ValueKey('conversion-preview')));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'CSV availability rejects invalid, scalar, fieldless and ambiguous input',
    () {
      for (final source in [
        '',
        '[',
        'null',
        'true',
        '123',
        '"text"',
        '{}',
        '[{}]',
        r'[{"$":1},true]',
        '[{"a":1,"a":2,"a #2":3}]',
      ]) {
        expect(canConvertJsonToCsv(source), isFalse, reason: source);
      }
      for (final source in [
        '[]',
        '{"id":1}',
        '[{"id":1}]',
        '[true,"text",null]',
        '[{"id":1},true,"text"]',
      ]) {
        expect(canConvertJsonToCsv(source), isTrue, reason: source);
      }
    },
  );

  testWidgets(
    'CSV menu follows the current document and source input is absent',
    (tester) async {
      final container = await mount(tester, ThemeMode.light, source: 'true');
      expect(
        find.descendant(
          of: find.byType(ConversionDialog),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      final selector = find.byType(WorkbenchSelect<ConversionDirection>);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.text('JSON → CSV'), findsNothing);
      expect(find.text('YAML → JSON'), findsNothing);
      await tester.tap(find.text('JSON → YAML').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      container
          .read(workspaceProvider.notifier)
          .editSource(
            container.read(workspaceProvider).activeId,
            '[{"id":1},true]',
          );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Document tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Format conversion'));
      await tester.pumpAndSettle();
      await direction(tester, 'JSON → CSV');
      await convert(tester);
      expect(
        tester
            .widget<EJsonCodeEditor>(
              find.byKey(const ValueKey('conversion-preview')),
            )
            .source,
        '"id","\$"\r\n"1",""\r\n"","true"',
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('CSV conversion reuses quoting and supports column options', () {
    final result = convertDocument(
      const ConversionRequest(
        '[{"a":"x,\\"y\\"\\n中文","b":null},{"b":1e2}]',
        ConversionDirection.jsonToCsv,
        delimiter: ';',
        header: false,
        crlf: false,
        bom: true,
        columns: [(key: 'b', occurrence: 1), (key: 'a', occurrence: 1)],
      ),
    );
    expect(result.source, '"null";"x,""y""\n中文"\n"1e2";""');
    expect(result.bom, isTrue);
    expect(result.format, DocumentFormat.csv);
    expect(
      parseOtherFormat(result.source, DocumentFormat.csv).diagnostics,
      isEmpty,
    );
    expect(
      () => convertDocument(
        const ConversionRequest('1', ConversionDirection.jsonToCsv),
      ),
      throwsFormatException,
    );
    expect(
      () => convertDocument(
        const ConversionRequest('[{}]', ConversionDirection.jsonToCsv),
      ),
      throwsFormatException,
    );
  });
  test(
    'mixed JSON arrays preserve every row in CSV with and without flattening',
    () {
      const source =
          '[{"today":false,"near":{"front":{"environment":'
          '[{"bring":[true,{"wolf":{"consonant":82213238.3333838}}]},false]}}},'
          'true,"journey","outline","truth","burn",null,1e2,[1,2]]';
      for (final flatten in [false, true]) {
        final result = convertDocument(
          ConversionRequest(
            source,
            ConversionDirection.jsonToCsv,
            flatten: flatten,
          ),
        );
        expect(result.columns.last, (key: null, occurrence: 1));
        expect(result.source, contains('82213238.3333838'));
        expect(result.source, contains('"true"'));
        expect(result.source, contains('"journey"'));
        expect(result.source, contains('"burn"'));
        expect(result.source, contains('"null"'));
        expect(result.source, contains('"1e2"'));
        expect(result.source, contains('"[1,2]"'));
        expect(result.source.split('\r\n'), hasLength(10));
        expect(
          parseOtherFormat(result.source, DocumentFormat.csv).diagnostics,
          isEmpty,
        );
      }
      expect(
        convertDocument(
          const ConversionRequest(
            '[true,"journey",null]',
            ConversionDirection.jsonToCsv,
          ),
        ).source,
        '"\$"\r\n"true"\r\n"journey"\r\n"null"',
      );
    },
  );

  test(
    'single objects convert as one row and invalid JSON retains its diagnostic',
    () {
      for (final flatten in [false, true]) {
        final result = convertDocument(
          ConversionRequest(
            '{"id":123456789012345678901,"nested":{"v":true}}',
            ConversionDirection.jsonToCsv,
            flatten: flatten,
          ),
        );
        expect(result.source, contains('123456789012345678901'));
        expect(result.source.split('\r\n'), hasLength(2));
      }
      expect(
        () => convertDocument(
          const ConversionRequest('[1,', ConversionDirection.jsonToCsv),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Expected a JSON value'),
          ),
        ),
      );
    },
  );

  test('flattened CSV keeps path columns and exact raw values', () {
    final result = convertDocument(
      const ConversionRequest(
        '[{"a":{"id":"001"},"n":123456789012345678901}]',
        ConversionDirection.jsonToCsv,
        flatten: true,
      ),
    );
    expect(result.columns.map((c) => c.key), [r'$["a"]["id"]', r'$["n"]']);
    expect(result.source, contains('123456789012345678901'));
    expect(result.source, contains('"001"'));
  });
  test('conversion jobs can be cancelled and a fresh job can run', () async {
    final job = ConversionJob();
    final task = job.run(
      const ConversionRequest('{"id":1}', ConversionDirection.jsonToYaml),
    );
    final checked = expectLater(task, throwsA(isA<ConversionCancelled>()));
    job.cancel();
    await checked;
    final result = await ConversionJob().run(
      const ConversionRequest('id: 1', ConversionDirection.yamlToJson),
    );
    expect(jsonDecode(result.source), {'id': 1});
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'conversion opens typed YAML tabs with syntax validation in $mode',
      (tester) async {
        final container = await mount(tester, mode);
        expect(find.text('Copy result'), findsNothing);
        final original = container.read(workspaceProvider).active.text;
        expect(
          tester.getBottomLeft(find.byType(PopupMenuButton<int>)).dy,
          closeTo(
            tester
                .getBottomLeft(
                  find.widgetWithText(TextButton, 'Convert and preview'),
                )
                .dy,
            0.01,
          ),
        );
        await convert(tester);
        expect(
          tester.getCenter(find.widgetWithText(TextButton, 'Copy result')).dy,
          closeTo(
            tester.getCenter(find.widgetWithText(TextButton, 'Cancel')).dy,
            0.01,
          ),
        );
        expect(
          tester
              .widget<EJsonCodeEditor>(
                find.byKey(const ValueKey('conversion-preview')),
              )
              .format,
          DocumentFormat.yaml,
        );
        await tester.tap(find.text('Open in new tab'));
        await tester.pumpAndSettle();
        await waitFor(tester, find.text('Valid YAML'));
        expect(
          container.read(workspaceProvider).active.format,
          DocumentFormat.yaml,
        );
        expect(container.read(workspaceProvider).tabs.first.text, original);
        expect(find.text('JSON tree'), findsNothing);
        final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
        expect(editor.style!.codeTheme!.languages, contains('yaml'));
        final tab = container.read(workspaceProvider).active;
        container
            .read(workspaceProvider.notifier)
            .editSource(tab.id, 'broken: [');
        await tester.pump(const Duration(milliseconds: 250));
        await waitFor(tester, find.textContaining('Error'));
        container.read(workspaceProvider.notifier).undo(tab.id);
        await tester.pump(const Duration(milliseconds: 250));
        await waitFor(tester, find.text('Valid YAML'));
        expect(
          container.read(workspaceProvider).active.format,
          DocumentFormat.yaml,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'YAML multi-document selection converts and invalidates old results',
    (tester) async {
      await mount(
        tester,
        ThemeMode.light,
        source: '---\nid: "001"\n---\nid: "002"\n',
        format: DocumentFormat.yaml,
      );
      await direction(tester, 'YAML → JSON');
      final fields = find.descendant(
        of: find.byType(ConversionDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.last, '2');
      await tester.pump();
      await convert(tester);
      expect(
        jsonDecode(
          tester
              .widget<EJsonCodeEditor>(
                find.byKey(const ValueKey('conversion-preview')),
              )
              .source,
        ),
        {'id': '002'},
      );
      await tester.enterText(fields.last, '1');
      await tester.pump();
      expect(find.byKey(const ValueKey('conversion-preview')), findsNothing);
      expect(find.text('Copy result'), findsNothing);
      await convert(tester);
      expect(
        jsonDecode(
          tester
              .widget<EJsonCodeEditor>(
                find.byKey(const ValueKey('conversion-preview')),
              )
              .source,
        ),
        {'id': '001'},
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('CSV export uses csv extension and writes the selected BOM', (
    tester,
  ) async {
    Uint8List? saved;
    String? suggested;
    final container = await mount(
      tester,
      ThemeMode.light,
      save: (_, bytes) => saved = bytes,
      source: '[{"id":"001","n":1e2}]',
    );
    const selector = MethodChannel('plugins.flutter.io/file_selector');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(selector, (call) async {
      if (call.method == 'getSavePath') {
        suggested = (call.arguments as Map)['suggestedName'] as String?;
        return '/tmp/ejson-conversion-test.csv';
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(selector, null));
    await direction(tester, 'JSON → CSV');
    await tester.ensureVisible(find.text('UTF-8 BOM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UTF-8 BOM'));
    await tester.pumpAndSettle();
    await convert(tester);
    await tester.tap(find.text('Export file'));
    await waitFor(tester, find.text('ejson-conversion-test.csv'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(suggested, 'untitled.csv');
    expect(saved!.take(3), [0xef, 0xbb, 0xbf]);
    expect(utf8.decode(saved!), contains('"001","1e2"'));
    expect(container.read(workspaceProvider).active.format, DocumentFormat.csv);
    expect(container.read(workspaceProvider).active.bom, isTrue);
    expect(container.read(workspaceProvider).active.dirty, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('CSV columns can be selected and reordered before reconverting', (
    tester,
  ) async {
    await mount(
      tester,
      ThemeMode.light,
      source: '[{"id":"001","n":1e2,"nested":{"v":true}}]',
    );
    await direction(tester, 'JSON → CSV');
    await convert(tester);
    await tester.ensureVisible(find.text('Columns and order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Columns and order'));
    await tester.pumpAndSettle();
    final rowN = find.byKey(
      const ValueKey<Object>(('conversion-column', (key: 'n', occurrence: 1))),
    );
    await tester.ensureVisible(rowN);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: rowN,
        matching: find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Move column up',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rowId = find.byKey(
      const ValueKey<Object>(('conversion-column', (key: 'id', occurrence: 1))),
    );
    await tester.ensureVisible(rowId);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: rowId, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversion-preview')), findsNothing);
    await convert(tester);
    final result = tester
        .widget<EJsonCodeEditor>(
          find.byKey(const ValueKey('conversion-preview')),
        )
        .source;
    expect(result, '"n","nested"\r\n"1e2","{""v"":true}"');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed conversion preserves the current document', (
    tester,
  ) async {
    final container = await mount(
      tester,
      ThemeMode.light,
      source: '{"id":1,"id":2}',
    );
    final original = container.read(workspaceProvider).active.text;
    await tester.tap(find.text('Convert and preview'));
    await waitFor(tester, find.textContaining('unique keys'));
    expect(find.byKey(const ValueKey('conversion-preview')), findsNothing);
    expect(container.read(workspaceProvider).active.text, original);
    expect(
      find.descendant(
        of: find.byType(ConversionDialog),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large reading fonts and copying results work at minimum size', (
    tester,
  ) async {
    final container = await mount(tester, ThemeMode.dark);
    await container
        .read(toolPreferencesProvider.notifier)
        .setReading(const ReadingPreferences(fontSize: 32));
    await tester.pumpAndSettle();
    String? copied;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await convert(tester);
    final preview = find.byKey(const ValueKey('conversion-preview'));
    final editor = tester.widget<CodeEditor>(
      find.descendant(of: preview, matching: find.byType(CodeEditor)),
    );
    expect(editor.style!.fontSize, 32);
    await tester.ensureVisible(find.text('Copy result'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy result'));
    await tester.pumpAndSettle();
    expect(copied, tester.widget<EJsonCodeEditor>(preview).source);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'conversion preview fills the remaining body and grows with the window',
    (tester) async {
      await mount(tester, ThemeMode.light);
      await convert(tester);
      final preview = find.byKey(const ValueKey('conversion-preview'));
      final body = find.byKey(const ValueKey('conversion-body'));
      final smallHeight = tester.getSize(preview).height;
      expect(smallHeight, greaterThan(0));
      expect(
        tester.getBottomLeft(preview).dy,
        closeTo(tester.getBottomLeft(body).dy, 0.01),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(720, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.binding.setSurfaceSize(const Size(720, 800));
      await tester.pumpAndSettle();
      expect(tester.getSize(preview).height, greaterThan(smallHeight + 100));
      expect(
        tester.getBottomLeft(preview).dy,
        closeTo(tester.getBottomLeft(body).dy, 0.01),
      );
      await direction(tester, 'JSON → CSV');
      await convert(tester);
      expect(tester.getSize(preview).height, greaterThan(0));
      expect(
        tester.getBottomLeft(preview).dy,
        closeTo(tester.getBottomLeft(body).dy, 0.01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Chinese conversion dialog fits the minimum window', (
    tester,
  ) async {
    await mount(tester, ThemeMode.dark, language: 'zh');
    await convert(tester, chinese: true);
    expect(find.text('在新标签页打开'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'saved YAML and CSV files are inferred when opening or restoring',
    () async {
      final container = ProviderContainer(
        overrides: [
          initialWorkspaceProvider.overrideWithValue((
            files: const [
              LocalJsonFile('/tmp/a.yaml', 'name: test'),
              LocalJsonFile('/tmp/a.csv', '"a"\n"1"'),
            ],
            activePath: '/tmp/a.yaml',
          )),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(workspaceProvider).tabs.map((t) => t.format), [
        DocumentFormat.yaml,
        DocumentFormat.csv,
      ]);
    },
  );
  testWidgets('promised YAML file drops retain format and BOM in a new draft', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        installedFontsProvider.overrideWith((ref) async => []),
        localFileReaderProvider.overrideWithValue(
          (path) async => LocalJsonFile(path, 'name: test', bom: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const EJsonApp()),
    );
    await tester.pumpAndSettle();
    tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(
        files: [DropItemFile('/tmp/promised.yaml', fromPromise: true)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Valid YAML'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final tab = container.read(workspaceProvider).active;
    expect(tab.format, DocumentFormat.yaml);
    expect(tab.bom, isTrue);
    expect(tab.file, isNull);
    expect(tab.text, 'name: test');
    expect(tester.takeException(), isNull);
  });
}
