part of 'workbench.dart';

class _PathDialog extends StatefulWidget {
  const _PathDialog({required this.root});

  final JsonNode root;

  @override
  State<_PathDialog> createState() => _PathDialogState();
}

class _PathDialogState extends State<_PathDialog> {
  final _path = TextEditingController();
  JsonPathStatus? _error;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  void _submit() {
    final result = resolveJsonPath(widget.root, _path.text);
    if (result.status == JsonPathStatus.found) {
      Navigator.pop(context, result.range);
    } else {
      setState(() => _error = result.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return WorkbenchDialog(
      title: strings.goToJsonPath,
      content: SizedBox(
        width: 400,
        child: WorkbenchTextField(
          autofocus: true,
          controller: _path,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
          style: ReadingStyle.of(context).text,
          hintText: r'$["items"][0]',
          errorText: switch (_error) {
            JsonPathStatus.invalid => strings.invalidJsonPath,
            JsonPathStatus.missing => strings.missingJsonPath,
            JsonPathStatus.ambiguous => strings.ambiguousJsonPath,
            _ => null,
          },
        ),
      ),
      actions: [
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          onPressed: _submit,
          child: Text(strings.goToNode),
        ),
      ],
    );
  }
}

class _NodeEditor extends StatefulWidget {
  const _NodeEditor({
    required this.value,
    required this.keyName,
    required this.highlight,
    this.addTo,
    this.formatOptions = const JsonFormatOptions(),
  });
  final String value;
  final bool keyName;
  final JsonKind? addTo;
  final JsonFormatOptions formatOptions;
  final JsonHighlight highlight;

  @override
  State<_NodeEditor> createState() => _NodeEditorState();
}

class _NodeEditorState extends State<_NodeEditor> {
  late final String _initialValue = _formatValue(widget.value);
  late String _value = _initialValue;
  late final TextEditingController? _keyText = widget.keyName
      ? TextEditingController(text: widget.value)
      : null;
  final _property = TextEditingController();
  JsonDiagnostic? _error;
  bool _requiresString = false;

  String _formatValue(String source) {
    final snapshot = parseJson(source);
    return snapshot.root == null
        ? source
        : rewriteJson(
            JsonDocument(SourceBuffer(source), snapshot: snapshot),
            options: widget.formatOptions,
          );
  }

  void _submit() {
    final text = _keyText?.text ?? _value;
    final snapshot = parseJson(text);
    final node = snapshot.root;
    if (node == null || (widget.keyName && node.kind != JsonKind.string)) {
      setState(() {
        _error = snapshot.diagnostics.firstOrNull;
        _requiresString = node != null;
      });
      return;
    }
    final value = !widget.keyName && text == _initialValue
        ? widget.value
        : text.substring(node.range.start, node.range.end);
    Navigator.pop(
      context,
      widget.addTo == JsonKind.object
          ? '${jsonEncode(_property.text)}: $value'
          : value,
    );
  }

  @override
  void dispose() {
    _keyText?.dispose();
    _property.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final error = _requiresString
        ? strings.quotedString
        : _error == null
        ? null
        : strings.diagnosticMessage(_error!);
    return WorkbenchDialog(
      title: switch (widget.addTo) {
        JsonKind.object => strings.addProperty,
        JsonKind.array => strings.addArrayItem,
        _ => widget.keyName ? strings.renameKey : strings.replaceJsonValue,
      },
      content: SizedBox(
        width: 480,
        child: widget.keyName
            ? WorkbenchTextField(
                controller: _keyText,
                autofocus: true,
                style: ReadingStyle.of(context).text,
                errorText: error,
                onSubmitted: (_) => _submit(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.addTo == JsonKind.object) ...[
                    WorkbenchTextField(
                      controller: _property,
                      autofocus: true,
                      labelText: strings.propertyName,
                    ),
                    const SizedBox(height: WorkbenchStyle.space12),
                  ],
                  Material(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        WorkbenchStyle.controlRadius,
                      ),
                      side: BorderSide(
                        color: error == null
                            ? colors.outlineVariant
                            : colors.error,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: (MediaQuery.sizeOf(context).height * .38).clamp(
                        100.0,
                        280.0,
                      ),
                      child: EJsonCodeEditor(
                        source: _value,
                        highlight: widget.highlight,
                        readOnly: false,
                        useWorkspaceShortcuts: false,
                        onChanged: (text) {
                          _value = text;
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: workbenchDialogButtonStyle(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          style: workbenchDialogButtonStyle(
            context,
            role: DialogButtonRole.primary,
          ),
          child: Text(strings.apply),
        ),
      ],
    );
  }
}
