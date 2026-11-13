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
    final colors = Theme.of(context).colorScheme;
    return WorkbenchDialog(
      title: strings.settings,
      content: SizedBox(
        width: 460,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(WorkbenchStyle.groupRadius),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WorkbenchStyle.space12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      setState(() => _theme = mode);
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
                        setState(() => _glass = value);
                        widget.onGlassChanged(value);
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
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
                      setState(() => _highlight = style);
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
                      setState(() => _treeStyle = style);
                      widget.onTreeStyleChanged(style);
                    },
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
                      setState(() => _language = language);
                      widget.onLanguageChanged(language);
                    },
                  ),
                ),
                const Divider(height: 1),
                const _ReleaseSettings(),
              ],
            ),
          ),
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.icon,
    required this.child,
    this.detail,
  });

  final String label;
  final IconData icon;
  final Widget child;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: WorkbenchStyle.space4),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: WorkbenchStyle.rowHeight),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _SettingsLabel(label: label, icon: icon, detail: detail),
          ),
          const SizedBox(width: WorkbenchStyle.space12),
          Expanded(
            flex: 3,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel({required this.label, required this.icon, this.detail});

  final String label;
  final IconData icon;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: WorkbenchStyle.controlIconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: WorkbenchStyle.space8),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: label,
              children: [
                if (detail != null)
                  TextSpan(
                    text: '  $detail',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
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
      thumbColor: colors.surfaceContainerLow,
      groupValue: selected,
      children: {
        for (final option in options.entries)
          option.key: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WorkbenchStyle.space8,
              vertical: WorkbenchStyle.space4,
            ),
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
          padding: const EdgeInsets.symmetric(
            horizontal: WorkbenchStyle.space8,
            vertical: WorkbenchStyle.space4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(options[selected]!)),
              const SizedBox(width: WorkbenchStyle.space8),
              Icon(
                CupertinoIcons.chevron_up_chevron_down,
                color: colors.onSurfaceVariant,
                size: WorkbenchStyle.controlIconSize,
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
        _SettingsRow(
          label: strings.about,
          icon: CupertinoIcons.info_circle,
          detail: _version == null ? null : strings.versionLabel('$_version'),
          child: TextButton(
            onPressed: _checking ? null : _check,
            style: TextButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(strings.checkUpdates),
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: WorkbenchStyle.controlIconSize + WorkbenchStyle.space8,
              bottom: WorkbenchStyle.space8,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (_result?.status == UpdateStatus.available)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _open(latestReleasePage),
              child: Text(strings.downloadRelease),
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: WorkbenchStyle.space4),
          child: TextButton(
            onPressed: () => _open(supportPage),
            style: TextButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, WorkbenchStyle.rowHeight),
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _SettingsLabel(
              label: strings.buyCoffee,
              icon: CupertinoIcons.heart,
            ),
          ),
        ),
        if (_browserFailed)
          Text(strings.browserFailed, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
