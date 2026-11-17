import 'package:flutter/material.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/a11y-dark.dart';
import 'package:re_highlight/styles/a11y-light.dart';
import 'package:re_highlight/styles/stackoverflow-dark.dart';
import 'package:re_highlight/styles/stackoverflow-light.dart';
import 'package:re_highlight/styles/tokyo-night-dark.dart';
import 'package:re_highlight/styles/tokyo-night-light.dart';
import 'package:re_highlight/styles/vs.dart';
import 'package:re_highlight/styles/vs2015.dart';

import '../l10n/app_localizations.dart';
import 'package:ejson_core/ejson_core.dart';

enum JsonHighlight {
  atomOne,
  github,
  visualStudio,
  tokyoNight,
  stackOverflow,
  accessibility,
  monochrome,
  intellijLight,
  darcula,
  darculaContrast;

  String label(AppLocalizations strings) => switch (this) {
    atomOne => 'Atom One',
    github => 'GitHub',
    visualStudio => 'Visual Studio',
    tokyoNight => 'Tokyo Night',
    stackOverflow => 'Stack Overflow',
    accessibility => strings.highlightAccessibility,
    monochrome => strings.highlightMonochrome,
    intellijLight => 'IntelliJ Light',
    darcula => 'Darcula',
    darculaContrast => 'Darcula Contrast',
  };

  Color? editorBackground(Brightness brightness) {
    return this == monochrome ? null : _background(brightness);
  }

  Color valueColor(JsonKind kind, ColorScheme scheme) {
    final palette = colors(scheme.brightness);
    final token = switch (kind) {
      JsonKind.string => 'string',
      JsonKind.number => 'number',
      JsonKind.boolean || JsonKind.nil => 'literal',
      _ => 'root',
    };
    return palette?[token]?.color ??
        palette?['root']?.color ??
        scheme.onSurface;
  }

  Map<String, TextStyle>? colors(Brightness brightness) {
    return _paletteCache.putIfAbsent((this, brightness), () {
      final palette = _colors(brightness);
      if (palette == null) return null;
      final background = _background(brightness);
      return {
        for (final entry in palette.entries)
          entry.key: entry.value.copyWith(
            color: entry.value.color == null
                ? null
                : _readable(entry.value.color!, background),
            // The editor paints its background across the full viewport.
            backgroundColor: entry.key == 'root'
                ? background
                : entry.value.backgroundColor,
          ),
      };
    });
  }

  Color _background(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (dark) {
      return switch (this) {
        intellijLight || darcula => const Color(0xff2b2b2b),
        darculaContrast => const Color(0xff1e1f22),
        _ =>
          _colors(brightness)?['root']?.backgroundColor ??
              const Color(0xff1e1e1e),
      };
    }
    return switch (this) {
      atomOne => const Color(0xfffffaf2),
      github => const Color(0xfff5f9ff),
      visualStudio => const Color(0xfff7fafc),
      tokyoNight => const Color(0xfff4f1fb),
      stackOverflow => const Color(0xfffff6ee),
      accessibility => const Color(0xffffffff),
      darcula => const Color(0xfff5f7fa),
      darculaContrast => const Color(0xfff1f4f8),
      intellijLight => const Color(0xfffffdf8),
      monochrome => const Color(0xffffffff),
    };
  }

  Map<String, TextStyle>? _colors(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      atomOne =>
        dark
            ? atomOneDarkTheme
            : {
                ...atomOneLightTheme,
                'root': const TextStyle(color: Color(0xff343b49)),
                'attr': const TextStyle(color: Color(0xff754b91)),
                'string': const TextStyle(color: Color(0xff286247)),
                'number': const TextStyle(color: Color(0xff9b4d23)),
                'literal': const TextStyle(color: Color(0xff355f9c)),
                'comment': const TextStyle(
                  color: Color(0xff69727b),
                  fontStyle: FontStyle.italic,
                ),
              },
      github => dark ? githubDarkTheme : githubTheme,
      visualStudio => dark ? vs2015Theme : vsTheme,
      tokyoNight => dark ? tokyoNightDarkTheme : tokyoNightLightTheme,
      stackOverflow => dark ? stackoverflowDarkTheme : stackoverflowLightTheme,
      accessibility => dark ? a11YDarkTheme : a11YLightTheme,
      monochrome => null,
      intellijLight => dark ? _darcula : _intellijLight,
      darcula => dark ? _darcula : _darculaLight,
      darculaContrast => dark ? _darculaContrast : _darculaContrastLight,
    };
  }
}

// JSON token palettes inspired by the IntelliJ editor schemes.
const _intellijLight = {
  'root': TextStyle(color: Color(0xff080808)),
  'attr': TextStyle(color: Color(0xff871094)),
  'string': TextStyle(color: Color(0xff067d17)),
  'number': TextStyle(color: Color(0xff1750eb)),
  'literal': TextStyle(color: Color(0xff0033b3)),
  'punctuation': TextStyle(color: Color(0xff080808)),
  'comment': TextStyle(color: Color(0xff737373)),
};
const _darcula = {
  'root': TextStyle(color: Color(0xffa9b7c6)),
  'attr': TextStyle(color: Color(0xffc79bd2)),
  'string': TextStyle(color: Color(0xffa5c180)),
  'number': TextStyle(color: Color(0xff6897bb)),
  'literal': TextStyle(color: Color(0xffd58a46)),
  'punctuation': TextStyle(color: Color(0xffa9b7c6)),
  'comment': TextStyle(color: Color(0xff929292)),
};
const _darculaContrast = {
  'root': TextStyle(color: Color(0xffeeeeee)),
  'attr': TextStyle(color: Color(0xffdfb7ef)),
  'string': TextStyle(color: Color(0xffb5d99c)),
  'number': TextStyle(color: Color(0xff8ec7ff)),
  'literal': TextStyle(color: Color(0xffffb66d)),
  'punctuation': TextStyle(color: Color(0xffeeeeee)),
  'comment': TextStyle(color: Color(0xffb0b0b0)),
};

const _darculaLight = {
  'root': TextStyle(color: Color(0xff292a2e)),
  'attr': TextStyle(color: Color(0xff7a3e9d)),
  'string': TextStyle(color: Color(0xff356f2c)),
  'number': TextStyle(color: Color(0xff285f91)),
  'literal': TextStyle(color: Color(0xff9a4d0b)),
  'punctuation': TextStyle(color: Color(0xff292a2e)),
  'comment': TextStyle(color: Color(0xff707070)),
};
const _darculaContrastLight = {
  'root': TextStyle(color: Color(0xff101214)),
  'attr': TextStyle(color: Color(0xff60127a)),
  'string': TextStyle(color: Color(0xff175521)),
  'number': TextStyle(color: Color(0xff064b8e)),
  'literal': TextStyle(color: Color(0xff813400)),
  'punctuation': TextStyle(color: Color(0xff101214)),
  'comment': TextStyle(color: Color(0xff555555)),
};

// Preserve each token's hue while raising low-contrast text to a readable level.
Color _readable(Color foreground, Color background) {
  double contrast(Color color) {
    final a = color.computeLuminance();
    final b = background.computeLuminance();
    return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
  }

  if (contrast(foreground) >= 4.5) return foreground;
  final target = background.computeLuminance() > .179
      ? Colors.black
      : Colors.white;
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 12; i++) {
    final middle = (low + high) / 2;
    if (contrast(Color.lerp(foreground, target, middle)!) < 4.5) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return Color.lerp(foreground, target, high)!;
}

final _paletteCache = <(JsonHighlight, Brightness), Map<String, TextStyle>?>{};
