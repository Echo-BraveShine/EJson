import 'dart:async';
import 'dart:io';

import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/editor/conversion_job.dart';
import 'package:ejson/editor/json_lines_filter.dart' show filterJsonLines;
import 'package:ejson/editor/json_lines_view.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson/workspace/file_io.dart';
import 'package:ejson/workspace/local_files.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'support/conversion_test_harness.dart' show waitForConversion;

void main() {
  test('record filtering yields and can discard an outdated result', () async {
    final data = readJsonLines('{"name":"Alpha"}\ninvalid\n' * 2000);
    var cancelled = false;
    final pending = filterJsonLines(
      data,
      'alpha',
      JsonLinesFilter.all,
      cancelled: () => cancelled,
    );
    cancelled = true;
    expect(await pending, isNull);
    final current = await filterJsonLines(
      data,
      'INVALID',
      JsonLinesFilter.invalid,
      cancelled: () => false,
    );
    expect(data.invalidCount, 2000);
    expect(current?.records, hasLength(2000));
    expect(current?.records.first.lineNumber, 2);
    expect(current?.allValid, isFalse);
  });

  test('record search finds a match near the end of a long line', () async {
    final data = readJsonLines('"${'x' * 160000}TaIl"\n');
    final selection = await filterJsonLines(
      data,
      'tail',
      JsonLinesFilter.all,
      cancelled: () => false,
    );
    expect(selection?.records.single, same(data.records.single));
    expect(selection?.allValid, isTrue);
  });

  test(
    'large JSON Lines files still produce per-line validation data',
    () async {
      final source = '"${'x' * (maxParsedUnits + 1)}"\nnull\n';
      final container = ProviderContainer(
        overrides: [
          initialWorkspaceProvider.overrideWithValue((
            files: [LocalJsonFile('/logs.ndjson', source)],
            activePath: '/logs.ndjson',
          )),
        ],
      );
      final ready = Completer<void>();
      container.listen(workspaceProvider, (_, next) {
        if (next.active.document.snapshot?.jsonLines != null &&
            !ready.isCompleted) {
          ready.complete();
        }
      });
      try {
        expect(container.read(workspaceProvider).active.large, isTrue);
        await ready.future.timeout(const Duration(seconds: 10));
        expect(
          container
              .read(workspaceProvider)
              .active
              .document
              .snapshot!
              .jsonLines!
              .records,
          hasLength(2),
        );
      } finally {
        container.dispose();
      }
    },
  );
  test('conversion jobs support JSON Lines in both directions', () async {
    final lines = await ConversionJob().run(
      const ConversionRequest(
        '[{"id":123456789012345678901},null]',
        ConversionDirection.jsonToJsonLines,
      ),
    );
    expect(lines.format, DocumentFormat.jsonLines);
    expect(readJsonLines(lines.source).records, hasLength(2));
    final result = await ConversionJob().run(
      ConversionRequest(lines.source, ConversionDirection.jsonLinesToJson),
    );
    expect(result.source, contains('123456789012345678901'));
    expect(parseJson(result.source).root!.children, hasLength(2));
  });

  for (final language in ['en', 'zh']) {
    testWidgets('JSON Lines browsing and filtering works in $language', (
      tester,
    ) async {
      final directory = Directory.systemTemp.createTempSync(
        'ejson-json-lines-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final exported = File(
        '${directory.path}/filtered.${language == 'en' ? 'jsonl' : 'json'}',
      );
      const selector = MethodChannel('plugins.flutter.io/file_selector');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        selector,
        (call) async => call.method == 'getSavePath' ? exported.path : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          selector,
          null,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(720, 460));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          installedFontsProvider.overrideWith((ref) async => []),
          workspaceAtomicWriterProvider.overrideWithValue((path, bytes) async {
            File(path).writeAsBytesSync(bytes);
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EJsonApp(
            initialLanguage: language,
            initialThemeMode: language == 'en'
                ? ThemeMode.light
                : ThemeMode.dark,
          ),
        ),
      );
      container
          .read(workspaceProvider.notifier)
          .newTabWithSource(
            '{"name":"Alpha"}\ninvalid\n{"name":"Beta"}\n',
            format: DocumentFormat.jsonLines,
          );
      await tester.pump(const Duration(milliseconds: 200));
      await waitForConversion(tester, find.byType(JsonLinesView));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('json-line-2')), findsOneWidget);
      await tester.tap(find.byType(WorkbenchSelect<JsonLinesFilter>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(language == 'en' ? 'Invalid records' : '无效记录').last,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('json-line-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('json-line-1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('json-line-2')));
      await tester.pumpAndSettle();
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      expect(editor.controller!.selectedText, 'invalid');
      await tester.tap(find.byType(WorkbenchSelect<JsonLinesFilter>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(language == 'en' ? 'All records' : '全部记录').last,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('json-lines-search')),
          matching: find.byType(TextField),
        ),
        'beta',
      );
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('json-line-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('json-line-1')), findsNothing);
      expect(
        tester.widget<EJsonCodeEditor>(find.byType(EJsonCodeEditor)).format,
        DocumentFormat.jsonLines,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byTooltip(language == 'en' ? 'Export filtered records' : '导出筛选结果'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(language == 'en' ? 'JSON Lines (.jsonl)' : 'JSON (.json)'),
      );
      await waitForConversion(
        tester,
        find.text(language == 'en' ? 'Filtered records exported' : '筛选结果已导出'),
      );
      if (language == 'en') {
        expect(exported.readAsStringSync(), '{"name":"Beta"}\n');
      } else {
        final exportedJson = parseJson(exported.readAsStringSync());
        expect(exportedJson.root!.kind, JsonKind.array);
        expect(exportedJson.root!.children, hasLength(1));
        expect(exported.readAsStringSync(), contains('"Beta"'));
      }
    });
  }
}
