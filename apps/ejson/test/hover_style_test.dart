import 'dart:ui' as ui;

import 'package:ejson/design/workbench_style.dart';
import 'package:ejson/design/workbench_text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('controls keep their appearance on hover in $brightness', (
      tester,
    ) async {
      final theme = workbenchTheme(brightness);
      for (final overlay in [
        theme.textButtonTheme.style!.overlayColor!,
        theme.filledButtonTheme.style!.overlayColor!,
        theme.iconButtonTheme.style!.overlayColor!,
        theme.outlinedButtonTheme.style!.overlayColor!,
        theme.elevatedButtonTheme.style!.overlayColor!,
        theme.checkboxTheme.overlayColor!,
        theme.radioTheme.overlayColor!,
        theme.switchTheme.overlayColor!,
      ]) {
        expect(overlay.resolve({WidgetState.hovered}), Colors.transparent);
      }
      expect(theme.hoverColor, Colors.transparent);
      expect(
        theme.scrollbarTheme.thumbColor!.resolve({}),
        theme.scrollbarTheme.thumbColor!.resolve({WidgetState.hovered}),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('hover-surface'),
              child: SizedBox(
                width: 300,
                child: Column(
                  children: [
                    TextButton(
                      key: const ValueKey('text'),
                      onPressed: () {},
                      child: const Text('Action'),
                    ),
                    FilledButton(
                      key: const ValueKey('filled'),
                      onPressed: () {},
                      child: const Text('Primary'),
                    ),
                    IconButton(
                      key: const ValueKey('icon'),
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                    ),
                    Checkbox(
                      key: const ValueKey('check'),
                      value: true,
                      onChanged: (_) {},
                    ),
                    ListTile(
                      key: const ValueKey('row'),
                      title: const Text('Row'),
                      onTap: () {},
                    ),
                    const WorkbenchTextField(
                      key: ValueKey('input'),
                      hintText: 'Search',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(790, 590));
      addTearDown(mouse.removePointer);
      Future<Uint8List> pixels() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('hover-surface')),
        );
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        image.dispose();
        return bytes.buffer.asUint8List();
      }

      for (final key in ['text', 'filled', 'icon', 'check', 'row', 'input']) {
        await mouse.moveTo(const Offset(790, 590));
        await tester.pumpAndSettle();
        final before = await pixels();
        await mouse.moveTo(tester.getCenter(find.byKey(ValueKey(key))));
        await tester.pumpAndSettle();
        expect(listEquals(before, await pixels()), isTrue, reason: key);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
