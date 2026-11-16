import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';

Future<void> settleDocumentEdits(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

Future<void> clickTabClose(
  WidgetTester tester,
  String name, {
  String? tooltip,
}) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getCenter(find.text(name)));
  try {
    await tester.pump();
    await tester.tap(find.byTooltip(tooltip ?? 'Close $name'));
  } finally {
    await mouse.removePointer();
  }
}
