import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/design/workbench_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'input geometry and border states stay consistent in $brightness',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: workbenchTheme(brightness),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    WorkbenchTextField(hintText: 'Search'),
                    WorkbenchTextField(labelText: 'Name'),
                    WorkbenchTextField(
                      hintText: 'Filter',
                      prefixIcon: Icon(Icons.search),
                    ),
                    WorkbenchTextField(
                      labelText: 'Path',
                      errorText: 'Invalid path',
                    ),
                    WorkbenchTextField(
                      labelText: 'Schema',
                      minLines: 3,
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final inputs = find.byType(TextField);
        for (var i = 0; i < 4; i++) {
          expect(
            tester.getSize(inputs.at(i)).height,
            WorkbenchStyle.inputHeight,
          );
          final painted = InputDecorator.containerOf(
            tester.element(find.byType(EditableText).at(i)),
          )!;
          expect(painted.size.height, WorkbenchStyle.inputHeight);
          final widget = tester.widget<TextField>(inputs.at(i));
          final decoration = widget.decoration!.applyDefaults(
            Theme.of(tester.element(inputs.at(i))).inputDecorationTheme,
          );
          for (final border in [
            decoration.enabledBorder,
            decoration.focusedBorder,
            decoration.disabledBorder,
            decoration.errorBorder,
            decoration.focusedErrorBorder,
          ]) {
            final outline = border! as OutlineInputBorder;
            expect(
              outline.borderRadius,
              BorderRadius.circular(WorkbenchStyle.controlRadius),
            );
            expect(outline.borderSide.width, 1);
          }
          final colors = Theme.of(tester.element(inputs.at(i))).colorScheme;
          expect(
            decoration.enabledBorder!.borderSide.color,
            i == 3 ? colors.error : colors.outlineVariant,
          );
          expect(
            decoration.focusedBorder!.borderSide.color,
            i == 3 ? colors.error : colors.primary,
          );
        }
        expect(
          tester.getSize(inputs.last).height,
          greaterThan(WorkbenchStyle.inputHeight),
        );
        await tester.tap(inputs.first);
        await tester.pumpAndSettle();
        expect(tester.getSize(inputs.first).height, WorkbenchStyle.inputHeight);
        expect(find.text('Invalid path'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('large text grows single-line input without clipping', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: workbenchTheme(Brightness.light),
        home: const Scaffold(
          body: WorkbenchTextField(
            style: TextStyle(fontSize: 32),
            labelText: 'Value',
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThan(WorkbenchStyle.inputHeight),
    );
    expect(
      InputDecorator.containerOf(
        tester.element(find.byType(EditableText)),
      )!.size.height,
      tester.getSize(find.byType(TextField)).height,
    );
    await tester.enterText(find.byType(TextField), '中文 abc 123');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
