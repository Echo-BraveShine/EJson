import '../design/workbench_text_field.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/workbench_style.dart';
import '../l10n/app_localizations.dart';
import 'installed_fonts.dart';

typedef FontChoice = ({String? family});

class FontPicker extends ConsumerStatefulWidget {
  const FontPicker({super.key, required this.selected});

  final String? selected;

  @override
  ConsumerState<FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends ConsumerState<FontPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final fonts = ref.watch(installedFontsProvider);
    final query = _search.text.toLowerCase();
    final matches = fonts.value
        ?.where(
          (font) =>
              font.family.toLowerCase().contains(query) ||
              font.name.toLowerCase().contains(query),
        )
        .toList();
    return WorkbenchDialog(
      title: strings.readingFont,
      scrollable: false,
      content: SizedBox(
        width: 460,
        height: (MediaQuery.sizeOf(context).height * .5).clamp(160.0, 440.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: WorkbenchTextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    hintText: strings.searchFonts,
                    prefixIcon: const Icon(
                      CupertinoIcons.search,
                      size: WorkbenchStyle.controlIconSize,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: strings.refreshFonts,
                  onPressed: () => ref.invalidate(installedFontsProvider),
                  icon: const Icon(
                    CupertinoIcons.arrow_clockwise,
                    size: WorkbenchStyle.controlIconSize,
                  ),
                ),
              ],
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(strings.defaultReadingFont),
              trailing: widget.selected == null
                  ? const Icon(CupertinoIcons.checkmark, size: 16)
                  : null,
              onTap: () => Navigator.pop(context, (family: null)),
            ),
            const Divider(height: 1),
            Expanded(
              child: fonts.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : fonts.hasError
                  ? Center(child: Text(strings.fontListFailed))
                  : matches == null || matches.isEmpty
                  ? Center(child: Text(strings.noMatchingFonts))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final font = matches[index];
                        final selected =
                            font.family.toLowerCase() ==
                            widget.selected?.toLowerCase();
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: WorkbenchStyle.space4,
                          ),
                          title: Text(
                            font.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: font.monospace
                              ? Text(strings.monospaceFont)
                              : null,
                          trailing: selected
                              ? const Icon(CupertinoIcons.checkmark, size: 16)
                              : Text(
                                  'Abc 123',
                                  style: TextStyle(
                                    fontFamily: font.family,
                                    fontSize: 13,
                                  ),
                                ),
                          onTap: () =>
                              Navigator.pop(context, (family: font.family)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: workbenchDialogButtonStyle(context),
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
      ],
    );
  }
}
