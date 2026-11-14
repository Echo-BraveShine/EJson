part of 'settings_panel.dart';

extension _ReadingSettings on _SettingsPanelState {
  Future<void> _setReading(ReadingPreferences value) async {
    _updateView(() {
      _savingReading = true;
      _readingSaveFailed = false;
    });
    final saved = await ref
        .read(toolPreferencesProvider.notifier)
        .setReading(value);
    if (!mounted) return;
    _updateView(() {
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
}
