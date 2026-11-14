part of 'conversion_dialog.dart';

extension _ConversionFormatOptions on _ConversionDialogState {
  List<Widget> _formatOptions() {
    final strings = AppLocalizations.of(context);
    final exportCsv = _direction == ConversionDirection.jsonToCsv;
    final yaml = _direction == ConversionDirection.yamlToJson;
    final notice = switch (_direction) {
      ConversionDirection.yamlToJson => strings.conversionYamlNotice,
      ConversionDirection.jsonToToml ||
      ConversionDirection.tomlToJson => strings.conversionTomlNotice,
      ConversionDirection.jsonToXml => strings.conversionXmlNotice,
      ConversionDirection.xmlToJson => strings.conversionXmlImportNotice,
      _ => '',
    };
    return [
      WorkbenchSelect<ConversionDirection>(
        label: strings.conversionDirection,
        value: _direction,
        options: [
          for (final direction in _directions)
            (value: direction, label: direction.label),
        ],
        onChanged: (direction) {
          _direction = direction;
          _invalidate(resetColumns: true);
        },
      ),
      const SizedBox(height: WorkbenchStyle.space12),
      if (!exportCsv)
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_direction == ConversionDirection.jsonToToml)
              const Spacer()
            else
              Expanded(
                child: WorkbenchSelect<int>(
                  label: strings.formatIndentation,
                  value: _indent,
                  options: [
                    (value: 2, label: strings.indentTwo),
                    (value: 4, label: strings.indentFour),
                    (value: 8, label: strings.indentEight),
                  ],
                  onChanged: (value) {
                    _indent = value;
                    _invalidate();
                  },
                ),
              ),
            if (yaml) ...[
              const SizedBox(width: WorkbenchStyle.space12),
              Expanded(
                child: WorkbenchTextField(
                  controller: _document,
                  keyboardType: TextInputType.number,
                  labelText: strings.conversionDocument,
                  onChanged: (_) => _invalidate(),
                ),
              ),
            ],
            const SizedBox(width: WorkbenchStyle.space8),
            _runButton(),
          ],
        ),
      if (notice.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: WorkbenchStyle.space8),
          child: Text(notice, style: WorkbenchStyle.caption),
        ),
      if (_direction == ConversionDirection.jsonToXml) ...[
        const SizedBox(height: WorkbenchStyle.space12),
        WorkbenchSelect<XmlMappingMode>(
          label: strings.xmlMapping,
          value: _xmlMapping,
          options: [
            (value: XmlMappingMode.typed, label: strings.xmlTypedMapping),
            (value: XmlMappingMode.elements, label: strings.xmlElementMapping),
          ],
          onChanged: (value) {
            _xmlMapping = value;
            _invalidate();
          },
        ),
        if (_xmlMapping == XmlMappingMode.typed) ...[
          const SizedBox(height: WorkbenchStyle.space8),
          WorkbenchTextField(
            controller: _xmlRoot,
            labelText: strings.xmlRootName,
            onChanged: (_) => _invalidate(),
          ),
        ],
      ],
      if (exportCsv) ..._csvOptions(),
      if (_direction == ConversionDirection.csvToJson) ..._csvImportOptions(),
    ];
  }
}
