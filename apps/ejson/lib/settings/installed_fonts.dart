import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InstalledFont {
  const InstalledFont({
    required this.family,
    required this.name,
    required this.monospace,
  });

  final String family;
  final String name;
  final bool monospace;
}

final installedFontsProvider = FutureProvider<List<InstalledFont>>((ref) async {
  final values = await const MethodChannel(
    'dev.ekko.ejson/fonts',
  ).invokeListMethod<dynamic>('list');
  final fonts = <String, InstalledFont>{};
  for (final value in values ?? const []) {
    if (value is! Map || value['family'] is! String) continue;
    final family = (value['family'] as String).trim();
    if (family.isEmpty) continue;
    final name = value['name'];
    fonts[family.toLowerCase()] = InstalledFont(
      family: family,
      name: name is String && name.isNotEmpty ? name : family,
      monospace: value['monospace'] == true,
    );
  }
  final sorted = fonts.values.toList()
    ..sort((a, b) {
      if (a.monospace != b.monospace) return a.monospace ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return List.unmodifiable(sorted);
}, retry: (_, _) => null);

InstalledFont? findInstalledFont(List<InstalledFont>? fonts, String? family) =>
    family == null
    ? null
    : fonts
          ?.where((font) => font.family.toLowerCase() == family.toLowerCase())
          .firstOrNull;
