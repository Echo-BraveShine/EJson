import '../design/workbench_text_field.dart';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';

enum WorkbenchCommandId {
  newTab,
  open,
  recentFiles,
  save,
  saveAs,
  closeTab,
  undo,
  redo,
  find,
  format,
  repair,
  minify,
  escape,
  unescape,
  jsonPath,
  jsonQuery,
  compare,
  arrayTable,
  sortArray,
  convert,
  schema,
  redact,
  settings,
  newYaml,
  newCsv,
  newXml,
  newToml,
  newJsonLines,
}

class WorkbenchCommand {
  const WorkbenchCommand({
    required this.id,
    required this.label,
    required this.icon,
    required this.action,
    this.shortcut,
    this.keywords = '',
  });

  final WorkbenchCommandId id;
  final String label;
  final IconData icon;
  final VoidCallback? action;
  final String? shortcut;
  final String keywords;
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.commands});

  final List<WorkbenchCommand> commands;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late List<WorkbenchCommand> _matches;
  int _selected = -1;
  bool _choosing = false;

  double get _rowHeight => math.max(
    WorkbenchStyle.rowHeight,
    MediaQuery.textScalerOf(context).scale(WorkbenchStyle.body.fontSize!) *
            WorkbenchStyle.body.height! +
        WorkbenchStyle.space12,
  );

  @override
  void initState() {
    super.initState();
    _filter();
  }

  @override
  void didUpdateWidget(covariant CommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    _filter(preserveSelection: true);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filter({bool preserveSelection = false}) {
    final selected = preserveSelection && _selected >= 0
        ? _matches[_selected].id
        : null;
    final terms = _search.text.trim().toLowerCase().split(RegExp(r'\s+'));
    _matches = widget.commands.where((command) {
      final text = '${command.label} ${command.keywords}'.toLowerCase();
      return terms.every(text.contains);
    }).toList();
    _selected = _matches.indexWhere(
      (command) => command.id == selected && command.action != null,
    );
    if (_selected < 0) {
      _selected = _matches.indexWhere((command) => command.action != null);
    }
  }

  void _move(int direction) {
    final enabled = [
      for (var index = 0; index < _matches.length; index++)
        if (_matches[index].action != null) index,
    ];
    if (enabled.isEmpty) return;
    setState(() {
      final position = enabled.indexOf(_selected);
      _selected = enabled[(position + direction) % enabled.length];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final top = _selected * _rowHeight;
      final bottom = top + _rowHeight;
      var offset = _scroll.offset;
      if (top < offset) offset = top;
      if (bottom > offset + _scroll.position.viewportDimension) {
        offset = bottom - _scroll.position.viewportDimension;
      }
      _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  void _choose(int index) {
    if (_choosing || index < 0 || _matches[index].action == null) return;
    _choosing = true;
    Navigator.pop(context, _matches[index].id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter): () =>
            _choose(_selected),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: WorkbenchDialog(
        title: strings.commandPalette,
        scrollable: false,
        content: SizedBox(
          width: 560,
          height: (MediaQuery.sizeOf(context).height * .6).clamp(200.0, 500.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkbenchTextField(
                autofocus: true,
                controller: _search,
                onChanged: (_) {
                  setState(_filter);
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                },
                onSubmitted: (_) => _choose(_selected),
                hintText: strings.searchCommands,
                prefixIcon: const Icon(
                  CupertinoIcons.search,
                  size: WorkbenchStyle.controlIconSize,
                ),
              ),
              const SizedBox(height: WorkbenchStyle.space8),
              Expanded(
                child: _matches.isEmpty
                    ? Center(child: Text(strings.noMatchingCommands))
                    : Scrollbar(
                        controller: _scroll,
                        child: ListView.builder(
                          controller: _scroll,
                          itemExtent: _rowHeight,
                          itemCount: _matches.length,
                          itemBuilder: (context, index) {
                            final command = _matches[index];
                            final enabled = command.action != null;
                            final selected = index == _selected;
                            final foreground = !enabled
                                ? colors.onSurface.withValues(alpha: .38)
                                : selected
                                ? colors.onSecondaryContainer
                                : colors.onSurface;
                            return Semantics(
                              button: true,
                              enabled: enabled,
                              selected: selected,
                              child: Material(
                                borderRadius: BorderRadius.circular(
                                  WorkbenchStyle.controlRadius,
                                ),
                                clipBehavior: Clip.antiAlias,
                                color: selected
                                    ? colors.secondaryContainer
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: enabled ? () => _choose(index) : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: WorkbenchStyle.space8,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          command.icon,
                                          size: WorkbenchStyle.controlIconSize,
                                          color: enabled && !selected
                                              ? colors.onSurfaceVariant
                                              : foreground,
                                        ),
                                        const SizedBox(
                                          width: WorkbenchStyle.space12,
                                        ),
                                        Expanded(
                                          child: Text(
                                            command.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: WorkbenchStyle.body.copyWith(
                                              color: foreground,
                                            ),
                                          ),
                                        ),
                                        if (command.shortcut != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: WorkbenchStyle.space8,
                                            ),
                                            child: Text(
                                              command.shortcut!,
                                              style: WorkbenchStyle.caption
                                                  .copyWith(
                                                    color: enabled && !selected
                                                        ? colors
                                                              .onSurfaceVariant
                                                        : foreground,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: WorkbenchStyle.space8),
              Text(
                strings.commandKeyboardHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: workbenchDialogButtonStyle(context),
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
  }
}
