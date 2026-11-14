part of 'conversion_dialog.dart';

extension _ConversionExecution on _ConversionDialogState {
  Future<void> _convert() async {
    final number = int.tryParse(_document.text);
    if (_direction == ConversionDirection.yamlToJson &&
        (number == null || number < 1)) {
      _updateView(
        () => _error = AppLocalizations.of(context).conversionDocumentError,
      );
      return;
    }
    final generation = ++_generation;
    final job = ConversionJob();
    _job = job;
    _updateView(() {
      _busy = true;
      _error = null;
      _output = null;
    });
    try {
      final result = await job.run(
        ConversionRequest(
          widget.source,
          _direction,
          indent: _indent,
          document: (number ?? 1) - 1,
          flatten: _flatten,
          delimiter: _delimiter,
          header: _header,
          crlf: _crlf,
          bom: _bom,
          csvPath: _csvPath.text,
          importColumns: _direction == ConversionDirection.csvToJson
              ? _importColumns
              : null,
          emptyCells: _emptyCells,
          xmlRoot: _xmlRoot.text.trim(),
          xmlMapping: _xmlMapping,
          columns: _columnsKnown
              ? _order.where(_included.contains).toList()
              : null,
        ),
      );
      if (!mounted || generation != _generation) return;
      _updateView(() {
        _output = result;
        if (!_columnsKnown && _direction == ConversionDirection.jsonToCsv) {
          _order = List.of(result.columns);
          _included.addAll(_order);
          _columnsKnown = true;
        }
      });
    } on ConversionCancelled {
      /* The input or options changed, or the user cancelled. */
    } catch (error) {
      if (mounted && generation == _generation) {
        _updateView(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        _updateView(() {
          _busy = false;
          _job = null;
        });
      }
    }
  }
}
