enum DocumentFormat {
  json('JSON', 'json'),
  yaml('YAML', 'yaml'),
  csv('CSV', 'csv'),
  xml('XML', 'xml'),
  toml('TOML', 'toml');

  const DocumentFormat(this.label, this.extension);
  final String label;
  final String extension;

  static DocumentFormat fromPath(String path) =>
      switch (path.toLowerCase().split('.').last) {
        'yaml' || 'yml' => yaml,
        'csv' => csv,
        'xml' => xml,
        'toml' => toml,
        _ => json,
      };
}
