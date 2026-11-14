part of 'workbench.dart';

extension _WorkbenchNavigation on _WorkbenchState {
  Widget _tool(String label, IconData icon, VoidCallback? action) => IconButton(
    tooltip: label,
    icon: Icon(icon, size: WorkbenchStyle.controlIconSize),
    onPressed: action,
    style: IconButton.styleFrom(
      minimumSize: const Size(32, WorkbenchStyle.toolbarControlHeight),
      fixedSize: const Size(32, WorkbenchStyle.toolbarControlHeight),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  Future<void> _openSettings() async {
    if (_settingsOpen || _confirmingExit || _closingTab || _fileBusy) return;
    _settingsOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => SettingsPanel(
          themeMode: widget.themeMode,
          restoreOnStartup: _restoreOnStartup,
          onRestoreOnStartupChanged: (value) {
            final update = _setRestoreOnStartup(value);
            _savingRestorePreference = update;
            return update;
          },
          highlight: widget.highlight,
          onHighlightChanged: widget.onHighlightChanged,
          treeStyle: widget.treeStyle,
          onTreeStyleChanged: widget.onTreeStyleChanged,
          glassEnabled: _glass,
          language: widget.language,
          onThemeChanged: widget.onThemeChanged,
          onGlassChanged: (value) => _updateView(() => _glass = value),
          onLanguageChanged: widget.onLanguageChanged,
        ),
      );
    } finally {
      _settingsOpen = false;
    }
  }

