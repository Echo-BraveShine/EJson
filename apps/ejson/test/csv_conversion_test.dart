import 'dart:convert';
import 'dart:io';
import 'package:ejson/editor/conversion_job.dart';
import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/conversion_test_harness.dart';

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

  testWidgets('CSV export uses csv extension and writes the selected BOM', (
    tester,
  ) async {
    final exportDirectory = Directory.systemTemp.createTempSync(
      'ejson-conversion-',
    );
    addTearDown(() => exportDirectory.deleteSync(recursive: true));
    final exportPath = File.fromUri(
      exportDirectory.uri.resolve('ejson-conversion-test.csv'),
    ).path;
    Uint8List? saved;
    String? suggested;
    final container = await mountConversion(
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
        return exportPath;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(selector, null));
    await selectConversionDirection(tester, 'JSON → CSV');
    await tester.ensureVisible(find.text('UTF-8 BOM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UTF-8 BOM'));
    await tester.pumpAndSettle();
    await previewConversion(tester);
    await tester.tap(find.text('Export file'));
    await waitForConversion(tester, find.text('ejson-conversion-test.csv'));
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
    await mountConversion(
      tester,
      ThemeMode.light,
      source: '[{"id":"001","n":1e2,"nested":{"v":true}}]',
    );
    await selectConversionDirection(tester, 'JSON → CSV');
    await previewConversion(tester);
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
    await previewConversion(tester);
    final result = tester
        .widget<EJsonCodeEditor>(
          find.byKey(const ValueKey('conversion-preview')),
        )
        .source;
    expect(result, '"n","nested"\r\n"1e2","{""v"":true}"');
    expect(tester.takeException(), isNull);
  });
}
