import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'design/workbench_style.dart';
import 'editor/json_highlight.dart';
import 'editor/tree_style.dart';
import 'l10n/app_localizations.dart';
import 'workspace/workbench.dart';
import 'workspace/workspace.dart';
import 'workspace/workspace_session.dart';

const _languageKey = 'language';
const _themeModeKey = 'themeMode';
const _highlightKey = 'jsonHighlight';
const _treeStyleKey = 'jsonTreeStyle';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  final preferences = SharedPreferencesAsync();
  var themeMode = ThemeMode.system;
  try {
    final saved = await preferences.getString(_themeModeKey);
    themeMode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  } on PlatformException catch (error) {
    debugPrint('Could not read appearance preference: ${error.code}');
  }
  final launchBrightness = switch (themeMode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => binding.platformDispatcher.platformBrightness,
  };
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: 'EJson',
      size: const Size(1120, 740),
      minimumSize: const Size(720, 460),
      center: true,
      backgroundColor: workbenchTheme(launchBrightness).scaffoldBackgroundColor,
    ),
  );
  String? language;
  var highlight = JsonHighlight.atomOne;
  var treeStyle = JsonTreeStyle.classic;
  try {
    language = await preferences.getString(_languageKey);
    final saved = await preferences.getString(_highlightKey);
    highlight = JsonHighlight.values.firstWhere(
      (style) => style.name == saved,
      orElse: () => JsonHighlight.atomOne,
    );
    final savedTreeStyle = await preferences.getString(_treeStyleKey);
    treeStyle = JsonTreeStyle.values.firstWhere(
      (style) => style.name == savedTreeStyle,
      orElse: () => JsonTreeStyle.classic,
    );
  } on PlatformException catch (error) {
    debugPrint('Could not read preferences: ${error.code}');
  }
  final session = WorkspaceSession(preferences);
  var restoreOnStartup = true;
  var restored = const RestoredWorkspace();
  try {
    restoreOnStartup = await session.isEnabled();
    if (restoreOnStartup) restored = await session.restore();
  } on Exception catch (error) {
    debugPrint('Could not read the saved workspace: ${error.runtimeType}');
  }
  runApp(
    ProviderScope(
      overrides: [
        initialWorkspaceProvider.overrideWithValue((
          files: restored.files,
          activePath: restored.activePath,
        )),
      ],
      child: EJsonApp(
        manageWindow: true,
        workspaceSession: session,
        restoreOnStartup: restoreOnStartup,
        failedRestorePaths: restored.failedPaths,
        initialLanguage: language,
        initialThemeMode: themeMode,
        saveThemeMode: (mode) =>
            preferences.setString(_themeModeKey, mode.name),
        initialHighlight: highlight,
        initialTreeStyle: treeStyle,
        saveTreeStyle: (style) =>
            preferences.setString(_treeStyleKey, style.name),
        saveHighlight: (style) =>
            preferences.setString(_highlightKey, style.name),
        saveLanguage: (value) => value == null
            ? preferences.remove(_languageKey)
            : preferences.setString(_languageKey, value),
      ),
    ),
  );
  await binding.waitUntilFirstFrameRasterized;
  if (Platform.isMacOS) {
    await const MethodChannel(
      'dev.ekko.ejson/appearance',
    ).invokeMethod<void>('allowWindowDisplay');
  }
  await windowManager.show();
  await windowManager.focus();
}

class EJsonApp extends StatefulWidget {
  const EJsonApp({
    super.key,
    this.manageWindow = false,
    this.workspaceSession,
    this.restoreOnStartup = true,
    this.failedRestorePaths = const [],
    this.initialLanguage,
    this.saveLanguage,
    this.initialThemeMode = ThemeMode.system,
    this.saveThemeMode,
    this.initialHighlight = JsonHighlight.atomOne,
    this.saveHighlight,
    this.initialTreeStyle = JsonTreeStyle.classic,
    this.saveTreeStyle,
  });
  final bool manageWindow;
  final WorkspaceSession? workspaceSession;
  final bool restoreOnStartup;
  final List<String> failedRestorePaths;
  final String? initialLanguage;
  final ThemeMode initialThemeMode;
  final JsonHighlight initialHighlight;
  final JsonTreeStyle initialTreeStyle;
  final Future<void> Function(JsonTreeStyle)? saveTreeStyle;
  final Future<void> Function(JsonHighlight)? saveHighlight;
  final Future<void> Function(String?)? saveLanguage;
  final Future<void> Function(ThemeMode)? saveThemeMode;

  @override
  State<EJsonApp> createState() => _EJsonAppState();
}

class _EJsonAppState extends State<EJsonApp> {
  late ThemeMode mode = widget.initialThemeMode;
  Future<void> _pendingThemeSave = Future<void>.value();
  late JsonHighlight highlight = widget.initialHighlight;
  late JsonTreeStyle treeStyle = widget.initialTreeStyle;
  late String? language = switch (widget.initialLanguage) {
    'en' || 'zh' => widget.initialLanguage,
    _ => null,
  };

  void _selectLanguage(String? value) {
    setState(() => language = value);
    unawaited(_persistLanguage(value));
  }

  void _selectTheme(ThemeMode value) {
    setState(() => mode = value);
    _pendingThemeSave = _pendingThemeSave.then((_) async {
      try {
        await widget.saveThemeMode?.call(value);
      } on PlatformException catch (error) {
        debugPrint('Could not save appearance preference: ${error.code}');
      }
    });
  }

  Future<void> _persistLanguage(String? value) async {
    try {
      await widget.saveLanguage?.call(value);
    } on PlatformException catch (error) {
      debugPrint('Could not save language preference: ${error.code}');
    }
  }

  Future<void> _selectHighlight(JsonHighlight value) async {
    setState(() => highlight = value);
    try {
      await widget.saveHighlight?.call(value);
    } on PlatformException catch (error) {
      debugPrint('Could not save JSON highlight preference: ${error.code}');
    }
  }

  Future<void> _selectTreeStyle(JsonTreeStyle value) async {
    setState(() => treeStyle = value);
    try {
      await widget.saveTreeStyle?.call(value);
    } on PlatformException catch (error) {
      debugPrint('Could not save JSON tree style preference: ${error.code}');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EJson',
    locale: language == null ? null : Locale(language!),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    debugShowCheckedModeBanner: false,
    theme: workbenchTheme(Brightness.light),
    darkTheme: workbenchTheme(Brightness.dark),
    themeMode: mode,
    home: Workbench(
      manageWindow: widget.manageWindow,
      workspaceSession: widget.workspaceSession,
      restoreOnStartup: widget.restoreOnStartup,
      failedRestorePaths: widget.failedRestorePaths,
      themeMode: mode,
      highlight: highlight,
      onHighlightChanged: _selectHighlight,
      treeStyle: treeStyle,
      onTreeStyleChanged: _selectTreeStyle,
      language: language,
      onLanguageChanged: _selectLanguage,
      onThemeChanged: _selectTheme,
      waitForThemeSave: () => _pendingThemeSave,
    ),
  );
}
