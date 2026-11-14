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
    final dark = brightness == Brightness.dark;
    return switch (this) {
      intellijLight => const Color(0xffffffff),
      darcula => dark ? const Color(0xff2b2b2b) : const Color(0xffffffff),
      darculaContrast =>
        dark ? const Color(0xff1e1f22) : const Color(0xffffffff),
      _ => null,
    };
  }

  Map<String, TextStyle>? colors(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      atomOne => dark ? atomOneDarkTheme : atomOneLightTheme,
      github => dark ? githubDarkTheme : githubTheme,
      visualStudio => dark ? vs2015Theme : vsTheme,
      tokyoNight => dark ? tokyoNightDarkTheme : tokyoNightLightTheme,
      stackOverflow => dark ? stackoverflowDarkTheme : stackoverflowLightTheme,
      accessibility => dark ? a11YDarkTheme : a11YLightTheme,
      monochrome => null,
      intellijLight => _intellijLight,
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
