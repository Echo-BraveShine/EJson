import 'package:ejson/editor/tree_panel.dart';
import 'package:ejson/l10n/app_localizations.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('deep branches focus locally and keep their source locations', (
    tester,
  ) async {
    var source = '42';
    for (var level = 8; level > 0; level--) {
      source = '{"level$level":$source}';
    }
    SourceRange? revealed;

    Future<void> showTree(String text) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TreePanel(
            snapshot: parseJson(text),
            source: text,
            current: true,
            onReveal: (range) => revealed = range,
            onEdit: (_, _) {},
          ),
        ),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(280, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await showTree(source);
    String path(int depth) => 'root${'/0' * depth}';
    for (var depth = 1; depth <= 7; depth++) {
      await tester.tap(find.byKey(ValueKey('expand:${path(depth)}')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    final horizontal = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(horizontal.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.text('level8'), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(horizontal.offset, greaterThan(0));

    await tester.tap(find.text('level8'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(SourceBuffer(source).slice(revealed!), '42');

    Future<void> focusLevel6() async {
      horizontal.jumpTo(horizontal.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final expand = find.byKey(ValueKey('expand:${path(6)}'));
      final row = find
          .ancestor(of: expand, matching: find.byType(Material))
          .first;
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Edit node')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Focus subtree'));
      await tester.pumpAndSettle();
    }

    await focusLevel6();
    expect(find.text('root › … › level5 › level6'), findsOneWidget);
    expect(find.text('level1'), findsNothing);
    await tester.tap(find.byTooltip('Go to parent'));
    await tester.pumpAndSettle();
    expect(find.text('root › … › level4 › level5'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to root'));
    await tester.pumpAndSettle();
    expect(find.text('level1'), findsOneWidget);

    await focusLevel6();
    await showTree('{"different":{}}');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back to root'), findsNothing);
    expect(find.text('different'), findsOneWidget);
  });
}