  Widget _toolbar(WorkspaceTab tab, bool valid) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkbenchStyle.space12,
        vertical: WorkbenchStyle.space8,
      ),
      child: Row(
        children: [
          Image.asset(
            _logoAsset(theme.brightness == Brightness.dark),
            width: 19,
            height: 19,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 7),
          Text(
            'EJson',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GlassGroup(
            enabled: _glass,
            child: Row(
              children: [
                _tool(
                  strings.open,
                  CupertinoIcons.folder,
                  _fileBusy ? null : _open,
                ),
                _tool(
                  strings.recentFiles,
                  CupertinoIcons.clock,
                  _fileBusy ? null : _openRecents,
                ),
                _tool(
                  strings.save,
                  CupertinoIcons.square_arrow_down,
                  _fileBusy ? null : () => _save(tab.id),
                ),
                _tool(
                  strings.saveAs,
                  CupertinoIcons.square_arrow_down_on_square,
                  _fileBusy ? null : () => _save(tab.id, saveAs: true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GlassGroup(
            enabled: _glass,
            child: Row(
              children: [
                _tool(
                  strings.compareDocuments,
                  CupertinoIcons.square_split_2x1,
                  workspace.tabs
                              .where(
                                (item) => !item.large && item.document.isValid,
                              )
                              .take(2)
                              .length ==
                          2
                      ? _openComparison
                      : null,
                ),
                _tool(
                  strings.goToJsonPath,
                  CupertinoIcons.location,
                  valid ? () => _goToPath(tab) : null,
                ),
                _tool(
                  strings.jsonQuery,
                  CupertinoIcons.line_horizontal_3_decrease,
                  valid ? () => _openQuery(tab) : null,
                ),
                _tool(strings.findInDocument, CupertinoIcons.search, _openFind),
                _tool(
                  tab.document.snapshot?.root?.kind == JsonKind.string
                      ? strings.unescapeJson
                      : strings.escapeJson,
                  CupertinoIcons.text_quote,
                  tab.large || tab.format != DocumentFormat.json
                      ? null
                      : () => _toggleString(tab),
                ),
                _tool(
                  strings.undo,
                  CupertinoIcons.arrow_uturn_left,
                  controller.canUndo(tab.id)
                      ? () => controller.undo(tab.id)
                      : null,
                ),
                _tool(
                  strings.redo,
                  CupertinoIcons.arrow_uturn_right,
                  controller.canRedo(tab.id)
                      ? () => controller.redo(tab.id)
                      : null,
                ),
                const SizedBox(height: 16, child: VerticalDivider(width: 8)),
                _tool(
                  strings.minify,
                  CupertinoIcons.arrow_down_right_arrow_up_left,
                  tab.canMinify ? () => _rewrite(tab, minify: true) : null,
                ),
                _tool(
                  strings.format,
                  CupertinoIcons.text_alignleft,
                  tab.canFormat ? () => _rewrite(tab, minify: false) : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: WorkbenchStyle.space8),
          GlassGroup(
            enabled: _glass,
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: WorkbenchStyle.toolbarControlHeight,
                  child: PopupMenuButton<WorkbenchCommandId>(
                    tooltip: strings.documentTools,
                    enabled: !tab.large,
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      CupertinoIcons.ellipsis,
                      size: WorkbenchStyle.controlIconSize,
                    ),
                    onSelected: (id) => _commands()
                        .firstWhere((command) => command.id == id)
                        .action
                        ?.call(),
                    itemBuilder: (_) => [
                      WorkbenchMenuItem(
                        value: WorkbenchCommandId.convert,
                        enabled: true,
                        label: strings.formatConversion,
                        icon: CupertinoIcons.arrow_2_squarepath,
                      ),
                      WorkbenchMenuItem(
                        enabled: valid,
                        value: WorkbenchCommandId.schema,
                        label: strings.schemaValidation,
                        icon: CupertinoIcons.checkmark_shield,
                      ),
                      WorkbenchMenuItem(
                        enabled: valid,
                        value: WorkbenchCommandId.redact,
                        label: strings.redactData,
                        icon: CupertinoIcons.eye_slash,
                      ),
                    ],
                  ),
                ),
                _tool(
                  strings.commandPalette,
                  CupertinoIcons.command,
                  _fileBusy ? null : _openPalette,
                ),
                _tool(
                  strings.settings,
                  CupertinoIcons.slider_horizontal_3,
                  _openSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(Workspace model) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 39,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
        scrollDirection: Axis.horizontal,
        itemCount: model.tabs.length + 1,
        findItemIndexCallback: (key) {
          if (key is! ValueKey<int>) return null;
          final index = model.tabs.indexWhere((tab) => tab.id == key.value);
          return index < 0 ? null : index;
        },
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          if (index == model.tabs.length) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tool(strings.newTab, CupertinoIcons.plus, controller.newTab),
                PopupMenuButton<DocumentFormat>(
                  tooltip: strings.newDocumentFormat,
                  onSelected: (format) => controller.newTab(format: format),
                  itemBuilder: (_) => [
                    for (final format in DocumentFormat.values)
                      WorkbenchMenuItem(value: format, label: format.label),
                  ],
                  child: const SizedBox(
                    width: 24,
                    height: WorkbenchStyle.toolbarControlHeight,
                    child: Icon(CupertinoIcons.chevron_down, size: 12),
                  ),
                ),
              ],
            );
          }
          final item = model.tabs[index];
          final selected = item.id == model.activeId;
          return Semantics(
            key: ValueKey(item.id),
            selected: selected,
            child: Material(
              color: selected ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  WorkbenchStyle.controlRadius,
                ),
                onTap: () => controller.activate(item.id),
                child: Tooltip(
                  message: item.file?.path ?? strings.tabName(item),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 11, right: 3),
                    child: Row(
                      children: [
                        Icon(
                          item.dirty ? Icons.circle : CupertinoIcons.doc_text,
                          size: item.dirty ? 7 : 15,
                          color: selected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 190),
                          child: Text(
                            strings.tabName(item),
                            overflow: TextOverflow.ellipsis,
                            style: WorkbenchStyle.body.copyWith(
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (model.canClose(item)) ...[
                          const SizedBox(width: 3),
                          IconButton(
                            tooltip: strings.closeTab(strings.tabName(item)),
                            icon: const Icon(CupertinoIcons.xmark, size: 14),
                            onPressed: _fileBusy ? null : () => _close(item.id),
                          ),
                        ] else
                          const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
