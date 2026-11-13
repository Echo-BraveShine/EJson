import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum JsonTreeStyle {
  classic,
  colorByType,
  striped,
  compact,
  outline;

  String label(AppLocalizations strings) => switch (this) {
    classic => strings.treeStyleClassic,
    colorByType => strings.treeStyleColor,
    striped => strings.treeStyleStriped,
    compact => strings.treeStyleCompact,
    outline => strings.treeStyleOutline,
  };

  double get rowHeight => this == compact ? 28 : 34;
  double get indent => this == compact ? 10 : 12;

  Color valueColor(JsonKind kind, ColorScheme colors) {
    if (this == outline || kind == JsonKind.object || kind == JsonKind.array) {
      return colors.onSurfaceVariant;
    }
    if (this != colorByType) return colors.primary;

    final dark = colors.brightness == Brightness.dark;
    return switch (kind) {
      JsonKind.string =>
        dark ? const Color(0xff8cdaa7) : const Color(0xff126445),
      JsonKind.number =>
        dark ? const Color(0xffa4c8ff) : const Color(0xff174f96),
      JsonKind.boolean =>
        dark ? const Color(0xffd5b6ff) : const Color(0xff713bad),
      _ => colors.onSurfaceVariant,
    };
  }
}
