import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl, CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ejson_core/ejson_core.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/workbench_style.dart';
import '../editor/json_highlight.dart';
import '../editor/tree_style.dart';
import '../l10n/app_localizations.dart';
import 'release_updates.dart';
import 'tool_preferences.dart';
import 'reading_preferences.dart';
import 'installed_fonts.dart';
import 'font_picker.dart';
import '../editor/code_editor.dart';

class SettingsPanel extends ConsumerStatefulWidget {
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
  ConsumerState<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends ConsumerState<SettingsPanel> {
  bool _savingFormat = false;
  bool _formatSaveFailed = false;

  Future<void> _setFormat(JsonFormatOptions value) async {
    setState(() {
      _savingFormat = true;
      _formatSaveFailed = false;
    });
    final saved = await ref
        .read(toolPreferencesProvider.notifier)
        .setFormat(value);
    if (mounted) {
      setState(() {
        _savingFormat = false;
        _formatSaveFailed = !saved;
      });
    }
  }

  bool _savingReading = false;
  bool _readingSaveFailed = false;

  Future<void> _setReading(ReadingPreferences value) async {
    setState(() {
      _savingReading = true;
      _readingSaveFailed = false;
    });
    final saved = await ref
        .read(toolPreferencesProvider.notifier)
        .setReading(value);
    if (!mounted) return;
    setState(() {
      _savingReading = false;
      _readingSaveFailed = !saved;
    });
  }

  Future<void> _chooseFont(ReadingPreferences reading) async {
    final choice = await showDialog<FontChoice>(
      context: context,
      builder: (_) => FontPicker(selected: reading.fontFamily),
    );
    if (choice != null && mounted) {
      await _setReading(reading.withFont(choice.family));
    }
  }

  Widget _readingSettings() {
    final strings = AppLocalizations.of(context);
    final reading = ref.watch(toolPreferencesProvider).reading;
    final catalog = ref.watch(installedFontsProvider);
    final font = findInstalledFont(catalog.value, reading.fontFamily);
    final unavailable =
        catalog.hasValue &&
        !catalog.isLoading &&
        !catalog.hasError &&
        reading.fontFamily != null &&
        font == null;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          label: strings.readingFont,
          icon: CupertinoIcons.textformat,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: TextButton(
              onPressed: _savingReading ? null : () => _chooseFont(reading),
              style:
                  TextButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    backgroundColor: colors.surfaceContainerLow,
                    disabledForegroundColor: colors.onSurface.withValues(
                      alpha: .38,
                    ),
                    side: BorderSide(color: colors.outlineVariant),
                    minimumSize: const Size(0, WorkbenchStyle.inputHeight),
                    visualDensity: VisualDensity.standard,
                    padding: const EdgeInsets.symmetric(
                      horizontal: WorkbenchStyle.space8,
                      vertical: WorkbenchStyle.space4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        WorkbenchStyle.controlRadius,
                      ),
                    ),
                  ).copyWith(
                    overlayColor: workbenchInteractionOverlay(colors.onSurface),
                  ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      font?.name ??
                          reading.fontFamily ??
                          strings.defaultReadingFont,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WorkbenchStyle.body,
                    ),
                  ),
                  const SizedBox(width: WorkbenchStyle.space8),
                  Icon(
                    CupertinoIcons.chevron_up_chevron_down,
                    size: WorkbenchStyle.controlIconSize,
                    color: _savingReading
                        ? colors.onSurface.withValues(alpha: .38)
                        : colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (unavailable)
          Text(
            strings.fontUnavailable(reading.fontFamily!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (catalog.hasError)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.invalidate(installedFontsProvider),
              child: Text(strings.fontListFailed),
            ),
          ),
        const Divider(height: 1),
        _SettingsRow(
          label: strings.fontSize,
          icon: CupertinoIcons.textformat_size,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: strings.decreaseFontSize,
                onPressed: _savingReading || reading.fontSize <= 10
                    ? null
                    : () => _setReading(reading.withSize(reading.fontSize - 1)),
                icon: const Icon(CupertinoIcons.minus, size: 14),
              ),
              Flexible(
                child: _StylePicker<int>(
                  label: strings.fontSize,
                  options: {
                    for (var size = 10; size <= 32; size++) size: '$size',
                  },
                  selected: reading.fontSize,
                  onChanged: _savingReading
                      ? null
                      : (size) => _setReading(reading.withSize(size)),
                ),
              ),
              IconButton(
                tooltip: strings.increaseFontSize,
                onPressed: _savingReading || reading.fontSize >= 32
                    ? null
                    : () => _setReading(reading.withSize(reading.fontSize + 1)),
                icon: const Icon(CupertinoIcons.plus, size: 14),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        _SettingsRow(
          label: strings.lineSpacing,
          icon: CupertinoIcons.text_alignleft,
          child: _StylePicker<ReadingLineSpacing>(
            label: strings.lineSpacing,
            options: {
              ReadingLineSpacing.compact: strings.spacingCompact,
              ReadingLineSpacing.standard: strings.spacingStandard,
              ReadingLineSpacing.spacious: strings.spacingSpacious,
            },
            selected: reading.lineSpacing,
            onChanged: _savingReading
                ? null
                : (spacing) => _setReading(reading.withSpacing(spacing)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: WorkbenchStyle.space8),
          child: Text(
            strings.readingPreview,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Material(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 150,
            child: EJsonCodeEditor(
              key: const ValueKey('reading-preview'),
              highlight: _highlight,
              source:
                  '{\n  "name": "中文 / English",\n  "count": 123,\n  "active": true,\n  "emoji": "🙂"\n}',
              onChanged: (_) {},
              readOnly: true,
              useWorkspaceShortcuts: false,
            ),
          ),
        ),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: _savingReading
                  ? null
                  : () => _setReading(const ReadingPreferences()),
              child: Text(strings.resetReading),
            ),
          ],
        ),
        if (_readingSaveFailed)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: WorkbenchStyle.space8,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                strings.toolPreferenceFailed,
                style: TextStyle(color: colors.error),
              ),
            ),
          ),
      ],
    );
  }

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

  _SettingsCategory _category = _SettingsCategory.general;
  final _scrollControllers = {
    for (final category in _SettingsCategory.values)
      category: ScrollController(),
  };

  @override
  void dispose() {
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final format = ref.watch(toolPreferencesProvider).format;
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final sections = <_SettingsCategory, ({String label, IconData icon})>{
      _SettingsCategory.general: (
        label: strings.settingsGeneral,
        icon: CupertinoIcons.gear,
      ),
      _SettingsCategory.appearance: (
        label: strings.appearance,
        icon: CupertinoIcons.circle_lefthalf_fill,
      ),
      _SettingsCategory.reading: (
        label: strings.readingDisplay,
        icon: CupertinoIcons.textformat,
      ),
      _SettingsCategory.formatting: (
        label: strings.settingsFormatting,
        icon: CupertinoIcons.increase_indent,
      ),
      _SettingsCategory.about: (
        label: strings.about,
        icon: CupertinoIcons.info_circle,
      ),
    };
    final pages = <_SettingsCategory, List<Widget>>{
      _SettingsCategory.general: [
        _SettingsCard(
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
          ],
        ),
      ],
      _SettingsCategory.appearance: [
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
          ],
        ),
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
    return WorkbenchDialog(
      title: strings.settings,
      scrollable: false,
      content: SizedBox(
        width: (size.width - 120).clamp(240.0, 820.0),
        height: (size.height - 180).clamp(220.0, 560.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 136,
              child: ListView(
                children: [
                  for (final entry in sections.entries)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: WorkbenchStyle.space4,
                      ),
                      child: ListTile(
                        key: ValueKey('settings-${entry.key.name}'),
                        dense: true,
                        selected: _category == entry.key,
                        selectedColor: colors.onSecondaryContainer,
                        selectedTileColor: colors.secondaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            WorkbenchStyle.controlRadius,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: WorkbenchStyle.space8,
                        ),
                        minLeadingWidth: WorkbenchStyle.controlIconSize,
                        horizontalTitleGap: WorkbenchStyle.space8,
                        leading: Icon(
                          entry.value.icon,
                          size: WorkbenchStyle.controlIconSize,
                        ),
                        title: Text(
                          entry.value.label,
                          style: WorkbenchStyle.body,
                        ),
                        onTap: () => setState(() => _category = entry.key),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: WorkbenchStyle.space12),
            const VerticalDivider(width: 1),
            const SizedBox(width: WorkbenchStyle.space16),
            Expanded(
              child: IndexedStack(
                index: _category.index,
                sizing: StackFit.expand,
                children: [
                  for (final category in _SettingsCategory.values)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            sections[category]!.label,
                            style: WorkbenchStyle.heading.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: WorkbenchStyle.space12),
                        Expanded(
                          child: Scrollbar(
                            controller: _scrollControllers[category],
                            child: SingleChildScrollView(
                              controller: _scrollControllers[category],
                              key: PageStorageKey(
                                'settings-content-${category.name}',
                              ),
                              primary: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final card in pages[category]!)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: WorkbenchStyle.space12,
                                      ),
                                      child: card,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          child: Text(strings.done),
        ),
      ],
    );
  }
}

enum _SettingsCategory { general, appearance, reading, formatting, about }

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(WorkbenchStyle.groupRadius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WorkbenchStyle.space12,
          vertical: WorkbenchStyle.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

double _settingsRowHeight(BuildContext context) {
  final text = Theme.of(context).textTheme.bodyMedium!;
  final twoLines =
      MediaQuery.textScalerOf(context).scale(text.fontSize!) *
      (text.height ?? 1.38) *
      2;
  return (twoLines + WorkbenchStyle.space16).clamp(
    WorkbenchStyle.settingsRowHeight,
    double.infinity,
  );
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
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('settings-row-$label'),
    height: _settingsRowHeight(context),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: WorkbenchStyle.space8),
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
    return SizedBox(
      height: WorkbenchStyle.inputHeightFor(
        context,
        Theme.of(context).textTheme.bodyMedium!,
      ),
      child: CupertinoSlidingSegmentedControl<T>(
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
      ),
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
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      tooltip: label,
      enabled: onChanged != null,
      constraints: const BoxConstraints(minWidth: 185, maxWidth: 260),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options.entries)
          WorkbenchMenuItem(
            value: option.key,
            checked: option.key == selected,
            label: option.value,
          ),
      ],
      child: SizedBox(
        height: WorkbenchStyle.inputHeightFor(
          context,
          Theme.of(context).textTheme.bodyMedium!,
        ),
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
        SizedBox(
          key: const ValueKey('settings-row-website'),
          height: _settingsRowHeight(context),
          child: TextButton(
            onPressed: () => _open(websitePage),
            style: TextButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, WorkbenchStyle.inputHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.globe,
                  size: WorkbenchStyle.controlIconSize,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: WorkbenchStyle.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: .min,
                    children: [
                      Text(strings.website, style: WorkbenchStyle.body),
                      Text(
                        websitePage.toString(),
                        style: WorkbenchStyle.caption.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.arrow_up_right,
                  size: WorkbenchStyle.controlIconSize,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          key: const ValueKey('settings-row-support'),
          height: _settingsRowHeight(context),
          child: TextButton(
            onPressed: () => _open(supportPage),
            style: TextButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, WorkbenchStyle.inputHeight),
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
