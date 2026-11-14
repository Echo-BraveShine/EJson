import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';

class FileDropZone extends StatefulWidget {
  const FileDropZone({
    super.key,
    required this.enabled,
    required this.onDrop,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<DropDoneDetails> onDrop;
  final Widget child;

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _hovered = false;

  bool get _enabled =>
      widget.enabled && (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void didUpdateWidget(covariant FileDropZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _hovered = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) _hovered = false;
  }

  void _hover(bool value) {
    if (!_enabled || value == _hovered) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DropTarget(
      enable: _enabled,
      onDragEntered: (_) => _hover(true),
      onDragExited: (_) => _hover(false),
      onDragDone: (details) {
        if (!_enabled) return;
        _hover(false);
        widget.onDrop(details);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_hovered && _enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(WorkbenchStyle.space8),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(
                      WorkbenchStyle.groupRadius,
                    ),
                    border: Border.all(color: colors.primary, width: 2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.doc_on_doc,
                          color: colors.primary,
                          size: 32,
                        ),
                        const SizedBox(height: WorkbenchStyle.space12),
                        Text(
                          AppLocalizations.of(context).dropFilesToOpen,
                          style: WorkbenchStyle.heading,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
