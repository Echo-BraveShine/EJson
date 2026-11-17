import 'package:ejson/editor/code_editor.dart';
import 'package:ejson/editor/json_highlight.dart';
import 'package:ejson/editor/large_source_view.dart';
import 'package:ejson/l10n/app_localizations.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  testWidgets('preview pages preserve Unicode, CRLF and source jumps', (
    tester,
  ) async {
    const pageSize = 16 * 1024;
    final first = '${'a' * (pageSize - 1)}🙂';
    final second = 'next${'b' * (pageSize - 6)}\r\n';
    final source = '$first${second}last';
    Widget view({String? text, ({SourceRange range, int sequence})? jump}) =>
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LargeSourceView(
              source: text ?? source,
              highlight: JsonHighlight.tokyoNight,
              format: DocumentFormat.json,
              jump: jump,
              focusOnJump: false,
            ),
          ),
        );
    EJsonCodeEditor editor() =>
        tester.widget<EJsonCodeEditor>(find.byType(EJsonCodeEditor));

    await tester.pumpWidget(view());
    expect(editor().source, first);
    expect(editor().readOnly, isTrue);
    expect(editor().highlight, JsonHighlight.tokyoNight);
    expect(
      tester.widget<CodeEditor>(find.byType(CodeEditor)).style!.backgroundColor,
      JsonHighlight.tokyoNight.editorBackground(Brightness.light),
    );
    await tester.tap(find.byTooltip('Next source page'));
    await tester.pumpAndSettle();
    expect(editor().source, second);

    final start = first.length + second.length;
    await tester.pumpWidget(
      view(jump: (range: (start: start, end: start + 4), sequence: 1)),
    );
    await tester.pumpAndSettle();
    expect(editor().source, 'last');
    final controller = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    expect(controller.selectedText, 'last');

    await tester.tap(find.byTooltip('Previous source page'));
    await tester.pumpAndSettle();
    expect(editor().source, second);

    await tester.tap(find.text('Page 2 of 3'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1');
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(editor().source, first);

    await tester.pumpWidget(view(text: first));
    await tester.pumpAndSettle();
    expect(find.text('Page 1 of 1'), findsOneWidget);
    expect(editor().source, first);
  });
}
