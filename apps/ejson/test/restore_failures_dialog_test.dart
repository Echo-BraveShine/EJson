import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['zh', 'en']) {
    testWidgets('restore failures use the shared dialog style in $language', (
      tester,
    ) async {
        await tester.binding.setSurfaceSize(const Size(720, 460));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [installedFontsProvider.overrideWith((ref) async => [])],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EJsonApp(
            initialLanguage: language,
            failedRestorePaths: const [
              '/Users/example/Documents/已移动的配置.toml',
              '/Volumes/Offline/archive/runtime-settings.yaml',
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = language == 'zh'
          ? '部分文件无法重新打开'
          : 'Could not reopen some files';
      final done = language == 'zh' ? '完成' : 'Done';
      expect(find.text(title), findsOneWidget);
      expect(
        find.byKey(const ValueKey('restore-failures-list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('restore-failure-row:0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('restore-failure-row:1')),
        findsOneWidget,
      );
      expect(find.text('已移动的配置.toml'), findsOneWidget);
      expect(find.text('runtime-settings.yaml'), findsOneWidget);

      final button = find.widgetWithText(FilledButton, done);
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).style, isNotNull);
      expect(tester.getSize(button).height, WorkbenchStyle.dialogButtonHeight);
      expect(tester.takeException(), isNull);
    });
  }
}
