import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'dart:math' as math;

class HierarchyGuidePainter extends CustomPainter {
  const HierarchyGuidePainter(
    this.continuation,
    this.indent,
    this.color, {
    this.expanded = false,
  });
  final List<bool> continuation;
  final double indent;
  final Color color;
  final bool expanded;

  void _dash(Canvas canvas, Paint paint, Offset start, Offset end) {
    final length = (end - start).distance;
    if (length == 0) return;
    final direction = (end - start) / length;
    for (double position = 0; position < length; position += 5) {
      canvas.drawLine(
        start + direction * position,
        start + direction * math.min(position + 2, length),
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1;
    for (var level = 0; level < continuation.length; level++) {
      final x = 16 + indent * level;
      final lastLevel = level == continuation.length - 1;
      if (lastLevel || continuation[level]) {
        _dash(
          canvas,
          paint,
          Offset(x, 0),
          Offset(
            x,
            lastLevel && !continuation[level] ? size.height / 2 : size.height,
          ),
        );
      }
      if (lastLevel) {
        _dash(
          canvas,
          paint,
          Offset(x, size.height / 2),
          Offset(x + indent, size.height / 2),
        );
      }
    }
    if (expanded) {
      final x = 16 + indent * continuation.length;
      _dash(
        canvas,
        paint,
        Offset(x, size.height / 2 + 6),
        Offset(x, size.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant HierarchyGuidePainter oldDelegate) =>
      indent != oldDelegate.indent ||
      color != oldDelegate.color ||
      expanded != oldDelegate.expanded ||
      !listEquals(continuation, oldDelegate.continuation);
}
