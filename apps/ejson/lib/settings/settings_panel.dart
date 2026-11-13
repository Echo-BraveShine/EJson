import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl, CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/workbench_style.dart';
import '../editor/json_highlight.dart';
import '../editor/tree_style.dart';
import '../l10n/app_localizations.dart';
import 'release_updates.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.themeMode,
    required this.restoreOnStartup,
    required this.onRestoreOnStartupChanged,
    required this.glassEnabled,
    required this.language,
    required this.onThemeChanged,
    required this.highlight,
    required this.onHighlightChanged,
    required this.treeStyle,
    required this.onTreeStyleChanged,
    required this.onGlassChanged,
    required this.onLanguageChanged,
  });

  final ThemeMode themeMode;
  final bool restoreOnStartup;
  final Future<bool> Function(bool) onRestoreOnStartupChanged;
  final JsonHighlight highlight;
  final JsonTreeStyle treeStyle;
  final ValueChanged<JsonTreeStyle> onTreeStyleChanged;
  final ValueChanged<JsonHighlight> onHighlightChanged;
  final bool glassEnabled;
  final String? language;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<bool> onGlassChanged;
  final ValueChanged<String?> onLanguageChanged;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late ThemeMode _theme = widget.themeMode;
  late bool _restoreOnStartup = widget.restoreOnStartup;
  bool _savingRestorePreference = false;

  Future<void> _setRestoreOnStartup(bool value) async {
    setState(() => _savingRestorePreference = true);
    final saved = await widget.onRestoreOnStartupChanged(value);
    if (!mounted) return;
    setState(() {
      if (saved) _restoreOnStartup = value;
      _savingRestorePreference = false;
    });
  }

  late JsonHighlight _highlight = widget.highlight;
  late JsonTreeStyle _treeStyle = widget.treeStyle;
  late bool _glass = widget.glassEnabled;
  late String? _language = widget.language;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return WorkbenchDialog(
      title: strings.settings,
      content: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SettingsGroup(
              label: strings.about,
              icon: CupertinoIcons.info_circle,
              children: const [_ReleaseSettings()],
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            _SettingsGroup(
              label: strings.startup,
              icon: CupertinoIcons.clock,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(strings.restoreWorkspace)),
                    Semantics(
                      label: strings.restoreWorkspace,
                      child: CupertinoSwitch(
                        value: _restoreOnStartup,
                        activeTrackColor: colors.primary,
                        onChanged: _savingRestorePreference
                            ? null
                            : _setRestoreOnStartup,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            _SettingsGroup(
              label: strings.appearance,
              icon: CupertinoIcons.circle_lefthalf_fill,
              children: [
                _SettingsSelector(
                  options: {
                    ThemeMode.system: strings.systemTheme,
                    ThemeMode.light: strings.lightTheme,
                    ThemeMode.dark: strings.darkTheme,
                  },
                  selected: _theme,
                  onChanged: (mode) {
                    setState(() => _theme = mode);
                    widget.onThemeChanged(mode);
                  },
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.glassToolbar,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Semantics(
                      label: strings.glassToolbar,
                      child: CupertinoSwitch(
                        value: _glass,
                        activeTrackColor: colors.primary,
                        onChanged: (value) {
                          setState(() => _glass = value);
                          widget.onGlassChanged(value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            _SettingsGroup(
              label: strings.jsonHighlight,
              icon: CupertinoIcons.paintbrush,
              children: [
                _StylePicker(
                  label: strings.jsonHighlight,
                  options: {
                    for (final style in JsonHighlight.values)
                      style: style.label(strings),
                  },
                  selected: _highlight,
                  onChanged: (style) {
                    setState(() => _highlight = style);
                    widget.onHighlightChanged(style);
                  },
                ),
              ],
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            _SettingsGroup(
              label: strings.treeStyle,
              icon: CupertinoIcons.list_bullet_indent,
              children: [
                _StylePicker(
                  label: strings.treeStyle,
                  options: {
                    for (final style in JsonTreeStyle.values)
                      style: style.label(strings),
                  },
                  selected: _treeStyle,
                  onChanged: (style) {
                    setState(() => _treeStyle = style);
                    widget.onTreeStyleChanged(style);
                  },
                ),
              ],
            ),
            const SizedBox(height: WorkbenchStyle.space12),
            _SettingsGroup(
              label: strings.language,
              icon: CupertinoIcons.globe,
              children: [
                _SettingsSelector(
                  options: {
                    'system': strings.systemLanguage,
                    'en': strings.english,
                    'zh': strings.simplifiedChinese,
                  },
                  selected: _language ?? 'system',
                  onChanged: (value) {
                    final language = value == 'system' ? null : value;
                    setState(() => _language = language);
                    widget.onLanguageChanged(language);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.done),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.label,
    required this.icon,
    required this.children,
  });

  final String label;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(WorkbenchStyle.groupRadius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WorkbenchStyle.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsSelector<T extends Object> extends StatelessWidget {
  const _SettingsSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CupertinoSlidingSegmentedControl<T>(
      backgroundColor: colors.surfaceContainer,
      thumbColor: colors.brightness == Brightness.dark
          ? const Color(0xff565658)
          : colors.surface,
      groupValue: selected,
      children: {
        for (final option in options.entries)
          option.key: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            child: Text(
              option.value,
              textAlign: TextAlign.center,
              style: WorkbenchStyle.body.copyWith(
                color: option.key == selected
                    ? colors.onSurface
                    : colors.onSurfaceVariant,
              ),
            ),
          ),
      },
      onValueChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _StylePicker<T> extends StatelessWidget {
  const _StylePicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 185, maxWidth: 260),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options.entries)
          WorkbenchMenuItem(
            value: option.key,
            checked: option.key == selected,
            icon: CupertinoIcons.circle,
            label: option.value,
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(options[selected]!)),
              Icon(
                CupertinoIcons.chevron_up_chevron_down,
                color: colors.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseSettings extends StatefulWidget {
  const _ReleaseSettings();

  @override
  State<_ReleaseSettings> createState() => _ReleaseSettingsState();
}

class _ReleaseSettingsState extends State<_ReleaseSettings> {
  Version? _version;
  UpdateResult? _result;
  bool _checking = false;
  bool _checkFailed = false;
  bool _browserFailed = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await installedVersion();
      if (mounted) setState(() => _version = version);
    } on Exception {
      // Package metadata may be unavailable in an unpackaged test build.
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
      _checkFailed = false;
    });
    try {
      final version = _version ?? await installedVersion();
      final result = await checkForUpdate(version);
      if (mounted) setState(() => _result = result);
    } on Exception {
      if (mounted) setState(() => _checkFailed = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _open(Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      // The desktop environment may have no default browser.
    }
    if (mounted) setState(() => _browserFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final message = _checking
        ? strings.checkingUpdates
        : _checkFailed
        ? strings.updateFailed
        : switch (_result?.status) {
            UpdateStatus.available => strings.updateAvailable(
              '${_result!.latest}',
            ),
            UpdateStatus.current => strings.updateCurrent,
            UpdateStatus.noRelease => strings.noRelease,
            null => null,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: WorkbenchStyle.space8,
          children: [
            if (_version != null) Text(strings.versionLabel('$_version')),
            TextButton.icon(
              onPressed: _checking ? null : _check,
              icon: const Icon(CupertinoIcons.arrow_clockwise, size: 15),
              label: Text(strings.checkUpdates),
            ),
          ],
        ),
        if (message != null)
          Semantics(
            liveRegion: true,
            child: Text(message, style: theme.textTheme.bodySmall),
          ),
        if (_result?.status == UpdateStatus.available)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _open(latestReleasePage),
              child: Text(strings.downloadRelease),
            ),
          ),
        const Divider(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _open(supportPage),
            icon: const Icon(CupertinoIcons.heart, size: 15),
            label: Text(strings.buyCoffee),
          ),
        ),
        if (_browserFailed)
          Text(strings.browserFailed, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
