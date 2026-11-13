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
  monochrome;

  String label(AppLocalizations strings) => switch (this) {
    atomOne => 'Atom One',
    github => 'GitHub',
    visualStudio => 'Visual Studio',
    tokyoNight => 'Tokyo Night',
    stackOverflow => 'Stack Overflow',
    accessibility => strings.highlightAccessibility,
    monochrome => strings.highlightMonochrome,
  };

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
    };
  }
}
