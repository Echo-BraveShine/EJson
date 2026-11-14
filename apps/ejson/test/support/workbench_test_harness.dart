import 'package:flutter_test/flutter_test.dart';

Future<void> settleDocumentEdits(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}
