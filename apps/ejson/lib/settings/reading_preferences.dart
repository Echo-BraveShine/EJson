enum ReadingLineSpacing {
  compact(1.2),
  standard(1.4),
  spacious(1.8);

  const ReadingLineSpacing(this.height);
  final double height;
}

class ReadingPreferences {
  const ReadingPreferences({
    this.fontFamily,
    this.fontSize = 13,
    this.lineSpacing = ReadingLineSpacing.standard,
  }) : assert(fontSize >= 10 && fontSize <= 32);

  factory ReadingPreferences.fromJson(Object? value) {
    if (value is! Map) return const ReadingPreferences();
    final family = value['fontFamily'];
    final size = value['fontSize'];
    return ReadingPreferences(
      fontFamily: family is String && family.trim().isNotEmpty
          ? family.trim()
          : null,
      fontSize: size is num && size.isFinite ? size.round().clamp(10, 32) : 13,
      lineSpacing:
          ReadingLineSpacing.values
              .where((spacing) => spacing.name == value['lineSpacing'])
              .firstOrNull ??
          ReadingLineSpacing.standard,
    );
  }

  final String? fontFamily;
  final int fontSize;
  final ReadingLineSpacing lineSpacing;

  ReadingPreferences withFont(String? family) => ReadingPreferences(
    fontFamily: family,
    fontSize: fontSize,
    lineSpacing: lineSpacing,
  );
  ReadingPreferences withSize(int size) => ReadingPreferences(
    fontFamily: fontFamily,
    fontSize: size,
    lineSpacing: lineSpacing,
  );
  ReadingPreferences withSpacing(ReadingLineSpacing spacing) =>
      ReadingPreferences(
        fontFamily: fontFamily,
        fontSize: fontSize,
        lineSpacing: spacing,
      );

  Map<String, Object?> toJson() => {
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'lineSpacing': lineSpacing.name,
  };
}
