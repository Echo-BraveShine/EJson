part of 'settings_panel.dart';

extension _SettingsPages on _SettingsPanelState {
  Map<_SettingsCategory, List<Widget>> _pages() {
    final strings = AppLocalizations.of(context);
    final format = ref.watch(toolPreferencesProvider).format;
    final colors = Theme.of(context).colorScheme;
    return <_SettingsCategory, List<Widget>>{
      _SettingsCategory.general: [
        _SettingsCard(
          children: [
            _SettingsRow(
              label: strings.diskSyncSetting,
              icon: CupertinoIcons.arrow_2_circlepath,
              child: Tooltip(
                message: strings.diskSyncDescription,
                child: Semantics(
                  label: strings.diskSyncSetting,
                  child: CupertinoSwitch(
                    value: ref.watch(toolPreferencesProvider).syncDiskFiles,
                    activeTrackColor: colors.primary,
                    onChanged: _savingDiskSyncPreference ? null : _setDiskSync,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _SettingsRow(
              label: strings.autosaveDrafts,
              icon: CupertinoIcons.floppy_disk,
              child: Tooltip(
                message: strings.autosaveDescription,
                child: Semantics(
                  label: strings.autosaveDrafts,
                  child: CupertinoSwitch(
                    value: ref.watch(toolPreferencesProvider).autosave,
                    activeTrackColor: colors.primary,
                    onChanged: _savingAutosavePreference ? null : _setAutosave,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _SettingsRow(
              label: strings.restoreWorkspace,
              icon: CupertinoIcons.clock,
              child: Semantics(
                label: strings.restoreWorkspace,
                child: CupertinoSwitch(
                  value: _restoreOnStartup,
                  activeTrackColor: colors.primary,
                  onChanged: _savingRestorePreference
                      ? null
                      : _setRestoreOnStartup,
                ),
              ),
            ),
            const Divider(height: 1),
            _SettingsRow(
              label: strings.language,
              icon: CupertinoIcons.globe,
              child: _SettingsSelector(
                options: {
                  'system': strings.systemLanguage,
                  'en': strings.english,
                  'zh': strings.simplifiedChinese,
                },
                selected: _language ?? 'system',
                onChanged: (value) {
                  final language = value == 'system' ? null : value;
                  _updateView(() => _language = language);
                  widget.onLanguageChanged(language);
                },
              ),
            ),
          ],
        ),
      ],
      _SettingsCategory.appearance: [
        _SettingsCard(
          children: [
            _SettingsRow(
              label: strings.themePreset,
              icon: CupertinoIcons.paintbrush,
              child: _StylePicker<String>(
                label: strings.themePreset,
                options: {
                  '': strings.themeCustom,
                  'paper': strings.themeWarmPaper,
                  'github': 'GitHub',
                  'darcula': 'Darcula',
                  'tokyo': 'Tokyo Night',
                  'contrast': strings.highlightAccessibility,
                },
                selected: switch ((
                  _colorTheme,
                  _highlight,
                  _theme,
                  _treeStyle,
                )) {
                  (
                    AppColorTheme.amber,
                    JsonHighlight.atomOne,
                    ThemeMode.light,
                    JsonTreeStyle.structure,
                  ) =>
                    'paper',
                  (
                    AppColorTheme.slate,
                    JsonHighlight.github,
                    ThemeMode.system,
                    JsonTreeStyle.structure,
                  ) =>
                    'github',
                  (
                    AppColorTheme.steel,
                    JsonHighlight.darcula,
                    ThemeMode.dark,
                    JsonTreeStyle.structure,
                  ) =>
                    'darcula',
                  (
                    AppColorTheme.purple,
                    JsonHighlight.tokyoNight,
                    ThemeMode.dark,
                    JsonTreeStyle.structure,
                  ) =>
                    'tokyo',
                  (
                    AppColorTheme.blue,
                    JsonHighlight.accessibility,
                    ThemeMode.system,
                    JsonTreeStyle.structure,
                  ) =>
                    'contrast',
                  _ => '',
                },
                onChanged: (preset) {
                  if (preset.isEmpty) return;
                  final (color, highlight, mode) = switch (preset) {
                    'paper' => (
                      AppColorTheme.amber,
                      JsonHighlight.atomOne,
                      ThemeMode.light,
                    ),
                    'darcula' => (
                      AppColorTheme.steel,
                      JsonHighlight.darcula,
                      ThemeMode.dark,
                    ),
                    'tokyo' => (
                      AppColorTheme.purple,
                      JsonHighlight.tokyoNight,
                      ThemeMode.dark,
                    ),
                    'contrast' => (
                      AppColorTheme.blue,
                      JsonHighlight.accessibility,
                      ThemeMode.system,
                    ),
                    _ => (
                      AppColorTheme.slate,
                      JsonHighlight.github,
                      ThemeMode.system,
                    ),
                  };
                  _updateView(() {
                    _colorTheme = color;
                    _highlight = highlight;
                    _theme = mode;
                    _treeStyle = JsonTreeStyle.structure;
                  });
                  widget.onColorThemeChanged(color);
                  widget.onHighlightChanged(highlight);
                  widget.onThemeChanged(mode);
                  widget.onTreeStyleChanged(JsonTreeStyle.structure);
                },
              ),
            ),
          ],
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              label: strings.appearance,
              icon: CupertinoIcons.circle_lefthalf_fill,
              child: _SettingsSelector(
                options: {
                  ThemeMode.system: strings.systemTheme,
                  ThemeMode.light: strings.lightTheme,
                  ThemeMode.dark: strings.darkTheme,
                },
                selected: _theme,
                onChanged: (mode) {
                  _updateView(() => _theme = mode);
                  widget.onThemeChanged(mode);
                },
              ),
            ),
            const Divider(height: 1),
            _SettingsRow(
              label: strings.glassToolbar,
              icon: CupertinoIcons.rectangle_on_rectangle,
              child: Semantics(
                label: strings.glassToolbar,
                child: CupertinoSwitch(
                  value: _glass,
                  activeTrackColor: colors.primary,
                  onChanged: (value) {
                    _updateView(() => _glass = value);
                    widget.onGlassChanged(value);
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            _SettingsRow(
              label: strings.colorTheme,
              icon: CupertinoIcons.color_filter,
              child: _StylePicker<AppColorTheme>(
                label: strings.colorTheme,
                options: {
                  AppColorTheme.systemDefault: strings.colorThemeSystemDefault,
                  AppColorTheme.blue: strings.colorThemeBlue,
                  AppColorTheme.amber: strings.colorThemeAmber,
                  AppColorTheme.green: strings.colorThemeGreen,
                  AppColorTheme.purple: strings.colorThemePurple,
                  AppColorTheme.rose: strings.colorThemeRose,
                  AppColorTheme.websiteBlue: strings.colorThemeWebsiteBlue,
                  AppColorTheme.slate: strings.colorThemeSlate,
                  AppColorTheme.steel: strings.colorThemeSteel,
                },
                selected: _colorTheme,
                onChanged: (theme) {
                  _updateView(() => _colorTheme = theme);
                  widget.onColorThemeChanged(theme);
                },
              ),
            ),
          ],
        ),
        _SettingsCard(
          children: [
            _SettingsRow(
              label: strings.jsonHighlight,
              icon: CupertinoIcons.paintbrush,
              child: _StylePicker(
                label: strings.jsonHighlight,
                options: {
                  for (final style in JsonHighlight.values)
                    style: style.label(strings),
                },
                selected: _highlight,
                onChanged: (style) {
                  _updateView(() => _highlight = style);
                  widget.onHighlightChanged(style);
                },
              ),
            ),
            const Divider(height: 1),
            _SettingsRow(
              label: strings.treeStyle,
              icon: CupertinoIcons.list_bullet_indent,
              child: _StylePicker(
                label: strings.treeStyle,
                options: {
                  for (final style in JsonTreeStyle.values)
                    style: style.label(strings),
                },
                selected: _treeStyle,
                onChanged: (style) {
                  _updateView(() => _treeStyle = style);
                  widget.onTreeStyleChanged(style);
                },
              ),
            ),
            const Divider(height: 1),
            _SettingsRow(
              label: strings.treeConnectors,
              icon: Icons.account_tree_outlined,
              child: Semantics(
                label: strings.treeConnectors,
                child: CupertinoSwitch(
                  value: ref.watch(toolPreferencesProvider).treeConnectors,
                  activeTrackColor: colors.primary,
                  onChanged: _savingTreeConnectors ? null : _setTreeConnectors,
                ),
              ),
            ),
            const Divider(height: 1),
            _SettingsRow(
              label: strings.sourceFolding,
              icon: CupertinoIcons.chevron_down,
              child: Semantics(
                label: strings.sourceFolding,
                child: CupertinoSwitch(
                  value: ref.watch(toolPreferencesProvider).sourceFolding,
                  activeTrackColor: colors.primary,
                  onChanged: _savingSourceFolding ? null : _setSourceFolding,
                ),
              ),
            ),
          ],
        ),
        _SettingsCard(children: [_appearancePreview()]),
      ],
      _SettingsCategory.reading: [
        _SettingsCard(children: [_readingSettings()]),
      ],
      _SettingsCategory.formatting: [
        _SettingsCard(
          children: [
            _SettingsRow(
              label: strings.formatIndentation,
              icon: CupertinoIcons.increase_indent,
              child: _StylePicker<JsonIndentation>(
                label: strings.formatIndentation,
                options: {
                  JsonIndentation.twoSpaces: strings.indentTwo,
                  JsonIndentation.fourSpaces: strings.indentFour,
                  JsonIndentation.eightSpaces: strings.indentEight,
                  JsonIndentation.tabs: strings.indentTabs,
                },
                selected: format.indentation,
                onChanged: _savingFormat
                    ? null
                    : (indentation) => _setFormat(
                        JsonFormatOptions(
                          indentation: indentation,
                          lineEnding: format.lineEnding,
                        ),
                      ),
              ),
            ),
            const Divider(height: 1),
            _SettingsRow(
              label: strings.lineEnding,
              icon: CupertinoIcons.return_icon,
              child: _StylePicker<JsonLineEnding>(
                label: strings.lineEnding,
                options: {
                  JsonLineEnding.preserve: strings.preserveLineEnding,
                  JsonLineEnding.lf: 'LF',
                  JsonLineEnding.crlf: 'CRLF',
                  JsonLineEnding.cr: 'CR',
                },
                selected: format.lineEnding,
                onChanged: _savingFormat
                    ? null
                    : (lineEnding) => _setFormat(
                        JsonFormatOptions(
                          indentation: format.indentation,
                          lineEnding: lineEnding,
                        ),
                      ),
              ),
            ),
            if (_formatSaveFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: WorkbenchStyle.space8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    strings.toolPreferenceFailed,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
          ],
        ),
      ],
      _SettingsCategory.about: [
        const _SettingsCard(children: [_ReleaseSettings()]),
      ],
    };
  }

  Widget _appearancePreview() {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
      side: BorderSide(color: colors.outlineVariant),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WorkbenchStyle.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.highlightPreview, style: WorkbenchStyle.label),
          const SizedBox(height: WorkbenchStyle.space8),
          Material(
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 150,
              child: EJsonCodeEditor(
                key: const ValueKey('appearance-code-preview'),
                highlight: _highlight,
                source: _SettingsPanelState._appearanceSource,
                onChanged: (_) {},
                readOnly: true,
                useWorkspaceShortcuts: false,
              ),
            ),
          ),
          const SizedBox(height: WorkbenchStyle.space16),
          Text(strings.treePreview, style: WorkbenchStyle.label),
          const SizedBox(height: WorkbenchStyle.space8),
          Material(
            shape: shape,
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 210,
              child: TreePanel(
                highlight: _highlight,
                key: const ValueKey('appearance-tree-preview'),
                snapshot: _appearanceSnapshot,
                source: _SettingsPanelState._appearanceSource,
                style: _treeStyle,
                showConnectors: ref
                    .watch(toolPreferencesProvider)
                    .treeConnectors,
                current: true,
                readOnly: true,
                onReveal: (_) {},
                onEdit: (_, key) {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setFormat(JsonFormatOptions value) async {
    _updateView(() {
      _savingFormat = true;
      _formatSaveFailed = false;
    });
    final saved = await ref
        .read(toolPreferencesProvider.notifier)
        .setFormat(value);
    if (mounted) {
      _updateView(() {
        _savingFormat = false;
        _formatSaveFailed = !saved;
      });
    }
  }
}
