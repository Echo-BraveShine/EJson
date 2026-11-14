import 'package:flutter/material.dart';

/// Bundled CJK coverage also works on desktops without Chinese system fonts.
abstract final class WorkbenchTypography {
  static const cjkFamily = 'EJson Noto Sans SC';

  static String? interfaceFamily(TargetPlatform platform) => switch (platform) {
    TargetPlatform.windows => 'Segoe UI',
    TargetPlatform.linux => cjkFamily,
    _ => null,
  };

  static List<String> interfaceFallback(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.windows => [cjkFamily, 'Segoe UI Emoji'],
        TargetPlatform.linux => [cjkFamily, 'Noto Color Emoji'],
        TargetPlatform.macOS ||
        TargetPlatform.iOS => ['PingFang SC', cjkFamily, 'Apple Color Emoji'],
        _ => [cjkFamily],
      };

  static List<String> codeFallback(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.macOS || TargetPlatform.iOS => [
          'Menlo',
          'PingFang SC',
          cjkFamily,
          'Apple Color Emoji',
        ],
        TargetPlatform.windows => ['Consolas', cjkFamily, 'Segoe UI Emoji'],
        _ => ['monospace', cjkFamily, 'Noto Color Emoji'],
      };
}
