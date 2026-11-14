const maxRecentFiles = 20;

class RecentFile {
  const RecentFile(this.path, {this.bookmark});

  final String path;
  final String? bookmark;

  String get name =>
      Uri.file(
        path,
      ).pathSegments.where((segment) => segment.isNotEmpty).lastOrNull ??
      path;

  static RecentFile? fromJson(Object? value) {
    if (value is! Map || value['path'] is! String) return null;
    final path = value['path'] as String;
    if (path.isEmpty) return null;
    final bookmark = value['bookmark'];
    return RecentFile(
      path,
      bookmark: bookmark is String && bookmark.isNotEmpty ? bookmark : null,
    );
  }

  Map<String, String> toJson() => {'path': path, 'bookmark': ?bookmark};
}
