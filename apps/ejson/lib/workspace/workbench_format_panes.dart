part of 'workbench.dart';

extension _WorkbenchFormatPanes on _WorkbenchState {
  Widget _otherPanes(WorkspaceTab tab) {
    if (tab.large && tab.format != DocumentFormat.jsonLines) {
      return _Panel(
        title: '${strings.source} · ${tab.format.label}',
        icon: CupertinoIcons.doc_text,
        child: _sourceEditor(tab),
      );
    }
    final snapshot = tab.document.snapshot;
    final colors = Theme.of(context).colorScheme;
    final Widget structure;
    if (snapshot?.jsonLines case final lines?) {
      structure = JsonLinesView(
        key: ValueKey('json-lines-${tab.id}'),
        data: lines,
        onReveal: _reveal,
        onExport: (source, format) => _exportDocument(
          source,
          format,
          'filtered.${format.extension}',
          strings.jsonLinesExported,
        ),
      );
    } else if (snapshot?.table case final table?) {
      structure = CsvDocumentView(
        key: ValueKey('csv-table-${tab.id}'),
        data: table,
        onReveal: _reveal,
      );
    } else if (snapshot?.structure case final root?) {
      structure = FormatTreeView(
        key: ValueKey('format-tree-${tab.id}'),
        root: root,
        style: widget.treeStyle,
        highlight: widget.highlight,
        showConnectors: ref.watch(toolPreferencesProvider).treeConnectors,
        truncated: snapshot!.structureTruncated,
        onReveal: _reveal,
      );
    } else {
      structure = Center(
        child: Text(snapshot == null ? strings.checking : strings.noStructure),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          SizedBox(
            width:
                (constraints.maxWidth - 7).clamp(0, double.infinity) * _split,
            child: _Panel(
              title: '${strings.source} · ${tab.format.label}',
              icon: CupertinoIcons.doc_text,
              child: _sourceEditor(tab),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (event) => _updateView(
                () => _split = (_split + event.delta.dx / constraints.maxWidth)
                    .clamp(.35, .72),
              ),
              child: VerticalDivider(width: 7, color: colors.outlineVariant),
            ),
          ),
          Expanded(
            child: _Panel(
              title: tab.format == DocumentFormat.jsonLines
                  ? strings.jsonLinesRecords
                  : tab.format == DocumentFormat.csv
                  ? strings.arrayTable
                  : strings.documentStructure,
              icon: tab.format == DocumentFormat.csv
                  ? CupertinoIcons.table
                  : CupertinoIcons.list_bullet_indent,
              child: structure,
            ),
          ),
        ],
      ),
    );
  }
}
