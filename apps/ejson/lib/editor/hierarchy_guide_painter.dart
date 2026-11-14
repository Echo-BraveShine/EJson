import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;

class HierarchyGuidePainter extends CustomPainter {
  const HierarchyGuidePainter(this.continuation, this.indent, this.color);
  final List<bool> continuation;
  final double indent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var level = 0; level < continuation.length; level++) {
      final x = 16 + indent * level;
      final lastLevel = level == continuation.length - 1;
      if (lastLevel || continuation[level]) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(
            x,
            lastLevel && !continuation[level] ? size.height / 2 : size.height,
          ),
          paint,
        );
      }
      if (lastLevel) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(x + indent, size.height / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant HierarchyGuidePainter oldDelegate) =>
      indent != oldDelegate.indent ||
      color != oldDelegate.color ||
      !listEquals(continuation, oldDelegate.continuation);
}
