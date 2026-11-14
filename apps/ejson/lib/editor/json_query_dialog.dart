import '../design/workbench_text_field.dart';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:ejson_core/ejson_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/workbench_style.dart';
import '../design/reading_style.dart';
import '../l10n/app_localizations.dart';
import '../settings/tool_preferences.dart';

final jsonQueryProvider =
    Provider<Future<List<JsonQueryMatch>> Function(String, JsonNode, String)>(
      (ref) =>
          (source, root, query) =>
              Isolate.run(() => queryJsonPath(source, root, query)),
    );

class JsonQueryResult {
  const JsonQueryResult.reveal(this.range) : source = null;
  const JsonQueryResult.extract(this.source) : range = null;

  final SourceRange? range;
  final String? source;
}

class JsonQueryDialog extends ConsumerStatefulWidget {
  const JsonQueryDialog({super.key, required this.source, required this.root});

  final String source;
  final JsonNode root;

  @override
  ConsumerState<JsonQueryDialog> createState() => _JsonQueryDialogState();
}

class _JsonQueryDialogState extends ConsumerState<JsonQueryDialog> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  List<JsonQueryMatch>? _matches;
  int _request = 0;
  bool _busy = false;
  String? _error;
  bool _savingFavorite = false;
  bool _favoriteSaveFailed = false;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed(String _) => setState(() {
    _request++;
    _busy = false;
    _error = null;
    _matches = null;
  });

  Future<void> _run() async {
    if (_busy || _query.text.trim().isEmpty) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
      _matches = null;
    });
    try {
      final matches = await ref.read(jsonQueryProvider)(
        widget.source,
        widget.root,
        _query.text,
      );
      if (!mounted || request != _request) return;
      setState(() => _matches = matches);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } on FormatException catch (error) {
      if (!mounted || request != _request) return;
      setState(
        () => _error = AppLocalizations.of(
          context,
        ).invalidJsonQuery((error.offset ?? 0) + 1),
      );
    } on Exception {
      if (!mounted || request != _request) return;
      setState(() => _error = AppLocalizations.of(context).jsonQueryFailed);
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final query = _query.text.trim();
    if (query.isEmpty || _savingFavorite) return;
    final saved = ref.read(toolPreferencesProvider).queries.contains(query);
    setState(() {
      _savingFavorite = true;
      _favoriteSaveFailed = false;
    });
    final success = await ref
        .read(toolPreferencesProvider.notifier)
        .setQuerySaved(query, saved: !saved);
    if (mounted) {
      setState(() {
        _savingFavorite = false;
        _favoriteSaveFailed = !success;
      });
    }
  }

  void _useFavorite(String query) {
    _query.text = query;
    _changed(query);
    _run();
  }

  void _extract() {
    final matches = _matches;
    if (matches == null || _busy) return;
    final values = matches.map(
      (match) =>
          widget.source.substring(match.node.range.start, match.node.range.end),
    );
    Navigator.pop(context, JsonQueryResult.extract('[${values.join(',')}]'));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final matches = _matches;
    final favorites = ref.watch(toolPreferencesProvider).queries;
    final saved = favorites.contains(_query.text.trim());
    return WorkbenchDialog(
      title: strings.jsonQuery,
      scrollable: false,
      content: SizedBox(
        width: (size.width - 120).clamp(240.0, 900.0),
        height: (size.height * .6).clamp(180.0, 560.0),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .55,
                ),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: WorkbenchTextField(
                              autofocus: true,
                              controller: _query,
                              onChanged: _changed,
                              onSubmitted: (_) => _run(),
                              style: ReadingStyle.of(context).text,
                              hintText: r'$.items[?(@.price >= 100)]',
                              errorText: _error,
                              errorMaxLines: 2,
                            ),
                          ),
                          const SizedBox(width: WorkbenchStyle.space8),
                          TextButton(
                            style: workbenchDialogButtonStyle(context),
                            onPressed: _busy || _query.text.trim().isEmpty
                                ? null
                                : _run,
                            child: Text(strings.runQuery),
                          ),
                        ],
                      ),
                      const SizedBox(height: WorkbenchStyle.space8),
                      Row(
                        children: [
                          IconButton(
                            tooltip: saved
                                ? strings.unsaveQuery
                                : strings.saveQuery,
                            icon: Icon(
                              saved
                                  ? CupertinoIcons.star_fill
                                  : CupertinoIcons.star,
                              size: WorkbenchStyle.controlIconSize,
                            ),
                            onPressed:
                                _savingFavorite || _query.text.trim().isEmpty
                                ? null
                                : _toggleFavorite,
                          ),
                          PopupMenuButton<String>(
                            tooltip: strings.savedQueries,
                            icon: const Icon(
                              CupertinoIcons.bookmark,
                              size: WorkbenchStyle.controlIconSize,
                            ),
                            onSelected: _useFavorite,
                            itemBuilder: (_) => favorites.isEmpty
                                ? [
                                    PopupMenuItem(
                                      enabled: false,
                                      child: Text(strings.noSavedQueries),
                                    ),
                                  ]
                                : [
                                    for (final query in favorites)
                                      PopupMenuItem(
                                        value: query,
                                        height: ReadingStyle.of(
                                          context,
                                        ).rowHeight(),
                                        child: Tooltip(
                                          message: query,
                                          child: Text(
                                            query,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: ReadingStyle.of(
                                              context,
                                            ).text,
                                          ),
                                        ),
                                      ),
                                  ],
                          ),
                          Expanded(
                            child: Text(
                              strings.jsonQueryHelp,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      if (_favoriteSaveFailed)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            strings.toolPreferenceFailed,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      const SizedBox(height: WorkbenchStyle.space12),
                    ],
                  ),
                ),
              ),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              if (matches != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: WorkbenchStyle.space8),
                  child: Text(
                    strings.queryResultCount(matches.length),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              Expanded(
                child: matches == null || matches.isEmpty
                    ? Center(
                        child: Text(
                          _busy
                              ? strings.queryRunning
                              : matches == null
                              ? ''
                              : strings.noMatches,
                        ),
                      )
                    : Scrollbar(
                        controller: _scroll,
                        child: ListView.builder(
                          controller: _scroll,
                          itemCount: matches.length,
                          itemExtent: math.max(
                            56,
                            ReadingStyle.of(context).lineHeight * 2 + 24,
                          ),
                          itemBuilder: (context, index) {
                            final match = matches[index];
                            final range = match.node.range;
                            final preview = widget.source.substring(
                              range.start,
                              (range.start + 160).clamp(range.start, range.end),
                            );
                            return Material(
                              color: index.isOdd
                                  ? colors.surfaceContainer
                                  : colors.surface,
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: WorkbenchStyle.space8,
                                ),
                                title: Text(
                                  match.path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ReadingStyle.of(context).text,
                                ),
                                subtitle: Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ReadingStyle.of(context).text,
                                ),
                                minVerticalPadding: 8,
                                trailing: Icon(
                                  CupertinoIcons.location,
                                  size: WorkbenchStyle.controlIconSize,
                                  color: colors.onSurfaceVariant,
                                ),
                                onTap: () => Navigator.pop(
                                  context,
                                  JsonQueryResult.reveal(range),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: matches == null || _busy ? null : _extract,
          child: Text(strings.extractQueryResults),
        ),
        FilledButton(
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.done),
        ),
      ],
    );
  }
}
