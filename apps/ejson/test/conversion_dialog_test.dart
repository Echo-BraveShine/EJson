import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/editor/conversion_dialog.dart';
import 'package:ejson/editor/conversion_job.dart';
import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson/settings/reading_preferences.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'support/conversion_test_harness.dart';

void main() {
  testWidgets(
    'CSV menu follows the current document and source input is absent',
    (tester) async {
      final container = await mountConversion(
        tester,
        ThemeMode.light,
        source: 'true',
      );
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
      await selectConversionDirection(tester, 'JSON → CSV');
      await previewConversion(tester);
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

  testWidgets('failed conversion preserves the current document', (
    tester,
  ) async {
    final container = await mountConversion(
      tester,
      ThemeMode.light,
      source: '{"id":1,"id":2}',
    );
    final original = container.read(workspaceProvider).active.text;
    await tester.tap(find.text('Convert and preview'));
    await waitForConversion(tester, find.textContaining('unique keys'));
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
    final container = await mountConversion(tester, ThemeMode.dark);
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
    await previewConversion(tester);
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
      await mountConversion(tester, ThemeMode.light);
      await previewConversion(tester);
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
      await selectConversionDirection(tester, 'JSON → CSV');
      await previewConversion(tester);
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
    await mountConversion(tester, ThemeMode.dark, language: 'zh');
    await previewConversion(tester, chinese: true);
    expect(find.text('在新标签页打开'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
