part of 'workbench.dart';

extension _WorkbenchDocumentActions on _WorkbenchState {
  Future<void> _rewrite(WorkspaceTab tab, {required bool minify}) async {
    try {
      await controller.rewrite(tab.id, minify: minify);
    } catch (error) {
      if (mounted) _message(strings.formatFailed(error.toString()));
    }
  }

  void _reveal(SourceRange range, {bool search = false}) => _updateView(() {
    _searchJump = search;
    _jump = (
      range: range,
      sequence: ++_jumpSequence,
      tabId: workspace.activeId,
      revision: workspace.active.document.revision,
    );
  });

  Future<void> _openComparison() async {
    final model = workspace;
    final tabs = model.tabs
        .where((tab) => !tab.large && tab.document.isValid)
        .toList();
    if (tabs.length < 2) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CompareDocuments(
        treeStyle: widget.treeStyle,
        tabs: tabs,
        activeId: model.activeId,
        highlight: widget.highlight,
      ),
    );
  }

  Future<void> _goToPath(WorkspaceTab tab) async {
    final range = await showDialog<SourceRange>(
      context: context,
      builder: (_) => _PathDialog(root: tab.document.snapshot!.root!),
    );
    if (!mounted || range == null) return;
    final active = workspace.active;
    if (active.id != tab.id ||
        active.document.revision != tab.document.revision) {
      _message(strings.staleNode);
      return;
    }
    _reveal(range, search: true);
  }

  Future<void> _openQuery(WorkspaceTab tab) async {
    final result = await showDialog<JsonQueryResult>(
      context: context,
      builder: (_) =>
          JsonQueryDialog(source: tab.text, root: tab.document.snapshot!.root!),
    );
    if (!mounted || result == null) return;
    if (!_isCurrent(tab) || workspace.activeId != tab.id) {
      _message(strings.staleNode);
      return;
    }
    if (result.range case final range?) {
      _reveal(range, search: true);
    } else if (result.source case final source?) {
      controller.newTabWithSource(source);
    }
  }

  Future<void> _openConversion(WorkspaceTab tab) async {
    final result = await showDialog<ConversionResult>(
      context: context,
      builder: (_) => ConversionDialog(
        source: tab.text,
        format: tab.format,
        highlight: widget.highlight,
      ),
    );
    if (!mounted || result == null) return;
    final output = result.output;
    controller.newTabWithSource(
      output.source,
      format: output.format,
      bom: output.bom,
    );
    if (result.save) await _save(workspace.activeId, saveAs: true);
  }

  Future<void> _openSchema(WorkspaceTab tab) async {
    final range = await showDialog<SourceRange>(
      context: context,
      builder: (_) => SchemaDialog(
        source: tab.text,
        initialSchema: _schemaDraft,
        onSchemaChanged: (value) => _schemaDraft = value,
      ),
    );
    if (!mounted || range == null) return;
    if (!_isCurrent(tab)) {
      _message(strings.staleNode);
      return;
    }
    _reveal(range, search: true);
  }

  Future<void> _openRedaction(WorkspaceTab tab) async {
    final result = await showDialog<RedactionResult>(
      context: context,
      builder: (_) =>
          RedactionDialog(source: tab.text, highlight: widget.highlight),
    );
    if (!mounted || result == null) return;
    controller.newTabWithSource(result.source);
    if (result.save) await _save(workspace.activeId, saveAs: true);
  }

  void _toggleString(WorkspaceTab tab) {
    if (tab.large) return;
    try {
      final decoded = jsonDecode(tab.text);
      if (decoded is String) {
        controller.editSource(tab.id, decoded);
        return;
      }
    } on FormatException {
      // Plain text can be escaped into a JSON string as well.
    }
    controller.editSource(tab.id, jsonEncode(tab.text));
  }

  void _transformString(WorkspaceTab tab, {required bool escape}) {
    if (tab.large) return;
    if (escape) {
      controller.editSource(tab.id, jsonEncode(tab.text));
      return;
    }
    try {
      final decoded = jsonDecode(tab.text);
      if (decoded is! String) throw const FormatException();
      controller.editSource(tab.id, decoded);
    } on FormatException {
      _message(strings.unescapeFailed);
    }
  }

  void _openFind() {
    _updateView(() => _findOpen = true);
    _findFocus.requestFocus();
  }

  void _closeFind() => _updateView(() {
    _findOpen = false;
    if (_searchJump) _jump = null;
  });

  bool _isCurrent(WorkspaceTab tab) =>
      workspace.tab(tab.id)?.document.revision == tab.document.revision &&
      tab.document.isValid &&
      !tab.large;

  Future<void> _copyValue(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _message(strings.valueCopied);
  }

  Future<void> _openTable(WorkspaceTab tab, JsonNode array) async {
    if (!_isCurrent(tab)) {
      _message(strings.staleNode);
      return;
    }
    final range = await showDialog<SourceRange>(
      context: context,
      builder: (_) => ArrayTable(
        source: tab.text,
        array: array,
        onCopy: (value) => Clipboard.setData(ClipboardData(text: value)),
        onExport: _exportCsv,
        onReveal: (range) => Navigator.pop(context, range),
      ),
    );
    if (!mounted || range == null) return;
    if (!_isCurrent(tab) || workspace.activeId != tab.id) {
      _message(strings.staleNode);
      return;
    }
    _reveal(range, search: true);
  }

  Future<String?> _exportCsv(String csv) async {
    try {
      final destination = await getSaveLocation(suggestedName: 'array.csv');
      if (destination == null || !mounted) return null;
      final target = File(destination.path);
      final resolved = await target.exists()
          ? await target.resolveSymbolicLinks()
          : target.absolute.path;
      if (!mounted) return null;
      if (workspace.tabs.any((tab) => tab.file?.path == resolved)) {
        return strings.fileAlreadyOpen;
      }
      await LocalJsonFile(destination.path, '').save(
        csv,
        destination: destination.path,
        writeAtomically: ref.read(workspaceAtomicWriterProvider),
      );
      return mounted ? strings.csvExported : null;
    } on Exception {
      return mounted ? strings.exportFailed : null;
    }
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) _message(strings.jsonPathCopied);
  }

  void _applyTreePatch(WorkspaceTab tab, SourcePatch patch) {
    if (!controller.editNode(tab.id, tab.document.revision, patch)) {
      _message(strings.staleNode);
    }
  }

  Future<void> _addChild(WorkspaceTab tab, JsonNode parent) async {
    final entry = await showDialog<String>(
      context: context,
      builder: (_) => _NodeEditor(
        value: 'null',
        keyName: false,
        addTo: parent.kind,
        highlight: widget.highlight,
        formatOptions: ref.read(toolPreferencesProvider).format,
      ),
    );
    if (entry == null || !mounted) return;
    final result = await ref.read(formatTreeAdditionProvider)(
      tab.text,
      parent,
      entry,
    );
    if (!mounted) return;
    if (result.patch case final patch?) {
      _applyTreePatch(tab, patch);
    } else {
      _message(strings.diagnosticMessage(result.error!));
    }
  }

  Future<void> _sortArray(WorkspaceTab tab, JsonNode array) async {
    final options = await showDialog<ArraySortOptions>(
      context: context,
      builder: (_) => ArraySortDialog(array: array),
    );
    if (options == null || !mounted) return;
    final source = tab.text;
    try {
      final patch = await Isolate.run(
        () => sortJsonArray(
          source,
          array,
          key: options.key,
          ascending: options.ascending,
        ),
      );
      if (mounted) _applyTreePatch(tab, patch);
    } on FormatException {
      if (mounted) _message(strings.sortArrayAmbiguous);
    }
  }

  Future<void> _editNode(WorkspaceTab tab, SourceRange range, bool key) async {
    final document = tab.document;
    final replacement = await showDialog<String>(
      context: context,
      builder: (_) => _NodeEditor(
        value: document.source.slice(range),
        keyName: key,
        highlight: widget.highlight,
        formatOptions: ref.read(toolPreferencesProvider).format,
      ),
    );
    if (replacement == null || !mounted) return;
    _applyTreePatch(tab, SourcePatch(range, replacement));
  }
}
