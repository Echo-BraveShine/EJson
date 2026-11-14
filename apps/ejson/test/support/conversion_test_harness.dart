import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/editor/conversion_job.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/workspace/workbench.dart';
import 'package:ejson/workspace/workspace.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitForConversion(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

Future<ProviderContainer> mountConversion(
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

Future<void> selectConversionDirection(
  WidgetTester tester,
  String label,
) async {
  await tester.ensureVisible(find.byType(WorkbenchSelect<ConversionDirection>));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(WorkbenchSelect<ConversionDirection>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> previewConversion(
  WidgetTester tester, {
  bool chinese = false,
}) async {
  final button = find.text(chinese ? '转换并预览' : 'Convert and preview');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await waitForConversion(
    tester,
    find.byKey(const ValueKey('conversion-preview')),
  );
  await tester.pumpAndSettle();
}
