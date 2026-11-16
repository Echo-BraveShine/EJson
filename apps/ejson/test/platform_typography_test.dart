import 'dart:convert';
import 'package:ejson/design/reading_style.dart';
import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/design/workbench_typography.dart';
import 'package:ejson/main.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/settings/reading_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Linux uses the bundled Chinese font in settings and shared controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [installedFontsProvider.overrideWith((ref) async => [])],
          child: const EJsonApp(initialLanguage: 'zh'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-about')));
      await tester.pumpAndSettle();

      for (final label in ['设置', '关于 EJson', '检查版本更新', '官方网站']) {
        final paragraphs = tester
            .widgetList<RichText>(find.byType(RichText))
            .where((widget) => widget.text.toPlainText() == label);
        expect(paragraphs, isNotEmpty, reason: label);
        for (final paragraph in paragraphs) {
          expect(
            paragraph.text.style?.fontFamily,
            WorkbenchTypography.cjkFamily,
            reason: label,
          );
        }
      }
      final context = tester.element(find.text('官方网站'));
      final theme = Theme.of(context);
      for (final style in [
        theme.dialogTheme.contentTextStyle,
        theme.popupMenuTheme.textStyle,
        theme.filledButtonTheme.style?.textStyle?.resolve({}),
        workbenchDialogButtonStyle(context).textStyle?.resolve({}),
      ]) {
        expect(style?.fontFamily, WorkbenchTypography.cjkFamily);
      }
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );

  test(
    'Chinese font and license are included in the application bundle',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      expect(
        manifest.where(
          (entry) => entry['family'] == WorkbenchTypography.cjkFamily,
        ),
        hasLength(1),
      );
      final data = await rootBundle.load(
        'assets/fonts/NotoSansSC-Variable.ttf',
      );
      expect(data.lengthInBytes, greaterThan(1000000));
      expect(
        await rootBundle.loadString('assets/fonts/OFL-NotoSansSC.txt'),
        contains('SIL OPEN FONT LICENSE'),
      );
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    testWidgets(
      '$platform UI and reading styles always have bundled Chinese coverage',
      (tester) async {
        late ThemeData theme;
        late ReadingStyle reading;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            theme: workbenchTheme(Brightness.light),
            home: Builder(
              builder: (context) {
                theme = Theme.of(context);
                reading = ReadingStyle.resolve(
                  context,
                  const ReadingPreferences(),
                  [],
                );
                return const Text('中文设置', style: WorkbenchStyle.heading);
              },
            ),
          ),
        );
        expect(
          theme.textTheme.bodyMedium!.fontFamily,
          WorkbenchTypography.interfaceFamily(platform),
        );
        expect(
          theme.textTheme.bodyMedium!.fontFamilyFallback,
          contains(WorkbenchTypography.cjkFamily),
        );
        expect(theme.textTheme.titleMedium!.fontWeight, FontWeight.w600);
        expect(
          reading.text.fontFamilyFallback,
          contains(WorkbenchTypography.cjkFamily),
        );
        expect(reading.text.fontWeight, FontWeight.w400);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
