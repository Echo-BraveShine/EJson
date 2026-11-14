import 'dart:convert';
import 'package:ejson/editor/conversion_dialog.dart';
import 'package:ejson/editor/conversion_job.dart';
import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'support/conversion_test_harness.dart';

void main() {
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
        final container = await mountConversion(tester, mode);
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
        await previewConversion(tester);
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
        await waitForConversion(tester, find.text('Valid YAML'));
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
        await waitForConversion(tester, find.textContaining('Error'));
        container.read(workspaceProvider.notifier).undo(tab.id);
        await tester.pump(const Duration(milliseconds: 250));
        await waitForConversion(tester, find.text('Valid YAML'));
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
      await mountConversion(
        tester,
        ThemeMode.light,
        source: '---\nid: "001"\n---\nid: "002"\n',
        format: DocumentFormat.yaml,
      );
      await selectConversionDirection(tester, 'YAML → JSON');
      final fields = find.descendant(
        of: find.byType(ConversionDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.last, '2');
      await tester.pump();
      await previewConversion(tester);
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
      await previewConversion(tester);
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
}
