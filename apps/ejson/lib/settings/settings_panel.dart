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
import '../editor/tree_panel.dart';
import '../l10n/app_localizations.dart';
import 'release_updates.dart';
import 'tool_preferences.dart';
import 'reading_preferences.dart';
import 'installed_fonts.dart';
import 'font_picker.dart';
import '../editor/code_editor.dart';

part 'reading_settings.dart';
part 'settings_pages.dart';
part 'settings_controls.dart';
part 'release_settings.dart';

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
  void _updateView(VoidCallback update) => setState(update);

  bool _savingFormat = false;
  bool _formatSaveFailed = false;

  bool _savingReading = false;
  bool _readingSaveFailed = false;

  static const _appearanceSource =
      '{\n  "name": "EJson",\n  "active": true,\n  "items": [{"id": 1, "note": null}, {"id": 2}]\n}';
  final _appearanceSnapshot = parseJson(_appearanceSource);

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
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final pages = _pages();
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
