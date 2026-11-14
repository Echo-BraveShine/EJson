part of 'workbench.dart';

extension _WorkbenchCommands on _WorkbenchState {
  JsonNode? _arrayForCommands(WorkspaceTab tab) {
    if (!tab.document.isValid || tab.large) return null;
    final root = tab.document.snapshot!.root!;
    final jump = _jump;
    if (jump != null &&
        jump.tabId == tab.id &&
        jump.revision == tab.document.revision) {
      JsonNode? selected(JsonNode node) {
        if (node.range == jump.range && node.kind == JsonKind.array) {
          return node;
        }
        for (final child in node.children) {
          if (child.value.range.start <= jump.range.start &&
              child.value.range.end >= jump.range.end) {
            final match = selected(child.value);
            if (match != null) return match;
          }
        }
        return null;
      }

      final array = selected(root);
      if (array != null) return array;
    }
    return root.kind == JsonKind.array ? root : null;
  }

  List<WorkbenchCommand> _commands() {
    final tab = workspace.active;
    final valid = tab.document.isValid && !tab.large;
    final io = !_fileBusy && !_closingTab && !_confirmingExit;
    final array = _arrayForCommands(tab);
    final primary = Platform.isMacOS ? '⌘' : 'Ctrl+';
    final shift = Platform.isMacOS ? '⇧' : 'Shift+';
    final compare =
        workspace.tabs
            .where((tab) => !tab.large && tab.document.isValid)
            .take(2)
            .length ==
        2;
    return [
      WorkbenchCommand(
        id: WorkbenchCommandId.newTab,
        label: strings.newTab,
        icon: CupertinoIcons.plus,
        shortcut: '${primary}N',
        keywords: 'new document tab 新建 文档 标签页',
        action: controller.newTab,
      ),
      for (final entry in [
        (WorkbenchCommandId.newYaml, DocumentFormat.yaml),
        (WorkbenchCommandId.newCsv, DocumentFormat.csv),
        (WorkbenchCommandId.newXml, DocumentFormat.xml),
        (WorkbenchCommandId.newToml, DocumentFormat.toml),
      ])
        WorkbenchCommand(
          id: entry.$1,
          label: strings.newDocument(entry.$2.label),
          icon: CupertinoIcons.doc,
          keywords: 'new document ${entry.$2.extension} 新建 文档',
          action: () => controller.newTab(format: entry.$2),
        ),
      WorkbenchCommand(
        id: WorkbenchCommandId.open,
        label: strings.open,
        icon: CupertinoIcons.folder,
        shortcut: '${primary}O',
        keywords: 'open file 打开 文件',
        action: io ? _open : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.recentFiles,
        label: strings.recentFiles,
        icon: CupertinoIcons.clock,
        shortcut: '${primary}P',
        keywords: 'recent files history 最近 文件 历史',
        action: io ? _openRecents : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.save,
        label: strings.save,
        icon: CupertinoIcons.square_arrow_down,
        shortcut: '${primary}S',
        keywords: 'save file 保存 文件',
        action: io ? () => _save(tab.id) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.saveAs,
        label: strings.saveAs,
        icon: CupertinoIcons.square_arrow_down_on_square,
        shortcut: '$primary${shift}S',
        keywords: 'save as 另存为',
        action: io ? () => _save(tab.id, saveAs: true) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.closeTab,
        label: strings.closeTab(strings.tabName(tab)),
        icon: CupertinoIcons.xmark,
        shortcut: '${primary}W',
        keywords: 'close tab 关闭 标签页',
        action: io && workspace.canClose(tab) ? () => _close(tab.id) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.undo,
        label: strings.undo,
        icon: CupertinoIcons.arrow_uturn_left,
        shortcut: '${primary}Z',
        keywords: 'undo 撤销',
        action: controller.canUndo(tab.id)
            ? () => controller.undo(tab.id)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.redo,
        label: strings.redo,
        icon: CupertinoIcons.arrow_uturn_right,
        shortcut: '$primary${shift}Z',
        keywords: 'redo 重做',
        action: controller.canRedo(tab.id)
            ? () => controller.redo(tab.id)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.find,
        label: strings.findInDocument,
        icon: CupertinoIcons.search,
        shortcut: '${primary}F',
        keywords: 'find search replace 查找 搜索 替换',
        action: _openFind,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.format,
        label: strings.format,
        icon: CupertinoIcons.text_alignleft,
        keywords: 'format pretty json 格式化',
        action: tab.canFormat ? () => _rewrite(tab, minify: false) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.minify,
        label: strings.minify,
        icon: CupertinoIcons.arrow_down_right_arrow_up_left,
        keywords: 'minify compact json 压缩',
        action: tab.canMinify ? () => _rewrite(tab, minify: true) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.escape,
        label: strings.escapeJson,
        icon: CupertinoIcons.text_quote,
        keywords: 'escape json string 转义 字符串',
        action: !tab.large && tab.format == DocumentFormat.json
            ? () => _transformString(tab, escape: true)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.unescape,
        label: strings.unescapeJson,
        icon: CupertinoIcons.text_quote,
        keywords: 'unescape decode json string 反转义',
        action: !tab.large && tab.format == DocumentFormat.json
            ? () => _transformString(tab, escape: false)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.jsonPath,
        label: strings.goToJsonPath,
        icon: CupertinoIcons.location,
        keywords: 'jsonpath goto path 跳转 路径',
        action: valid ? () => _goToPath(tab) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.jsonQuery,
        label: strings.jsonQuery,
        icon: CupertinoIcons.line_horizontal_3_decrease,
        keywords: 'jsonpath query filter 查询 筛选',
        action: valid ? () => _openQuery(tab) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.compare,
        label: strings.compareDocuments,
        icon: CupertinoIcons.square_split_2x1,
        keywords: 'compare diff json 对比 比较 差异',
        action: compare ? _openComparison : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.arrayTable,
        label: strings.arrayTable,
        icon: CupertinoIcons.table,
        keywords: 'array table csv export 数组 表格 导出',
        action: array != null ? () => _openTable(tab, array) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.sortArray,
        label: strings.sortArray,
        icon: CupertinoIcons.sort_down,
        keywords: 'sort array 排序 数组',
        action: array != null && array.children.length > 1
            ? () => _sortArray(tab, array)
            : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.convert,
        label: strings.formatConversion,
        icon: CupertinoIcons.arrow_2_squarepath,
        keywords: 'convert conversion json yaml csv xml toml 转换 格式',
        action: !tab.large ? () => _openConversion(tab) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.schema,
        label: strings.schemaValidation,
        icon: CupertinoIcons.checkmark_shield,
        keywords: 'schema validate validation 校验 规则',
        action: valid ? () => _openSchema(tab) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.redact,
        label: strings.redactData,
        icon: CupertinoIcons.eye_slash,
        keywords: 'redact mask privacy 脱敏 隐私',
        action: valid ? () => _openRedaction(tab) : null,
      ),
      WorkbenchCommand(
        id: WorkbenchCommandId.settings,
        label: strings.settings,
        icon: CupertinoIcons.slider_horizontal_3,
        keywords: 'settings preferences font theme language 设置 字体 字号 主题 语言',
        action: io && !_settingsOpen ? _openSettings : null,
      ),
    ];
  }

  Future<void> _openPalette() async {
    if (_paletteOpen || !_canOpenFiles) return;
    _updateView(() => _paletteOpen = true);
    WorkbenchCommandId? selected;
    try {
      selected = await showDialog<WorkbenchCommandId>(
        context: context,
        builder: (_) => Consumer(
          builder: (context, ref, _) {
            ref.watch(workspaceProvider);
            return CommandPalette(commands: _commands());
          },
        ),
      );
    } finally {
      if (mounted) _updateView(() => _paletteOpen = false);
    }
    if (!mounted || selected == null) return;
    _commands()
        .where((command) => command.id == selected)
        .firstOrNull
        ?.action
        ?.call();
  }
}
