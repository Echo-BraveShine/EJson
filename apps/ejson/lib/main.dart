import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'design/workbench_style.dart';
import 'editor/json_highlight.dart';
import 'editor/tree_style.dart';
import 'l10n/app_localizations.dart';
import 'settings/tool_preferences.dart';
import 'settings/installed_fonts.dart';
import 'settings/release_updates.dart';
import 'design/reading_style.dart';
import 'workspace/workbench.dart';
import 'workspace/workspace.dart';
import 'workspace/workspace_session.dart';
import 'workspace/external_file_opens.dart';
import 'workspace/recovered_workspace.dart';
import 'workspace/workspace_recovery.dart';
import 'workspace/workspace_autosave.dart';
import 'workspace/disk_sync.dart';

const _languageKey = 'language';
const _themeModeKey = 'themeMode';
const _colorThemeKey = 'colorTheme';
const _highlightKey = 'jsonHighlight';
const _treeStyleKey = 'jsonTreeStyle';

Future<void> main(List<String> arguments) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final externalFiles = ExternalFileOpens(arguments);
  if (Platform.isMacOS) await externalFiles.connectMacOS();
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
  var colorTheme = AppColorTheme.systemDefault;
  try {
    final savedColorTheme = await preferences.getString(_colorThemeKey);
    colorTheme = appColorThemeByName(savedColorTheme ?? '');
  } on PlatformException catch (error) {
    debugPrint('Could not read color theme preference: ${error.code}');
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
      backgroundColor: workbenchTheme(
        launchBrightness,
        colorTheme,
      ).scaffoldBackgroundColor,
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
  var toolPreferences = const ToolPreferences();
  try {
    final saved = await preferences.getString('toolPreferences');
    if (saved != null) {
      toolPreferences = ToolPreferences.fromJson(jsonDecode(saved));
    }
  } on Exception catch (error) {
    debugPrint('Could not read tool preferences: ${error.runtimeType}');
  }
  final session = WorkspaceSession(preferences);
  var restoreOnStartup = true;
  var restored = const RestoredWorkspace();
  try {
    restoreOnStartup = await session.isEnabled();
  } on Exception catch (error) {
    debugPrint('Could not read the saved workspace: ${error.runtimeType}');
  }
  WorkspaceRecovery? recovery;
  RecoveredWorkspace? recovered;
  final recoveryFailures = <String>[];
  try {
    final support = await getApplicationSupportDirectory();
    final directory = Directory.fromUri(support.uri.resolve('Recovery/'));
    recovery = await WorkspaceRecovery.open(
      directory,
      bookmarkFor: session.bookmarkFor,
      accessFile: session.accessFile,
    );
    try {
      recovered = await recovery.restore(restoreCleanFiles: restoreOnStartup);
      if (recovered != null && recovered.documents.isEmpty) {
        recoveryFailures.addAll(recovered.failedPaths);
        recovered = null;
      }
    } on Exception catch (error) {
      recoveryFailures.add(directory.path);
      debugPrint('Could not recover drafts: ${error.runtimeType}');
    }
  } on Exception catch (error) {
    debugPrint('Could not initialize recovery: ${error.runtimeType}');
  }
  if (recovered == null && restoreOnStartup) {
    try {
      restored = await session.restore();
    } on Exception catch (error) {
      debugPrint('Could not restore the saved workspace: ${error.runtimeType}');
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        startupUpdateCheckProvider.overrideWithValue(
          () async => checkForUpdate(await installedVersion()),
        ),
        externalFileOpensProvider.overrideWithValue(externalFiles),
        initialToolPreferencesProvider.overrideWithValue(toolPreferences),
        workspaceRecoveryProvider.overrideWithValue(recovery),
        diskSyncAvailableProvider.overrideWithValue(true),
        initialRecoveredWorkspaceProvider.overrideWithValue(recovered),
        saveToolPreferencesProvider.overrideWithValue(
          (value) => preferences.setString(
            'toolPreferences',
            jsonEncode(value.toJson()),
          ),
        ),
        initialWorkspaceProvider.overrideWithValue((
          files: restored.files,
          activePath: restored.activePath,
        )),
      ],
      child: EJsonApp(
        manageWindow: true,
        workspaceSession: session,
        recoveryUnavailable: recovery == null,
        restoreOnStartup: restoreOnStartup,
        failedRestorePaths: [
          ...restored.failedPaths,
          ...?recovered?.failedPaths,
          ...recoveryFailures,
        ],
        initialLanguage: language,
        initialThemeMode: themeMode,
        saveThemeMode: (mode) =>
            preferences.setString(_themeModeKey, mode.name),
        initialColorTheme: colorTheme,
        saveColorTheme: (theme) =>
            preferences.setString(_colorThemeKey, theme.name),
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
    this.recoveryUnavailable = false,
    this.restoreOnStartup = true,
    this.failedRestorePaths = const [],
    this.initialLanguage,
    this.saveLanguage,
    this.initialThemeMode = ThemeMode.system,
    this.saveThemeMode,
    this.initialColorTheme = AppColorTheme.systemDefault,
    this.saveColorTheme,
    this.initialHighlight = JsonHighlight.atomOne,
    this.saveHighlight,
    this.initialTreeStyle = JsonTreeStyle.classic,
    this.saveTreeStyle,
  });
  final bool manageWindow;
  final WorkspaceSession? workspaceSession;
  final bool recoveryUnavailable;
  final bool restoreOnStartup;
  final List<String> failedRestorePaths;
  final String? initialLanguage;
  final ThemeMode initialThemeMode;
  final AppColorTheme initialColorTheme;
  final Future<void> Function(AppColorTheme)? saveColorTheme;
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
  late AppColorTheme colorTheme = widget.initialColorTheme;
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

  void _selectColorTheme(AppColorTheme value) {
    setState(() => colorTheme = value);
    _pendingThemeSave = _pendingThemeSave.then((_) async {
      try {
        await widget.saveColorTheme?.call(value);
      } on PlatformException catch (error) {
        debugPrint('Could not save color theme preference: ${error.code}');
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
    builder: (context, child) => Consumer(
      builder: (context, ref, _) {
        final reading = ref.watch(toolPreferencesProvider).reading;
        final fonts = ref.watch(installedFontsProvider).value;
        return ReadingStyleScope(
          style: ReadingStyle.resolve(context, reading, fonts),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
    locale: language == null ? null : Locale(language!),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    debugShowCheckedModeBanner: false,
    theme: workbenchTheme(Brightness.light, colorTheme),
    darkTheme: workbenchTheme(Brightness.dark, colorTheme),
    themeMode: mode,
    home: Workbench(
      manageWindow: widget.manageWindow,
      workspaceSession: widget.workspaceSession,
      recoveryUnavailable: widget.recoveryUnavailable,
      restoreOnStartup: widget.restoreOnStartup,
      failedRestorePaths: widget.failedRestorePaths,
      themeMode: mode,
      colorTheme: colorTheme,
      onColorThemeChanged: _selectColorTheme,
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
