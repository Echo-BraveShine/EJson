import 'package:ejson/main.dart';
import 'package:ejson/design/workbench_style.dart';
import 'package:flutter/services.dart';
import 'package:ejson/settings/installed_fonts.dart';
import 'package:ejson/settings/tool_preferences.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final language in ['en', 'zh']) {
      testWidgets('settings categories fit minimum window in $mode $language', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(720, 460));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [installedFontsProvider.overrideWith((ref) async => [])],
            child: EJsonApp(initialThemeMode: mode, initialLanguage: language),
          ),
        );
        await tester.pumpAndSettle();
        final groups = find.byType(GlassGroup);
        expect(groups, findsNWidgets(3));
        final heights = [
          for (var i = 0; i < 3; i++) tester.getSize(groups.at(i)).height,
        ];
        expect(heights, everyElement(WorkbenchStyle.toolbarControlHeight + 4));
        await tester.tap(find.byTooltip(language == 'zh' ? '设置' : 'Settings'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ListTile>(find.byKey(const ValueKey('settings-general')))
              .selected,
          isTrue,
        );
        for (final category in [
          'appearance',
          'reading',
          'formatting',
          'about',
          'general',
        ]) {
          final navigation = find.byKey(ValueKey('settings-$category'));
          await tester.ensureVisible(navigation);
          await tester.tap(navigation);
          await tester.pumpAndSettle();
          expect(tester.widget<ListTile>(navigation).selected, isTrue);
          final rows = find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'settings-row-',
                ),
          );
          expect(rows, findsWidgets);
          for (var i = 0; i < rows.evaluate().length; i++) {
            expect(
              tester.getSize(rows.at(i)).height,
              WorkbenchStyle.settingsRowHeight,
            );
          }
          if (category == 'about') {
            expect(
              find.text('https://echo-braveshine.github.io/EJson/'),
              findsOneWidget,
            );
          }
          if (category == 'reading') {
            final font = find.widgetWithText(
              TextButton,
              language == 'zh' ? '系统默认等宽字体' : 'Default monospace font',
            );
            final button = tester.widget<TextButton>(font);
            expect(tester.getSize(font).width, lessThanOrEqualTo(200));
            expect(button.style!.side!.resolve({}), isNotNull);
            expect(
              tester.getSize(font).height,
              greaterThanOrEqualTo(WorkbenchStyle.rowHeight),
            );
          }

          expect(tester.takeException(), isNull);
        }
        expect(
          find.byTooltip(language == 'zh' ? '字号' : 'Font size'),
          findsNothing,
        );
      });
    }
  }

  testWidgets('settings menus show text and selected checkmarks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [installedFontsProvider.overrideWith((ref) async => [])],
        child: const EJsonApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    for (final entry in {
      'reading': ['Font size', 'Line spacing'],
      'formatting': ['Format indentation', 'Line endings'],
      'appearance': ['JSON highlighting', 'JSON tree style'],
    }.entries) {
      await tester.tap(find.byKey(ValueKey('settings-${entry.key}')));
      await tester.pumpAndSettle();
      for (final label in entry.value) {
        final picker = find.byTooltip(label);
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(find.byIcon(CupertinoIcons.circle), findsNothing);
        expect(find.byIcon(CupertinoIcons.checkmark), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('about website launches the GitHub Pages deployment address', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? launched;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') {
        launched = (call.arguments as Map)['url'] as String;
      }
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const ProviderScope(child: EJsonApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-about')));
    await tester.pumpAndSettle();
    final website = find.text('https://echo-braveshine.github.io/EJson/');
    await tester.ensureVisible(website);
    await tester.tap(website);
    await tester.pumpAndSettle();
    expect(launched, 'https://echo-braveshine.github.io/EJson/');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category switching keeps reading changes and its scroll position',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(720, 460));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [installedFontsProvider.overrideWith((ref) async => [])],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EJsonApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-reading')));
      await tester.pumpAndSettle();
      final increase = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Increase font size',
      );
      await tester.ensureVisible(increase);
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(container.read(toolPreferencesProvider).reading.fontSize, 14);
      final preview = find.byKey(const ValueKey('reading-preview'));
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      final readingScroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const PageStorageKey('settings-content-reading')),
          )
          .controller!;
      final offset = readingScroll.offset;
      expect(offset, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('settings-formatting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Format indentation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 spaces').last);
      await tester.pumpAndSettle();
      expect(
        container.read(toolPreferencesProvider).format.indentation,
        JsonIndentation.fourSpaces,
      );
      await tester.tap(find.byKey(const ValueKey('settings-reading')));
      await tester.pumpAndSettle();
      expect(readingScroll.offset, offset);
      expect(container.read(toolPreferencesProvider).reading.fontSize, 14);
      expect(tester.takeException(), isNull);
    },
  );
}
