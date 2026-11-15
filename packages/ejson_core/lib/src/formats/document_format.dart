enum DocumentFormat {
  json('JSON', 'json'),
  yaml('YAML', 'yaml'),
  csv('CSV', 'csv'),
  xml('XML', 'xml'),
  toml('TOML', 'toml'),
  jsonLines('JSON Lines', 'jsonl');

  const DocumentFormat(this.label, this.extension);
  final String label;
  final String extension;
  List<String> get extensions => switch (this) {
    yaml => const ['yaml', 'yml'],
    jsonLines => const ['jsonl', 'ndjson'],
    _ => [extension],
  };

  static DocumentFormat fromPath(String path) =>
      switch (path.toLowerCase().split('.').last) {
        'yaml' || 'yml' => yaml,
        'csv' => csv,
        'xml' => xml,
        'toml' => toml,
        'jsonl' || 'ndjson' => jsonLines,
        _ => json,
      };
}
