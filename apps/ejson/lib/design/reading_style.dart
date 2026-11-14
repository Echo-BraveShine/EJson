import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../settings/installed_fonts.dart';
import '../settings/reading_preferences.dart';
import 'workbench_style.dart';

class ReadingStyle {
  ReadingStyle._(this.text, this.lineHeight, this.scaledFontSize);

  factory ReadingStyle.resolve(
    BuildContext context,
    ReadingPreferences preferences,
    List<InstalledFont>? fonts,
  ) {
    final platform = Theme.of(context).platform;
    final family =
        findInstalledFont(fonts, preferences.fontFamily)?.family ??
        WorkbenchStyle.codeFont(platform);
    final fallback = switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.iOS => ['Menlo', 'PingFang SC', 'Apple Color Emoji'],
      TargetPlatform.windows => [
        'Consolas',
        'Microsoft YaHei',
        'Segoe UI Emoji',
      ],
      _ => ['monospace', 'Noto Sans CJK SC', 'Noto Color Emoji'],
    };
    final text = WorkbenchStyle.code(platform).copyWith(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: preferences.fontSize.toDouble(),
      height: preferences.lineSpacing.height,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: 'Ag中🙂', style: text),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final height = painter.height.ceilToDouble();
    painter.dispose();
    return ReadingStyle._(
      text,
      height,
      scaler.scale(preferences.fontSize.toDouble()),
    );
  }

  static ReadingStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadingStyleScope>()?.style ??
      ReadingStyle.resolve(context, const ReadingPreferences(), null);

  final TextStyle text;
  final double lineHeight;
  final double scaledFontSize;

  double rowHeight({
    double minimum = WorkbenchStyle.rowHeight,
    double padding = 12,
  }) => math.max(minimum, lineHeight + padding);
  double get widthScale => math.max(1, scaledFontSize / 13);
}

class ReadingStyleScope extends InheritedWidget {
  const ReadingStyleScope({
    super.key,
    required this.style,
    required super.child,
  });

  final ReadingStyle style;

  @override
  bool updateShouldNotify(ReadingStyleScope oldWidget) =>
      oldWidget.style.text != style.text ||
      oldWidget.style.lineHeight != style.lineHeight ||
      oldWidget.style.scaledFontSize != style.scaledFontSize;
}
