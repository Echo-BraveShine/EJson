import 'package:ejson_core/ejson_core.dart';

import 'local_files.dart';

class RecoveredDocument {
  const RecoveredDocument({
    required this.source,
    required this.format,
    required this.bom,
    this.file,
  });

  final String source;
  final DocumentFormat format;
  final bool bom;
  final LocalJsonFile? file;
}

class RecoveredWorkspace {
  const RecoveredWorkspace({
    required this.documents,
    required this.activeIndex,
    required this.recoveredCount,
    this.failedPaths = const [],
  });

  final List<RecoveredDocument> documents;
  final int activeIndex;
  final int recoveredCount;
  final List<String> failedPaths;
}
