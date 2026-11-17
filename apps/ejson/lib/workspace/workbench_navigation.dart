part of 'workbench.dart';

enum _TabMenuAction { reveal, close }

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
          colorTheme: widget.colorTheme,
          onColorThemeChanged: widget.onColorThemeChanged,
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
                  '${strings.format} (${Platform.isMacOS ? '⇧⌥F' : 'Shift+Alt+F'})',
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
                        enabled:
                            tab.format == DocumentFormat.json &&
                            tab.text.trim().isNotEmpty,
                        value: WorkbenchCommandId.repair,
                        label: strings.repairJson,
                        icon: CupertinoIcons.wand_stars,
                      ),
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

  Future<void> _showTabMenu(int id, Offset anchor) async {
    final model = workspace;
    final tab = model.tab(id);
    if (tab == null) return;
    final path = tab.file?.path;
    final canClose = model.canClose(tab);
    if (path == null && !canClose) return;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final point = overlay.globalToLocal(anchor);
    final label = Platform.isMacOS
        ? strings.revealInFinder
        : strings.revealInFolder;
    final action = await showMenu<_TabMenuAction>(
      context: context,
      position: RelativeRect.fromSize(
        Rect.fromPoints(point, point),
        overlay.size,
      ),
      items: [
        if (path != null)
          WorkbenchMenuItem(
            value: _TabMenuAction.reveal,
            label: label,
            icon: CupertinoIcons.folder,
          ),
        if (canClose)
          WorkbenchMenuItem(
            value: _TabMenuAction.close,
            label: strings.closeTabMenu,
            icon: CupertinoIcons.xmark,
            enabled: !_fileBusy,
          ),
      ],
    );
    if (action == null || !mounted) return;
    if (action == _TabMenuAction.close) {
      await _close(id);
      return;
    }
    if (path == null) return;
    final result = await ref.read(revealFileProvider)(path);
    if (!mounted) return;
    switch (result) {
      case RevealFileResult.opened:
        break;
      case RevealFileResult.openedOriginalFolder:
        _message(strings.revealFileMissing);
      case RevealFileResult.folderMissing:
        _message(strings.revealFolderMissing);
      case RevealFileResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.revealFolderFailed),
            action: SnackBarAction(
              label: strings.copyFilePath,
              onPressed: () =>
                  unawaited(Clipboard.setData(ClipboardData(text: path))),
            ),
          ),
        );
    }
  }

  void _chooseNewDocumentFormat() {
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      _newDocumentMenu.currentState?.showButtonMenu();
    }
  }

  Widget _tabs(Workspace model) {
    return SizedBox(
      height: 39,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in model.tabs)
              Padding(
                key: ValueKey(item.id),
                padding: const EdgeInsetsDirectional.only(end: 2),
                child: _WorkspaceFileTab(
                  tab: item,
                  name: strings.tabName(item),
                  selected: item.id == model.activeId,
                  canClose: model.canClose(item),
                  closeLabel: strings.closeTab(strings.tabName(item)),
                  onActivate: () => controller.activate(item.id),
                  onClose: _fileBusy ? null : () => _close(item.id),
                  onMenu: (anchor) => _showTabMenu(item.id, anchor),
                ),
              ),
            const SizedBox(width: 4),
            PopupMenuButton<DocumentFormat>(
              key: _newDocumentMenu,
              tooltip: strings.newDocumentFormat,
              onSelected: (format) => controller.newTab(format: format),
              itemBuilder: (_) => [
                for (final format in DocumentFormat.values)
                  WorkbenchMenuItem(value: format, label: format.label),
              ],
              child: const SizedBox.square(
                dimension: WorkbenchStyle.toolbarControlHeight,
                child: Icon(
                  CupertinoIcons.plus,
                  size: WorkbenchStyle.controlIconSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceFileTab extends StatefulWidget {
  const _WorkspaceFileTab({
    required this.tab,
    required this.name,
    required this.selected,
    required this.canClose,
    required this.closeLabel,
    required this.onActivate,
    required this.onClose,
    required this.onMenu,
  });

  final WorkspaceTab tab;
  final String name;
  final bool selected;
  final bool canClose;
  final String closeLabel;
  final VoidCallback onActivate;
  final VoidCallback? onClose;
  final Future<void> Function(Offset) onMenu;

  @override
  State<_WorkspaceFileTab> createState() => _WorkspaceFileTabState();
}

class _WorkspaceFileTabState extends State<_WorkspaceFileTab> {
  bool _hovered = false;
  @override
  void initState() {
    super.initState();
    if (widget.selected) _revealTab();
  }

  @override
  void didUpdateWidget(covariant _WorkspaceFileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) _revealTab();
  }

  void _revealTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.selected) return;
      final scroll = Scrollable.of(context).position;
      final target = context.findRenderObject()!;
      // Each policy moves only if its edge lies outside the viewport.
      unawaited(
        scroll.ensureVisible(
          target,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
      unawaited(
        scroll.ensureVisible(
          target,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final path = widget.tab.file?.path;
    final showClose = _hovered && widget.canClose && widget.onClose != null;
    final background = _hovered
        ? Color.alphaBlend(
            colors.onSurface.withValues(alpha: widget.selected ? .035 : .07),
            widget.selected ? colors.surface : colors.surfaceContainer,
          )
        : widget.selected
        ? colors.surface
        : Colors.transparent;
    return Semantics(
      selected: widget.selected,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: background,
          animationDuration: const Duration(milliseconds: 100),
          borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(WorkbenchStyle.controlRadius),
            onTap: widget.onActivate,
            onSecondaryTapUp: path != null || widget.canClose
                ? (details) => unawaited(widget.onMenu(details.globalPosition))
                : null,
            child: Tooltip(
              message: path ?? widget.name,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, end: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 24,
                      child: showClose
                          ? IconButton(
                              tooltip: widget.closeLabel,
                              iconSize: 12,
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                fixedSize: const Size.square(24),
                                minimumSize: const Size.square(24),
                                visualDensity: VisualDensity.standard,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                alignment: Alignment.center,
                              ),
                              icon: const Icon(Icons.close_rounded),
                              onPressed: widget.onClose,
                            )
                          : Icon(
                              widget.tab.dirty
                                  ? Icons.circle
                                  : CupertinoIcons.doc_text,
                              size: widget.tab.dirty ? 7 : 15,
                              color: widget.selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                    ),
                    const SizedBox(width: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WorkbenchStyle.body.copyWith(
                          leadingDistribution: TextLeadingDistribution.even,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
