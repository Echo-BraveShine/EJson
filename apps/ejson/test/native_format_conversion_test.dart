import 'dart:convert';
import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/editor/conversion_job.dart';
import 'package:ejson/editor/format_tree_view.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/conversion_test_harness.dart';

void main() {
  test('conversion choices exclude incompatible TOML and CSV data', () {
    expect(
      availableConversions('{"a":null}', DocumentFormat.json),
      isNot(contains(ConversionDirection.jsonToToml)),
    );
    expect(
      availableConversions('true', DocumentFormat.json),
      isNot(contains(ConversionDirection.jsonToCsv)),
    );
    expect(
      availableConversions('{"a":1}', DocumentFormat.json),
      contains(ConversionDirection.jsonToToml),
    );
  });

  test(
    'worker converts all added directions and validates its output',
    () async {
      for (final request in [
        const ConversionRequest('{"id":1}', ConversionDirection.jsonToToml),
        const ConversionRequest('id=1', ConversionDirection.tomlToJson),
        const ConversionRequest('{"id":1}', ConversionDirection.jsonToXml),
        const ConversionRequest(
          '<r><id>001</id></r>',
          ConversionDirection.xmlToJson,
        ),
        const ConversionRequest('id\n001', ConversionDirection.csvToJson),
        const ConversionRequest(
          '{"rows":[{"id":1}]}',
          ConversionDirection.jsonToCsv,
          csvPath: r'$.rows',
        ),
      ]) {
        final result = await ConversionJob().run(request);
        final parsed = parseOtherFormat(result.source, result.format);
        expect(parsed.diagnostics, isEmpty, reason: request.direction.label);
      }
    },
  );

  testWidgets('CSV column types are explicitly selected before preview', (
    tester,
  ) async {
    await mountConversion(
      tester,
      ThemeMode.light,
      source: 'id,count\n001,123456789012345678901',
      format: DocumentFormat.csv,
    );
    final columns = find.byType(ExpansionTile);
    await tester.ensureVisible(columns);
    await tester.tap(columns);
    await tester.pumpAndSettle();
    final type = find.byType(WorkbenchSelect<CsvValueType>).last;
    await tester.ensureVisible(type);
    await tester.tap(type);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Number').last);
    await tester.pumpAndSettle();
    await previewConversion(tester);
    final result = tester
        .widget<EJsonCodeEditor>(
          find.byKey(const ValueKey('conversion-preview')),
        )
        .source;
    expect(result, contains('"id": "001"'));
    expect(result, contains('"count": 123456789012345678901'));
    expect(tester.takeException(), isNull);
  });

  for (final direction in [
    ConversionDirection.jsonToXml,
    ConversionDirection.jsonToToml,
  ]) {
    testWidgets(
      '${direction.label} opens a highlighted native tab with structure',
      (tester) async {
        final container = await mountConversion(
          tester,
          ThemeMode.light,
          source: '{"id":1,"name":"中文"}',
        );
        await selectConversionDirection(tester, direction.label);
        await previewConversion(tester);
        final preview = tester.widget<EJsonCodeEditor>(
          find.byKey(const ValueKey('conversion-preview')),
        );
        expect(preview.format, direction.targetFormat);
        await tester.tap(find.text('Open in new tab'));
        await tester.pumpAndSettle();
        await waitForConversion(
          tester,
          find.text('Valid ${direction.targetFormat.label}'),
        );
        expect(
          container.read(workspaceProvider).active.format,
          direction.targetFormat,
        );
        expect(find.byType(FormatTreeView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in {
    DocumentFormat.toml: 'id=1\nname="中文"',
    DocumentFormat.xml: '<r><id>001</id></r>',
    DocumentFormat.csv: 'id,name\n001,中文',
  }.entries) {
    testWidgets(
      '${entry.key.label} imports from the active source and opens JSON',
      (tester) async {
        final container = await mountConversion(
          tester,
          ThemeMode.dark,
          source: entry.value,
          format: entry.key,
        );
        await previewConversion(tester);
        final preview = tester.widget<EJsonCodeEditor>(
          find.byKey(const ValueKey('conversion-preview')),
        );
        final decoded = jsonDecode(preview.source);
        if (entry.key == DocumentFormat.csv) {
          expect(decoded, [
            {'id': '001', 'name': '中文'},
          ]);
        }
        await tester.tap(find.text('Open in new tab'));
        await tester.pumpAndSettle();
        expect(
          container.read(workspaceProvider).active.format,
          DocumentFormat.json,
        );
        expect(container.read(workspaceProvider).tabs[1].text, entry.value);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
